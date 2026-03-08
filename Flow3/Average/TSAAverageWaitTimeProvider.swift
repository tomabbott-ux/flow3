import Foundation

final class TSAAverageWaitTimeProvider: WaitTimeProviding {

    private struct CacheEntry {
        let waitTimes: [WaitTimeEstimate]
        let fetchedAt: Date
    }

    private let session: URLSession
    private let cacheTTL: TimeInterval = 600

    private static var cache: [FlowAirport: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "TSAAverageWaitTimeProvider.cache")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        // If airport is not TSA supported just return nothing
        guard airport.isTSAAverageAirport else { return [] }

        // If URL missing, fallback immediately
        guard let url = airport.tsaAverageURL else {
            return fallbackWait(for: airport)
        }

        if let cached = Self.cachedEntry(for: airport, ttl: cacheTTL) {
            return cached.waitTimes
        }

        let html = (try? await fetchHTML(url: url)) ?? ""

        let minutes = (try? parseAverageMinutes(from: html)) ?? 12

        let now = Date()

        let results = [
            WaitTimeEstimate(
                airport: airport,
                terminal: 1,
                queueType: .general,
                minutes: max(0, minutes),
                observedAt: now,
                checkpointName: "Terminal 1",
                areaName: "Security",
                sourceType: .estimated
            )
        ]

        Self.storeCache(results, for: airport, fetchedAt: now)

        return results
    }

    private func fallbackWait(for airport: FlowAirport) -> [WaitTimeEstimate] {

        let now = Date()

        return [
            WaitTimeEstimate(
                airport: airport,
                terminal: 1,
                queueType: .general,
                minutes: 12,
                observedAt: now,
                checkpointName: "Terminal 1",
                areaName: "Security",
                sourceType: .estimated
            )
        ]
    }

    private func fetchHTML(url: URL) async throws -> String {

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        let (data, _) = try await session.data(for: request)

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseAverageMinutes(from html: String) throws -> Int {

        let minutesSecondsPattern = #"(\d+)\s+minutes?\s+and\s+(\d+)\s+seconds?"#

        if let regex = try? NSRegularExpression(pattern: minutesSecondsPattern, options: [.caseInsensitive]) {

            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)

            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               let minRange = Range(match.range(at: 1), in: html),
               let secRange = Range(match.range(at: 2), in: html),
               let minutes = Int(html[minRange]),
               let seconds = Int(html[secRange]) {

                return seconds >= 30 ? minutes + 1 : minutes
            }
        }

        let minutesOnlyPattern = #"(\d+)\s+minutes?"#

        if let regex = try? NSRegularExpression(pattern: minutesOnlyPattern, options: [.caseInsensitive]) {

            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)

            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               let minRange = Range(match.range(at: 1), in: html),
               let minutes = Int(html[minRange]) {

                return minutes
            }
        }

        throw NSError(domain: "ParseError", code: 0)
    }

    private static func cachedEntry(for airport: FlowAirport, ttl: TimeInterval) -> CacheEntry? {
        cacheQueue.sync {
            guard let entry = cache[airport] else { return nil }
            let age = Date().timeIntervalSince(entry.fetchedAt)
            return age <= ttl ? entry : nil
        }
    }

    private static func storeCache(_ waitTimes: [WaitTimeEstimate], for airport: FlowAirport, fetchedAt: Date) {
        cacheQueue.sync {
            cache[airport] = CacheEntry(waitTimes: waitTimes, fetchedAt: fetchedAt)
        }
    }
}

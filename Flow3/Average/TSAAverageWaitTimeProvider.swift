import Foundation

final class TSAAverageWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingAverageWait
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport.isTSAAverageAirport else { return [] }
        guard let url = airport.tsaAverageURL else { throw ProviderError.invalidResponse }

        let html = try await fetchHTML(url: url)
        let minutes = try parseAverageMinutes(from: html)

        let now = Date()

        return [
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

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ProviderError.invalidResponse
        }

        return html
    }

    private func parseAverageMinutes(from html: String) throws -> Int {

        // Pattern 1:
        // "3 minutes and 12 seconds"
        let minutesSecondsPattern = #"(\d+)\s+minutes?\s+and\s+(\d+)\s+seconds?"#

        if let regex = try? NSRegularExpression(
            pattern: minutesSecondsPattern,
            options: [.caseInsensitive]
        ) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)

            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               let minRange = Range(match.range(at: 1), in: html),
               let secRange = Range(match.range(at: 2), in: html),
               let minutes = Int(html[minRange]),
               let seconds = Int(html[secRange]) {

                return seconds >= 30 ? minutes + 1 : minutes
            }
        }

        // Pattern 2:
        // "17 minutes"
        let minutesOnlyPattern = #"(\d+)\s+minutes?"#

        if let regex = try? NSRegularExpression(
            pattern: minutesOnlyPattern,
            options: [.caseInsensitive]
        ) {
            let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)

            if let match = regex.firstMatch(in: html, options: [], range: nsrange),
               let minRange = Range(match.range(at: 1), in: html),
               let minutes = Int(html[minRange]) {

                return minutes
            }
        }

        throw ProviderError.missingAverageWait
    }
}

import Foundation

final class TSAWebsiteWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case unsupportedAirport
        case invalidURL
        case badHTTPStatus(Int)
        case invalidHTML
        case noWaitTimeFound
    }

    private struct CacheEntry {
        let waitTimes: [WaitTimeEstimate]
        let fetchedAt: Date
    }

    private struct ParsedCheckpointRow: Hashable {
        let title: String
        let subtitle: String
        let minutes: Int
        let queueType: QueueType
    }

    private let session: URLSession
    private let cacheTTL: TimeInterval = 180

    private static var cache: [FlowAirport: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "TSAWebsiteWaitTimeProvider.cache")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard isSupported(airport) else {
            throw ProviderError.unsupportedAirport
        }

        if let cached = Self.cachedEntry(for: airport, ttl: cacheTTL) {
            return cached.waitTimes
        }

        guard let url = websiteURL(for: airport) else {
            throw ProviderError.invalidURL
        }

        let html = try await fetchHTML(from: url)
        let now = Date()

        let checkpointRows = parseTerminalWaitTimes(from: html, airport: airport)

        guard !checkpointRows.isEmpty else {
            throw ProviderError.noWaitTimeFound
        }

        let results = checkpointRows.map { row in
            WaitTimeEstimate(
                airport: airport,
                terminal: nil,
                queueType: row.queueType,
                minutes: row.minutes,
                observedAt: now,
                checkpointName: row.title,
                areaName: row.subtitle,
                sourceType: .predicted
            )
        }

        Self.storeCache(results, for: airport, fetchedAt: now)
        return results
    }

    private func isSupported(_ airport: FlowAirport) -> Bool {
        switch airport {
        case .msp:
            return true
        default:
            return false
        }
    }

    private func websiteURL(for airport: FlowAirport) -> URL? {
        switch airport {
        case .msp:
            return URL(string: "https://www.mspairport.com/airport/security-screening/security-wait-times")
        default:
            return nil
        }
    }

    private func fetchHTML(from url: URL) async throws -> String {

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidHTML
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ProviderError.invalidHTML
        }

        return html
    }

    private func parseTerminalWaitTimes(from html: String, airport: FlowAirport) -> [ParsedCheckpointRow] {
        switch airport {
        case .msp:
            return parseMSPCheckpointRows(from: html)
        default:
            return []
        }
    }

    private func parseMSPCheckpointRows(from html: String) -> [ParsedCheckpointRow] {

        let normalized = normalizeHTML(html)

        let mappings: [(label: String, title: String, queueType: QueueType)] = [
            ("T1 NORTH", "T1 North", .general),
            ("T1 SOUTH", "T1 South", .general),
            ("T2 CHECKPOINT 1", "T2 Checkpoint 1", .general),
            ("T2 CHECKPOINT 2", "T2 PreCheck", .precheck)
        ]

        var rows: [ParsedCheckpointRow] = []

        for mapping in mappings {
            let escaped = NSRegularExpression.escapedPattern(for: mapping.label)
            let pattern = escaped + #".{0,700}?(Less than\s+\d+\s+minutes|\d+\s+minutes)"#

            if let match = firstMatch(
                pattern: pattern,
                in: normalized,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                let phrase = match[0]

                if let minutesMatch = firstMatch(
                    pattern: #"Less than\s+(\d+)\s+minutes|(\d+)\s+minutes"#,
                    in: phrase,
                    options: [.caseInsensitive]
                ) {
                    let value = minutesMatch.first { !$0.isEmpty } ?? "0"
                    let minutes = Int(value) ?? 0

                    rows.append(
                        ParsedCheckpointRow(
                            title: mapping.title,
                            subtitle: "Minneapolis",
                            minutes: minutes,
                            queueType: mapping.queueType
                        )
                    )
                }
            }
        }

        return rows
    }

    private func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func firstMatch(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [.caseInsensitive]
    ) -> [String]? {

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        var values: [String] = []

        for index in 1..<match.numberOfRanges {
            let r = match.range(at: index)

            if let sr = Range(r, in: text) {
                values.append(String(text[sr]))
            }
        }

        return values
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

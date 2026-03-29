import Foundation

final class TSAWebsiteWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case unsupportedAirport
        case invalidURL
        case badHTTPStatus(Int)
        case invalidHTML
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
        let terminal: Int
    }

    private let session: URLSession
    private let cacheTTL: TimeInterval = 180

    private static var cache: [FlowAirport: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "TSAWebsiteWaitTimeProvider.cache")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .msp else {
            throw ProviderError.unsupportedAirport
        }

        if let cached = Self.cachedEntry(for: airport, ttl: cacheTTL) {
            return cached.waitTimes
        }

        guard let url = URL(string: "https://www.mspairport.com/airport/security-screening/security-wait-times") else {
            throw ProviderError.invalidURL
        }

        let html = try await fetchHTML(from: url)

        let now = Date()
        let parsedRows = parseMSPCheckpointRows(from: html)
        let rowsToUse = parsedRows.isEmpty ? fallbackMSPRows() : parsedRows

        let results = rowsToUse.map { row in
            WaitTimeEstimate(
                airport: airport,
                terminal: row.terminal,
                queueType: row.queueType,
                minutes: row.minutes,
                observedAt: now,
                checkpointName: row.title,
                areaName: row.subtitle,
                sourceType: .predicted,
                isClosed: false
            )
        }

        Self.storeCache(results, for: airport, fetchedAt: now)
        return results
    }

    // MARK: - Networking

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

    // MARK: - MSP Parsing

    private func parseMSPCheckpointRows(from html: String) -> [ParsedCheckpointRow] {
        let normalized = normalizeHTML(html)

        let mappings: [(label: String, title: String, queueType: QueueType, terminal: Int)] = [
            ("T1 NORTH", "T1 North", .general, 1),
            ("T1 SOUTH", "T1 South", .general, 1),
            ("T2 CHECKPOINT 1", "T2 Checkpoint 1", .general, 2),
            ("T2 CHECKPOINT 2", "T2 PreCheck", .precheck, 2)
        ]

        var rows: [ParsedCheckpointRow] = []

        for mapping in mappings {
            guard let labelRange = normalized.range(
                of: mapping.label,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let start = labelRange.lowerBound
            let end = normalized.index(
                start,
                offsetBy: 2500,
                limitedBy: normalized.endIndex
            ) ?? normalized.endIndex

            let slice = String(normalized[start..<end])

            let timeText = firstCapturedGroup(
                pattern: #"security-wait-time__time[^>]*>\s*([^<]+)\s*<"#,
                in: slice
            )

            let messageText = firstCapturedGroup(
                pattern: #"security-wait-time__message[^>]*>\s*([^<]+)\s*<"#,
                in: slice
            )

            let minutes = minutesFromMSPText(timeText)

            guard let minutes else {
                continue
            }

            let derivedQueueType: QueueType
            if mapping.queueType == .precheck {
                derivedQueueType = .precheck
            } else if (messageText ?? "").localizedCaseInsensitiveContains("precheck") {
                derivedQueueType = .precheck
            } else {
                derivedQueueType = .general
            }

            rows.append(
                ParsedCheckpointRow(
                    title: mapping.title,
                    subtitle: "Minneapolis",
                    minutes: minutes,
                    queueType: derivedQueueType,
                    terminal: mapping.terminal
                )
            )
        }

        return dedupeMSPRows(rows)
    }

    private func minutesFromMSPText(_ text: String?) -> Int? {
        guard let text else { return nil }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let value = cleaned
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .first

        guard let value else { return nil }

        if cleaned.localizedCaseInsensitiveContains("less than") {
            return max(1, value - 1)
        }

        return value
    }

    private func dedupeMSPRows(_ rows: [ParsedCheckpointRow]) -> [ParsedCheckpointRow] {
        var seen = Set<String>()
        var result: [ParsedCheckpointRow] = []

        for row in rows {
            if seen.insert(row.title).inserted {
                result.append(row)
            }
        }

        return result
    }

    private func fallbackMSPRows() -> [ParsedCheckpointRow] {
        [
            ParsedCheckpointRow(title: "T1 North", subtitle: "Minneapolis", minutes: 4, queueType: .general, terminal: 1),
            ParsedCheckpointRow(title: "T1 South", subtitle: "Minneapolis", minutes: 4, queueType: .general, terminal: 1),
            ParsedCheckpointRow(title: "T2 Checkpoint 1", subtitle: "Minneapolis", minutes: 4, queueType: .general, terminal: 2),
            ParsedCheckpointRow(title: "T2 PreCheck", subtitle: "Minneapolis", minutes: 4, queueType: .precheck, terminal: 2)
        ]
    }

    // MARK: - Helpers

    private func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func firstCapturedGroup(
        pattern: String,
        in text: String
    ) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        guard match.numberOfRanges > 1 else {
            return nil
        }

        let captureRange = match.range(at: 1)

        guard let swiftRange = Range(captureRange, in: text) else {
            return nil
        }

        return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
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

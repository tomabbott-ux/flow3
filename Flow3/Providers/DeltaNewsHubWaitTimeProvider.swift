import Foundation

final class DeltaNewsHubWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case unsupportedAirport
        case invalidURL
        case badHTTPStatus(Int)
        case invalidHTML
        case airportBlockNotFound
    }

    private struct CacheEntry {
        let waitTimes: [WaitTimeEstimate]
        let fetchedAt: Date
    }

    private struct ParsedRow {
        let checkpointName: String
        let areaName: String
        let minutes: Int
        let queueType: QueueType
        let terminal: Int?
    }

    private let session: URLSession
    private let cacheTTL: TimeInterval = 180

    private static var cache: [FlowAirport: CacheEntry] = [:]
    private static let cacheQueue = DispatchQueue(label: "DeltaNewsHubWaitTimeProvider.cache")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .msp || airport == .dtw || airport == .lax else {
            throw ProviderError.unsupportedAirport
        }

        if let cached = Self.cachedEntry(for: airport, ttl: cacheTTL) {
            return cached.waitTimes
        }

        guard let url = URL(string: "https://news.delta.com/airport-wait-times") else {
            throw ProviderError.invalidURL
        }

        let html = try await fetchHTML(from: url)
        let now = Date()

        let parsedRows: [ParsedRow]

        switch airport {
        case .msp:
            parsedRows = try parseMSPRows(from: html)

        case .dtw:
            parsedRows = try parseDTWRows(from: html)

        case .lax:
            parsedRows = try parseLAXRows(from: html)

        default:
            parsedRows = []
        }

        let results = parsedRows.map { row in
            WaitTimeEstimate(
                airport: airport,
                terminal: row.terminal,
                queueType: row.queueType,
                minutes: row.minutes,
                observedAt: now,
                checkpointName: row.checkpointName,
                areaName: row.areaName,
                sourceType: .live,
                isClosed: false
            )
        }

        print("✅ DELTA FINAL RESULTS for \(airport.rawValue):", results)

        Self.storeCache(results, for: airport, fetchedAt: now)
        return results
    }

    // MARK: - Networking

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://news.delta.com/airport-wait-times", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidHTML
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ProviderError.invalidHTML
        }

        return html
    }

    // MARK: - MSP

    private func parseMSPRows(from html: String) throws -> [ParsedRow] {
        let normalized = normalizeHTML(html)
        let block = try airportBlock(for: "MSP", in: normalized)

        let rowMatches = matches(
            pattern: #"<tr>\s*<td>\s*(.*?)\s*</td>\s*<td(?: class="([^"]*)")?>\s*(.*?)\s*</td>\s*<td>\s*(.*?)\s*</td>\s*</tr>"#,
            in: block,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        var rows: [ParsedRow] = []

        for rowMatch in rowMatches {
            let rawCheckpoint = decodeHTML(rowMatch[safe: 0] ?? "")
            let rawWait = decodeHTML(rowMatch[safe: 2] ?? "")
            let rawStatus = decodeHTML(rowMatch[safe: 3] ?? "")

            guard let minutes = minutesFromText(rawWait) else { continue }

            let checkpoint = cleanText(rawCheckpoint)
            let terminal = terminalFromMSPCheckpoint(checkpoint)

            let queueType: QueueType = rawStatus.localizedCaseInsensitiveContains("precheck")
                ? .precheck
                : .general

            rows.append(
                ParsedRow(
                    checkpointName: checkpoint,
                    areaName: terminal == 2 ? "Terminal 2" : "Terminal 1",
                    minutes: minutes,
                    queueType: queueType,
                    terminal: terminal
                )
            )
        }

        return rows.sorted(by: mspSort)
    }

    private func terminalFromMSPCheckpoint(_ checkpoint: String) -> Int? {
        let value = checkpoint.uppercased()

        if value.hasPrefix("T1") { return 1 }
        if value.hasPrefix("T2") { return 2 }

        return nil
    }

    private func mspSort(_ lhs: ParsedRow, _ rhs: ParsedRow) -> Bool {
        let lhsTerminal = lhs.terminal ?? 999
        let rhsTerminal = rhs.terminal ?? 999

        if lhsTerminal != rhsTerminal {
            return lhsTerminal < rhsTerminal
        }

        let order = [
            "T1 North",
            "T1 South",
            "T2 Checkpoint 1",
            "T2 Checkpoint 2"
        ]

        let lhsIndex = order.firstIndex(of: lhs.checkpointName) ?? 999
        let rhsIndex = order.firstIndex(of: rhs.checkpointName) ?? 999

        return lhsIndex < rhsIndex
    }

    // MARK: - DTW

    private func parseDTWRows(from html: String) throws -> [ParsedRow] {
        let textOnly = htmlToCleanText(html)

        guard let mcnamaraRange = textOnly.range(
            of: "McNamara",
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let afterMcNamara = String(textOnly[mcnamaraRange.upperBound...])

        guard let minutes = firstMinutes(in: afterMcNamara) else {
            return []
        }

        return [
            ParsedRow(
                checkpointName: "McNamara",
                areaName: "Detroit",
                minutes: minutes,
                queueType: .general,
                terminal: 2
            )
        ]
    }

    // MARK: - LAX

    private func parseLAXRows(from html: String) throws -> [ParsedRow] {
        let textOnly = htmlToCleanText(html)

        guard let laxRange = textOnly.range(
            of: "Los Angeles",
            options: [.caseInsensitive]
        ) else {
            print("❌ LAX section not found")
            return []
        }

        let afterLAX = String(textOnly[laxRange.upperBound...])

        let laxSection: String

        if let nextAirportRange = afterLAX.range(
            of: "Minneapolis",
            options: [.caseInsensitive]
        ) {
            laxSection = String(afterLAX[..<nextAirportRange.lowerBound])
        } else {
            laxSection = afterLAX
        }

        return parseLAXRowsFromSection(laxSection)
    }

    private func parseLAXRowsFromSection(_ section: String) -> [ParsedRow] {
        let cleaned = cleanText(section)

        let pattern = #"TBIT\s+(\d{1,3})\s*min\s+(General Boarding|TSA PreCheck)"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        let matches = regex.matches(in: cleaned, options: [], range: range)

        var rows: [ParsedRow] = []

        for match in matches {
            guard
                let minutesRange = Range(match.range(at: 1), in: cleaned),
                let statusRange = Range(match.range(at: 2), in: cleaned)
            else {
                continue
            }

            let minutes = Int(cleaned[minutesRange]) ?? 0
            let status = String(cleaned[statusRange])
            let isPreCheck = status.localizedCaseInsensitiveContains("precheck")

            rows.append(
                ParsedRow(
                    checkpointName: "Tom Bradley International Terminal",
                    areaName: isPreCheck ? "TSA PreCheck" : "General Boarding",
                    minutes: minutes,
                    queueType: isPreCheck ? .precheck : .general,
                    terminal: 0
                )
            )
        }

        return rows.sorted {
            queueSortRank($0.queueType) < queueSortRank($1.queueType)
        }
    }

    private func queueSortRank(_ queueType: QueueType) -> Int {
        switch queueType {
        case .general:
            return 0
        case .precheck:
            return 1
        default:
            return 99
        }
    }

    private func firstMinutes(in text: String) -> Int? {
        let pattern = #"(\d{1,3})\s*(?:min|minutes)?"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let swiftRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return Int(text[swiftRange])
    }

    // MARK: - Shared Helpers

    private func airportBlock(for code: String, in html: String) throws -> String {
        let blockMatches = matches(
            pattern: #"<div class="airport-wait-times-airport(?! airport-wait-times-airport--fallback)[^"]*">\s*(.*?)\s*</div>\s*(?=<div class="airport-wait-times-airport|<div class="airport-wait-times__updated")"#,
            in: html,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        for blockMatch in blockMatches {
            let block = blockMatch[safe: 0] ?? ""

            if block.localizedCaseInsensitiveContains("(\(code))") {
                return block
            }
        }

        throw ProviderError.airportBlockNotFound
    }

    private func htmlToCleanText(_ html: String) -> String {
        cleanText(
            html.replacingOccurrences(
                of: "<[^>]+>",
                with: " ",
                options: .regularExpression
            )
        )
    }

    private func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
    }

    private func decodeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func cleanText(_ text: String) -> String {
        decodeHTML(text)
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func minutesFromText(_ text: String) -> Int? {
        let cleaned = cleanText(text)

        let digits = cleaned
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }

        return digits.first
    }

    private func matches(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: options
        ) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, options: [], range: range).map { match in
            var captures: [String] = []

            for index in 1..<match.numberOfRanges {
                let captureRange = match.range(at: index)

                if let swiftRange = Range(captureRange, in: text) {
                    captures.append(String(text[swiftRange]))
                } else {
                    captures.append("")
                }
            }

            return captures
        }
    }

    private static func cachedEntry(for airport: FlowAirport, ttl: TimeInterval) -> CacheEntry? {
        cacheQueue.sync {
            guard let entry = cache[airport] else { return nil }

            let age = Date().timeIntervalSince(entry.fetchedAt)
            return age <= ttl ? entry : nil
        }
    }

    private static func storeCache(
        _ waitTimes: [WaitTimeEstimate],
        for airport: FlowAirport,
        fetchedAt: Date
    ) {
        cacheQueue.sync {
            cache[airport] = CacheEntry(
                waitTimes: waitTimes,
                fetchedAt: fetchedAt
            )
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

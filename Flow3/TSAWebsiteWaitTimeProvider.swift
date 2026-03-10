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

        guard let url = tsaWebsiteURL(for: airport) else {
            throw ProviderError.invalidURL
        }

        let html = try await fetchHTML(from: url)
        let now = Date()

        let checkpointRows = parseTerminalWaitTimes(from: html, airport: airport)

        let results: [WaitTimeEstimate]

        if !checkpointRows.isEmpty {
            results = checkpointRows.map { row in
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: row.minutes,
                    observedAt: now,
                    checkpointName: row.title,
                    areaName: row.subtitle,
                    sourceType: .predicted
                )
            }
        } else {
            let overallMinutes = try parseCurrentWaitMinutes(from: html)

            results = [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: overallMinutes,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: airport.displayName,
                    sourceType: .predicted
                )
            ]
        }

        Self.storeCache(results, for: airport, fetchedAt: now)

        return results
    }

    // MARK: - Supported airports

    private func isSupported(_ airport: FlowAirport) -> Bool {
        switch airport {
        case .san, .las, .bos, .sea, .mia, .sfo:
            return true
        default:
            return false
        }
    }

    private func tsaWebsiteURL(for airport: FlowAirport) -> URL? {
        URL(string: "https://www.tsawaittimes.com/security-wait-times/\(airport.rawValue)")
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

    // MARK: - Overall wait parsing

    private func parseCurrentWaitMinutes(from html: String) throws -> Int {

        let normalized = normalizeHTML(html)

        if normalized.range(of: "less than one minute", options: .caseInsensitive) != nil {
            return 0
        }

        if let match = firstMatch(
            pattern: #"(\d+)\s+minutes?\s+and\s+(\d+)\s+seconds?"#,
            in: normalized
        ) {
            let minutes = Int(match[0]) ?? 0
            let seconds = Int(match[1]) ?? 0
            return seconds >= 30 ? minutes + 1 : minutes
        }

        if let match = firstMatch(
            pattern: #"anticipate\s+waiting\s+on\s+average\s+for:\s*(\d+)\s+minutes?"#,
            in: normalized
        ) {
            return Int(match[0]) ?? 0
        }

        if let match = firstMatch(
            pattern: #"average\s+for:\s*(\d+)\s+minutes?"#,
            in: normalized
        ) {
            return Int(match[0]) ?? 0
        }

        if let match = firstMatch(
            pattern: #"data-percent\s*=\s*"(\d+)""#,
            in: normalized
        ) {
            return Int(match[0]) ?? 0
        }

        throw ProviderError.noWaitTimeFound
    }

    // MARK: - Multi-checkpoint parsing

    private func parseTerminalWaitTimes(from html: String, airport: FlowAirport) -> [ParsedCheckpointRow] {

        let normalized = normalizeHTML(html)
        var results: [ParsedCheckpointRow] = []

        let directMatches = allMatches(
            pattern: #"(Terminal\s+[A-Z0-9]+|Terminal\s+One|Terminal\s+Two|Terminal\s+Three|Terminal\s+Four|Terminal\s+Five|International(?:\s+Terminal)?|North\s+Checkpoint|South\s+Checkpoint|Central\s+Checkpoint|Checkpoint\s+[A-Z0-9]+|Terminal\s+[A-E])[^<]{0,220}?(\d+)\s+minutes?(?:\s+and\s+(\d+)\s+seconds?)?"#,
            in: normalized
        )

        for match in directMatches {
            guard match.count >= 2 else { continue }

            let rawTitle = cleanLabel(match[0])
            let minutes = Int(match[1]) ?? 0
            let seconds = match.count > 2 ? (Int(match[2]) ?? 0) : 0
            let roundedMinutes = seconds >= 30 ? minutes + 1 : minutes

            results.append(
                ParsedCheckpointRow(
                    title: rawTitle,
                    subtitle: airport.displayName,
                    minutes: max(0, roundedMinutes)
                )
            )
        }

        let tableRowMatches = allMatches(
            pattern: #"<tr[^>]*>.*?<t[dh][^>]*>\s*(Terminal\s+[A-Z0-9]+|International(?:\s+Terminal)?|North\s+Checkpoint|South\s+Checkpoint|Central\s+Checkpoint|Checkpoint\s+[A-Z0-9]+|Terminal\s+[A-E])\s*</t[dh]>.*?<t[dh][^>]*>\s*(?:less than one minute|(\d+)\s*(?:m|min|minutes?)(?:\s+and\s+(\d+)\s+seconds?)?)\s*</t[dh]>.*?</tr>"#,
            in: normalized
        )

        for match in tableRowMatches {
            guard !match.isEmpty else { continue }

            let rawTitle = cleanLabel(match[0])

            let roundedMinutes: Int
            if normalized.lowercased().contains("less than one minute") && match.count >= 3 && match[1].isEmpty {
                roundedMinutes = 0
            } else {
                let minutes = match.count > 1 ? (Int(match[1]) ?? 0) : 0
                let seconds = match.count > 2 ? (Int(match[2]) ?? 0) : 0
                roundedMinutes = seconds >= 30 ? minutes + 1 : minutes
            }

            results.append(
                ParsedCheckpointRow(
                    title: rawTitle,
                    subtitle: airport.displayName,
                    minutes: max(0, roundedMinutes)
                )
            )
        }

        for label in likelyCheckpointLabels(for: airport) {
            if let minutes = parseMinutes(near: label, in: normalized) {
                results.append(
                    ParsedCheckpointRow(
                        title: label,
                        subtitle: airport.displayName,
                        minutes: minutes
                    )
                )
            }
        }

        var seen: Set<String> = []

        let deduped = results.filter { row in
            let key = row.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return false }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return deduped
    }

    private func likelyCheckpointLabels(for airport: FlowAirport) -> [String] {
        switch airport {
        case .san:
            return ["Terminal 1", "Terminal 2"]
        case .las:
            return ["Terminal 1", "Terminal 3"]
        case .bos:
            return ["Terminal A", "Terminal B", "Terminal C", "Terminal E"]
        case .sea:
            return ["North Checkpoint", "South Checkpoint", "Checkpoint 1", "Checkpoint 2", "Checkpoint 3", "Checkpoint 4", "Checkpoint 5"]
        case .mia:
            return ["North Terminal", "Central Terminal", "South Terminal", "Checkpoint 1", "Checkpoint 2", "Checkpoint 3"]
        case .sfo:
            return ["Terminal 1", "Terminal 2", "Terminal 3", "International Terminal"]
        default:
            return []
        }
    }

    private func parseMinutes(near label: String, in normalized: String) -> Int? {

        guard let labelRange = normalized.range(of: label, options: [.caseInsensitive]) else {
            return nil
        }

        let searchEnd = normalized.index(
            labelRange.upperBound,
            offsetBy: 250,
            limitedBy: normalized.endIndex
        ) ?? normalized.endIndex

        let window = String(normalized[labelRange.lowerBound..<searchEnd])

        if window.range(of: "less than one minute", options: .caseInsensitive) != nil {
            return 0
        }

        if let match = firstMatch(
            pattern: #"(\d+)\s+minutes?\s+and\s+(\d+)\s+seconds?"#,
            in: window
        ) {
            let minutes = Int(match[0]) ?? 0
            let seconds = Int(match[1]) ?? 0
            return seconds >= 30 ? minutes + 1 : minutes
        }

        if let match = firstMatch(
            pattern: #"(\d+)\s*(?:m|min|minutes?)"#,
            in: window
        ) {
            return Int(match[0]) ?? 0
        }

        return nil
    }

    // MARK: - Helpers

    private func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func cleanLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstMatch(pattern: String, in text: String) -> [String]? {

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        var values: [String] = []

        for index in 1..<match.numberOfRanges {
            let matchRange = match.range(at: index)

            if let swiftRange = Range(matchRange, in: text) {
                values.append(String(text[swiftRange]))
            } else {
                values.append("")
            }
        }

        return values
    }

    private func allMatches(pattern: String, in text: String) -> [[String]] {

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        return matches.map { match in
            var values: [String] = []

            for index in 1..<match.numberOfRanges {
                let matchRange = match.range(at: index)

                if let swiftRange = Range(matchRange, in: text) {
                    values.append(String(text[swiftRange]))
                } else {
                    values.append("")
                }
            }

            return values
        }
    }

    // MARK: - Cache

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

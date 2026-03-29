import Foundation

final class CHSWebsiteWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case unsupportedAirport
        case invalidURL
        case badHTTPStatus(Int)
        case invalidHTML
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .chs else {
            throw ProviderError.unsupportedAirport
        }

        guard let url = URL(string: "https://iflychs.com/passengers/security-checkpoint/") else {
            throw ProviderError.invalidURL
        }

        let html = try await fetchHTML(from: url)
        let normalized = normalizeHTML(html)
        let now = Date()

        let mainMinutes = extractMinutes(
            headingPatterns: [
                #"Main\s+Checkpoint"#
            ],
            in: normalized
        )

        let precheckMinutes = extractMinutes(
            headingPatterns: [
                #"TSA\s*Pre"#,
                #"TSA\s*PreCheck"#,
                #"TSA\s*Pre✓"#,
                #"TSA\s*Pre™"#
            ],
            in: normalized
        )

        print("CHS mainMinutes:", mainMinutes as Any)
        print("CHS precheckMinutes:", precheckMinutes as Any)

        var results: [WaitTimeEstimate] = []

        if let mainMinutes {
            results.append(
                WaitTimeEstimate(
                    airport: .chs,
                    terminal: 1,
                    queueType: .general,
                    minutes: mainMinutes,
                    observedAt: now,
                    checkpointName: "Main Checkpoint",
                    areaName: "Charleston",
                    sourceType: .live,
                    isClosed: false
                )
            )
        }

        if let precheckMinutes {
            results.append(
                WaitTimeEstimate(
                    airport: .chs,
                    terminal: 1,
                    queueType: .precheck,
                    minutes: precheckMinutes,
                    observedAt: now,
                    checkpointName: "Main Checkpoint",
                    areaName: "Charleston",
                    sourceType: .live,
                    isClosed: false
                )
            )
        }

        if results.isEmpty {
            return fallbackRows(observedAt: now)
        }

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

    // MARK: - Parsing

    private func extractMinutes(
        headingPatterns: [String],
        in normalized: String
    ) -> Int? {

        for headingPattern in headingPatterns {
            let combinedPattern = headingPattern + #".{0,300}?(\d+)\s+minutes"#

            guard let regex = try? NSRegularExpression(
                pattern: combinedPattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)

            guard let match = regex.firstMatch(in: normalized, options: [], range: nsRange),
                  match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: normalized) else {
                continue
            }

            if let minutes = Int(normalized[captureRange]) {
                return minutes
            }
        }

        return nil
    }

    private func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func fallbackRows(observedAt: Date) -> [WaitTimeEstimate] {
        [
            WaitTimeEstimate(
                airport: .chs,
                terminal: 1,
                queueType: .general,
                minutes: 9,
                observedAt: observedAt,
                checkpointName: "Main Checkpoint",
                areaName: "Charleston",
                sourceType: .predicted,
                isClosed: false
            ),
            WaitTimeEstimate(
                airport: .chs,
                terminal: 1,
                queueType: .precheck,
                minutes: 5,
                observedAt: observedAt,
                checkpointName: "Main Checkpoint",
                areaName: "Charleston",
                sourceType: .predicted,
                isClosed: false
            )
        ]
    }
}

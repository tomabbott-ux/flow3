import Foundation

struct AMSWaitTimeResult {
    let displayText: String
    let minMinutes: Int?
    let maxMinutes: Int?
    let observedAt: Date
    let detailText: String?
}

final class AMSWaitTimeService {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTime(from publicFlightURL: URL) async throws -> AMSWaitTimeResult? {

        var request = URLRequest(url: publicFlightURL)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let displayText = extractWaitTimeText(from: html) else {
            return nil
        }

        let parsed = parseMinutes(from: displayText)
        let detail = extractSecurityDetailText(from: html)

        return AMSWaitTimeResult(
            displayText: displayText,
            minMinutes: parsed.minMinutes,
            maxMinutes: parsed.maxMinutes,
            observedAt: Date(),
            detailText: detail
        )
    }

    private func extractWaitTimeText(from html: String) -> String? {
        let patterns = [
            #"data-testid="waiting-time-chip-value"[^>]*>([^<]+)<"#,
            #"waiting-time-chip-value[^>]*>([^<]+)<"#,
            #">([0-9]{1,2}\s*-\s*[0-9]{1,2}\s*mins?)<"#,
            #">([0-9]{1,2}\s*mins?)<"#
        ]

        for pattern in patterns {
            if let text = firstMatch(pattern: pattern, in: html) {
                let cleaned = htmlDecoded(text)
                    .replacingOccurrences(of: "min.", with: "mins")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func extractSecurityDetailText(from html: String) -> String? {
        let patterns = [
            #"Security.*?waiting-time-chip-value.*?</[^>]+>\s*<[^>]+>([^<]+)<"#,
            #"Follow signs to ([^<]+)<"#,
            #"Gate\s+[A-Z0-9]+"#
        ]

        for pattern in patterns {
            if let text = firstMatch(pattern: pattern, in: html) {
                let cleaned = htmlDecoded(text)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)

        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            return nil
        }

        let targetRange: NSRange
        if match.numberOfRanges > 1 {
            targetRange = match.range(at: 1)
        } else {
            targetRange = match.range(at: 0)
        }

        guard let range = Range(targetRange, in: text) else {
            return nil
        }

        return String(text[range])
    }

    private func htmlDecoded(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    private func parseMinutes(from text: String) -> (minMinutes: Int?, maxMinutes: Int?) {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "minutes", with: "min")
            .replacingOccurrences(of: "mins", with: "min")
            .replacingOccurrences(of: " ", with: "")

        if normalized.contains("-") {
            let parts = normalized
                .replacingOccurrences(of: "min", with: "")
                .split(separator: "-")
                .map(String.init)

            if parts.count == 2,
               let minValue = Int(parts[0]),
               let maxValue = Int(parts[1]) {
                return (minValue, maxValue)
            }
        }

        let digits = normalized
            .replacingOccurrences(of: "min", with: "")

        if let value = Int(digits) {
            return (value, value)
        }

        return (nil, nil)
    }
}

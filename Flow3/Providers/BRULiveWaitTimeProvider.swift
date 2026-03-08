import Foundation

final class BRULiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingWaitTime
    }

    private let session: URLSession
    private let pageURL = URL(string: "https://www.brusselsairport.be/en/passengers")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .bru else { return [] }

        var request = URLRequest(url: pageURL)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
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

        let minutes = try parseMinutes(from: html)

        return [
            WaitTimeEstimate(
                airport: .bru,
                terminal: nil,
                queueType: .general,
                minutes: minutes,
                observedAt: Date(),
                checkpointName: "Security Check",
                areaName: "Airport Security",
                sourceType: .live
            )
        ]
    }

    private func parseMinutes(from html: String) throws -> Int {
        let patterns = [
            #">(\d+)\s*min\.\s*Current waiting time<"#,
            #">(\d+)\s*min\.\s*Current waiting time"#,
            #"(\d+)\s*min\.\s*Current waiting time"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(html.startIndex..<html.endIndex, in: html)

                if let match = regex.firstMatch(in: html, options: [], range: range),
                   let minuteRange = Range(match.range(at: 1), in: html),
                   let minutes = Int(html[minuteRange]) {
                    return minutes
                }
            }
        }

        throw ProviderError.missingWaitTime
    }
}

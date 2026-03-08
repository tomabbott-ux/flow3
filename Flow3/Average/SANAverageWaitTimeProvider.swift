import Foundation

final class SANAverageWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingAverageWait
    }

    private let session: URLSession
    private let pageURL = URL(string: "https://www.tsawaittimes.com/security-wait-times/SAN/San-Diego-International")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .san else { return [] }

        let html = try await fetchHTML()
        let minutes = try parseAverageMinutes(from: html)

        let now = Date()

        return [
            WaitTimeEstimate(
                airport: .san,
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

    private func fetchHTML() async throws -> String {
        var request = URLRequest(url: pageURL)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
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
        let pattern = #"(\d+)\s*m"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            throw ProviderError.invalidResponse
        }

        let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)

        guard let match = regex.firstMatch(in: html, options: [], range: nsrange),
              let minutesRange = Range(match.range(at: 1), in: html),
              let minutes = Int(html[minutesRange]) else {
            throw ProviderError.missingAverageWait
        }

        return minutes
    }
}

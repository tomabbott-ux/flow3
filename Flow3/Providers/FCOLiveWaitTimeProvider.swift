import Foundation

final class FCOLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingWaitTime
    }

    private let session: URLSession
    private let pageURL = URL(string: "https://www.adr.it/web/aeroporti-di-roma-en/skytrax-best-airport-awards")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .fco else { return [] }

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

        let points = try parsePoints(from: html)

        return points.map { point in
            WaitTimeEstimate(
                airport: .fco,
                terminal: point.terminal,
                queueType: .general,
                minutes: point.minutes,
                observedAt: Date(),
                checkpointName: "Security",
                areaName: "Terminal \(point.terminal)",
                sourceType: .live
            )
        }
    }

    private func parsePoints(from html: String) throws -> [(terminal: Int, minutes: Int)] {
        let pattern = #"Terminal\s*(\d+):\s*<time>(\d+)\s*min</time>"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            throw ProviderError.invalidResponse
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        var results: [(Int, Int)] = []

        for match in matches {
            guard
                let terminalRange = Range(match.range(at: 1), in: html),
                let minuteRange = Range(match.range(at: 2), in: html),
                let terminal = Int(html[terminalRange]),
                let minutes = Int(html[minuteRange])
            else { continue }

            results.append((terminal, minutes))
        }

        guard !results.isEmpty else {
            throw ProviderError.missingWaitTime
        }

        return results
    }
}

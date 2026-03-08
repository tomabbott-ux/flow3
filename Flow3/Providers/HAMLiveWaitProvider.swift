import Foundation

final class HAMLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingWaitTime
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://www.hamburg-airport.de/service/waittimes/waittimes")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .ham else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
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

        let decoded = try JSONDecoder().decode(HAMResponse.self, from: data)

        guard let minutes = parseMinutes(from: decoded.waitingTime) else {
            throw ProviderError.missingWaitTime
        }

        let observedAt = Date(timeIntervalSince1970: TimeInterval(decoded.lastUpdate) / 1000.0)

        return [
            WaitTimeEstimate(
                airport: .ham,
                terminal: 1,
                queueType: .general,
                minutes: minutes,
                observedAt: observedAt,
                checkpointName: "Security Check",
                areaName: "Terminal",
                sourceType: .live
            )
        ]
    }

    private func parseMinutes(from value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let pattern = #"(\d+)(?:\s*-\s*(\d+))?\s*min"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else {
            return nil
        }

        if let secondRange = Range(match.range(at: 2), in: trimmed),
           let second = Int(trimmed[secondRange]) {
            return second
        }

        if let firstRange = Range(match.range(at: 1), in: trimmed),
           let first = Int(trimmed[firstRange]) {
            return first
        }

        return nil
    }
}

private struct HAMResponse: Decodable {
    let id: String
    let waitingTime: String
    let lastUpdate: Int
}

import Foundation

final class EDILiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingWaitTime
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://blip-api.edinburghairport.com/blip-api/blip?version=2")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .edi else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.edinburghairport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.edinburghairport.com/", forHTTPHeaderField: "Referer")
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

        let decoded = try JSONDecoder().decode(EDIResponse.self, from: data)

        guard decoded.minutes >= 0 else {
            throw ProviderError.missingWaitTime
        }

        return [
            WaitTimeEstimate(
                airport: .edi,
                terminal: nil,
                queueType: .general,
                minutes: decoded.minutes,
                observedAt: Date(),
                checkpointName: "Security Check",
                areaName: "Main Terminal",
                sourceType: .live
            )
        ]
    }
}

private struct EDIResponse: Decodable {
    let queue: Int
    let minutes: Int
    let cached: Int
    let version: String
}

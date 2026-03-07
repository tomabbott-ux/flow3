import Foundation

final class SLCLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://slcairport.com/ajaxtsa/waittimes")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .slc else { return [] }

        let data = try await fetchAPIData()

        let payload: SLCResponse
        do {
            payload = try JSONDecoder().decode(SLCResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse
        }

        let now = Date()

        return [
            WaitTimeEstimate(
                airport: .slc,
                terminal: 1,
                queueType: .general,
                minutes: max(0, payload.rightnow),
                observedAt: now,
                checkpointName: "Main Security",
                areaName: "Terminal 1",
                sourceType: .live
            )
        ]
    }

    private func fetchAPIData() async throws -> Data {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://slcairport.com/", forHTTPHeaderField: "Referer")
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

        return data
    }
}

private struct SLCResponse: Decodable {
    let code: String
    let rightnow: Int

    enum CodingKeys: String, CodingKey {
        case code
        case rightnow
    }
}

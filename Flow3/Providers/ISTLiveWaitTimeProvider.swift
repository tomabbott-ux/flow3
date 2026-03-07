import Foundation

final class ISTLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://www.istairport.com/umbraco/api/Checkpoint/GetWaitingTimes?culture=en-US")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .ist else { return [] }

        let payload = try await fetchPayload()

        guard payload.status else {
            throw ProviderError.invalidResponse
        }

        let now = Date()
        var results: [WaitTimeEstimate] = []

        if let minutes = payload.result.gateWaitTime {
            results.append(
                WaitTimeEstimate(
                    airport: .ist,
                    terminal: nil,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: now,
                    checkpointName: "Terminal Entrance",
                    areaName: payload.result.gateWaitTimeName,
                    sourceType: .live
                )
            )
        }

        if let minutes = payload.result.passQueueWaitTime {
            results.append(
                WaitTimeEstimate(
                    airport: .ist,
                    terminal: nil,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: now,
                    checkpointName: "Passport Control",
                    areaName: payload.result.passQueueWaitTimeName,
                    sourceType: .live
                )
            )
        }

        if let minutes = payload.result.domQueueWaitTime {
            results.append(
                WaitTimeEstimate(
                    airport: .ist,
                    terminal: nil,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: now,
                    checkpointName: "Domestic Control",
                    areaName: payload.result.domQueueWaitTimeName,
                    sourceType: .live
                )
            )
        }

        return results
    }

    private func fetchPayload() async throws -> ISTCheckpointResponse {

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.istairport.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        return try JSONDecoder().decode(ISTCheckpointResponse.self, from: data)
    }
}

private struct ISTCheckpointResponse: Decodable {
    let status: Bool
    let result: ISTCheckpointResult
}

private struct ISTCheckpointResult: Decodable {

    let gateWaitTime: Int?
    let gateWaitTimeName: String?

    let passQueueWaitTime: Int?
    let passQueueWaitTimeName: String?

    let domQueueWaitTime: Int?
    let domQueueWaitTimeName: String?
}

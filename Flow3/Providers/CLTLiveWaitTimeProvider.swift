import Foundation

final class CLTLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .clt else { return [] }

        guard let url = URL(string: "https://api.cltairport.mobi/wait-times/checkpoint/CLT") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.cltairport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.cltairport.com/", forHTTPHeaderField: "Referer")
        request.setValue("130", forHTTPHeaderField: "Api-Version")
        request.setValue("5ccb418715f9428ca6cb4df1635d4815", forHTTPHeaderField: "Api-Key")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let payload = try JSONDecoder().decode(CLTWaitTimesResponse.self, from: data)

        return payload.data.waitTimes
            .filter { $0.isDisplayable }
            .map { item in

                let isPreCheck = item.attributes.preCheck == true
                let queueType: QueueType = isPreCheck ? .precheck : .general

                let observedAt = Date(timeIntervalSince1970: TimeInterval(item.lastUpdatedTimestamp))
                let minutes = Int((Double(item.waitSeconds) / 60.0).rounded())

                let checkpointName: String
                if isPreCheck {
                    checkpointName = "\(item.name) TSA"
                } else {
                    checkpointName = item.name
                }

                return WaitTimeEstimate(
                    airport: .clt,
                    terminal: nil,
                    queueType: queueType,
                    minutes: max(0, minutes),
                    observedAt: observedAt,
                    checkpointName: checkpointName,
                    areaName: "Charlotte",
                    sourceType: .live,
                    isClosed: !item.isOpen
                )
            }
    }
}

// MARK: - Models

private struct CLTWaitTimesResponse: Decodable {
    let data: CLTWaitTimesData
}

private struct CLTWaitTimesData: Decodable {
    let waitTimes: [CLTCheckpoint]

    enum CodingKeys: String, CodingKey {
        case waitTimes = "wait_times"
    }
}

private struct CLTCheckpoint: Decodable {
    let id: String
    let lane: String?
    let name: String
    let openTime: String?
    let closeTime: String?
    let remark: String?
    let isOpen: Bool
    let isDisplayable: Bool
    let waitSeconds: Int
    let minWaitSeconds: Int?
    let maxWaitSeconds: Int?
    let lastUpdatedTimestamp: Int
    let attributes: CLTCheckpointAttributes

    enum CodingKeys: String, CodingKey {
        case id
        case lane
        case name
        case openTime
        case closeTime
        case remark
        case isOpen
        case isDisplayable
        case waitSeconds
        case minWaitSeconds
        case maxWaitSeconds
        case lastUpdatedTimestamp
        case attributes
    }
}

private struct CLTCheckpointAttributes: Decodable {
    let mapId: String?
    let general: Bool?
    let preCheck: Bool?

    enum CodingKeys: String, CodingKey {
        case mapId
        case general
        case preCheck
    }
}

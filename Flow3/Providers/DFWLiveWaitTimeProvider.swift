import Foundation

struct DFWLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://api.dfwairport.mobi/wait-times/checkpoint/DFW")!
    private let apiKey = "87856E0636AA4BF282150FCBE1AD63DE"

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .dfw else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"

        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("170", forHTTPHeaderField: "Api-Version")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("https://www.dfwairport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.dfwairport.com/", forHTTPHeaderField: "Referer")

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(DFWResponse.self, from: data)

        let now = Date()
        var results: [WaitTimeEstimate] = []

        for row in decoded.data.wait_times {

            guard row.isOpen else { continue }
            guard row.isDisplayable else { continue }

            let queueType = mapQueueType(row.lane)
            guard let queue = queueType else { continue }

            let minutes = max(0, Int(row.waitSeconds / 60))

            results.append(
                WaitTimeEstimate(
                    airport: .dfw,
                    terminal: nil,
                    queueType: queue,
                    minutes: minutes,
                    observedAt: now,
                    checkpointName: row.name,
                    areaName: "Terminal",
                    sourceType: .live
                )
            )
        }

        return results
    }

    private func mapQueueType(_ lane: String) -> QueueType? {

        let l = lane.lowercased()

        if l.contains("pre") {
            return .precheck
        }

        if l.contains("general") {
            return .general
        }

        return nil
    }
}

private struct DFWResponse: Decodable {
    let data: DFWData
}

private struct DFWData: Decodable {
    let wait_times: [DFWRow]
}

private struct DFWRow: Decodable {

    let id: String
    let lane: String
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
}

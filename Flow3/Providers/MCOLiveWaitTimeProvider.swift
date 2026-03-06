import Foundation

struct MCOLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://api.goaa.aero/wait-times/checkpoint/MCO")!
    private let apiKey = "8eaac7209c824616a8fe58d22268cd59"
    private let apiVersion = "140"

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .mco else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(apiVersion, forHTTPHeaderField: "Api-Version")
        request.setValue("https://flymco.com", forHTTPHeaderField: "Origin")
        request.setValue("https://flymco.com/", forHTTPHeaderField: "Referer")
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

        let decoded = try JSONDecoder().decode(MCOResponse.self, from: data)

        var results: [WaitTimeEstimate] = []

        for row in decoded.data.wait_times {
            guard row.isOpen else { continue }
            guard row.isDisplayable else { continue }

            let queueType = mapQueueType(row.lane)
            guard let queueType else { continue }

            let minutes = max(0, Int(row.waitSeconds / 60))
            let observedAt = Date(timeIntervalSince1970: TimeInterval(row.lastUpdatedTimestamp))
            let areaName = gateRangeString(from: row.attributes)

            results.append(
                WaitTimeEstimate(
                    airport: .mco,
                    terminal: nil,
                    queueType: queueType,
                    minutes: minutes,
                    observedAt: observedAt,
                    checkpointName: normalizedCheckpointName(row.name),
                    areaName: areaName,
                    sourceType: .live
                )
            )
        }

        return results
    }

    private func mapQueueType(_ lane: String) -> QueueType? {
        let lane = lane.lowercased()

        if lane.contains("pre") {
            return .precheck
        }

        if lane.contains("general") || lane.contains("standard") {
            return .general
        }

        return nil
    }

    private func normalizedCheckpointName(_ name: String) -> String {
        let lower = name.lowercased()

        if lower.contains("south") { return "South" }
        if lower.contains("west") { return "West" }
        if lower.contains("east") { return "East" }

        return name
    }

    private func gateRangeString(from attributes: MCOAttributes?) -> String {
        guard let attributes else { return "Security" }

        if let minGate = attributes.minGate, let maxGate = attributes.maxGate {
            return "Gates \(minGate)-\(maxGate)"
        }

        return "Security"
    }
}

private struct MCOResponse: Decodable {
    let data: MCOData
    let status: MCOStatus
}

private struct MCOData: Decodable {
    let wait_times: [MCORow]
}

private struct MCOStatus: Decodable {
    let code: Int
    let message: String
}

private struct MCORow: Decodable {
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
    let attributes: MCOAttributes?
    let predictions: [MCOEmptyPrediction]?
}

private struct MCOAttributes: Decodable {
    let minGate: String?
    let maxGate: String?
}

private struct MCOEmptyPrediction: Decodable {}

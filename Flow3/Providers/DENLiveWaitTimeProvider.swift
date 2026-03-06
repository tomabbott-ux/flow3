import Foundation

struct DENLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://app.flyfruition.com/api/public/tsa")!
    private let apiKey = "vqw8ruvwqpv02pqu938bh5p028"

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .den else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.flydenver.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.flydenver.com/", forHTTPHeaderField: "Referer")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let checkpoints = try JSONDecoder().decode([DENCheckpoint].self, from: data)
        let now = Date()

        var results: [WaitTimeEstimate] = []

        for checkpoint in checkpoints {
            for lane in checkpoint.lanes where !lane.hide_lane {
                let queueType = mapQueueType(lane.title)
                guard queueType != nil else { continue }

                let minutes = minutesFromRange(lane.wait_time)
                let observedAt = now

                results.append(
                    WaitTimeEstimate(
                        airport: .den,
                        terminal: nil,
                        queueType: queueType!,
                        minutes: minutes,
                        observedAt: observedAt,
                        checkpointName: checkpoint.title,
                        areaName: checkpoint.location,
                        sourceType: .live
                    )
                )
            }
        }

        return results
    }

    private func mapQueueType(_ title: String) -> QueueType? {
        let lower = title.lowercased()

        if lower.contains("precheck") || lower.contains("pre check") {
            return .precheck
        }

        if lower.contains("standard") {
            return .general
        }

        return nil
    }

    private func minutesFromRange(_ value: String) -> Int {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.contains("-") {
            let parts = cleaned.split(separator: "-").map { String($0) }
            if parts.count == 2,
               let low = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let high = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                return max(0, (low + high) / 2)
            }
        }

        if let exact = Int(cleaned) {
            return max(0, exact)
        }

        return 0
    }
}

private struct DENCheckpoint: Decodable {
    let title: String
    let description: String
    let thumbnail: String
    let location: String
    let direction_url: String
    let lanes: [DENLane]
}

private struct DENLane: Decodable {
    let lane_id: String
    let title: String
    let closed: Bool
    let wait_time: String
    let opening_info: String
    let hide_lane: Bool
}

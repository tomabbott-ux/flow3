import Foundation

final class MIALiveWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        let url = URL(string: "https://waittime.api.aero/waittime/v2/current/MIA")!

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("5d0cacea6e41416fdcde0c5c5a19d867", forHTTPHeaderField: "x-apikey")

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(MIAResponse.self, from: data)

        return response.current.compactMap { item in

            // ✅ Only open queues
            guard item.status == "Open" else { return nil }

            // ✅ Parse terminal + type
            let parts = item.queueName.split(separator: " ")
            guard let first = parts.first,
                  let terminal = Int(first) else { return nil }

            let label = item.queueName.lowercased()

            let queueType: QueueType

            if label.contains("tsa-pre") {
                queueType = .precheck
            } else if label.contains("general") {
                queueType = .general
            } else {
                return nil // ignore Clear / Priority for now
            }

            // ✅ Convert seconds → minutes
            let minutes = max(1, item.projectedWaitTime / 60)

            // ✅ Parse date
            let observedAt = ISO8601DateFormatter().date(from: item.time) ?? Date()
            
            return WaitTimeEstimate(
                airport: .mia,
                terminal: terminal,
                queueType: queueType,
                minutes: minutes,
                observedAt: observedAt,
                checkpointName: "Security",
                areaName: nil,
                sourceType: .live,
                isClosed: false
            )
        }
    }
}

// MARK: - Models

struct MIAResponse: Codable {
    let current: [MIAQueue]
}

struct MIAQueue: Codable {
    let queueName: String
    let status: String
    let projectedWaitTime: Int
    let time: String
}

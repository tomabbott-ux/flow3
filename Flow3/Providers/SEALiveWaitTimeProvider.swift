import Foundation

final class SEALiveWaitTimeProvider: WaitTimeProviding {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .sea else { return [] }

        let url = URL(string: "https://www.portseattle.org/api/cwt/wait-times")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.portseattle.org/page/live-estimated-checkpoint-wait-times", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let checkpoints = try JSONDecoder().decode([SEACheckpoint].self, from: data)

        return checkpoints.map { checkpoint in
            let observedAt = checkpoint.parsedLastUpdated ?? Date()
            let availableServices = checkpoint.availableServicesText

            let isUsable =
                checkpoint.IsOpen &&
                checkpoint.IsDataAvailable &&
                checkpoint.MinutesTillInvalid >= 0

            return WaitTimeEstimate(
                airport: .sea,
                terminal: checkpoint.Order,
                queueType: .general,
                minutes: isUsable ? max(0, checkpoint.WaitTimeMinutes) : 0,
                observedAt: observedAt,
                checkpointName: "Checkpoint \(checkpoint.Name)",
                areaName: availableServices,
                sourceType: .live,
                isClosed: !isUsable
            )
        }
    }
}

// MARK: - Models

private struct SEACheckpoint: Decodable {
    let CheckpointID: Int
    let Name: String
    let Order: Int
    let IsOpen: Bool
    let WaitTimeMinutes: Int
    let PreCheck: Int
    let Options: [SEAOption]
    let IsDataAvailable: Bool
    let LastUpdated: String
    let MinutesTillInvalid: Int
    let MinutesSinceLastUpdate: Int
    let QueueLength: Int

    var parsedLastUpdated: Date? {
        let digits = LastUpdated.filter(\.isNumber)
        guard let milliseconds = Double(digits) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000.0)
    }

    var availableServicesText: String {
        let available = Options
            .filter { $0.Availability.lowercased() == "available" }
            .map { option -> String in
                switch option.Name.lowercased() {
                case "general":
                    return "General"
                case "pre":
                    return "TSA Pre"
                case "clear":
                    return "Clear"
                case "premium":
                    return "Premium"
                case "spot saver":
                    return "Spot Saver"
                case "visitor pass":
                    return "Visitor Pass"
                default:
                    return option.Name
                }
            }

        if available.isEmpty {
            return "Security"
        }

        return available.joined(separator: " • ")
    }
}

private struct SEAOption: Decodable {
    let Name: String
    let Availability: String
}

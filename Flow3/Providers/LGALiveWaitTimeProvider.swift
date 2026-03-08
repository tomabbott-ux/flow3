import Foundation

final class LGALiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://avi-prod-mpp-webapp-api.azurewebsites.net/api/v1/SecurityWaitTimesPoints/LGA")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lga else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.laguardiaairport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.laguardiaairport.com/", forHTTPHeaderField: "Referer")
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

        let decoded = try JSONDecoder().decode([LGAWaitPoint].self, from: data)

        let usable = decoded.filter { $0.queueOpen }

        let iso = ISO8601DateFormatter()

        return usable.map { row in
            let observedAt = iso.date(from: row.updateTime) ?? Date()
            let isPre = row.queueType.uppercased().contains("TSAPRE")

            return WaitTimeEstimate(
                airport: .lga,
                terminal: terminalNumber(from: row.terminal),
                queueType: isPre ? .precheck : .general,
                minutes: max(0, row.timeInMinutes),
                observedAt: observedAt,
                checkpointName: cleanCheckpointName(row.checkPoint),
                areaName: nil,
                sourceType: .live
            )
        }
    }

    private func terminalNumber(from code: String) -> Int? {
        switch code.uppercased() {
        case "A": return 1
        case "B": return 2
        case "C": return 3
        case "D": return 4
        default: return nil
        }
    }

    private func cleanCheckpointName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.lowercased() == "main chekpoint" {
            return "Main Checkpoint"
        }

        return trimmed
    }
}

private struct LGAWaitPoint: Decodable {
    let pointID: Int
    let timeInSeconds: Int
    let title: String
    let timeInMinutes: Int
    let passengerCount: Int
    let area: String
    let gate: String
    let terminal: String
    let checkPoint: String
    let queueType: String
    let queueOpen: Bool
    let updateTime: String
    let isWaitTimeAvailable: Bool
    let status: String
    let updateTimeText: String
    let updateDateTimeText: String
}

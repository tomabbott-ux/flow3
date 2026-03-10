import Foundation

final class EWRLiveWaitTimeProvider: WaitTimeProviding {

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

        guard airport == .ewr else { return [] }

        guard let url = URL(string: "https://avi-prod-mpp-webapp-api.azurewebsites.net/api/v1/SecurityWaitTimesPoints/EWR") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.newarkairport.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.newarkairport.com/", forHTTPHeaderField: "Referer")
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

        let payload = try JSONDecoder().decode([EWRWaitPoint].self, from: data)

        let formatter = ISO8601DateFormatter()

        return payload.map { item in
            let queueType: QueueType = item.queueType.uppercased().contains("PRE") ? .precheck : .general
            let observedAt = formatter.date(from: item.updateTime) ?? Date()

            return WaitTimeEstimate(
                airport: .ewr,
                terminal: Int(item.terminal),
                queueType: queueType,
                minutes: max(0, item.timeInMinutes),
                observedAt: observedAt,
                checkpointName: item.displayCheckpointTitle,
                areaName: item.displaySubtitle,
                sourceType: .live,
                isClosed: !item.queueOpen || !item.isWaitTimeAvailable
            )
        }
    }
}

private struct EWRWaitPoint: Decodable {
    let pointID: Int
    let timeInSeconds: Int
    let title: String
    let timeInMinutes: Int
    let passengerCount: Int?
    let area: String
    let gate: String?
    let terminal: String
    let checkPoint: String
    let queueType: String
    let queueOpen: Bool
    let updateTime: String
    let isWaitTimeAvailable: Bool
    let status: String?
    let updateTimeText: String?
    let updateDateTimeText: String?

    var displayCheckpointTitle: String {
        let terminalTitle = "Terminal \(terminal)"
        let cleanedGate = (gate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedGate.isEmpty || cleanedGate.uppercased() == "ALL GATES" {
            return terminalTitle
        }

        return "\(terminalTitle) • \(cleanedGate)"
    }

    var displaySubtitle: String {
        let terminalTitle = "Terminal \(terminal)"
        let cleanedGate = (gate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanedGate.isEmpty || cleanedGate.uppercased() == "ALL GATES" {
            return terminalTitle
        }

        return "Gates \(cleanedGate)"
    }
}

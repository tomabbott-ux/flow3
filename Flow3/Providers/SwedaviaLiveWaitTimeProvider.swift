import Foundation

final class ARNLiveWaitTimeProvider: WaitTimeProviding {

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
        guard airport == .arn else { return [] }

        guard let url = URL(string: "https://www.swedavia.com/services/queuetimes/v2/airport/en/ARN/true") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.swedavia.com/arlanda/", forHTTPHeaderField: "Referer")
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

        let payload = try JSONDecoder().decode(ARNQueueResponse.self, from: data)
        let now = Date()

        let results = payload.queueTimesList.map { item in
            let terminalNumber = Int(item.terminalId.first ?? "")

            let checkpointTitle: String = {
                if !item.displayNameEnglish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "Terminal \(item.displayNameEnglish)"
                }

                if !item.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return item.locationName
                }

                if let terminalNumber {
                    return "Terminal \(terminalNumber)"
                }

                return "Security"
            }()

            let minutes = max(0, Int(round(Double(item.currentProjectedQueueTime) / 60.0)))

            return WaitTimeEstimate(
                airport: .arn,
                terminal: terminalNumber,
                queueType: item.isFastTrack ? .precheck : .general,
                minutes: minutes,
                observedAt: now,
                checkpointName: checkpointTitle,
                areaName: item.name,
                sourceType: .live,
                isClosed: item.isStationClosed || item.isDisabled
            )
        }

        return results.sorted {
            ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
        }
    }
}

private struct ARNQueueResponse: Decodable {
    let queueTimesDisabled: Bool
    let queueTimesReplacementMessage: String
    let queueTimesList: [ARNQueueItem]
}

private struct ARNQueueItem: Decodable {
    let id: Int
    let longId: String
    let terminalId: [String]
    let name: String
    let shortName: String
    let locationName: String
    let interval: String
    let currentProjectedQueueTime: Int
    let isFastTrack: Bool
    let isDisabled: Bool
    let hasTerminalMap: Bool
    let displayName: String
    let displayNameEnglish: String
    let overflow: Bool
    let isStationClosed: Bool
}

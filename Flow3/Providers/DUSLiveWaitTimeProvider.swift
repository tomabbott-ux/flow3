import Foundation

final class DUSLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case hasError
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://www.dus.com/api/sitecore/flightapi/WaitingTimes?lang=en")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .dus else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.dus.com/en/inform/security-control", forHTTPHeaderField: "Referer")
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

        let decoded = try JSONDecoder().decode(DUSResponse.self, from: data)

        guard decoded.hasError == false else {
            throw ProviderError.hasError
        }

        let now = Date()

        return decoded.data.map { item in
            WaitTimeEstimate(
                airport: .dus,
                terminal: nil,
                queueType: .general,
                minutes: max(0, item.waitingTime),
                observedAt: now,
                checkpointName: cleanedCheckpointName(from: item.name),
                areaName: "Security",
                sourceType: .live
            )
        }
    }

    private func cleanedCheckpointName(from name: String) -> String {
        if name == "Sicherheitskontrolle A" { return "Security Check A" }
        if name == "Sicherheitskontrolle B" { return "Security Check B" }
        if name == "Sicherheitskontrolle C" { return "Security Check C" }
        return name
    }
}

private struct DUSResponse: Decodable {
    let data: [DUSWaitPoint]
    let serviceType: String
    let hasError: Bool
    let internalErrorMessage: String
    let errorCode: String
}

private struct DUSWaitPoint: Decodable {
    let id: Int
    let name: String
    let waitingTime: Int
    let gateTerminal: String
    let waitingTimeText: String
}

import Foundation

final class IAHLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://api.houstonairports.mobi/wait-times/checkpoint/iah")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .iah else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("9ACB3B733BE94B11A03B6E84CA87E895", forHTTPHeaderField: "Api-Key")
        request.setValue("120", forHTTPHeaderField: "Api-Version")
        request.setValue("https://www.fly2houston.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.fly2houston.com/", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(IAHAPIResponse.self, from: data)

        let rows = decoded.data.waitTimes.filter {
            $0.isOpen && $0.isDisplayable
        }

        let now = Date()

        return rows.map {

            let minutes = Int((Double($0.waitSeconds) / 60.0).rounded())

            return WaitTimeEstimate(
                airport: .iah,
                terminal: terminalNumber(from: $0.name),
                queueType: .general,
                minutes: minutes,
                observedAt: now,
                checkpointName: $0.name,
                areaName: "Security",
                sourceType: .live
            )
        }
    }

    private func terminalNumber(from name: String) -> Int? {

        let upper = name.uppercased()

        if upper.contains("TERMINAL A") { return 1 }
        if upper.contains("TERMINAL B") { return 2 }
        if upper.contains("TERMINAL C") { return 3 }
        if upper.contains("TERMINAL D") { return 4 }
        if upper.contains("TERMINAL E") { return 5 }

        return nil
    }
}

private struct IAHAPIResponse: Decodable {
    let data: IAHAPIData
}

private struct IAHAPIData: Decodable {

    let waitTimes: [IAHWaitTime]

    enum CodingKeys: String, CodingKey {
        case waitTimes = "wait_times"
    }
}

private struct IAHWaitTime: Decodable {

    let name: String
    let waitSeconds: Int
    let isOpen: Bool
    let isDisplayable: Bool
}

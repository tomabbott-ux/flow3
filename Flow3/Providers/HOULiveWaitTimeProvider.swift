import Foundation

struct HOULiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://api.houstonairports.mobi/wait-times/checkpoint/hou")!
    private let apiKey = "9ACB3B733BE94B11A03B6E84CA87E895"
    private let apiVersion = "120"

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .hou else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(apiVersion, forHTTPHeaderField: "Api-Version")
        request.setValue("https://www.fly2houston.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.fly2houston.com/", forHTTPHeaderField: "Referer")
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

        let decoded = try JSONDecoder().decode(HOUResponse.self, from: data)

        var results: [WaitTimeEstimate] = []

        for row in decoded.data.wait_times {
            guard row.isOpen else { continue }
            guard row.isDisplayable else { continue }

            // Exclude customs / FIS from Flow's main security screen
            if row.lane.lowercased() == "fis" { continue }
            if row.name.lowercased().contains("immigration") { continue }
            if row.name.lowercased().contains("customs") { continue }

            let minutes = max(0, Int(row.waitSeconds / 60))
            let observedAt = Date(timeIntervalSince1970: TimeInterval(row.lastUpdatedTimestamp))

            results.append(
                WaitTimeEstimate(
                    airport: .hou,
                    terminal: nil,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: observedAt,
                    checkpointName: row.name,
                    areaName: "Security",
                    sourceType: .live
                )
            )
        }

        return results
    }
}

private struct HOUResponse: Decodable {
    let data: HOUData
    let status: HOUStatus
}

private struct HOUData: Decodable {
    let wait_times: [HOURow]
}

private struct HOUStatus: Decodable {
    let code: Int
    let message: String
}

private struct HOURow: Decodable {
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
    let attributes: [String]?
    let predictions: [HOUEmptyPrediction]?
}

private struct HOUEmptyPrediction: Decodable {}

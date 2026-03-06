import Foundation

struct YYCLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://rmsflightdata.yyc.com:8091/api/currentwaittimes")!

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .yyc else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("https://www.yyc.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.yyc.com/", forHTTPHeaderField: "Referer")
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

        let decoded = try JSONDecoder().decode(YYCWaitResponse.self, from: data)
        let observedAt = parseYYCDate(decoded.updatedAt) ?? Date()

        return decoded.waittimes
            .map { checkpoint, rawMinutes in
                let minutes = max(0, Int(rawMinutes) ?? 0)

                return WaitTimeEstimate(
                    airport: .yyc,
                    terminal: nil,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: observedAt,
                    checkpointName: checkpoint,
                    areaName: "Security",
                    sourceType: .live
                )
            }
            .sorted { ($0.checkpointName ?? "") < ($1.checkpointName ?? "") }
    }

    private func parseYYCDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Edmonton")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter.date(from: value)
    }
}

private struct YYCWaitResponse: Decodable {
    let updatedAt: String
    let lastScan: String
    let waittimes: [String: String]
}

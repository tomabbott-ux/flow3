import Foundation

struct YVRLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://www.yvr.ca/_api/CatsaWait")!

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .yvr else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "https://www.yvr.ca/en/passengers/travel-planning/operational-snapshot",
            forHTTPHeaderField: "Referer"
        )
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(YVRCatsaResponse.self, from: data)

        return decoded.value
            .map { row in
                let seconds = Int(row.WaitTime) ?? 0
                let minutes = max(0, Int(ceil(Double(seconds) / 60.0)))
                let observedAt = parseYVRDate(row.LastUpdatedDate) ?? Date()

                return WaitTimeEstimate(
                    airport: .yvr,
                    terminal: nil,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: observedAt,
                    checkpointName: row.Terminal,
                    areaName: "Security",
                    sourceType: .live
                )
            }
    }

    private func parseYVRDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Vancouver")
        formatter.dateFormat = "EEEE, dd MMMM yyyy HH:mm:ss"
        return formatter.date(from: value)
    }
}

private struct YVRCatsaResponse: Decodable {
    let value: [YVRCatsaRow]
}

private struct YVRCatsaRow: Decodable {
    let WaitTime: String
    let Terminal: String
    let CreatedDate: String
    let LastUpdatedDate: String
}

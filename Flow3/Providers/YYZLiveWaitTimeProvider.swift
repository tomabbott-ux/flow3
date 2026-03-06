import Foundation

struct YYZLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://www.torontopearson.com/api/waittimeapidata/getcheckpoints?scenario=departure")!

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .yyz else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://www.torontopearson.com/en/airport-wait-time-dashboard", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(YYZWaitResponse.self, from: data)

        let rows = decoded.checkpoints
            .filter { $0.departure }
            .compactMap { checkpoint -> WaitTimeEstimate? in
                guard let terminal = terminalNumber(from: checkpoint.terminal) else { return nil }

                let minutes = max(0, Int(ceil(Double(checkpoint.waitTimeInSecond) / 60.0)))
                let observedAt = isoDate(from: checkpoint.lastUpdate) ?? Date()

                return WaitTimeEstimate(
                    airport: .yyz,
                    terminal: terminal,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: observedAt,
                    checkpointName: checkpoint.nameEn,
                    areaName: checkpoint.zone,
                    sourceType: .live
                )
            }

        var bestByTerminal: [Int: WaitTimeEstimate] = [:]

        for row in rows {
            let key = row.terminal ?? -1

            if let existing = bestByTerminal[key] {
                if row.minutes < existing.minutes {
                    bestByTerminal[key] = row
                }
            } else {
                bestByTerminal[key] = row
            }
        }

        return bestByTerminal
            .keys
            .sorted()
            .compactMap { bestByTerminal[$0] }
    }

    private func terminalNumber(from text: String) -> Int? {
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(digits)
    }

    private func isoDate(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: string) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string)
    }
}

private struct YYZWaitResponse: Decodable {
    let serverTime: String
    let lastUpdate: String
    let scenario: String
    let checkpoints: [YYZCheckpoint]
}

private struct YYZCheckpoint: Decodable {
    let waitTimeInSecond: Int
    let lastUpdate: String
    let id: Int
    let nameEn: String
    let nameFr: String
    let terminal: String
    let zone: String
    let departure: Bool
    let connection: Bool
}

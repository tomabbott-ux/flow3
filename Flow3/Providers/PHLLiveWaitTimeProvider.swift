import Foundation

struct PHLLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://api.livereachmedia.com/api/v1/locations/3951/metrics/live?metrics=waitTime&metrics=waitTimeRange")!
    private let apiKey = "28a78f782249d64ad419e4e78ae50d95"

    private let zoneMap: [Int: (name: String, queueType: QueueType)] = [
        4126: ("Terminal D/E", .precheck),
        3971: ("Terminal D/E", .general),
        4377: ("Terminal A-West", .general),
        4386: ("Terminal A-East", .precheck),
        4368: ("Terminal A-East", .general),
        5047: ("Terminal B", .general),
        5052: ("Terminal C", .precheck),
        5068: ("Terminal F", .general)
    ]

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .phl else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://www.phl.org", forHTTPHeaderField: "Origin")
        request.setValue("https://www.phl.org/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data, options: [])

        guard let root = json as? [String: Any],
              let content = root["content"] as? [String: Any],
              let rows = content["rows"] as? [Any] else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "Unsupported PHL response format."
                )
            )
        }

        var estimates: [WaitTimeEstimate] = []

        for item in rows {
            guard let row = item as? [Any],
                  row.count >= 2,
                  let zoneID = intValue(row[0]),
                  let mapping = zoneMap[zoneID],
                  let rawWait = doubleValue(row[1]) else {
                continue
            }

            let minutes = Int(ceil(rawWait))

            estimates.append(
                WaitTimeEstimate(
                    airport: .phl,
                    terminal: terminalNumber(for: mapping.name),
                    queueType: mapping.queueType,
                    minutes: max(0, minutes),
                    observedAt: Date(),
                    checkpointName: mapping.name,
                    areaName: "Security",
                    sourceType: .live
                )
            )
        }

        return estimates
    }

    private func terminalNumber(for checkpoint: String) -> Int? {
        if checkpoint.contains("A") { return 1 }
        if checkpoint.contains("B") { return 2 }
        if checkpoint.contains("C") { return 3 }
        if checkpoint.contains("D/E") { return 4 }
        if checkpoint.contains("F") { return 5 }
        return nil
    }

    private func intValue(_ value: Any) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String, let int = Int(string) { return int }
        return nil
    }

    private func doubleValue(_ value: Any) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String, let double = Double(string) { return double }
        return nil
    }
}

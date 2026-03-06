import Foundation

struct PHXLiveWaitTimeProvider: WaitTimeProviding {

    private let endpoint = URL(string: "https://api.phx.aero/avn-wait-times/raw?Key=4f85fe2ef5a240d59809b63de94ef536")!

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .phx else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.skyharbor.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.skyharbor.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data, options: [])

        let rawRows = extractRows(from: json)

        let results: [WaitTimeEstimate] = rawRows.compactMap { row in
            guard let checkpointRaw = stringValue(
                row["checkpoint"],
                row["checkpointName"],
                row["name"],
                row["queueName"],
                row["title"]
            ) else {
                return nil
            }

            guard let minutes = minutesValue(from: row) else {
                return nil
            }

            let observedAt =
                dateValue(
                    row["lastUpdated"],
                    row["last_updated"],
                    row["time"],
                    row["localTime"]
                )
                ?? timestampDate(
                    row["lastUpdatedTimestamp"],
                    row["timestamp"]
                )
                ?? Date()

            return WaitTimeEstimate(
                airport: .phx,
                terminal: terminalFromCheckpoint(checkpointRaw),
                queueType: .general,
                minutes: max(0, minutes),
                observedAt: observedAt,
                checkpointName: checkpointName(from: checkpointRaw),
                areaName: areaName(from: checkpointRaw),
                sourceType: .live
            )
        }

        return results
    }

    // MARK: - Row Extraction

    private func extractRows(from json: Any) -> [[String: Any]] {
        if let array = json as? [[String: Any]] {
            return array
        }

        if let dict = json as? [String: Any] {
            if let rows = dict["current"] as? [[String: Any]] {
                return rows
            }

            if let rows = dict["wait_times"] as? [[String: Any]] {
                return rows
            }

            if let data = dict["data"] as? [String: Any] {
                if let rows = data["wait_times"] as? [[String: Any]] {
                    return rows
                }

                if let rows = data["current"] as? [[String: Any]] {
                    return rows
                }
            }

            if let rows = dict["results"] as? [[String: Any]] {
                return rows
            }
        }

        return []
    }

    // MARK: - Field Parsing

    private func stringValue(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return string
            }
        }
        return nil
    }

    private func intValue(_ values: Any?...) -> Int? {
        for value in values {
            if let int = value as? Int {
                return int
            }
            if let double = value as? Double {
                return Int(double)
            }
            if let string = value as? String,
               let int = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return int
            }
        }
        return nil
    }

    private func minutesValue(from row: [String: Any]) -> Int? {
        if let minutes = intValue(
            row["waitTimeMinutes"],
            row["wait_minutes"],
            row["minutes"],
            row["projectedMinWaitMinutes"],
            row["projectedWaitMinutes"]
        ) {
            return minutes
        }

        if let seconds = intValue(
            row["waitSeconds"],
            row["projectedWaitTime"],
            row["wait_time_seconds"]
        ) {
            return Int((Double(seconds) / 60.0).rounded())
        }

        return nil
    }

    private func dateValue(_ values: Any?...) -> Date? {
        let iso = ISO8601DateFormatter()

        for value in values {
            if let string = value as? String {
                if let date = iso.date(from: string) {
                    return date
                }

                let fallback = DateFormatter()
                fallback.locale = Locale(identifier: "en_US_POSIX")
                fallback.dateFormat = "MM/dd/yy h:mm a"
                if let date = fallback.date(from: string) {
                    return date
                }
            }
        }

        return nil
    }

    private func timestampDate(_ values: Any?...) -> Date? {
        for value in values {
            if let int = intValue(value) {
                return Date(timeIntervalSince1970: TimeInterval(int))
            }
        }
        return nil
    }

    // MARK: - PHX Naming

    private func checkpointName(from raw: String) -> String {
        let upper = raw.uppercased()

        if upper.contains("CHECKPOINT A") { return "Checkpoint A" }
        if upper.contains("CHECKPOINT B") { return "Checkpoint B" }
        if upper.contains("CHECKPOINT C") { return "Checkpoint C" }
        if upper.contains("CHECKPOINT D") { return "Checkpoint D" }

        if upper.contains("TERMINAL 3") || upper.contains("T3") {
            return "Checkpoint"
        }

        return raw
    }

    private func areaName(from raw: String) -> String {
        let upper = raw.uppercased()

        if upper.contains("TERMINAL 3") || upper.contains("T3") {
            return "Terminal 3"
        }

        if upper.contains("TERMINAL 4") || upper.contains("T4") {
            return "Terminal 4"
        }

        return "Security"
    }

    private func terminalFromCheckpoint(_ raw: String) -> Int? {
        let upper = raw.uppercased()

        if upper.contains("TERMINAL 3") || upper.contains("T3") { return 3 }
        if upper.contains("TERMINAL 4") || upper.contains("T4") { return 4 }

        return nil
    }
}

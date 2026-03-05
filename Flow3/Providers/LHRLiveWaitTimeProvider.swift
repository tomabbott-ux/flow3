import Foundation

struct LHRLiveWaitTimeProvider: WaitTimeProviding {

    // ✅ Real Heathrow endpoint from your Network tab
    private let endpoint = URL(string: "https://api-dp-prod.dp.heathrow.com/pihub/securitywaittime?checkpointFacilityType=securityStandard")!

    // ✅ Align refresh expectation with ATL/JFK (60s)
    let refreshIntervalSeconds: TimeInterval = 60

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lhr else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("LHR API status: \(http.statusCode)")
            print("LHR API bytes: \(data.count)")
        }

        let json = try JSONSerialization.jsonObject(with: data, options: [])

        guard let arr = json as? [[String: Any]] else {
            print("LHR top-level not array")
            return []
        }

        let rows = parseRows(from: arr)
        print("LHR parsed rows: \(rows.count)")
        return rows
            .map { $0.toEstimate() }
    }

    // MARK: - Row

    private struct Row {
        let terminal: Int
        let queueType: QueueType
        let minutes: Int
        let observedAt: Date
        let checkpoint: String

        func toEstimate() -> WaitTimeEstimate {
            WaitTimeEstimate(
                airport: .lhr,
                terminal: terminal,
                queueType: queueType,
                minutes: minutes,
                observedAt: observedAt
            )
        }
    }

    // MARK: - Parsing

    private func parseRows(from arr: [[String: Any]]) -> [Row] {
        var out: [Row] = []
        for item in arr {
            if let row = parseOne(item) {
                out.append(row)
            }
        }

        // Deduplicate (Heathrow sometimes repeats)
        // Key: terminal + queueType
        var seen = Set<String>()
        var deduped: [Row] = []
        for r in out {
            let key = "\(r.terminal)|\(r.queueType)"
            if !seen.contains(key) {
                seen.insert(key)
                deduped.append(r)
            }
        }

        return deduped
    }

    private func parseOne(_ item: [String: Any]) -> Row? {
        // checkpointFacility -> terminalFacility.code and area (N/S)
        guard
            let checkpointFacility = item["checkpointFacility"] as? [String: Any],
            let terminalFacility = checkpointFacility["terminalFacility"] as? [String: Any],
            let terminalCode = terminalFacility["code"] as? String,
            let terminal = Int(terminalCode)
        else {
            return nil
        }

        let area = checkpointFacility["area"] as? String // "N" / "S" or nil
        let queueType = inferQueueType(terminal: terminal, area: area)

        let observedAt = parseISO8601(item["lastUpdated"] as? String) ?? Date()

        // Minutes can be:
        // - waitTimeRangeMinutes "<5"
        // - waitTimeMessage "Less than 5 minutes"
        // - queueMeasurements min/max with min = -1 max = 5
        let minutes = parseMinutes(item)

        // Safety: ignore nonsense (negative)
        if minutes < 0 { return nil }

        // checkpoint label (UI shows "Security" everywhere)
        let checkpoint = "Security"

        return Row(
            terminal: terminal,
            queueType: queueType,
            minutes: minutes,
            observedAt: observedAt,
            checkpoint: checkpoint
        )
    }

    private func inferQueueType(terminal: Int, area: String?) -> QueueType {
        // Your mapping:
        // T5 North -> .general
        // T5 South -> .precheck
        if terminal == 5 {
            if let a = area?.uppercased(), a == "S" {
                return .precheck
            } else {
                return .general
            }
        }
        return .general
    }

    private func parseMinutes(_ item: [String: Any]) -> Int {
        // 1) Try explicit range string first
        if let range = item["waitTimeRangeMinutes"] as? String {
            if let m = minutesFromRangeString(range) {
                return m
            }
        }

        // 2) Try message text
        if let msg = item["waitTimeMessage"] as? String {
            if let m = minutesFromMessage(msg) {
                return m
            }
        }

        // 3) Try queueMeasurements min/max
        if let qm = item["queueMeasurements"] as? [[String: Any]] {
            let minV = measurementValue(named: "minimumWaitTime", in: qm)
            let maxV = measurementValue(named: "maximumWaitTime", in: qm)

            // Heathrow uses min=-1 max=5 for "<5"
            if (minV == -1 && maxV == 5) {
                return 4
            }

            // If both exist and sane, use midpoint-ish
            if let minV, let maxV, minV >= 0, maxV >= 0 {
                if maxV == minV { return maxV }
                let mid = (minV + maxV) / 2
                return max(mid, 0)
            }

            // If only max exists and is sane, use max
            if let maxV, maxV >= 0 {
                return maxV
            }
        }

        // Fallback: unknown -> treat as 0? Better to show "--" in UI,
        // but Estimate needs an Int. Return 0 so your pill doesn’t break.
        return 0
    }

    private func measurementValue(named name: String, in arr: [[String: Any]]) -> Int? {
        for obj in arr {
            guard let n = obj["name"] as? String, n == name else { continue }
            if let v = obj["value"] as? Int { return v }
            if let v = obj["value"] as? Double { return Int(v) }
        }
        return nil
    }

    private func minutesFromRangeString(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // "<5" => use 4
        if trimmed.hasPrefix("<") {
            return 4
        }

        // "5-10" => use lower bound (stable)
        let parts = trimmed.split(separator: "-").map { String($0) }
        if parts.count == 2, let a = Int(parts[0].trimmingCharacters(in: .whitespaces)),
           let b = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            return max(0, min(a, b))
        }

        // "10" => direct
        if let v = Int(trimmed) {
            return max(0, v)
        }

        return nil
    }

    private func minutesFromMessage(_ s: String) -> Int? {
        let lower = s.lowercased()

        if lower.contains("less than 5") { return 4 }

        // Pull first integer if present
        let digits = lower.filter { $0.isNumber || $0 == " " }
        let comps = digits.split(separator: " ").compactMap { Int($0) }
        if let first = comps.first {
            return max(0, first)
        }

        return nil
    }

    private func parseISO8601(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }

        // Try without fractional seconds
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}

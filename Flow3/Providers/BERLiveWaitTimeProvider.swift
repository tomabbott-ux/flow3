import Foundation

struct BERLiveWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .ber else { return [] }

        let url = URL(string: "https://ber.berlin-airport.de/api.aplsv2.json?lang=en")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataBlock = json["data"] as? [String: Any],
            let checkpoints = dataBlock["apls-data"] as? [[String: Any]]
        else {
            return []
        }

        var estimates: [WaitTimeEstimate] = []

        for item in checkpoints {

            let terminal = item["terminal"] as? String ?? ""
            let security = item["security_control"] as? String ?? ""
            let low = item["low_minutes"] as? Int ?? 0
            let label = (item["workload_label"] as? String ?? "").lowercased()
            let workload = (item["workload"] as? String ?? "").uppercased()

            let terminalNumber = Int(terminal.replacingOccurrences(of: "T", with: "")) ?? 1

            let checkpointName: String
            let minutes: Int?
            let isClosed: Bool

            if label.contains("priority") || workload == "P" {
                checkpointName = "Priority Security"
                minutes = low
                isClosed = false

            } else if label.contains("runway") || workload == "R" {
                checkpointName = "Runway Security"
                minutes = low
                isClosed = false
                
            } else if label.contains("closed") || workload == "C" {
                if terminal == "T2" {
                    checkpointName = "Security"
                } else if security.isEmpty || security == "0" {
                    checkpointName = "Security"
                } else {
                    checkpointName = "Security \(security)"
                }
                minutes = nil
                isClosed = true

            } else if terminal == "T2" {
                checkpointName = "Security"
                minutes = low
                isClosed = false

            } else if security.isEmpty || security == "0" {
                checkpointName = "Security"
                minutes = low
                isClosed = false

            } else {
                checkpointName = "Security \(security)"
                minutes = low
                isClosed = false
            }

            let estimate = WaitTimeEstimate(
                airport: airport,
                terminal: terminalNumber,
                queueType: .general,
                minutes: minutes ?? 0,
                observedAt: Date(),
                checkpointName: checkpointName,
                areaName: "Terminal \(terminalNumber)",
                sourceType: .live,
                isClosed: isClosed
            )

            estimates.append(estimate)
        }

        return estimates.sorted { lhs, rhs in
            let lhsTerminal = lhs.terminal ?? 0
            let rhsTerminal = rhs.terminal ?? 0

            if lhsTerminal != rhsTerminal {
                return lhsTerminal < rhsTerminal
            }

            return sortRank(
                checkpointName: lhs.checkpointName ?? "",
                terminal: lhsTerminal
            ) < sortRank(
                checkpointName: rhs.checkpointName ?? "",
                terminal: rhsTerminal
            )
        }
    }

    private func sortRank(checkpointName: String, terminal: Int) -> Int {

        if terminal == 1 {
            switch checkpointName {
            case "Security 1": return 10
            case "Priority Security": return 20
            case "Security 2": return 30
            case "Runway Security": return 40
            case "Security 4": return 50
            case "Security 5": return 60
            default: return 999
            }
        }

        if terminal == 2 {
            switch checkpointName {
            case "Security": return 10
            default: return 999
            }
        }

        return 999
    }
}

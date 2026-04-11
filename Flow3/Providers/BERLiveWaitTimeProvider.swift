import Foundation

struct BERLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case invalidResponse
        case badHTTPStatus(Int)
        case invalidJSON
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .ber else { return [] }

        guard let url = URL(string: "https://ber.berlin-airport.de/api.aplsv2.json?lang=en") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://ber.berlin-airport.de/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataBlock = json["data"] as? [String: Any],
            let checkpoints = dataBlock["apls-data"] as? [[String: Any]]
        else {
            throw ProviderError.invalidJSON
        }

        var estimates: [WaitTimeEstimate] = []

        for item in checkpoints {

            let terminal = item["terminal"] as? String ?? ""
            let security = item["security_control"] as? String ?? ""
            let low = item["low_minutes"] as? Int ?? 0
            let label = (item["workload_label"] as? String ?? "").lowercased()
            let workload = (item["workload"] as? String ?? "").uppercased()

            let terminalNumber = Int(
                terminal
                    .replacingOccurrences(of: "T", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            ) ?? 1

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

import Foundation

final class DUBLiveWaitTimeProvider: WaitTimeProviding {

    private let url = URL(string: "https://api.dublinairport.com/dap/get-security-times")!

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return []
        }

        var results: [WaitTimeEstimate] = []

        for (key, value) in json {

            guard let minutes = cleanValue(value) else { continue }

            let terminal: Int

            switch key {
            case "T1":
                terminal = 1
            case "T2":
                terminal = 2
            default:
                continue
            }
            
            results.append(
                WaitTimeEstimate(
                    airport: airport,
                    terminal: terminal,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: Date()
                )
            )
        }

        return results.sorted { $0.minutes < $1.minutes }
    }

    private func cleanValue(_ raw: String) -> Int? {
        let cleaned = raw
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Int(cleaned)
    }
}

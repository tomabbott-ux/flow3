import Foundation

final class BNAWebsiteWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .bna else { return [] }

        let url = URL(string: "https://flynashville.com")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }

        let normalized = html.lowercased()

        let pattern = #"less than\s+(\d+)\s+minutes|(\d+)\s+minutes"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(normalized.startIndex..., in: normalized)

        if let match = regex.firstMatch(in: normalized, range: range) {

            var minutes: Int?

            if let r1 = Range(match.range(at: 1), in: normalized) {
                minutes = Int(normalized[r1])
            } else if let r2 = Range(match.range(at: 2), in: normalized) {
                minutes = Int(normalized[r2])
            }

            if let minutes {
                return [
                    WaitTimeEstimate(
                        airport: airport,
                        terminal: nil,
                        queueType: .general,
                        minutes: minutes,
                        observedAt: Date(),
                        checkpointName: "Main Checkpoint",
                        sourceType: .live,
                        isClosed: false
                    )
                ]
            }
        }

        return []
    }
}

import Foundation

struct FcoWaitTimeProvider {

    static func fetchWaitTimes() async throws -> [WaitTimeEstimate] {

        let url = URL(string: "https://www.adr.it/web/aeroporti-di-roma-en")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }

        let t1 = extractMinutes(from: html, after: "Terminal 1:")
        let t3 = extractMinutes(from: html, after: "Terminal 3:")

        var results: [WaitTimeEstimate] = []

        if let minutes = t1 {
            results.append(
                WaitTimeEstimate(
                    airport: .fco,
                    terminal: 1,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: Date()
                )
            )
        }

        if let minutes = t3 {
            results.append(
                WaitTimeEstimate(
                    airport: .fco,
                    terminal: 3,
                    queueType: .general,
                    minutes: minutes,
                    observedAt: Date()
                )
            )
        }

        return results
    }

    private static func extractMinutes(
        from html: String,
        after marker: String
    ) -> Int? {

        guard let markerRange = html.range(of: marker) else { return nil }

        let substring = html[markerRange.upperBound...]

        guard let start = substring.range(of: "<time>"),
              let end = substring.range(of: "</time>") else { return nil }

        let raw = substring[start.upperBound..<end.lowerBound]

        let cleaned = raw
            .replacingOccurrences(of: "min", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Int(cleaned)
    }
}

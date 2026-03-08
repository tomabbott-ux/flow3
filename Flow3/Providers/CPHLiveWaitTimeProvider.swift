import Foundation

final class CPHLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
        case missingWaitTime
    }

    private let session: URLSession
    private let apiURL = URL(string: "https://cphwaitingtime.z6.web.core.windows.net/waitingtime.json")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .cph else { return [] }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(CPHResponse.self, from: data)

        let observedAt = ISO8601DateFormatter().date(from: decoded.deliveryId) ?? Date()

        guard let t2Minutes = parseUpperBoundMinutes(from: decoded.t2WaitingTimeInterval),
              let t3Minutes = parseUpperBoundMinutes(from: decoded.t3WaitingTimeInterval) else {
            throw ProviderError.missingWaitTime
        }

        return [
            WaitTimeEstimate(
                airport: .cph,
                terminal: 2,
                queueType: .general,
                minutes: t2Minutes,
                observedAt: observedAt,
                checkpointName: "Security",
                areaName: "Terminal 2",
                sourceType: .live
            ),
            WaitTimeEstimate(
                airport: .cph,
                terminal: 3,
                queueType: .general,
                minutes: t3Minutes,
                observedAt: observedAt,
                checkpointName: "Security",
                areaName: "Terminal 3",
                sourceType: .live
            )
        ]
    }

    private func parseUpperBoundMinutes(from value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let pattern = #"(\d+)\s*-\s*(\d+)\s*min"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

            if let match = regex.firstMatch(in: trimmed, options: [], range: range),
               let upperRange = Range(match.range(at: 2), in: trimmed),
               let upper = Int(trimmed[upperRange]) {
                return upper
            }
        }

        let singlePattern = #"(\d+)\s*min"#

        if let regex = try? NSRegularExpression(pattern: singlePattern, options: [.caseInsensitive]) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

            if let match = regex.firstMatch(in: trimmed, options: [], range: range),
               let minuteRange = Range(match.range(at: 1), in: trimmed),
               let minute = Int(trimmed[minuteRange]) {
                return minute
            }
        }

        return nil
    }
}

private struct CPHResponse: Decodable {
    let t2WaitingTime: String
    let t2WaitingTimeInterval: String
    let t3WaitingTime: String
    let t3WaitingTimeInterval: String
    let supplier: String
    let documentName: String
    let deliveryId: String
}

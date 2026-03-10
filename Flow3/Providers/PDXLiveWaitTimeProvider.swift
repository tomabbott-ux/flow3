import Foundation

final class PDXLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .pdx else { return [] }

        guard let url = URL(string: "https://www.flypdx.com/TSAWaitTimesRefresh") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://www.flypdx.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.3 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(PDXResponse.self, from: data)
        let now = Date()

        var results: [WaitTimeEstimate] = []

        for counter in decoded.WaitTimes {
            let counterName = counter.CounterName.lowercased()

            var checkpoint = "Security"
            var queueType: QueueType = .general

            if counterName.contains("north") {
                checkpoint = "Checkpoint B C"
            }

            if counterName.contains("south") {
                checkpoint = "Checkpoint D E"
            }

            if counterName.contains("pre") {
                queueType = .precheck
            }

            let minutes = Int(counter.DisplayText) ?? 0

            results.append(
                WaitTimeEstimate(
                    airport: .pdx,
                    terminal: nil,
                    queueType: queueType,
                    minutes: minutes,
                    observedAt: now,
                    checkpointName: checkpoint,
                    areaName: "PDX",
                    sourceType: .live,
                    isClosed: false
                )
            )
        }

        return results.sorted {
            ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
        }
    }
}

private struct PDXResponse: Decodable {
    let WaitTimes: [PDXCounter]
}

private struct PDXCounter: Decodable {
    let CounterId: Int
    let CounterName: String
    let DisplayText: String
}

import Foundation

final class DTWLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case unsupportedAirport
        case invalidURL
        case invalidResponse
        case badHTTPStatus(Int)
        case emptyData
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .dtw else {
            throw ProviderError.unsupportedAirport
        }

        guard let url = URL(string: "https://proxy.metroairport.com/SkyFiiTSAProxy.ashx") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 6
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.metroairport.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://www.metroairport.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Safari/605.1.15",
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

        let rows = try JSONDecoder().decode([DTWCheckpointPayload].self, from: data)

        guard !rows.isEmpty else {
            throw ProviderError.emptyData
        }

        let now = Date()

        let results = rows.compactMap { row -> WaitTimeEstimate? in
            let rawName = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty else { return nil }

            let checkpointName = normalizedCheckpointName(from: rawName)
            let terminal = inferredTerminal(from: rawName)

            return WaitTimeEstimate(
                airport: .dtw,
                terminal: terminal,
                queueType: .general,
                minutes: max(0, row.waitTime),
                observedAt: now,
                checkpointName: checkpointName,
                areaName: "Detroit",
                sourceType: .live,
                isClosed: false
            )
        }

        guard !results.isEmpty else {
            throw ProviderError.emptyData
        }

        return results.sorted {
            ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
        }
    }

    private func normalizedCheckpointName(from rawName: String) -> String {
        let normalized = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized.lowercased() {
        case "evans":
            return "Evans"
        case "mcnamara":
            return "McNamara"
        default:
            return normalized
        }
    }

    private func inferredTerminal(from rawName: String) -> Int? {
        switch rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "evans":
            return 1
        case "mcnamara":
            return 2
        default:
            return nil
        }
    }
}

private struct DTWCheckpointPayload: Decodable {
    let name: String
    let waitTime: Int

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case waitTime = "WaitTime"
    }
}

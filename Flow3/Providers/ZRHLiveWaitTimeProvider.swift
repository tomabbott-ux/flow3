import Foundation

struct ZRHLiveWaitTimeProvider: WaitTimeProviding {

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
        guard airport == .zrh else { return [] }

        guard let url = URL(string: "https://waitingtimes.flughafen-zuerich.ch/WaitingTimes/Security") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.flughafen-zuerich.ch", forHTTPHeaderField: "Origin")
        request.setValue("https://www.flughafen-zuerich.ch/", forHTTPHeaderField: "Referer")
        request.setValue("www.flughafen-zuerich.ch", forHTTPHeaderField: "Jss-Origin-Host")
        request.setValue("https://www.flughafen-zuerich.ch/en/passengers/fly/flightinformation/departures", forHTTPHeaderField: "Jss-Original-Url")
        request.setValue("www.flughafen-zuerich.ch", forHTTPHeaderField: "X-Forwarded-Host")
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

        let payload = try JSONDecoder().decode(ZRHSecurityResponse.self, from: data)
        let minutes = parseMinutes(from: payload.maxWaitingTime)

        return [
            WaitTimeEstimate(
                airport: .zrh,
                terminal: nil,
                queueType: .general,
                minutes: minutes,
                observedAt: Date(),
                checkpointName: "Security",
                areaName: nil,
                sourceType: .live,
                isClosed: false
            )
        ]
    }

    private func parseMinutes(from raw: String) -> Int {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("-") {
            let parts = trimmed.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if let last = parts.last {
                return max(0, last)
            }
        }

        if let value = Int(trimmed) {
            return max(0, value)
        }

        return 0
    }
}

private struct ZRHSecurityResponse: Decodable {
    let maxWaitingTime: String
}

import Foundation

struct OSLLiveWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case invalidURL
        case invalidResponse
        case badHTTPStatus(Int)
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .osl else { return [] }

        guard let url = URL(string: "https://www.avinor.no/api/v1/airportsecurity/waittime/OSL?language=eng") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.avinor.no/en/airport/oslo/", forHTTPHeaderField: "Referer")
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload = try decoder.decode([OSLWaitTimeItem].self, from: data)

        let rows: [WaitTimeEstimate] = payload.compactMap { item in
            guard item.isAvailable else { return nil }

            let mapped = mapItem(item)
            guard mapped.include else { return nil }

            let minutes = max(0, item.timeMinutesRounded)

            return WaitTimeEstimate(
                airport: .osl,
                terminal: nil,
                queueType: .general,
                minutes: minutes,
                observedAt: item.lastUpdated,
                checkpointName: mapped.title,
                areaName: nil,
                sourceType: .live,
                isClosed: false
            )
        }

        return rows.sorted {
            ($0.checkpointName ?? "") < ($1.checkpointName ?? "")
        }
    }

    private func mapItem(_ item: OSLWaitTimeItem) -> (include: Bool, title: String) {
        let area = item.area.lowercased()
        let location = item.location?.lowercased() ?? ""

        if area == "csc" {
            return (true, "Central Security")
        }

        if area == "emi", location == "eu" {
            return (true, "Transfer Security EU")
        }

        if area == "emi", location == "noneu" {
            return (true, "Transfer Security Non-EU")
        }

        return (false, "")
    }
}

private struct OSLWaitTimeItem: Decodable {
    let airportIata: String
    let area: String
    let location: String?
    let timeSecond: Int
    let timeText: String
    let isAvailable: Bool
    let lastUpdated: Date
    let timeMinutesRounded: Int
    let timeTextMinutes: String
}

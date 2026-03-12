import Foundation

struct HELLiveWaitTimeProvider: WaitTimeProviding {

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
        guard airport == .hel else { return [] }

        guard let url = URL(string: "https://www.finavia.fi/en/api/security-waiting-time-stats") else {
            throw ProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://www.finavia.fi/en/airports/helsinki-airport/", forHTTPHeaderField: "Referer")
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
        let payload = try decoder.decode(HELSecurityResponse.self, from: data)

        guard !payload.secDepartureHall.isEmpty else { return [] }

        let now = Date()

        let parsedRows: [(entry: HELSecurityEntry, date: Date)] = payload.secDepartureHall.compactMap { entry in
            guard let date = Self.entryDateFormatter.date(from: "\(entry.messageDate) \(entry.messageTime)") else {
                return nil
            }
            return (entry, date)
        }

        guard !parsedRows.isEmpty else { return [] }

        // Prefer the nearest current/future row; if none, fall back to the latest past row.
        let chosen: (entry: HELSecurityEntry, date: Date)

        if let next = parsedRows
            .filter({ $0.date >= now })
            .min(by: { $0.date < $1.date }) {
            chosen = next
        } else if let latestPast = parsedRows.max(by: { $0.date < $1.date }) {
            chosen = latestPast
        } else {
            return []
        }

        let minutes = max(0, Int(ceil(chosen.entry.averageWaitingTime)))
        let isClosed = chosen.entry.securityLaneOpen == false

        return [
            WaitTimeEstimate(
                airport: .hel,
                terminal: nil,
                queueType: .general,
                minutes: minutes,
                observedAt: chosen.date,
                checkpointName: "Departure Security",
                areaName: "Terminal",
                sourceType: .live,
                isClosed: isClosed
            )
        ]
    }

    private static let entryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Helsinki")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}

private struct HELSecurityResponse: Decodable {
    let secDepartureHall: [HELSecurityEntry]

    enum CodingKeys: String, CodingKey {
        case secDepartureHall = "SecDepartureHall"
    }
}

private struct HELSecurityEntry: Decodable {
    let messageDate: String
    let messageTime: String
    let averageWaitingTime: Double
    let securityLaneOpen: Bool
    let countEnteringQueue: String
}

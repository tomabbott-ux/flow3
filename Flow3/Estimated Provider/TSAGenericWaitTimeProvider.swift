import Foundation

final class TSAGenericWaitTimeProvider: WaitTimeProviding {

    enum ProviderError: Error {
        case badHTTPStatus(Int)
        case invalidResponse
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard let url = URL(string: "https://tsawaittimes.com/api/airport/\(airport.rawValue)") else {
            throw ProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "application/json, text/plain, */*",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ProviderError.badHTTPStatus(http.statusCode)
        }

        let payload = try JSONDecoder().decode(TSAResponse.self, from: data)

        let now = Date()

        // Resolve best available wait time
        let waitMinutes = payload.rightnowMinutes ?? payload.hourlyFallback ?? 12

        let airportName = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAirportName = (airportName?.isEmpty == false) ? airportName! : airport.displayName

        return [
            WaitTimeEstimate(
                airport: airport,
                terminal: 1,
                queueType: .general,
                minutes: max(0, waitMinutes),
                observedAt: now,
                checkpointName: "Security",
                areaName: cleanAirportName,
                sourceType: .live
            )
        ]
    }
}

private struct TSAResponse: Decodable {

    let code: String?
    let name: String?
    let rightnowInt: Int?
    let rightnowDouble: Double?
    let rightnowString: String?
    let estimatedHourlyTimes: [TSAHourlySlot]

    var rightnowMinutes: Int? {

        if let rightnowInt {
            return rightnowInt
        }

        if let rightnowDouble {
            return Int(rightnowDouble.rounded())
        }

        if let rightnowString {

            let trimmed = rightnowString.trimmingCharacters(in: .whitespacesAndNewlines)

            if let intValue = Int(trimmed) {
                return intValue
            }

            if let doubleValue = Double(trimmed) {
                return Int(doubleValue.rounded())
            }
        }

        return nil
    }

    var hourlyFallback: Int? {
        estimatedHourlyTimes
            .compactMap { $0.waitMinutes }
            .first
    }

    enum CodingKeys: String, CodingKey {
        case code
        case name
        case rightnow
        case estimatedHourlyTimes = "estimated_hourly_times"
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decodeIfPresent(String.self, forKey: .code)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        rightnowInt = try container.decodeIfPresent(Int.self, forKey: .rightnow)
        rightnowDouble = try container.decodeIfPresent(Double.self, forKey: .rightnow)
        rightnowString = try container.decodeIfPresent(String.self, forKey: .rightnow)

        estimatedHourlyTimes = try container.decodeIfPresent(
            [TSAHourlySlot].self,
            forKey: .estimatedHourlyTimes
        ) ?? []
    }
}

private struct TSAHourlySlot: Decodable {

    let timeslot: String?
    let hour: Int?
    let waitInt: Int?
    let waitDouble: Double?
    let waitString: String?

    var waitMinutes: Int? {

        if let waitInt {
            return waitInt
        }

        if let waitDouble {
            return Int(waitDouble.rounded())
        }

        if let waitString {

            let trimmed = waitString.trimmingCharacters(in: .whitespacesAndNewlines)

            if let intValue = Int(trimmed) {
                return intValue
            }

            if let doubleValue = Double(trimmed) {
                return Int(doubleValue.rounded())
            }
        }

        return nil
    }

    enum CodingKeys: String, CodingKey {
        case timeslot
        case hour
        case waittime
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)

        timeslot = try container.decodeIfPresent(String.self, forKey: .timeslot)
        hour = try container.decodeIfPresent(Int.self, forKey: .hour)

        waitInt = try container.decodeIfPresent(Int.self, forKey: .waittime)
        waitDouble = try container.decodeIfPresent(Double.self, forKey: .waittime)
        waitString = try container.decodeIfPresent(String.self, forKey: .waittime)
    }
}

import Foundation

struct AMSFlightResult {
    let flightName: String
    let airlineCode: String?
    let flightNumber: String
    let scheduleDate: String
    let publicFlightURL: URL?
    let departureTerminal: String?
    let departureGate: String?
    let expectedSecurityFilter: String?
}

final class AMSFlightLookupService {

    private let session: URLSession
    private let maxPagesToSearch = 8

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookupFlight(
        flightNumber: String,
        departureDate: Date
    ) async throws -> AMSFlightResult? {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")

        let scheduleDate = dateFormatter.string(from: departureDate)
        let normalizedInput = normalizeFlightNumber(flightNumber)

        for page in 0..<maxPagesToSearch {
            if let match = try await fetchPageAndFindMatch(
                normalizedFlightNumber: normalizedInput,
                scheduleDate: scheduleDate,
                page: page
            ) {
                let publicURL = buildPublicFlightURL(
                    flightName: match.flightName,
                    scheduleDate: match.scheduleDate
                )

                return AMSFlightResult(
                    flightName: match.flightName,
                    airlineCode: match.prefixIATA,
                    flightNumber: match.flightName,
                    scheduleDate: match.scheduleDate,
                    publicFlightURL: publicURL,
                    departureTerminal: match.terminal,
                    departureGate: match.gate,
                    expectedSecurityFilter: match.expectedSecurityFilter
                )
            }
        }

        return nil
    }

    private func fetchPageAndFindMatch(
        normalizedFlightNumber: String,
        scheduleDate: String,
        page: Int
    ) async throws -> SchipholFlight? {

        let urlString =
            "\(SchipholAPIConfig.baseURL)/flights" +
            "?scheduleDate=\(scheduleDate)" +
            "&flightDirection=D" +
            "&includedelays=false" +
            "&page=\(page)" +
            "&sort=+scheduleTime"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            SchipholAPIConfig.appID.trimmingCharacters(in: .whitespacesAndNewlines),
            forHTTPHeaderField: "app_id"
        )
        request.setValue(
            SchipholAPIConfig.appKey.trimmingCharacters(in: .whitespacesAndNewlines),
            forHTTPHeaderField: "app_key"
        )
        request.setValue(
            SchipholAPIConfig.resourceVersion,
            forHTTPHeaderField: "ResourceVersion"
        )

        print("AMS LOOKUP URL:", url.absoluteString)
        print("AMS LOOKUP app_id length:", SchipholAPIConfig.appID.count)
        print("AMS LOOKUP app_key length:", SchipholAPIConfig.appKey.count)
        print("AMS LOOKUP resourceVersion:", SchipholAPIConfig.resourceVersion)
        print("AMS LOOKUP page:", page)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        print("AMS LOOKUP status:", http.statusCode)

        if let body = String(data: data, encoding: .utf8) {
            print("AMS LOOKUP body:", body)
        }

        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SchipholFlightsResponse.self, from: data)

        return decoded.flights.first(where: {
            normalizeFlightNumber($0.flightName) == normalizedFlightNumber
        })
    }

    private func normalizeFlightNumber(_ value: String) -> String {
        value
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func buildPublicFlightURL(
        flightName: String,
        scheduleDate: String
    ) -> URL? {
        let compactDate = scheduleDate.replacingOccurrences(of: "-", with: "")
        let slug = "D\(compactDate)\(flightName.uppercased())"
        return URL(string: "https://www.schiphol.nl/en/departures/flight/\(slug)/")
    }
}

// MARK: - Models

private struct SchipholFlightsResponse: Decodable {
    let flights: [SchipholFlight]
}

private struct SchipholFlight: Decodable {
    let flightName: String
    let scheduleDate: String
    let prefixIATA: String?
    let terminal: String?
    let gate: String?
    let expectedSecurityFilter: String?

    enum CodingKeys: String, CodingKey {
        case flightName
        case scheduleDate
        case prefixIATA
        case terminal
        case gate
        case expectedSecurityFilter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        flightName = try container.decode(String.self, forKey: .flightName)
        scheduleDate = try container.decode(String.self, forKey: .scheduleDate)
        prefixIATA = try container.decodeIfPresent(String.self, forKey: .prefixIATA)
        gate = try container.decodeIfPresent(String.self, forKey: .gate)
        expectedSecurityFilter = try container.decodeIfPresent(String.self, forKey: .expectedSecurityFilter)

        if let terminalString = try? container.decodeIfPresent(String.self, forKey: .terminal) {
            terminal = terminalString
        } else if let terminalInt = try? container.decodeIfPresent(Int.self, forKey: .terminal) {
            terminal = String(terminalInt)
        } else {
            terminal = nil
        }
    }
}

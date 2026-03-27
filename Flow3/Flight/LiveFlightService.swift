import Foundation

final class LiveFlightService {

    // MARK: - Keys

    private let aeroDataBoxAPIKey = "326a347895msh7460adc2983b80cp19f5e1jsn6e51a9fd6172"

    // MARK: - Public

    func lookupFlight(
        flightNumber: String,
        date: Date,
        airportIATA: String? = nil
    ) async throws -> FlightLookupResult {

        let normalizedFlightNumber = normalizeFlightNumber(flightNumber)
        let dateString = requestDateString(from: date)

        let result = try await fetchFromAeroDataBox(
            flightNumber: normalizedFlightNumber,
            dateString: dateString,
            date: date,
            preferredAirportIATA: cleanedString(airportIATA)
        )

        return result
    }

    // MARK: - AeroDataBox

    private func fetchFromAeroDataBox(
        flightNumber: String,
        dateString: String,
        date: Date,
        preferredAirportIATA: String?
    ) async throws -> FlightLookupResult {

        let urlString =
            "https://aerodatabox.p.rapidapi.com/flights/number/\(flightNumber)/\(dateString)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(aeroDataBoxAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "AeroDataBoxHTTPError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "AeroDataBox request failed."]
            )
        }

        guard let flights = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(
                domain: "InvalidJSON",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "AeroDataBox returned an unexpected response."]
            )
        }

        let matchingFlight = bestMatchingAeroFlight(
            from: flights,
            on: date,
            preferredAirportIATA: preferredAirportIATA
        )

        guard let flight = matchingFlight else {
            let preferredText = preferredAirportIATA?.uppercased() ?? "supported airport"
            throw NSError(
                domain: "FlightNotFound",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No matching departure found for \(flightNumber) on \(dateString) for \(preferredText)."
                ]
            )
        }

        let airline =
            ((flight["airline"] as? [String: Any])?["name"] as? String) ?? "Unknown"

        let departure = flight["departure"] as? [String: Any] ?? [:]
        let arrival = flight["arrival"] as? [String: Any] ?? [:]

        let departureAirport =
            ((departure["airport"] as? [String: Any])?["iata"] as? String) ?? "UNK"

        let arrivalAirport =
            ((arrival["airport"] as? [String: Any])?["iata"] as? String) ?? "UNK"

        let terminal = cleanedString(departure["terminal"] as? String)
        let gate = cleanedString(departure["gate"] as? String)
        let status = cleanedString(flight["status"] as? String)

        let scheduledLocal =
            ((departure["scheduledTime"] as? [String: Any])?["local"] as? String) ?? ""

        let revisedLocal =
            ((departure["revisedTime"] as? [String: Any])?["local"] as? String)

        guard let scheduledDate = parseAeroDate(scheduledLocal) else {
            throw NSError(
                domain: "DateError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not read scheduled departure time."]
            )
        }

        let revisedDate = revisedLocal.flatMap { parseAeroDate($0) }

        let shownDepartureDate: Date
        if let revisedDate, revisedDate > scheduledDate {
            shownDepartureDate = revisedDate
        } else {
            shownDepartureDate = scheduledDate
        }

        return FlightLookupResult(
            flightNumber: flightNumber,
            airline: airline,
            originIATA: departureAirport,
            destinationIATA: arrivalAirport,
            terminal: terminal,
            gate: gate,
            status: status,
            departureTime: shownDepartureDate
        )
    }

    private func bestMatchingAeroFlight(
        from flights: [[String: Any]],
        on date: Date,
        preferredAirportIATA: String?
    ) -> [String: Any]? {

        let calendar = Calendar(identifier: .gregorian)

        let sameDayFlights = flights.filter { flight in
            guard
                let departure = flight["departure"] as? [String: Any],
                let scheduledLocal = ((departure["scheduledTime"] as? [String: Any])?["local"] as? String),
                let scheduledDate = parseAeroDate(scheduledLocal)
            else {
                return false
            }

            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }

        guard !sameDayFlights.isEmpty else {
            return nil
        }

        if let preferredAirportIATA {
            if let exactPreferred = sameDayFlights.first(where: { flight in
                departureAirportIATA(from: flight)?.uppercased() == preferredAirportIATA.uppercased()
            }) {
                return exactPreferred
            }
        }

        let supportedAirportCodes = Set(
            AirportRegistry.airports.map { $0.airport.rawValue.uppercased() }
        )

        if let supportedMatch = sameDayFlights.first(where: { flight in
            guard let code = departureAirportIATA(from: flight)?.uppercased() else { return false }
            return supportedAirportCodes.contains(code)
        }) {
            return supportedMatch
        }

        return sameDayFlights.first
    }

    // MARK: - Helpers

    private func normalizeFlightNumber(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    private func requestDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseAeroDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mmXXXXX",
            "yyyy-MM-dd HH:mmZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mmXXXXX"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func cleanedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" {
            return nil
        }
        return trimmed
    }

    private func departureAirportIATA(from flight: [String: Any]) -> String? {
        let departure = flight["departure"] as? [String: Any]
        let airport = departure?["airport"] as? [String: Any]
        return cleanedString(airport?["iata"] as? String)
    }
}

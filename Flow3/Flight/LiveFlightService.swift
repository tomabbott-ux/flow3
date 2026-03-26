import Foundation

final class LiveFlightService {

    // MARK: - Keys

    private let aeroDataBoxAPIKey = "326a347895msh7460adc2983b80cp19f5e1jsn6e51a9fd6172"
    private let aviationStackAPIKey = "5ef21e44ec52ecc924562e17c4ef4c02"

    // MARK: - Public

    func lookupFlight(
        flightNumber: String,
        date: Date,
        airportIATA: String? = nil
    ) async throws -> FlightLookupResult {

        let normalizedFlightNumber = normalizeFlightNumber(flightNumber)
        let dateString = requestDateString(from: date)

        do {
            let aeroResult = try await fetchFromAeroDataBox(
                flightNumber: normalizedFlightNumber,
                dateString: dateString,
                date: date,
                preferredAirportIATA: cleanedString(airportIATA)
            )

            print("🔵 Aero result origin:", aeroResult.originIATA)
            print("🔵 Aero result terminal:", aeroResult.terminal ?? "nil")
            print("🔵 Aero result gate:", aeroResult.gate ?? "nil")
            print("🔵 Aero result status:", aeroResult.status ?? "nil")

            let needsGateFallback = isNilOrEmpty(aeroResult.gate)
            print("🔵 Needs gate fallback:", needsGateFallback)

            guard needsGateFallback else {
                return aeroResult
            }

            do {
                let fallback = try await fetchFallbackFromAviationStack(
                    flightNumber: normalizedFlightNumber,
                    dateString: dateString,
                    preferredAirportIATA: cleanedString(airportIATA),
                    resolvedDepartureAirportIATA: aeroResult.originIATA
                )

                let merged = FlightLookupResult(
                    flightNumber: aeroResult.flightNumber,
                    airline: aeroResult.airline,
                    originIATA: aeroResult.originIATA,
                    destinationIATA: aeroResult.destinationIATA,
                    terminal: firstNonEmpty(aeroResult.terminal, fallback.terminal),
                    gate: firstNonEmpty(aeroResult.gate, fallback.gate),
                    status: firstNonEmpty(aeroResult.status, fallback.status),
                    departureTime: aeroResult.departureTime
                )

                print("🟢 Merged terminal:", merged.terminal ?? "nil")
                print("🟢 Merged gate:", merged.gate ?? "nil")
                print("🟢 Merged status:", merged.status ?? "nil")

                return merged

            } catch {
                print("🔴 Aviationstack fallback failed:", error.localizedDescription)
                return aeroResult
            }

        } catch {
            print("🔴 LiveFlightService lookup failed:", error.localizedDescription)

            throw NSError(
                domain: "FlowFlightLookup",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "We couldn’t find this flight right now. Please check the flight number and date."
                ]
            )
        }
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
            throw NSError(
                domain: "AeroDataBoxURL",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid AeroDataBox URL."]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(aeroDataBoxAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AeroDataBoxHTTPError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid AeroDataBox response."]
            )
        }

        guard (200...299).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                print("🔴 AeroDataBox HTTP \(http.statusCode):")
                print(body)
            }

            throw NSError(
                domain: "AeroDataBoxHTTPError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "AeroDataBox request failed."]
            )
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            print("AeroDataBox JSON:")
            print(jsonString)
        }

        let flights = try parseAeroFlights(from: data)

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

        print("✈️ AeroDataBox Flight Debug:")
        print("✈️ Departure payload:", departure)
        print("✈️ Aero origin:", departureAirport)
        print("✈️ Aero terminal:", terminal ?? "nil")
        print("✈️ Aero gate:", gate ?? "nil")
        print("✈️ Aero status:", status ?? "nil")

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

    private func parseAeroFlights(from data: Data) throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: data)

        if let array = object as? [[String: Any]] {
            return array
        }

        if let dictionary = object as? [String: Any] {

            if let flights = dictionary["data"] as? [[String: Any]] {
                return flights
            }

            if let flights = dictionary["items"] as? [[String: Any]] {
                return flights
            }

            if let flights = dictionary["flights"] as? [[String: Any]] {
                return flights
            }

            if let message = dictionary["message"] as? String {
                throw NSError(
                    domain: "AeroDataBoxPayload",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }

            if let error = dictionary["error"] as? String {
                throw NSError(
                    domain: "AeroDataBoxPayload",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: error]
                )
            }
        }

        throw NSError(
            domain: "InvalidJSON",
            code: 500,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "AeroDataBox returned an unexpected response format."
            ]
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

        let sortedByDepartureTime = sameDayFlights.sorted { lhs, rhs in
            let lhsDate = aeroScheduledDate(from: lhs) ?? .distantFuture
            let rhsDate = aeroScheduledDate(from: rhs) ?? .distantFuture
            return lhsDate < rhsDate
        }

        return sortedByDepartureTime.first
    }

    private func departureAirportIATA(from flight: [String: Any]) -> String? {
        let departure = flight["departure"] as? [String: Any]
        let airport = departure?["airport"] as? [String: Any]
        return cleanedString(airport?["iata"] as? String)
    }

    private func aeroScheduledDate(from flight: [String: Any]) -> Date? {
        let departure = flight["departure"] as? [String: Any]
        let scheduledLocal = ((departure?["scheduledTime"] as? [String: Any])?["local"] as? String) ?? ""
        return parseAeroDate(scheduledLocal)
    }

    // MARK: - Aviationstack Fallback

    private func fetchFallbackFromAviationStack(
        flightNumber: String,
        dateString: String,
        preferredAirportIATA: String?,
        resolvedDepartureAirportIATA: String
    ) async throws -> AviationStackFallbackFields {

        guard aviationStackAPIKey != "YOUR_AVIATIONSTACK_KEY" else {
            throw NSError(
                domain: "AviationStackKeyMissing",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Replace YOUR_AVIATIONSTACK_KEY with your real Aviationstack key."
                ]
            )
        }

        var components = URLComponents(string: "https://api.aviationstack.com/v1/flights")
        components?.queryItems = [
            URLQueryItem(name: "access_key", value: aviationStackAPIKey),
            URLQueryItem(name: "flight_iata", value: flightNumber),
            URLQueryItem(name: "flight_date", value: dateString)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AviationStackHTTPError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Aviationstack request failed."]
            )
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            print("Aviationstack JSON:")
            print(jsonString)
        }

        guard (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "AviationStackHTTPError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Aviationstack request failed."]
            )
        }

        let decoded = try JSONDecoder().decode(AviationStackFlightsResponse.self, from: data)

        if let apiError = decoded.error {
            throw NSError(
                domain: "AviationStackAPIError",
                code: apiError.numericCode ?? 500,
                userInfo: [NSLocalizedDescriptionKey: apiError.message]
            )
        }

        guard !decoded.data.isEmpty else {
            throw NSError(
                domain: "AviationStackNoData",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No Aviationstack fallback data returned."]
            )
        }

        let preferredUpper = preferredAirportIATA?.uppercased()
        let resolvedUpper = resolvedDepartureAirportIATA.uppercased()
        let supportedAirportCodes = Set(
            AirportRegistry.airports.map { $0.airport.rawValue.uppercased() }
        )

        let sameFlightItems = decoded.data.filter { item in
            item.flight?.iata?.uppercased() == flightNumber.uppercased()
        }

        let match =
            sameFlightItems.first(where: { $0.departure?.iata?.uppercased() == preferredUpper }) ??
            sameFlightItems.first(where: { $0.departure?.iata?.uppercased() == resolvedUpper }) ??
            sameFlightItems.first(where: {
                guard let code = $0.departure?.iata?.uppercased() else { return false }
                return supportedAirportCodes.contains(code)
            }) ??
            sameFlightItems.first ??
            decoded.data.first

        guard let match else {
            throw NSError(
                domain: "AviationStackNoMatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No matching Aviationstack flight found."]
            )
        }

        let terminal = cleanedString(match.departure?.terminal)
        let gate = cleanedString(match.departure?.gate)
        let status = cleanedString(match.flight_status).map(mapAviationStackStatus)

        print("🟣 Aviationstack departure:", match.departure?.iata ?? "nil")
        print("🟣 Aviationstack terminal:", terminal ?? "nil")
        print("🟣 Aviationstack gate:", gate ?? "nil")
        print("🟣 Aviationstack status:", status ?? "nil")

        return AviationStackFallbackFields(
            terminal: terminal,
            gate: gate,
            status: status
        )
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

    private func isNilOrEmpty(_ value: String?) -> Bool {
        cleanedString(value) == nil
    }

    private func firstNonEmpty(_ first: String?, _ second: String?) -> String? {
        cleanedString(first) ?? cleanedString(second)
    }

    private func mapAviationStackStatus(_ raw: String) -> String {
        switch raw.lowercased() {
        case "scheduled":
            return "Scheduled"
        case "active":
            return "Active"
        case "landed":
            return "Landed"
        case "cancelled":
            return "Cancelled"
        case "incident":
            return "Incident"
        case "diverted":
            return "Diverted"
        default:
            return raw.capitalized
        }
    }
}

// MARK: - Aviationstack Models

private struct AviationStackFallbackFields {
    let terminal: String?
    let gate: String?
    let status: String?
}

private struct AviationStackFlightsResponse: Decodable {
    let data: [AviationStackFlight]
    let error: AviationStackAPIError?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decodeIfPresent([AviationStackFlight].self, forKey: .data) ?? []
        self.error = try container.decodeIfPresent(AviationStackAPIError.self, forKey: .error)
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case error
    }
}

private struct AviationStackAPIError: Decodable {
    let code: String?
    let message: String

    var numericCode: Int? {
        if let code, let intValue = Int(code) {
            return intValue
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringCode = try? container.decode(String.self, forKey: .code) {
            code = stringCode
        } else if let intCode = try? container.decode(Int.self, forKey: .code) {
            code = String(intCode)
        } else {
            code = nil
        }

        message = (try? container.decode(String.self, forKey: .message)) ?? "Unknown Aviationstack error"
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case message
    }
}

private struct AviationStackFlight: Decodable {
    let flight_status: String?
    let departure: AviationStackDeparture?
    let flight: AviationStackFlightInfo?
}

private struct AviationStackDeparture: Decodable {
    let iata: String?
    let terminal: String?
    let gate: String?
}

private struct AviationStackFlightInfo: Decodable {
    let iata: String?
}

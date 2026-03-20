import Foundation

final class LiveFlightService {

    // MARK: - Keys

    private let aeroDataBoxAPIKey = "326a347895msh7460adc2983b80cp19f5e1jsn6e51a9fd6172"
    private let aviationStackAPIKey = "5ef21e44ec52ecc924562e17c4ef4c02"
    // MARK: - Public

    func lookupFlight(
        flightNumber: String,
        date: Date,
        airportIATA: String = "LHR"
    ) async throws -> FlightLookupResult {

        let normalizedFlightNumber = normalizeFlightNumber(flightNumber)
        let dateString = requestDateString(from: date)

        // 1. Primary source = AeroDataBox
        let aeroResult = try await fetchFromAeroDataBox(
            flightNumber: normalizedFlightNumber,
            dateString: dateString,
            date: date,
            airportIATA: airportIATA
        )

        print("🔵 Aero result terminal:", aeroResult.terminal ?? "nil")
        print("🔵 Aero result gate:", aeroResult.gate ?? "nil")
        print("🔵 Aero result status:", aeroResult.status ?? "nil")

        // 2. Only fall back if gate is missing
        let needsGateFallback = isNilOrEmpty(aeroResult.gate)
        print("🔵 Needs gate fallback:", needsGateFallback)

        guard needsGateFallback else {
            return aeroResult
        }

        do {
            let fallback = try await fetchFallbackFromAviationStack(
                flightNumber: normalizedFlightNumber,
                dateString: dateString,
                airportIATA: airportIATA
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
    }

    // MARK: - AeroDataBox

    private func fetchFromAeroDataBox(
        flightNumber: String,
        dateString: String,
        date: Date,
        airportIATA: String
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

        if let jsonString = String(data: data, encoding: .utf8) {
            print("AeroDataBox JSON:")
            print(jsonString)
        }

        guard let flights = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(
                domain: "InvalidJSON",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "AeroDataBox returned an unexpected response."]
            )
        }

        let calendar = Calendar(identifier: .gregorian)

        let matchingFlight = flights.first { flight in
            guard
                let departure = flight["departure"] as? [String: Any],
                let airport = departure["airport"] as? [String: Any],
                let iata = airport["iata"] as? String,
                iata.uppercased() == airportIATA.uppercased()
            else {
                return false
            }

            guard
                let scheduledLocal = ((departure["scheduledTime"] as? [String: Any])?["local"] as? String),
                let scheduledDate = parseAeroDate(scheduledLocal)
            else {
                return false
            }

            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }

        guard let flight = matchingFlight else {
            throw NSError(
                domain: "FlightNotFound",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No matching \(airportIATA.uppercased()) departure found for \(flightNumber) on \(dateString)."
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

    // MARK: - Aviationstack Fallback

    private func fetchFallbackFromAviationStack(
        flightNumber: String,
        dateString: String,
        airportIATA: String
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
            URLQueryItem(name: "dep_iata", value: airportIATA.uppercased()),
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
                code: 500,
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

        let match = decoded.data.first(where: { item in
            item.departure?.iata?.uppercased() == airportIATA.uppercased() &&
            item.flight?.iata?.uppercased() == flightNumber.uppercased()
        }) ?? decoded.data.first

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

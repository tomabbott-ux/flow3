import Foundation

final class LiveFlightService {

    private let apiKey = "326a347895msh7460adc2983b80cp19f5e1jsn6e51a9fd6172"

    func lookupFlight(
        flightNumber: String,
        date: Date,
        airportIATA: String = "LHR"
    ) async throws -> FlightLookupResult {

        let requestDateFormatter = DateFormatter()
        requestDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        requestDateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = requestDateFormatter.string(from: date)

        let normalizedFlightNumber = flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        let urlString =
        "https://aerodatabox.p.rapidapi.com/flights/number/\(normalizedFlightNumber)/\(dateString)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.addValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, _) = try await URLSession.shared.data(for: request)

        if let jsonString = String(data: data, encoding: .utf8) {
            print("AeroDataBox JSON:")
            print(jsonString)
        }

        guard
            let flights = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
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
                let scheduledLocal =
                    ((departure["scheduledTime"] as? [String: Any])?["local"] as? String),
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
                userInfo: [NSLocalizedDescriptionKey: "No matching \(airportIATA.uppercased()) departure found for \(normalizedFlightNumber) on \(dateString)."]
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

        let terminal = departure["terminal"] as? String
        let gate = departure["gate"] as? String
        print("Departure payload:", departure)
        print("Parsed terminal:", terminal ?? "nil")
        print("Parsed gate:", gate ?? "nil")
        
        let scheduledLocal =
        ((departure["scheduledTime"] as? [String: Any])?["local"] as? String) ?? ""

        let revisedLocal =
        ((departure["revisedTime"] as? [String: Any])?["local"] as? String)

        guard let scheduledDate = parseAeroDate(scheduledLocal) else {
            throw NSError(
                domain: "DateError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not read scheduled departure time from AeroDataBox."]
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
            flightNumber: normalizedFlightNumber,
            airline: airline,
            originIATA: departureAirport,
            destinationIATA: arrivalAirport,
            terminal: terminal,
            gate: gate,
            departureTime: shownDepartureDate
        )
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
}

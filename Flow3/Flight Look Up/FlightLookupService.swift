import Foundation

enum FlightLookupServiceError: LocalizedError {
    case flightNotFound

    var errorDescription: String? {
        switch self {
        case .flightNotFound:
            return "Unable to find that flight."
        }
    }
}

final class FlightLookupService {

    func lookupFlight(
        flightNumber: String,
        date: Date,
        airportIATA: String
    ) async throws -> FlightLookupResult {

        let trimmed = flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let calendar = Calendar.current

        struct MockFlight {
            let airline: String
            let origin: String
            let destination: String
            let terminal: String
            let hour: Int
            let minute: Int
        }

        let flights: [String: MockFlight] = [

            "BA216": MockFlight(
                airline: "British Airways",
                origin: "LHR",
                destination: "ATL",
                terminal: "5",
                hour: 15,
                minute: 15
            ),

            "BA117": MockFlight(
                airline: "British Airways",
                origin: "LHR",
                destination: "JFK",
                terminal: "5",
                hour: 14,
                minute: 30
            ),

            "VS3": MockFlight(
                airline: "Virgin Atlantic",
                origin: "LHR",
                destination: "JFK",
                terminal: "3",
                hour: 11,
                minute: 30
            ),

            "AA51": MockFlight(
                airline: "American Airlines",
                origin: "LHR",
                destination: "DFW",
                terminal: "3",
                hour: 10,
                minute: 25
            )
        ]

        guard let match = flights[trimmed] else {
            throw FlightLookupServiceError.flightNotFound
        }

        // Only allow flights departing from selected airport
        guard match.origin.uppercased() == airportIATA.uppercased() else {
            throw FlightLookupServiceError.flightNotFound
        }

        let departure = calendar.date(
            bySettingHour: match.hour,
            minute: match.minute,
            second: 0,
            of: date
        ) ?? date

        return FlightLookupResult(
            flightNumber: trimmed,
            airline: match.airline,
            originIATA: match.origin,
            destinationIATA: match.destination,
            terminal: match.terminal,
            departureTime: departure
        )
    }
}

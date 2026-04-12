import Foundation

enum AirportTimeZoneResolver {
    private static let fallbackMap: [String: String] = [
        "PER": "Australia/Perth",
        "JNB": "Africa/Johannesburg",
        "SYD": "Australia/Sydney",
        "MEL": "Australia/Melbourne",
        "BNE": "Australia/Brisbane",
        "ADL": "Australia/Adelaide",
        "AKL": "Pacific/Auckland",
        "DXB": "Asia/Dubai",
        "DOH": "Asia/Qatar",
        "SIN": "Asia/Singapore",
        "HKG": "Asia/Hong_Kong",
        "BKK": "Asia/Bangkok",
        "NRT": "Asia/Tokyo",
        "HND": "Asia/Tokyo",
        "ICN": "Asia/Seoul",
        "LAX": "America/Los_Angeles",
        "SFO": "America/Los_Angeles",
        "SEA": "America/Los_Angeles",
        "DEN": "America/Denver",
        "DFW": "America/Chicago",
        "ORD": "America/Chicago",
        "ATL": "America/New_York",
        "JFK": "America/New_York",
        "EWR": "America/New_York",
        "BOS": "America/New_York",
        "MIA": "America/New_York",
        "YYZ": "America/Toronto",
        "YVR": "America/Vancouver",
        "YUL": "America/Toronto",
        "LHR": "Europe/London",
        "LGW": "Europe/London",
        "MAN": "Europe/London",
        "CDG": "Europe/Paris",
        "AMS": "Europe/Amsterdam",
        "FRA": "Europe/Berlin",
        "MUC": "Europe/Berlin",
        "ZRH": "Europe/Zurich",
        "MAD": "Europe/Madrid",
        "BCN": "Europe/Madrid",
        "CPH": "Europe/Copenhagen",
        "ARN": "Europe/Stockholm",
        "OSL": "Europe/Oslo",
        "HEL": "Europe/Helsinki",
        "IST": "Europe/Istanbul"
    ]

    static func timeZone(for airportCode: String, fallback: TimeZone) -> TimeZone {
        if let flowAirport = AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.caseInsensitiveCompare(airportCode) == .orderedSame }) {
            return flowAirport.timeZone
        }

        let uppercasedCode = airportCode.uppercased()

        if let identifier = fallbackMap[uppercasedCode],
           let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }

        return fallback
    }

    static func hasKnownTimeZone(for airportCode: String) -> Bool {
        if AirportRegistry.airports.contains(where: {
            $0.airport.rawValue.caseInsensitiveCompare(airportCode) == .orderedSame
        }) {
            return true
        }

        return fallbackMap[airportCode.uppercased()] != nil
    }
}

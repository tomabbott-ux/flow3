import Foundation
import EventKit

@MainActor
extension LandingStore {

    func scanCalendarForFlightsIfNeeded(force: Bool = false) async {
        if trackedFlight != nil && !force {
            print("📆 Calendar scan skipped: already tracking flight")
            return
        }

        print("📆 LandingStore scanning calendar for flights")

        let granted = await CalendarFlightScanner.shared.requestAccess()
        guard granted else {
            print("📆 Calendar scan stopped: access denied")
            return
        }

        let matches = CalendarFlightScanner.shared.upcomingFlightCandidates(withinDays: 30)
        let pendingFlights = matches.compactMap { pendingCalendarFlight(from: $0) }

        setPendingCalendarFlights(pendingFlights)

        print("📆 Pending calendar flights set:", pendingFlights.map(\.flightNumber))
    }

    func dismissPendingCalendarFlight(_ flight: PendingCalendarFlight) {
        // Intentionally empty so "Not now" keeps the flight in Alerts.
    }

    private func pendingCalendarFlight(from event: EKEvent) -> PendingCalendarFlight? {
        let fullText = [
            event.title,
            event.location,
            event.notes
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        guard let flightNumber = extractFlightNumber(from: fullText) else {
            print("📆 Could not extract flight number from event:", event.title ?? "(no title)")
            return nil
        }

        let airportCode = extractDepartureAirportCode(from: fullText)
        let routeText = extractRouteText(from: fullText)

        return PendingCalendarFlight(
            flightNumber: flightNumber,
            title: event.title ?? flightNumber,
            routeText: routeText,
            departureDate: event.startDate,
            departureAirportCode: airportCode,
            location: event.location,
            notes: event.notes
        )
    }

    private func extractFlightNumber(from text: String) -> String? {
        let upper = text.uppercased()
        let pattern = #"\b[A-Z0-9]{2,3}\s?\d{1,4}\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: upper, options: [], range: range)

        for match in matches {
            let candidate = nsText.substring(with: match.range)
                .replacingOccurrences(of: " ", with: "")
                .uppercased()

            if isLikelyRealFlightNumber(candidate) {
                return candidate
            }
        }

        return nil
    }

    private func extractDepartureAirportCode(from text: String) -> String? {
        let upper = text.uppercased()

        let routePatterns = [
            #"\b([A-Z]{3})\s?(?:->|→|-|/)\s?([A-Z]{3})\b"#,
            #"\b([A-Z]{3})\s+TO\s+([A-Z]{3})\b"#
        ]

        for pattern in routePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let nsText = upper as NSString
            let range = NSRange(location: 0, length: nsText.length)

            if let match = regex.firstMatch(in: upper, options: [], range: range),
               match.numberOfRanges >= 3 {
                let departure = nsText.substring(with: match.range(at: 1))
                return departure
            }
        }

        let supportedCodes = Set(AirportRegistry.airports.map { $0.airport.rawValue.uppercased() })

        for code in supportedCodes {
            if upper.contains(code) {
                return code
            }
        }

        return nil
    }

    private func extractRouteText(from text: String) -> String? {
        let upper = text.uppercased()

        let patterns = [
            #"\b[A-Z]{3}\s?(?:->|→|-|/)\s?[A-Z]{3}\b"#,
            #"\b[A-Z]{3}\s+TO\s+[A-Z]{3}\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let nsText = upper as NSString
            let range = NSRange(location: 0, length: nsText.length)

            if let match = regex.firstMatch(in: upper, options: [], range: range) {
                return nsText.substring(with: match.range)
            }
        }

        return nil
    }

    private func isLikelyRealFlightNumber(_ value: String) -> Bool {
        let cleaned = value
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleaned.count >= 3, cleaned.count <= 7 else { return false }
        guard cleaned.contains(where: { $0.isLetter }) else { return false }
        guard cleaned.contains(where: { $0.isNumber }) else { return false }

        let blockedPrefixes = ["MR", "MRS", "MS", "DR", "APT", "REF", "NO"]

        for prefix in blockedPrefixes where cleaned.hasPrefix(prefix) {
            return false
        }

        return true
    }
}

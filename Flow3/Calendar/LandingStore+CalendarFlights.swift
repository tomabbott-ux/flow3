import Foundation
import EventKit

@MainActor
extension LandingStore {

    func scanCalendarForFlightsIfNeeded(force: Bool = false) async {
        if trackedFlight != nil && pendingCalendarFlights.isEmpty && !force {
            print("📆 Calendar scan skipped: already tracking flight and no pending list refresh needed")
            return
        }

        print("📆 LandingStore scanning calendar for flights")

        let granted = await CalendarFlightScanner.shared.requestAccess()
        guard granted else {
            print("📆 Calendar scan stopped: access denied")
            return
        }

        let matches = CalendarFlightScanner.shared.upcomingFlightCandidates(withinDays: 30)

        guard !matches.isEmpty else {
            print("📆 Calendar scan found no flight candidates")
            pendingCalendarFlights = []
            return
        }

        let pendingFlights = matches.compactMap { pendingCalendarFlight(from: $0) }

        guard !pendingFlights.isEmpty else {
            print("📆 Calendar scan could not convert candidates into pending flights")
            pendingCalendarFlights = []
            return
        }

        let deduped = deduplicatePendingFlights(pendingFlights)

        // ✅ IMPORTANT:
        // Never show the currently tracked flight again as a pending calendar flight.
        let filtered = deduped.filter { pending in
            guard let trackedFlight else { return true }

            return pending.flightNumber.caseInsensitiveCompare(trackedFlight.flightNumber) != .orderedSame
        }

        pendingCalendarFlights = filtered

        print("📆 Pending calendar flights set:", filtered.map(\.flightNumber))
    }

    func pendingCalendarFlight(withID id: String?) -> PendingCalendarFlight? {
        guard let id else { return nil }
        return pendingCalendarFlights.first(where: { $0.id == id })
    }

    private func deduplicatePendingFlights(_ flights: [PendingCalendarFlight]) -> [PendingCalendarFlight] {
        var seen: Set<String> = []
        var result: [PendingCalendarFlight] = []

        for flight in flights.sorted(by: { $0.departureDate < $1.departureDate }) {
            if !seen.contains(flight.id) {
                seen.insert(flight.id)
                result.append(flight)
            }
        }

        return result
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
        let pattern = #"\b[A-Z]{2,3}\s?\d{1,4}\b"#

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

            if isLikelyRealFlightNumber(candidate), !looksLikeAirportRoomCode(candidate) {
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
                return nsText.substring(with: match.range(at: 1))
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
                let origin = nsText.substring(with: match.range(at: 1))
                let destination = nsText.substring(with: match.range(at: 2))
                return "\(origin) → \(destination)"
            }
        }

        return nil
    }

    private func isLikelyRealFlightNumber(_ value: String) -> Bool {
        let cleaned = value
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleaned.count >= 3, cleaned.count <= 7 else { return false }
        guard cleaned.prefix(2).allSatisfy({ $0.isLetter }) else { return false }
        guard cleaned.contains(where: { $0.isNumber }) else { return false }

        let blockedPrefixes = ["MR", "MRS", "MS", "DR", "APT", "REF", "NO"]

        for prefix in blockedPrefixes where cleaned.hasPrefix(prefix) {
            return false
        }

        return true
    }

    private func looksLikeAirportRoomCode(_ value: String) -> Bool {
        let cleaned = value.uppercased()
        let supportedCodes = Set(AirportRegistry.airports.map { $0.airport.rawValue.uppercased() })

        for code in supportedCodes {
            if cleaned.hasPrefix(code) {
                let suffix = cleaned.dropFirst(code.count)
                if !suffix.isEmpty && suffix.allSatisfy({ $0.isNumber }) {
                    return true
                }
            }
        }

        return false
    }
}

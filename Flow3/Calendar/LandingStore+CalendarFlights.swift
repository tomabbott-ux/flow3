import Foundation
import EventKit

@MainActor
extension LandingStore {

    func scanCalendarForFlightsIfNeeded(force: Bool = false) async {
        Swift.print("📆 LandingStore scanning calendar for flights")

        let granted = await CalendarFlightScanner.shared.requestAccess()

        guard granted else {
            Swift.print("📆 Calendar scan stopped: access denied")
            pendingCalendarFlights = []
            return
        }

        let matches = CalendarFlightScanner.shared.upcomingFlightCandidates(withinDays: 30)

        guard !matches.isEmpty else {
            Swift.print("📆 Calendar scan found no flight candidates")
            pendingCalendarFlights = []
            return
        }

        let parsedFlights = matches.compactMap { event in
            pendingCalendarFlight(from: event)
        }

        guard !parsedFlights.isEmpty else {
            Swift.print("📆 Calendar scan could not convert candidates into pending flights")
            pendingCalendarFlights = []
            return
        }

        let deduplicated = deduplicatePendingFlights(parsedFlights)

        let filtered = deduplicated.filter { pending in
            guard let trackedFlight else { return true }
            return pending.flightNumber.caseInsensitiveCompare(trackedFlight.flightNumber) != .orderedSame
        }

        pendingCalendarFlights = filtered.sorted { $0.departureDate < $1.departureDate }

        Swift.print("📆 Calendar scan complete")
        Swift.print("📆 pendingCalendarFlights count =", pendingCalendarFlights.count)
        Swift.print("📆 trackedFlight =", trackedFlight?.flightNumber ?? "nil")
    }

    func pendingCalendarFlight(withID id: String?) -> PendingCalendarFlight? {
        guard let id else { return nil }
        return pendingCalendarFlights.first(where: { $0.id == id })
    }
}

private extension LandingStore {

    func deduplicatePendingFlights(_ flights: [PendingCalendarFlight]) -> [PendingCalendarFlight] {
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

    func pendingCalendarFlight(from event: EKEvent) -> PendingCalendarFlight? {
        let fullText = [
            event.title,
            event.location,
            event.notes
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        guard let flightNumber = extractFlightNumber(from: fullText) else {
            Swift.print("📆 Could not extract flight number from event:", event.title ?? "(no title)")
            return nil
        }

        let departureAirportCode = extractDepartureAirportCode(from: fullText)
        let routeText = extractRouteText(from: fullText)

        return PendingCalendarFlight(
            flightNumber: flightNumber,
            title: event.title ?? flightNumber,
            routeText: routeText,
            departureDate: event.startDate,
            departureAirportCode: departureAirportCode,
            location: event.location,
            notes: event.notes
        )
    }

    func extractFlightNumber(from text: String) -> String? {
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
                Swift.print("🔎 Flight number candidate:", candidate)
                return candidate
            }
        }

        return nil
    }

    func extractDepartureAirportCode(from text: String) -> String? {
        if let route = extractRouteText(from: text) {
            let parts = route.components(separatedBy: "→").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let origin = parts.first, isSupportedAirportCode(origin) {
                return origin
            }
        }

        let supportedCodes = extractSupportedAirportCodes(from: text)

        if let first = supportedCodes.first {
            return first
        }

        return nil
    }

    func extractRouteText(from text: String) -> String? {
        let supportedCodes = extractSupportedAirportCodes(from: text)

        if supportedCodes.count >= 2 {
            let origin = supportedCodes[0]
            let destination = supportedCodes[1]

            if origin != destination {
                return "\(origin) → \(destination)"
            }
        }

        return nil
    }

    func extractSupportedAirportCodes(from text: String) -> [String] {
        let upper = text.uppercased()

        let supportedCodes = Set(
            AirportRegistry.airports.map { $0.airport.rawValue.uppercased() }
        )

        let pattern = #"\b[A-Z]{3}\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: upper, options: [], range: range)

        var ordered: [String] = []
        var seen: Set<String> = []

        for match in matches {
            let token = nsText.substring(with: match.range).uppercased()

            guard supportedCodes.contains(token) else { continue }
            guard !seen.contains(token) else { continue }

            seen.insert(token)
            ordered.append(token)
        }

        return ordered
    }

    func isSupportedAirportCode(_ value: String) -> Bool {
        let supportedCodes = Set(
            AirportRegistry.airports.map { $0.airport.rawValue.uppercased() }
        )
        return supportedCodes.contains(value.uppercased())
    }

    func isLikelyRealFlightNumber(_ value: String) -> Bool {
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

    func looksLikeAirportRoomCode(_ value: String) -> Bool {
        let cleaned = value.uppercased()
        let supportedCodes = Set(
            AirportRegistry.airports.map { $0.airport.rawValue.uppercased() }
        )

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

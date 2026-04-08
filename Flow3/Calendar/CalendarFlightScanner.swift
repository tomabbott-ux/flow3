import Foundation
import EventKit

@MainActor
final class CalendarFlightScanner {

    static let shared = CalendarFlightScanner()

    private let eventStore = EKEventStore()

    private init() {}

    // MARK: - Access

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                print("📆 Calendar access granted:", granted)
                return granted
            } catch {
                print("📆 Calendar access failed:", error.localizedDescription)
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        print("📆 Calendar access failed:", error.localizedDescription)
                    }
                    print("📆 Calendar access granted:", granted)
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Public scan

    func upcomingFlightCandidates(withinDays days: Int = 30) -> [EKEvent] {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start

        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }

        print("📆 Calendar events found in range:", events.count)

        for event in events.prefix(20) {
            print("📆 Event:", event.title ?? "(no title)", "| location:", event.location ?? "nil")
        }

        let matches = events
            .filter { isLikelyFlightEvent($0) }
            .sorted { $0.startDate < $1.startDate }

        print("✈️ Flight-like calendar matches:", matches.count)

        for match in matches {
            print("✈️ Matched flight event:", match.title ?? "(no title)")
        }

        return matches
    }

    func pendingFlight(from event: EKEvent) -> PendingCalendarFlight? {
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

        let route = extractRouteText(from: fullText)
        let departureAirportCode = extractDepartureAirportCode(from: fullText)

        return PendingCalendarFlight(
            flightNumber: flightNumber,
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? event.title!.trimmingCharacters(in: .whitespacesAndNewlines)
                : flightNumber,
            routeText: route,
            departureDate: event.startDate,
            departureAirportCode: departureAirportCode,
            location: cleanedText(event.location),
            notes: cleanedText(event.notes)
        )
    }

    // MARK: - Flight detection

    private func isLikelyFlightEvent(_ event: EKEvent) -> Bool {
        let title = normalized(event.title)
        let notes = normalized(event.notes)
        let location = normalized(event.location)

        let combined = [title, notes, location]
            .compactMap { $0 }
            .joined(separator: " ")

        guard !combined.isEmpty else { return false }

        if containsExcludedPhrase(in: combined) {
            print("🚫 Rejected event:", event.title ?? "(no title)", "| reason: excluded phrase")
            return false
        }

        let hasFlightNumber = containsFlightNumber(in: combined)
        let hasAirportRoute = containsAirportRoute(in: combined)
        let keywordScore = flightKeywordScore(in: combined)

        print(
            "🧪 Checking event:",
            event.title ?? "(no title)",
            "| flightNumber:", hasFlightNumber,
            "| airportRoute:", hasAirportRoute,
            "| keywordScore:", keywordScore
        )

        if hasFlightNumber || hasAirportRoute {
            return true
        }

        if keywordScore >= 2 {
            return true
        }

        return false
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Exclusions

    private func containsExcludedPhrase(in text: String) -> Bool {
        let excludedPhrases = [
            " v ",
            " vs ",
            " versus ",
            "football",
            "soccer",
            "match",
            "fixture",
            "stadium",
            "appointment",
            "hospital",
            "clinic",
            "doctor",
            "consultant",
            "gp",
            "surgery",
            "medical",
            "dentist",
            "orthodontist",
            "physio",
            "therapy",
            "checkup",
            "check-up",
            "birthday",
            "anniversary",
            "dinner",
            "lunch",
            "breakfast",
            "meeting",
            "zoom",
            "teams call",
            "school",
            "parents evening",
            "barber",
            "haircut",
            "wedding"
        ]

        let padded = " \(text.lowercased()) "

        for phrase in excludedPhrases {
            if padded.contains(" \(phrase.lowercased()) ") || padded.contains(phrase.lowercased()) {
                return true
            }
        }

        return false
    }

    // MARK: - Positive signals

    private func flightKeywordScore(in text: String) -> Int {
        let padded = " \(text.lowercased()) "

        let keywordGroups: [String] = [
            " flight ",
            " airline ",
            " terminal ",
            " gate ",
            " boarding ",
            " boarding time ",
            " check-in ",
            " check in ",
            " departure ",
            " departs ",
            " arriving ",
            " arrives ",
            " airport ",
            " passenger ",
            " seat "
        ]

        var matches = 0

        for keyword in keywordGroups where padded.contains(keyword) {
            matches += 1
        }

        return matches
    }

    private func containsFlightNumber(in text: String) -> Bool {
        extractFlightNumber(from: text) != nil
    }

    private func extractFlightNumber(from text: String) -> String? {
        let upper = text.uppercased()
        let pattern = #"\b[A-Z0-9]{2,3}\s?\d{1,4}[A-Z]?\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: upper, options: [], range: range)

        for match in matches {
            let candidate = nsText.substring(with: match.range)
            print("🔎 Flight number candidate:", candidate)

            if isLikelyRealFlightNumber(candidate) {
                return normalizedFlightNumber(candidate)
            }
        }

        return nil
    }

    private func normalizedFlightNumber(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        let pattern = #"^([A-Z]{2,3})(0*)(\d{1,4})([A-Z]?)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return cleaned
        }

        let ns = cleaned as NSString
        let range = NSRange(location: 0, length: ns.length)

        guard let match = regex.firstMatch(in: cleaned, options: [], range: range) else {
            return cleaned
        }

        let airlineCode = ns.substring(with: match.range(at: 1))
        let numericPart = ns.substring(with: match.range(at: 3))

        let suffix: String
        if match.range(at: 4).location != NSNotFound {
            suffix = ns.substring(with: match.range(at: 4))
        } else {
            suffix = ""
        }

        return "\(airlineCode)\(numericPart)\(suffix)"
    }

    private func isLikelyRealFlightNumber(_ value: String) -> Bool {
        let cleaned = value
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleaned.count >= 3, cleaned.count <= 8 else { return false }
        guard cleaned.contains(where: { $0.isLetter }) else { return false }
        guard cleaned.contains(where: { $0.isNumber }) else { return false }

        let blockedPrefixes = ["MR", "MRS", "MS", "DR", "APT", "REF", "NO"]

        for prefix in blockedPrefixes where cleaned.hasPrefix(prefix) {
            return false
        }

        return true
    }

    private func containsAirportRoute(in text: String) -> Bool {
        extractRouteText(from: text) != nil
    }

    private func extractRouteText(from text: String) -> String? {
        let upper = text.uppercased()

        let patterns = [
            #"\b([A-Z]{3})\s?(->|→|-|/)\s?([A-Z]{3})\b"#,
            #"\b([A-Z]{3})\s+TO\s+([A-Z]{3})\b"#
        ]

        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            if let match = regex.firstMatch(in: upper, options: [], range: range) {
                let full = nsText.substring(with: match.range)
                return full
                    .replacingOccurrences(of: "->", with: "→")
                    .replacingOccurrences(of: "-", with: "→")
                    .replacingOccurrences(of: "/", with: "→")
                    .replacingOccurrences(of: " TO ", with: " → ")
            }
        }

        return nil
    }

    private func extractDepartureAirportCode(from text: String) -> String? {
        let upper = text.uppercased()
        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)

        let routePatterns = [
            #"\b([A-Z]{3})\s?(?:->|→|-|/)\s?([A-Z]{3})\b"#,
            #"\b([A-Z]{3})\s+TO\s+([A-Z]{3})\b"#
        ]

        for pattern in routePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            if let match = regex.firstMatch(in: upper, options: [], range: range),
               match.numberOfRanges >= 3 {
                let departure = nsText.substring(with: match.range(at: 1))
                return isSupportedAirportCode(departure) ? departure : nil
            }
        }

        let airportAliases: [String: String] = [
            "HEATHROW": "LHR",
            "LONDON HEATHROW": "LHR",
            "GATWICK": "LGW",
            "LONDON GATWICK": "LGW",
            "STANSTED": "STN",
            "LONDON STANSTED": "STN",
            "LUTON": "LTN",
            "LONDON LUTON": "LTN",
            "CITY AIRPORT": "LCY",
            "LONDON CITY": "LCY",
            "MANCHESTER": "MAN",
            "PARIS CHARLES DE GAULLE": "CDG",
            "CHARLES DE GAULLE": "CDG",
            "PARIS ORLY": "ORY",
            "ORLY": "ORY",
            "DUBLIN": "DUB",
            "AMSTERDAM": "AMS",
            "SCHIPHOL": "AMS",
            "JFK": "JFK",
            "NEW YORK JFK": "JFK"
        ]

        for (alias, code) in airportAliases {
            if upper.contains(alias) {
                return code
            }
        }

        let supportedCodes = Set(AirportRegistry.airports.map { $0.airport.rawValue.uppercased() })

        for code in supportedCodes where upper.contains(code) {
            return code
        }

        return nil
    }

    private func isSupportedAirportCode(_ code: String) -> Bool {
        AirportRegistry.airports
            .map(\.airport)
            .contains { $0.rawValue.caseInsensitiveCompare(code) == .orderedSame }
    }
}

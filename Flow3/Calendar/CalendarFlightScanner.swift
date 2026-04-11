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
                if DebugFlags.calendar {
                    print("📅 Calendar access (iOS 17+):", granted)
                }
                return granted
            } catch {
                if DebugFlags.calendar {
                    print("❌ Calendar access error:", error.localizedDescription)
                }
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if DebugFlags.calendar, let error {
                        print("❌ Calendar access error:", error.localizedDescription)
                    }
                    if DebugFlags.calendar {
                        print("📅 Calendar access (< iOS 17):", granted)
                    }
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

        if DebugFlags.calendar {
            print("📅 Calendar events fetched:", events.count)

            for event in events.prefix(20) {
                print("   •", event.title ?? "(no title)", "|", event.startDate)
            }
        }

        let scored: [(event: EKEvent, score: Int, flightNumber: String)] = events.compactMap { event in
            guard let result = scoredFlightCandidate(for: event) else { return nil }
            return (event: event, score: result.score, flightNumber: result.flightNumber)
        }

        var bestByFlightNumber: [String: (event: EKEvent, score: Int)] = [:]

        for item in scored {
            let key = item.flightNumber.uppercased()

            if let existing = bestByFlightNumber[key] {
                if item.score > existing.score {
                    bestByFlightNumber[key] = (item.event, item.score)
                } else if item.score == existing.score,
                          item.event.startDate > existing.event.startDate {
                    bestByFlightNumber[key] = (item.event, item.score)
                }
            } else {
                bestByFlightNumber[key] = (item.event, item.score)
            }
        }

        let matches = bestByFlightNumber.values
            .map(\.event)
            .sorted { $0.startDate < $1.startDate }

        if DebugFlags.calendar {
            print("✈️ Calendar flight matches:", matches.count)

            for match in matches {
                print("   ✅", match.title ?? "(no title)", "|", match.startDate)
            }
        }

        return matches
    }

    // MARK: - Candidate scoring

    private func scoredFlightCandidate(for event: EKEvent) -> (flightNumber: String, score: Int)? {
        let title = normalized(event.title)
        let notes = normalized(event.notes)
        let location = normalized(event.location)

        let combined = [title, notes, location]
            .compactMap { $0 }
            .joined(separator: " ")

        guard !combined.isEmpty else { return nil }

        if containsHardExcludedPhrase(in: combined) {
            if DebugFlags.calendar {
                print("🚫 Hard excluded:", event.title ?? "(no title)")
            }
            return nil
        }

        if isCheckInOnlyEvent(combined) {
            if DebugFlags.calendar {
                print("🚫 Check-in only event:", event.title ?? "(no title)")
            }
            return nil
        }

        guard let flightMatch = extractStrictFlightNumber(from: combined) else {
            if DebugFlags.calendar {
                print("🚫 No strict flight number found:", event.title ?? "(no title)")
            }
            return nil
        }

        if looksLikeAirportRoomCode(flightMatch.fullFlightNumber) {
            if DebugFlags.calendar {
                print("🚫 Looks like airport room/checkpoint code:", flightMatch.fullFlightNumber, "|", event.title ?? "(no title)")
            }
            return nil
        }

        let hasRoute = containsAirportRoute(in: combined)
        let hasAirlineName = containsAirlineName(in: combined)
        let hasTerminalOrGate = containsTerminalOrGate(in: combined)
        let hasDepartureLanguage = containsDepartureLanguage(in: combined)
        let hasCheckInLanguage = containsCheckInLanguage(in: combined)
        let hasMeetingLanguage = containsMeetingLikeLanguage(in: combined)
        let keywordScore = flightKeywordScore(in: combined)
        let titleContainsFlightNumber = title?.uppercased().contains(flightMatch.fullFlightNumber) == true

        var score = 0

        // Strong base only after strict airline-code validation
        score += 100

        if hasRoute {
            score += 35
        }

        if hasAirlineName {
            score += 20
        }

        if hasTerminalOrGate {
            score += 14
        }

        if hasDepartureLanguage {
            score += 18
        }

        score += keywordScore * 8

        if titleContainsFlightNumber {
            score += 12
        }

        // Penalize weak/business-like or check-in-only language
        if hasCheckInLanguage && !hasRoute && !hasAirlineName {
            score -= 20
        }

        if hasMeetingLanguage {
            score -= 90
        }

        // Critical hardening:
        // Must have at least one strong travel context signal beyond just "AA123".
        let strongSignals = [
            hasRoute,
            hasAirlineName,
            hasTerminalOrGate,
            hasDepartureLanguage,
            keywordScore >= 2,
            containsAirportName(in: combined),
            containsLikelyTravelLocation(in: combined)
        ]

        let strongSignalCount = strongSignals.filter { $0 }.count

        if strongSignalCount == 0 {
            if DebugFlags.calendar {
                print("🚫 Rejected due to no travel context:", event.title ?? "(no title)", "|", flightMatch.fullFlightNumber)
            }
            return nil
        }

        if DebugFlags.calendar {
            print(
                "🧪 Checking event:",
                event.title ?? "(no title)",
                "| flightNumber:", flightMatch.fullFlightNumber,
                "| score:", score,
                "| route:", hasRoute,
                "| airline:", hasAirlineName,
                "| terminal/gate:", hasTerminalOrGate,
                "| depart:", hasDepartureLanguage,
                "| keywords:", keywordScore,
                "| meeting:", hasMeetingLanguage
            )
        }

        guard score >= 75 else {
            if DebugFlags.calendar {
                print("🚫 Score too low:", score, "|", event.title ?? "(no title)")
            }
            return nil
        }

        return (flightMatch.fullFlightNumber, score)
    }

    // MARK: - Normalization

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        guard !trimmed.isEmpty else { return nil }

        return trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    // MARK: - Hard exclusions

    private func containsHardExcludedPhrase(in text: String) -> Bool {
        let lowered = text.lowercased()

        let phrases = [
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
            "board meeting",
            "leadership workshop",
            "workshop",
            "board room",
            "conference room",
            "conference",
            "training room",
            "zoom",
            "teams call",
            "school",
            "parents evening",
            "barber",
            "haircut",
            "wedding"
        ]

        return phrases.contains(where: lowered.contains)
    }

    // MARK: - Check-in detection

    private func isCheckInOnlyEvent(_ text: String) -> Bool {
        let lowered = text.lowercased()

        let phrases = [
            "check-in opens",
            "check in opens",
            "online check-in opens",
            "online check in opens",
            "check-in open",
            "check in open",
            "check-in reminder",
            "check in reminder",
            "online check-in available",
            "online check in available",
            "time to check in",
            "check in for your flight"
        ]

        return phrases.contains(where: lowered.contains)
    }

    // MARK: - Flight number extraction

    private func extractStrictFlightNumber(from text: String) -> FlightNumberMatch? {
        let upper = text.uppercased()
        let nsText = upper as NSString
        let range = NSRange(location: 0, length: nsText.length)

        // Strict accepted patterns:
        // AA123
        // AA 123
        // U21234
        // B6 123
        let patterns = [
            #"\b([A-Z0-9]{2})(\d{1,4})\b"#,
            #"\b([A-Z0-9]{2})\s+(\d{1,4})\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let matches = regex.matches(in: upper, options: [], range: range)

            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }

                let full = nsText.substring(with: match.range(at: 0))
                    .replacingOccurrences(of: " ", with: "")
                    .uppercased()

                let airlineCode = nsText.substring(with: match.range(at: 1)).uppercased()
                let digits = nsText.substring(with: match.range(at: 2))

                guard validAirlineIATACodes.contains(airlineCode) else {
                    if DebugFlags.calendar {
                        print("🚫 Unknown airline code:", airlineCode, "| candidate:", full)
                    }
                    continue
                }

                guard digits.count >= 1 && digits.count <= 4 else {
                    continue
                }

                return FlightNumberMatch(
                    fullFlightNumber: airlineCode + digits,
                    airlineCode: airlineCode,
                    matchedText: full
                )
            }
        }

        return nil
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

    // MARK: - Positive signals

    private func flightKeywordScore(in text: String) -> Int {
        let lowered = text.lowercased()

        let keywords = [
            "flight",
            "airline",
            "terminal",
            "gate",
            "boarding",
            "boarding time",
            "check-in",
            "check in",
            "departure",
            "departs",
            "departs at",
            "scheduled departure",
            "arrival",
            "arrives",
            "airport",
            "passenger",
            "seat",
            "bag drop",
            "baggage",
            "boarding pass"
        ]

        return keywords.reduce(into: 0) { total, keyword in
            if lowered.contains(keyword) {
                total += 1
            }
        }
    }

    private func containsAirportRoute(in text: String) -> Bool {
        let upper = text.uppercased()

        let patterns = [
            #"\b([A-Z]{3})\s?(->|→|–|—|-|/)\s?([A-Z]{3})\b"#,
            #"\b([A-Z]{3})\s+TO\s+([A-Z]{3})\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let nsText = upper as NSString
            let range = NSRange(location: 0, length: nsText.length)

            let matches = regex.matches(in: upper, options: [], range: range)

            for match in matches {
                if match.numberOfRanges >= 4 {
                    let origin = nsText.substring(with: match.range(at: 1)).uppercased()
                    let destination = nsText.substring(with: match.range(at: 3)).uppercased()

                    if validAirportCodes.contains(origin), validAirportCodes.contains(destination) {
                        return true
                    }
                } else if match.numberOfRanges >= 3 {
                    let origin = nsText.substring(with: match.range(at: 1)).uppercased()
                    let destination = nsText.substring(with: match.range(at: 2)).uppercased()

                    if validAirportCodes.contains(origin), validAirportCodes.contains(destination) {
                        return true
                    }
                }
            }
        }

        return false
    }

    private func containsAirlineName(in text: String) -> Bool {
        let lowered = text.lowercased()

        let airlines = [
            "british airways",
            "american airlines",
            "delta",
            "delta air lines",
            "united",
            "united airlines",
            "southwest",
            "jetblue",
            "spirit",
            "frontier",
            "air canada",
            "westjet",
            "lufthansa",
            "klm",
            "air france",
            "swiss",
            "iberia",
            "tap air portugal",
            "sas",
            "finnair",
            "ita airways",
            "austrian",
            "easyjet",
            "jet2",
            "ryanair",
            "virgin atlantic",
            "vueling",
            "wizz air",
            "norwegian",
            "emirates",
            "qatar airways",
            "etihad",
            "saudia",
            "kuwait airways",
            "oman air",
            "flydubai",
            "air arabia",
            "singapore airlines",
            "cathay pacific",
            "all nippon airways",
            "ana",
            "japan airlines",
            "jal",
            "qantas",
            "virgin australia",
            "air new zealand",
            "thai airways",
            "malaysia airlines",
            "garuda indonesia",
            "airasia"
        ]

        return airlines.contains(where: lowered.contains)
    }

    private func containsTerminalOrGate(in text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("terminal") || lowered.contains("gate")
    }

    private func containsDepartureLanguage(in text: String) -> Bool {
        let lowered = text.lowercased()

        let phrases = [
            "departure",
            "departs",
            "departs at",
            "scheduled departure",
            "boarding",
            "operated by",
            "arrives",
            "arrival",
            "takeoff",
            "take-off"
        ]

        return phrases.contains(where: lowered.contains)
    }

    private func containsCheckInLanguage(in text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("check-in") || lowered.contains("check in")
    }

    private func containsMeetingLikeLanguage(in text: String) -> Bool {
        let lowered = text.lowercased()

        let phrases = [
            "workshop",
            "meeting",
            "board room",
            "conference room",
            "conference",
            "standup",
            "stand-up",
            "office",
            "leadership",
            "review",
            "sync",
            "1:1",
            "interview",
            "agenda",
            "project",
            "weekly",
            "monthly",
            "quarterly",
            "call",
            "teams",
            "zoom"
        ]

        return phrases.contains(where: lowered.contains)
    }

    private func containsAirportName(in text: String) -> Bool {
        let lowered = text.lowercased()

        let airportNameHints = [
            "heathrow",
            "gatwick",
            "stansted",
            "luton",
            "city airport",
            "new york jfk",
            "jfk",
            "newark",
            "laguardia",
            "atlanta",
            "schiphol",
            "doha",
            "charles de gaulle",
            "frankfurt",
            "munich",
            "madrid",
            "barcelona",
            "lisbon",
            "dublin",
            "dubai",
            "singapore",
            "haneda",
            "narita",
            "los angeles",
            "ohare",
            "dallas fort worth"
        ]

        return airportNameHints.contains(where: lowered.contains)
    }

    private func containsLikelyTravelLocation(in text: String) -> Bool {
        let lowered = text.lowercased()

        let travelLocationHints = [
            "airport",
            "terminal",
            "gate",
            "departures",
            "arrivals",
            "check-in",
            "check in"
        ]

        return travelLocationHints.contains(where: lowered.contains)
    }

    // MARK: - Models

    private struct FlightNumberMatch {
        let fullFlightNumber: String
        let airlineCode: String
        let matchedText: String
    }

    // MARK: - Lookup Data

    private var validAirportCodes: Set<String> {
        Set(AirportRegistry.airports.map { $0.airport.rawValue.uppercased() })
    }

    private let validAirlineIATACodes: Set<String> = [
        // UK & Europe
        "BA", "U2", "LS", "FR", "KL", "LH", "AF", "LX", "IB", "TP", "SK", "AY", "AZ", "OS",
        "VY", "W6", "DY",

        // North America
        "AA", "DL", "UA", "WN", "B6", "NK", "F9", "AC", "WS",

        // Middle East
        "EK", "QR", "EY", "SV", "KU", "WY", "FZ", "G9",

        // Asia-Pacific
        "SQ", "CX", "NH", "JL", "QF", "VA", "NZ", "TG", "MH", "GA", "AK"
    ]
}

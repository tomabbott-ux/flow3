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
                    print("📆 Calendar access granted:", granted)
                }
                return granted
            } catch {
                if DebugFlags.calendar {
                    print("📆 Calendar access failed:", error.localizedDescription)
                }
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if DebugFlags.calendar, let error {
                        print("📆 Calendar access failed:", error.localizedDescription)
                    }
                    if DebugFlags.calendar {
                        print("📆 Calendar access granted:", granted)
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
            print("📆 Calendar events found in range:", events.count)

            for event in events.prefix(20) {
                print("📆 Event:", event.title ?? "(no title)", "| location:", event.location ?? "nil")
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
            print("✈️ Flight-like calendar matches:", matches.count)

            for match in matches {
                print("✈️ Matched flight event:", match.title ?? "(no title)")
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
                print("🚫 Rejected event:", event.title ?? "(no title)", "| reason: hard excluded phrase")
            }
            return nil
        }

        if isCheckInOnlyEvent(combined) {
            if DebugFlags.calendar {
                print("🚫 Rejected event:", event.title ?? "(no title)", "| reason: check-in only event")
            }
            return nil
        }

        guard let flightNumber = extractLikelyFlightNumber(from: combined) else {
            if DebugFlags.calendar {
                print("🚫 Rejected event:", event.title ?? "(no title)", "| reason: no valid flight number")
            }
            return nil
        }

        if looksLikeAirportRoomCode(flightNumber) {
            if DebugFlags.calendar {
                print("🚫 Rejected event:", event.title ?? "(no title)", "| reason: airport/room code false positive")
            }
            return nil
        }

        var score = 0

        score += 100

        if containsAirportRoute(in: combined) {
            score += 30
        }

        score += flightKeywordScore(in: combined) * 8

        if containsAirlineName(in: combined) {
            score += 20
        }

        if containsTerminalOrGate(in: combined) {
            score += 12
        }

        if containsDepartureLanguage(in: combined) {
            score += 16
        }

        if containsCheckInLanguage(in: combined) {
            score -= 25
        }

        if containsMeetingLikeLanguage(in: combined) {
            score -= 80
        }

        if let title, title.uppercased().contains(flightNumber) {
            score += 10
        }

        if DebugFlags.calendar {
            print(
                "🧪 Checking event:",
                event.title ?? "(no title)",
                "| flightNumber:", flightNumber,
                "| score:", score
            )
        }

        guard score >= 70 else {
            if DebugFlags.calendar {
                print("🚫 Rejected event:", event.title ?? "(no title)", "| reason: score too low")
            }
            return nil
        }

        return (flightNumber, score)
    }

    // MARK: - Normalization

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    // MARK: - Hard exclusions

    private func containsHardExcludedPhrase(in text: String) -> Bool {
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
            "room",
            "slt",
            "zoom",
            "teams call",
            "school",
            "parents evening",
            "barber",
            "haircut",
            "wedding"
        ]

        let padded = " \(text.lowercased()) "

        for phrase in phrases where padded.contains(phrase.lowercased()) {
            return true
        }

        return false
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

        return phrases.contains(where: { lowered.contains($0) })
    }

    // MARK: - Flight number extraction

    private func extractLikelyFlightNumber(from text: String) -> String? {
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

            if DebugFlags.calendar {
                print("🔎 Flight number candidate:", candidate)
            }

            if isLikelyRealFlightNumber(candidate) {
                return candidate
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

        let blockedPrefixes = [
            "MR", "MRS", "MS", "DR", "APT", "REF", "NO"
        ]

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

    private func containsAirportRoute(in text: String) -> Bool {
        let upper = text.uppercased()

        let patterns = [
            #"\b[A-Z]{3}\s?(->|→|-|/)\s?[A-Z]{3}\b"#,
            #"\b[A-Z]{3}\s+TO\s+[A-Z]{3}\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let nsText = upper as NSString
            let range = NSRange(location: 0, length: nsText.length)

            if regex.firstMatch(in: upper, options: [], range: range) != nil {
                return true
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
            "united",
            "lufthansa",
            "klm",
            "air france",
            "easyjet",
            "ryanair",
            "virgin atlantic",
            "emirates",
            "qatar airways"
        ]

        return airlines.contains(where: { lowered.contains($0) })
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
            "operated by"
        ]

        return phrases.contains(where: { lowered.contains($0) })
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
            "room",
            "slt",
            "office",
            "leadership"
        ]

        return phrases.contains(where: { lowered.contains($0) })
    }
}

import Foundation
import UserNotifications

@MainActor
final class FlowNotificationManager {

    static let shared = FlowNotificationManager()

    private init() {}

    // MARK: - Categories

    private let trackedFlightCategoryID = "FLOW_TRACKED_FLIGHT"
    private var lastImmediateNotificationAt: Date?

    func requestPermission() async {
        do {
            let center = UNUserNotificationCenter.current()

            let openAction = UNNotificationAction(
                identifier: "OPEN_FLOW",
                title: "Open Flow",
                options: [.foreground]
            )

            let category = UNNotificationCategory(
                identifier: trackedFlightCategoryID,
                actions: [openAction],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )

            center.setNotificationCategories([category])

            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            print("Notification permission granted:", granted)
        } catch {
            print("Notification permission error:", error.localizedDescription)
        }
    }

    // MARK: - Clear

    func clearTrackedFlightNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: trackedFlightNotificationIDs())
        center.removeDeliveredNotifications(withIdentifiers: trackedFlightNotificationIDs())
    }

    // MARK: - Schedule reminders

    func scheduleTrackedFlightReminders(for flight: TrackedFlight) {
        clearTrackedFlightNotifications()

        let center = UNUserNotificationCenter.current()
        let now = Date()

        let standardBody = scheduledBody(for: flight)

        let reminders: [(id: String, fireDate: Date, title: String, subtitle: String, body: String)] = [
            (
                id: "trackedFlight.leave.60",
                fireDate: flight.leaveTime.addingTimeInterval(-60 * 60),
                title: "Leave \(formattedTime(flight.leaveTime))",
                subtitle: "\(flight.flightNumber) • \(flight.route)",
                body: standardBody
            ),
            (
                id: "trackedFlight.leave.30",
                fireDate: flight.leaveTime.addingTimeInterval(-30 * 60),
                title: "Leave \(formattedTime(flight.leaveTime))",
                subtitle: "\(flight.flightNumber) • \(flight.route)",
                body: standardBody
            ),
            (
                id: "trackedFlight.leave.15",
                fireDate: flight.leaveTime.addingTimeInterval(-15 * 60),
                title: "Leave \(formattedTime(flight.leaveTime))",
                subtitle: "\(flight.flightNumber) • \(flight.route)",
                body: standardBody
            ),
            (
                id: "trackedFlight.leave.5",
                fireDate: flight.leaveTime.addingTimeInterval(-5 * 60),
                title: "Leave \(formattedTime(flight.leaveTime))",
                subtitle: "\(flight.flightNumber) • \(flight.route)",
                body: standardBody
            ),
            (
                id: "trackedFlight.leave.now",
                fireDate: flight.leaveTime,
                title: "Leave now • \(formattedTime(flight.leaveTime))",
                subtitle: "\(flight.flightNumber) • \(flight.route)",
                body: standardBody
            )
        ]

        for reminder in reminders {
            guard reminder.fireDate > now else { continue }

            let content = baseContent(
                title: reminder.title,
                subtitle: reminder.subtitle,
                body: reminder.body
            )

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminder.fireDate
            )

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: reminder.id,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("Failed to schedule reminder \(reminder.id):", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Immediate updates

    func notifyTrackedFlightChanged(oldFlight: TrackedFlight, newFlight: TrackedFlight) {
        guard oldFlight.flightNumber == newFlight.flightNumber else { return }
        guard isWithinActiveNotificationWindow(for: newFlight) else { return }

        let securityDelta = newFlight.securityMinutes - oldFlight.securityMinutes
        let leaveDeltaMinutes = Int(
            (newFlight.leaveTime.timeIntervalSince1970 - oldFlight.leaveTime.timeIntervalSince1970) / 60
        )

        let checkpointChanged = oldFlight.securityRouteTitle != newFlight.securityRouteTitle
        let terminalChanged = normalizedText(oldFlight.terminal) != normalizedText(newFlight.terminal)
        let gateChanged = normalizedText(oldFlight.gate) != normalizedText(newFlight.gate)

        guard abs(securityDelta) >= 10 ||
              abs(leaveDeltaMinutes) >= 10 ||
              checkpointChanged ||
              terminalChanged ||
              gateChanged else {
            return
        }

        guard canSendImmediateNotification() else { return }

        let title = "New leave time \(formattedTime(newFlight.leaveTime))"
        let subtitle = "\(newFlight.flightNumber) • \(newFlight.route)"
        let body = trackedChangeBody(
            oldFlight: oldFlight,
            newFlight: newFlight,
            securityDelta: securityDelta,
            leaveDeltaMinutes: leaveDeltaMinutes,
            checkpointChanged: checkpointChanged,
            terminalChanged: terminalChanged,
            gateChanged: gateChanged
        )

        sendImmediateNotification(
            id: "trackedFlight.changed.\(UUID().uuidString)",
            title: title,
            subtitle: subtitle,
            body: body
        )
    }

    func notifyDepartureTimeChanged(oldFlight: TrackedFlight, newFlight: TrackedFlight) {
        guard oldFlight.departureTime != newFlight.departureTime else { return }
        guard isWithinActiveNotificationWindow(for: newFlight) else { return }

        let departureDeltaMinutes = Int(
            (newFlight.departureTime.timeIntervalSince1970 - oldFlight.departureTime.timeIntervalSince1970) / 60
        )

        guard abs(departureDeltaMinutes) >= 10 else { return }
        guard canSendImmediateNotification() else { return }

        let title = "New leave time \(formattedTime(newFlight.leaveTime))"
        let subtitle = "\(newFlight.flightNumber) • \(newFlight.route)"

        let body: String
        if departureDeltaMinutes > 0 {
            body = "Departure moved to \(formattedTime(newFlight.departureTime))"
        } else {
            body = "Departure moved earlier to \(formattedTime(newFlight.departureTime))"
        }

        sendImmediateNotification(
            id: "trackedFlight.departureChanged.\(UUID().uuidString)",
            title: title,
            subtitle: subtitle,
            body: body
        )
    }

    func notifyCheckpointClosed(_ flight: TrackedFlight) {
        guard isWithinActiveNotificationWindow(for: flight) else { return }
        guard canSendImmediateNotification() else { return }

        sendImmediateNotification(
            id: "trackedFlight.checkpointClosed.\(UUID().uuidString)",
            title: "New leave time \(formattedTime(flight.leaveTime))",
            subtitle: "\(flight.flightNumber) • \(flight.route)",
            body: "Checkpoint changed to \(flight.securityRouteTitle)"
        )
    }

    func notifyFlightDeparted(_ flight: TrackedFlight) {
        sendImmediateNotification(
            id: "trackedFlight.departed.\(UUID().uuidString)",
            title: "\(flight.flightNumber) • Departed",
            subtitle: flight.route,
            body: "Tracking finished"
        )
    }

    // MARK: - Helpers

    private func isWithinActiveNotificationWindow(for flight: TrackedFlight) -> Bool {
        let secondsUntilLeave = flight.leaveTime.timeIntervalSinceNow
        return secondsUntilLeave <= 3600
    }

    private func canSendImmediateNotification() -> Bool {
        let now = Date()

        if let lastImmediateNotificationAt,
           now.timeIntervalSince(lastImmediateNotificationAt) < 600 {
            return false
        }

        lastImmediateNotificationAt = now
        return true
    }

    private func sendImmediateNotification(id: String, title: String, subtitle: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = baseContent(title: title, subtitle: subtitle, body: body)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("Immediate notification failed:", error.localizedDescription)
            }
        }
    }

    private func baseContent(title: String, subtitle: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.categoryIdentifier = trackedFlightCategoryID
        return content
    }

    private func trackedFlightNotificationIDs() -> [String] {
        [
            "trackedFlight.leave.60",
            "trackedFlight.leave.30",
            "trackedFlight.leave.15",
            "trackedFlight.leave.5",
            "trackedFlight.leave.now"
        ]
    }

    private func scheduledBody(for flight: TrackedFlight) -> String {
        "Departs \(formattedTime(flight.departureTime)) • Security \(securityMinutesText(for: flight)) • \(displayTerminalShort(for: flight))"
    }

    private func trackedChangeBody(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight,
        securityDelta: Int,
        leaveDeltaMinutes: Int,
        checkpointChanged: Bool,
        terminalChanged: Bool,
        gateChanged: Bool
    ) -> String {
        var parts: [String] = []

        if abs(securityDelta) >= 10 {
            if securityDelta > 0 {
                parts.append("Security increased to \(newFlight.securityMinutes) min")
            } else {
                parts.append("Security dropped to \(newFlight.securityMinutes) min")
            }
        }

        if abs(leaveDeltaMinutes) >= 10 {
            if leaveDeltaMinutes > 0 {
                parts.append("Leave moved later")
            } else {
                parts.append("Leave moved earlier")
            }
        }

        if checkpointChanged {
            parts.append("Checkpoint \(newFlight.securityRouteTitle)")
        }

        if terminalChanged {
            parts.append("Terminal \(displayTerminalShort(for: newFlight))")
        }

        if gateChanged, let gate = cleanedGate(for: newFlight) {
            parts.append("Gate \(gate)")
        }

        if parts.isEmpty {
            parts.append("Travel plan updated")
        }

        return parts.joined(separator: " • ")
    }

    private func securityMinutesText(for flight: TrackedFlight) -> String {
        if flight.securityMinutes <= 0 {
            return "No wait"
        }
        return "\(flight.securityMinutes) min"
    }

    private func displayTerminalShort(for flight: TrackedFlight) -> String {
        let t = flight.terminal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "TBD" }
        return t.uppercased().hasPrefix("T") ? t.uppercased() : "T\(t)"
    }

    private func cleanedGate(for flight: TrackedFlight) -> String? {
        let g = (flight.gate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return g.isEmpty ? nil : g
    }

    private func normalizedText(_ text: String?) -> String {
        (text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

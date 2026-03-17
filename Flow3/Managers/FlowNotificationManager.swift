import Foundation
import UserNotifications

final class FlowNotificationManager {

    static let shared = FlowNotificationManager()

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()

        do {
            try await center.requestAuthorization(options: [
                .alert,
                .sound,
                .badge
            ])
        } catch {
            print("Notification permission error:", error.localizedDescription)
        }
    }

    // MARK: - Schedule reminders

    func scheduleTrackedFlightReminders(for flight: TrackedFlight) {
        clearTrackedFlightNotifications()

        let center = UNUserNotificationCenter.current()
        let now = Date()

        let notify30 = UserDefaults.standard.bool(forKey: "flow_notify_30")
        let notify15 = UserDefaults.standard.bool(forKey: "flow_notify_15")
        let notifyNow = UserDefaults.standard.bool(forKey: "flow_notify_leave_now")
        let notifyGate = UserDefaults.standard.bool(forKey: "flow_notify_gate")

        if notify30 {
            scheduleCalendarNotification(
                center: center,
                identifier: "flow.leaveReminder30",
                title: "Leave in 30 minutes",
                body: "You should leave in 30 minutes for \(flight.flightNumber)",
                date: Calendar.current.date(byAdding: .minute, value: -30, to: flight.leaveTime),
                now: now
            )
        }

        if notify15 {
            scheduleCalendarNotification(
                center: center,
                identifier: "flow.leaveReminder15",
                title: "Leave in 15 minutes",
                body: "You should leave in 15 minutes for \(flight.flightNumber)",
                date: Calendar.current.date(byAdding: .minute, value: -15, to: flight.leaveTime),
                now: now
            )
        }

        if notifyNow {
            scheduleCalendarNotification(
                center: center,
                identifier: "flow.leaveReminder",
                title: "Time to leave",
                body: "Leave now for \(flight.flightNumber)",
                date: flight.leaveTime,
                now: now
            )
        }

        if notifyGate {
            scheduleCalendarNotification(
                center: center,
                identifier: "flow.gateReminder",
                title: "Gate target time",
                body: "You should now be at the gate for \(flight.flightNumber)",
                date: flight.gateTargetTime,
                now: now
            )
        }

        debugPrintPendingNotifications()
    }

    private func scheduleCalendarNotification(
        center: UNUserNotificationCenter,
        identifier: String,
        title: String,
        body: String,
        date: Date?,
        now: Date
    ) {
        guard let date else { return }
        guard date > now else {
            print("Skipped notification \(identifier) because date is in the past:", date)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule \(identifier):", error.localizedDescription)
            } else {
                print("Scheduled notification:", identifier, "for", date)
            }
        }
    }

    // MARK: - Clear notifications

    func clearTrackedFlightNotifications() {
        let center = UNUserNotificationCenter.current()

        let identifiers = [
            "flow.leaveReminder30",
            "flow.leaveReminder15",
            "flow.leaveReminder",
            "flow.gateReminder",
            "flow.flightdeparted",
            "flow.leaveTimeChanged",
            "flow.checkpointClosed",
            "flow.departureChanged"
        ]

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Smart alerts

    func notifyTrackedFlightChanged(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight
    ) {
        let deltaMinutes = Int(newFlight.leaveTime.timeIntervalSince(oldFlight.leaveTime) / 60)
        guard abs(deltaMinutes) >= 5 else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let oldTime = formatter.string(from: oldFlight.leaveTime)
        let newTime = formatter.string(from: newFlight.leaveTime)

        let reason: String
        if deltaMinutes < 0 {
            reason = "Traffic or security has increased."
        } else {
            reason = "Conditions improved."
        }

        let content = UNMutableNotificationContent()
        content.title = "Leave time updated"
        content.body = "\(reason) Leave time changed from \(oldTime) to \(newTime) for \(newFlight.flightNumber)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flow.leaveTimeChanged",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 1,
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule leaveTimeChanged:", error.localizedDescription)
            } else {
                print("Scheduled leaveTimeChanged notification")
            }
        }
    }

    func notifyCheckpointClosed(_ flight: TrackedFlight) {
        let content = UNMutableNotificationContent()
        content.title = "Checkpoint closed"
        content.body = "Your selected checkpoint \(flight.securityRouteTitle) has closed. Review security options for \(flight.flightNumber)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flow.checkpointClosed",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 1,
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule checkpointClosed:", error.localizedDescription)
            } else {
                print("Scheduled checkpointClosed notification")
            }
        }
    }

    func notifyDepartureTimeChanged(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight
    ) {
        let deltaMinutes = Int(newFlight.departureTime.timeIntervalSince(oldFlight.departureTime) / 60)
        guard abs(deltaMinutes) >= 5 else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let oldTime = formatter.string(from: oldFlight.departureTime)
        let newTime = formatter.string(from: newFlight.departureTime)

        let content = UNMutableNotificationContent()
        content.title = "Departure time changed"
        content.body = "\(newFlight.flightNumber) departure changed from \(oldTime) to \(newTime)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flow.departureChanged",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 1,
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule departureChanged:", error.localizedDescription)
            } else {
                print("Scheduled departureChanged notification")
            }
        }
    }

    // MARK: - Flight departed notification

    func notifyFlightDeparted(_ flight: TrackedFlight) {
        let content = UNMutableNotificationContent()
        content.title = "Flight departed"
        content.body = "Flow has stopped tracking \(flight.flightNumber) as it has now departed."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flow.flightdeparted",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 1,
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule flightdeparted:", error.localizedDescription)
            } else {
                print("Scheduled flightdeparted notification")
            }
        }
    }

    // MARK: - Debug

    func debugPrintPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("Pending notifications count:", requests.count)

            for request in requests {
                print("Pending notification:", request.identifier)
            }
        }
    }
}

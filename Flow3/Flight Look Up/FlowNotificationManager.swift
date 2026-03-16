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

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let leaveContent = UNMutableNotificationContent()
        leaveContent.title = "Time to leave"
        leaveContent.body = "Leave now for \(flight.flightNumber)"
        leaveContent.sound = .default

        let leaveTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: flight.leaveTime
            ),
            repeats: false
        )

        let leaveRequest = UNNotificationRequest(
            identifier: "flow.leaveReminder",
            content: leaveContent,
            trigger: leaveTrigger
        )

        center.add(leaveRequest)

        let gateContent = UNMutableNotificationContent()
        gateContent.title = "Gate target time"
        gateContent.body = "You should now be at the gate for \(flight.flightNumber)"
        gateContent.sound = .default

        let gateTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: flight.gateTargetTime
            ),
            repeats: false
        )

        let gateRequest = UNNotificationRequest(
            identifier: "flow.gateReminder",
            content: gateContent,
            trigger: gateTrigger
        )

        center.add(gateRequest)
    }

    // MARK: - Clear notifications

    func clearTrackedFlightNotifications() {

        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: [
            "flow.leaveReminder",
            "flow.gateReminder",
            "flow.flightdeparted"
        ])
    }

    // MARK: - Notify when leave time changes

    func notifyTrackedFlightChanged(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight
    ) {

        guard oldFlight.leaveTime != newFlight.leaveTime else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let oldTime = formatter.string(from: oldFlight.leaveTime)
        let newTime = formatter.string(from: newFlight.leaveTime)

        let content = UNMutableNotificationContent()

        content.title = "Leave time updated"
        content.body = "Leave time changed from \(oldTime) to \(newTime) for \(newFlight.flightNumber)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flow.leaveTimeChanged",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 1,
                repeats: false
            )
        )

        UNUserNotificationCenter.current().add(request)
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

        UNUserNotificationCenter.current().add(request)
    }
}

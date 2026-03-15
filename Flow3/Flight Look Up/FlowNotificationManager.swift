import Foundation
import UserNotifications

final class FlowNotificationManager {

    static let shared = FlowNotificationManager()

    private init() {}

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
        }
    }

    func clearTrackedFlightNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "flow.leavechange",
                "flow.leave30",
                "flow.leave15",
                "flow.leavenow"
            ]
        )
    }

    func scheduleTrackedFlightReminders(for flight: TrackedFlight) {
        clearTrackedFlightNotifications()

        scheduleReminder(
            id: "flow.leave30",
            title: "Leave in 30 minutes",
            body: "\(flight.flightNumber) \(flight.route) · Leave at \(timeString(flight.leaveTime))",
            triggerDate: Calendar.current.date(byAdding: .minute, value: -30, to: flight.leaveTime)
        )

        scheduleReminder(
            id: "flow.leave15",
            title: "Leave in 15 minutes",
            body: "\(flight.flightNumber) \(flight.route) · Leave at \(timeString(flight.leaveTime))",
            triggerDate: Calendar.current.date(byAdding: .minute, value: -15, to: flight.leaveTime)
        )

        scheduleReminder(
            id: "flow.leavenow",
            title: "Leave now",
            body: "\(flight.flightNumber) \(flight.route) · Time to go",
            triggerDate: flight.leaveTime
        )
    }

    func notifyLeaveTimeChanged(
        flight: TrackedFlight,
        oldLeaveTime: Date,
        newLeaveTime: Date
    ) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["flow.leavechange"]
        )

        let title = newLeaveTime < oldLeaveTime
            ? "Leave time moved earlier"
            : "Leave time moved later"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(flight.flightNumber) \(flight.route) · \(timeString(oldLeaveTime)) → \(timeString(newLeaveTime))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "flow.leavechange",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleReminder(
        id: String,
        title: String,
        body: String,
        triggerDate: Date?
    ) {
        guard let triggerDate else { return }
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

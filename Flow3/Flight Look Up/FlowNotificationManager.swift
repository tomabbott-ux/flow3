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
            subtitle: flightSubtitle(for: flight),
            body: reminderBody(for: flight, actionText: "Leave at \(timeString(flight.leaveTime))"),
            triggerDate: Calendar.current.date(byAdding: .minute, value: -30, to: flight.leaveTime),
            relevanceScore: 0.50
        )

        scheduleReminder(
            id: "flow.leave15",
            title: "Leave in 15 minutes",
            subtitle: flightSubtitle(for: flight),
            body: reminderBody(for: flight, actionText: "Leave at \(timeString(flight.leaveTime))"),
            triggerDate: Calendar.current.date(byAdding: .minute, value: -15, to: flight.leaveTime),
            relevanceScore: 0.70
        )

        scheduleReminder(
            id: "flow.leavenow",
            title: "Leave now",
            subtitle: flightSubtitle(for: flight),
            body: reminderBody(for: flight, actionText: "Time to go"),
            triggerDate: flight.leaveTime,
            relevanceScore: 0.90
        )
    }

    func notifyTrackedFlightChanged(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight
    ) {
        let summary = changeSummary(oldFlight: oldFlight, newFlight: newFlight)
        guard summary.hasMeaningfulChange else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["flow.leavechange"]
        )

        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.subtitle = flightSubtitle(for: newFlight)
        content.body = summary.body
        content.sound = .default
        content.threadIdentifier = notificationThreadIdentifier(for: newFlight)

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
            content.relevanceScore = 0.8
        }

        let request = UNNotificationRequest(
            identifier: "flow.leavechange",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private func scheduleReminder(
        id: String,
        title: String,
        subtitle: String,
        body: String,
        triggerDate: Date?,
        relevanceScore: Double
    ) {
        guard let triggerDate else { return }
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.threadIdentifier = "flow.trackedFlight"

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
            content.relevanceScore = relevanceScore
        }

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

    private func flightSubtitle(for flight: TrackedFlight) -> String {
        "\(flight.flightNumber) · \(flight.route)"
    }

    private func reminderBody(for flight: TrackedFlight, actionText: String) -> String {
        let routeText = securityRouteText(for: flight)
        return "\(routeText) · \(actionText)"
    }

    private func securityRouteText(for flight: TrackedFlight) -> String {
        if flight.securityRouteSubtitle.isEmpty {
            return flight.securityRouteTitle
        }
        return "\(flight.securityRouteTitle) · \(flight.securityRouteSubtitle)"
    }

    private func notificationThreadIdentifier(for flight: TrackedFlight) -> String {
        "flow.\(flight.flightNumber)"
    }

    private func changeSummary(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight
    ) -> NotificationChangeSummary {

        let leaveDiff = minuteDifference(from: oldFlight.leaveTime, to: newFlight.leaveTime)
        let securityDiff = newFlight.securityMinutes - oldFlight.securityMinutes
        let departureDiff = minuteDifference(from: oldFlight.departureTime, to: newFlight.departureTime)

        let routeChanged =
            oldFlight.securityRouteID != newFlight.securityRouteID ||
            oldFlight.securityRouteMode != newFlight.securityRouteMode ||
            oldFlight.securityRouteTitle != newFlight.securityRouteTitle ||
            oldFlight.securityRouteSubtitle != newFlight.securityRouteSubtitle

        if abs(leaveDiff) >= 5 {
            let title = leaveDiff < 0 ? "Leave earlier" : "Leave later"
            let reason = primaryReason(
                oldFlight: oldFlight,
                newFlight: newFlight,
                securityDiff: securityDiff,
                departureDiff: departureDiff,
                routeChanged: routeChanged
            )

            return NotificationChangeSummary(
                hasMeaningfulChange: true,
                title: title,
                body: "New leave time \(timeString(newFlight.leaveTime)) · \(reason)"
            )
        }

        if routeChanged {
            return NotificationChangeSummary(
                hasMeaningfulChange: true,
                title: "Security route updated",
                body: "\(securityRouteText(for: newFlight))"
            )
        }

        if abs(securityDiff) >= 5 {
            let direction = securityDiff > 0 ? "increased" : "improved"

            return NotificationChangeSummary(
                hasMeaningfulChange: true,
                title: "Security wait changed",
                body: "\(securityRouteText(for: newFlight)) \(direction) to \(newFlight.securityMinutes)m"
            )
        }

        return NotificationChangeSummary(
            hasMeaningfulChange: false,
            title: "",
            body: ""
        )
    }

    private func primaryReason(
        oldFlight: TrackedFlight,
        newFlight: TrackedFlight,
        securityDiff: Int,
        departureDiff: Int,
        routeChanged: Bool
    ) -> String {

        if departureDiff >= 5 {
            return "Departure moved to \(timeString(newFlight.departureTime))"
        }

        if departureDiff <= -5 {
            return "Departure moved forward to \(timeString(newFlight.departureTime))"
        }

        if routeChanged {
            return "Using \(securityRouteText(for: newFlight))"
        }

        if securityDiff >= 5 {
            return "Security increased to \(newFlight.securityMinutes)m"
        }

        if securityDiff <= -5 {
            return "Security improved to \(newFlight.securityMinutes)m"
        }

        return "Flow updated your plan"
    }

    private func minuteDifference(from old: Date, to new: Date) -> Int {
        Int(round(new.timeIntervalSince(old) / 60))
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct NotificationChangeSummary {
    let hasMeaningfulChange: Bool
    let title: String
    let body: String
}

#if DEBUG

extension FlowNotificationManager {

    func debugTestLeaveReminder() {

        let content = UNMutableNotificationContent()
        content.title = "Leave in 15 minutes"
        content.subtitle = "DL830 · ATL → SLC"
        content.body = "Lower North · Domestic · Leave at 10:23"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "debug.leaveReminder",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    func debugTestLeaveEarlier() {

        let content = UNMutableNotificationContent()
        content.title = "Leave earlier"
        content.subtitle = "DL830 · ATL → SLC"
        content.body = "New leave time 10:15 · Security increased to 12m"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "debug.leaveEarlier",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    func debugTestRouteChange() {

        let content = UNMutableNotificationContent()
        content.title = "Security route updated"
        content.subtitle = "DL830 · ATL → SLC"
        content.body = "Main · International"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "debug.routeChange",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

}

#endif

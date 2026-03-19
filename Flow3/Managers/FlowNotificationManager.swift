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
        
        let reminders: [(id: String, fireDate: Date, title: String, subtitle: String, body: String)] = [
            (
                id: "trackedFlight.leave.60",
                fireDate: flight.leaveTime.addingTimeInterval(-60 * 60),
                title: "\(flight.departureAirportCode) • Security",
                subtitle: securitySubtitle(for: flight),
                body: "Leave in 1h • \(flight.flightNumber) • \(flight.route)"
            ),
            (
                id: "trackedFlight.leave.30",
                fireDate: flight.leaveTime.addingTimeInterval(-30 * 60),
                title: "\(flight.departureAirportCode) • Security",
                subtitle: securitySubtitle(for: flight),
                body: "Leave in 30m • Terminal \(displayTerminal(for: flight)) • \(flight.securityRouteTitle)"
            ),
            (
                id: "trackedFlight.leave.15",
                fireDate: flight.leaveTime.addingTimeInterval(-15 * 60),
                title: "\(flight.departureAirportCode) • Security",
                subtitle: securitySubtitle(for: flight),
                body: "Leave in 15m • \(flight.flightNumber) • \(flight.route)"
            ),
            (
                id: "trackedFlight.leave.5",
                fireDate: flight.leaveTime.addingTimeInterval(-5 * 60),
                title: "\(flight.departureAirportCode) • Leave soon",
                subtitle: securitySubtitle(for: flight),
                body: "Leave in 5m • Gate \(displayGate(for: flight))"
            ),
            (
                id: "trackedFlight.leave.now",
                fireDate: flight.leaveTime,
                title: "\(flight.departureAirportCode) • Leave now",
                subtitle: securitySubtitle(for: flight),
                body: "\(flight.flightNumber) • \(flight.route) • \(flight.securityRouteTitle)"
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
        
        let securityDelta = abs(newFlight.securityMinutes - oldFlight.securityMinutes)
        
        let leaveDeltaMinutes = abs(
            Int(newFlight.leaveTime.timeIntervalSince1970 - oldFlight.leaveTime.timeIntervalSince1970)
        ) / 60
        
        let checkpointChanged = oldFlight.securityRouteTitle != newFlight.securityRouteTitle
        let terminalChanged = oldFlight.terminal != newFlight.terminal
        let gateChanged = (oldFlight.gate ?? "") != (newFlight.gate ?? "")
        
        guard securityDelta >= 10 ||
              leaveDeltaMinutes >= 10 ||
              checkpointChanged ||
              terminalChanged ||
              gateChanged else {
            return
        }
        
        guard canSendImmediateNotification() else { return }
        
        let title = "\(newFlight.departureAirportCode) • Security updated"
        let subtitle = securitySubtitle(for: newFlight)
        let body = "Leave \(leaveSummary(for: newFlight)) • \(newFlight.securityRouteTitle)"
        
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
        
        let departureDeltaMinutes = abs(
            Int(newFlight.departureTime.timeIntervalSince1970 - oldFlight.departureTime.timeIntervalSince1970)
        ) / 60
        
        guard departureDeltaMinutes >= 10 else { return }
        guard canSendImmediateNotification() else { return }
        
        let title = "\(newFlight.flightNumber) • Departure updated"
        let subtitle = "New departure \(formattedTime(newFlight.departureTime))"
        let body = "Leave \(leaveSummary(for: newFlight)) • Terminal \(displayTerminal(for: newFlight))"
        
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
        
        let title = "\(flight.departureAirportCode) • Checkpoint changed"
        let subtitle = "Selected route unavailable"
        let body = "Review \(flight.flightNumber) • \(flight.route)"
        
        sendImmediateNotification(
            id: "trackedFlight.checkpointClosed.\(UUID().uuidString)",
            title: title,
            subtitle: subtitle,
            body: body
        )
    }
    
    func notifyFlightDeparted(_ flight: TrackedFlight) {
        let title = "\(flight.flightNumber) • Departed"
        let subtitle = flight.route
        let body = "Tracked flight cleared"
        
        sendImmediateNotification(
            id: "trackedFlight.departed.\(UUID().uuidString)",
            title: title,
            subtitle: subtitle,
            body: body
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
           now.timeIntervalSince(lastImmediateNotificationAt) < 300 {
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
    
    private func securitySubtitle(for flight: TrackedFlight) -> String {
        let mins = flight.securityMinutes
        if mins <= 0 {
            return "No wait"
        }
        return "\(mins) min • \(flight.securityRouteTitle)"
    }
    
    private func leaveSummary(for flight: TrackedFlight) -> String {
        let mins = max(0, Int(flight.leaveTime.timeIntervalSinceNow / 60))
        
        if mins == 0 {
            return "now"
        }
        
        let hours = mins / 60
        let remainingMinutes = mins % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "in \(hours)h \(remainingMinutes)m"
            } else {
                return "in \(hours)h"
            }
        } else {
            return "in \(remainingMinutes)m"
        }
    }
    
    private func displayTerminal(for flight: TrackedFlight) -> String {
        let t = flight.terminal.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "TBD" : t
    }
    
    private func displayGate(for flight: TrackedFlight) -> String {
        let g = (flight.gate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return g.isEmpty ? "TBD" : g
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Convenience

private extension TrackedFlight {
    var departureAirportCode: String {
        route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? "AIRPORT"
    }
}

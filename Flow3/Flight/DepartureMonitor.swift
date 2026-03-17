import Foundation

struct DepartureMonitorResult {
    let messages: [String]
    let hasMeaningfulChange: Bool
}

enum DepartureMonitor {

    static func compare(
        old: SavedFlightPlan,
        new: SavedFlightPlan
    ) -> DepartureMonitorResult {

        var messages: [String] = []

        let departureDiff = minuteDifference(from: old.departureTime, to: new.departureTime)

        if departureDiff != 0 {
            if departureDiff > 0 {
                messages.append("Flight delayed by \(departureDiff)m")
            } else {
                messages.append("Flight brought forward by \(abs(departureDiff))m")
            }
        }

        let travelDiff = new.travelMinutes - old.travelMinutes

        if abs(travelDiff) >= 5 {
            if travelDiff > 0 {
                messages.append("Travel time increased by \(travelDiff)m")
            } else {
                messages.append("Travel time improved by \(abs(travelDiff))m")
            }
        }

        let securityDiff = new.securityMinutes - old.securityMinutes

        if abs(securityDiff) >= 5 {
            if securityDiff > 0 {
                messages.append("Security wait increased by \(securityDiff)m")
            } else {
                messages.append("Security wait improved by \(abs(securityDiff))m")
            }
        }

        let leaveDiff = minuteDifference(from: old.leaveTime, to: new.leaveTime)

        if abs(leaveDiff) >= 5 {
            if leaveDiff > 0 {
                messages.append("New leave time \(timeString(new.leaveTime))")
            } else {
                messages.append("Updated leave time \(timeString(new.leaveTime))")
            }
        }

        return DepartureMonitorResult(
            messages: messages,
            hasMeaningfulChange: !messages.isEmpty
        )
    }

    private static func minuteDifference(from old: Date, to new: Date) -> Int {
        Int(round(new.timeIntervalSince(old) / 60))
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

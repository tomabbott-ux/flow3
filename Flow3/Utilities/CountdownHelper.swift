import Foundation

struct CountdownFormatter {

    static func string(until targetDate: Date) -> String {

        let interval = max(0, Int(targetDate.timeIntervalSinceNow))

        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

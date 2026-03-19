import SwiftUI

struct WatchDetailView: View {
    let flight: WatchTrackedFlight

    var body: some View {
        VStack(spacing: 6) {
            WatchMiniRow(
                title: "Leave",
                value: leaveStatusShort,
                valueColor: leaveColor
            )

            WatchMiniRow(
                title: "Gate",
                value: gateValue
            )

            WatchMiniRow(
                title: "Bags",
                value: bagsValue
            )
        }
    }

    // MARK: - Leave

    private var leaveStatusShort: String {
        let text = flight.leaveStatusText.lowercased()

        if text.contains("leave now") {
            return "Now"
        }

        // Extract number from string (e.g. "Leave in 598 minutes")
        let digits = flight.leaveStatusText.filter(\.isNumber)

        guard let mins = Int(digits) else {
            return flight.leaveStatusText
        }

        return formatMinutesShort(mins)
    }

    private var leaveColor: Color {
        let text = flight.leaveStatusText.lowercased()

        if text.contains("leave now") {
            return .red
        } else if let mins = Int(flight.leaveStatusText.filter(\.isNumber)), mins <= 5 {
            return .orange
        } else {
            return .white
        }
    }

    // MARK: - Gate

    private var gateValue: String {
        let gate = flight.gateText.trimmingCharacters(in: .whitespacesAndNewlines)
        return gate.isEmpty ? "TBD" : gate
    }

    // MARK: - Bags

    private var bagsValue: String {
        let bags = flight.bagText.trimmingCharacters(in: .whitespacesAndNewlines)
        return bags.isEmpty ? "Carry-on only" : bags
    }
}

// MARK: - Formatter

private func formatMinutesShort(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60

    if hours > 0 {
        if mins > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(hours)h"
        }
    } else {
        return "\(mins)m"
    }
}

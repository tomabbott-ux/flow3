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

    private var leaveStatusShort: String {
        let text = flight.leaveStatusText

        if text.lowercased().contains("leave now") {
            return "Now"
        }

        return text
            .replacingOccurrences(of: "Leave in ", with: "")
            .replacingOccurrences(of: " minutes", with: "m")
            .replacingOccurrences(of: " minute", with: "m")
    }

    private var gateValue: String {
        let gate = flight.gateText.trimmingCharacters(in: .whitespacesAndNewlines)
        return gate.isEmpty ? "TBD" : gate
    }

    private var bagsValue: String {
        let bags = flight.bagText.trimmingCharacters(in: .whitespacesAndNewlines)
        return bags.isEmpty ? "Carry-on only" : bags
    }

    private var leaveColor: Color {
        let text = flight.leaveStatusText.lowercased()

        if text.contains("leave now") {
            return .red
        } else if text.contains("1 minute")
                    || text.contains("2 minute")
                    || text.contains("3 minute")
                    || text.contains("4 minute")
                    || text.contains("5 minute") {
            return .orange
        } else {
            return .white
        }
    }
}

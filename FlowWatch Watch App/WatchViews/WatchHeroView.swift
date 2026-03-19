import SwiftUI

struct WatchHeroView: View {
    let flight: WatchTrackedFlight

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)

                Text("Tracking Flight")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }

            Text(routeLine)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            VStack(alignment: .leading, spacing: 0) {
                Text("Leave at")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Text(leaveAtText)
                    .font(.system(size: 34, weight: .heavy, design: .default))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(securityLine)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))

                Text(contextLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "6330C8"),
                            Color(hex: "34125E")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var routeLine: String {
        let flightNo = flight.flightNumber.isEmpty ? "Flight" : flight.flightNumber
        let route = flight.route.isEmpty ? "Route TBD" : flight.route
        return "\(flightNo) • \(route)"
    }

    private var leaveAtText: String {
        flight.leaveTimeText
    }

    private var securityMinutesValue: Int? {
        let digits = flight.securityText.filter(\.isNumber)
        return Int(digits)
    }

    private var securityLine: String {
        if let mins = securityMinutesValue {
            return "\(mins) min security"
        } else {
            return "Security unavailable"
        }
    }

    private var contextLine: String {
        "\(terminalDisplay) • \(checkpointDisplay)"
    }

    private var terminalDisplay: String {
        let raw = flight.terminalText.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.isEmpty || raw == "—" || raw.uppercased() == "TBD" {
            return "Terminal TBD"
        }

        if raw.uppercased().hasPrefix("T") || raw.uppercased().hasPrefix("S") {
            return "Terminal \(raw)"
        }

        return raw
    }

    private var checkpointDisplay: String {
        let raw = flight.checkpointText.trimmingCharacters(in: .whitespacesAndNewlines)

        if raw.isEmpty || raw.uppercased() == "TBD" {
            return "Checkpoint TBD"
        }

        return raw.capitalized
    }
}
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

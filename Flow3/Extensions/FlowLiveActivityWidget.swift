import ActivityKit
import WidgetKit
import SwiftUI

struct FlowLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(for: FlowActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in

            DynamicIsland {

                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(Color(hex: "7C3AED"))

                        Text("Leave \(context.state.leaveTimeText)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane.departure")
                            .foregroundColor(.white)

                        Text(context.state.departureTimeText)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {

                    let status = resolvedStatus(context.state.statusText)

                    VStack(alignment: .leading, spacing: 6) {

                        Text(context.attributes.route)
                            .font(.caption2)
                            .foregroundColor(.white)

                        HStack(spacing: 8) {

                            Text(status.text)
                                .font(.caption.bold())
                                .foregroundColor(status.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(status.color.opacity(0.16))
                                )

                            Text("Security \(context.state.securityText)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.90))
                        }
                    }
                }

            } compactLeading: {

                HStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(Color(hex: "7C3AED"))

                    Text(context.state.leaveTimeText)
                        .foregroundColor(.white)
                }

            } compactTrailing: {

                HStack(spacing: 2) {
                    Image(systemName: "airplane.departure")
                        .foregroundColor(.white)

                    Text(context.state.departureTimeText)
                        .foregroundColor(.white)
                }

            } minimal: {
                Image(systemName: "airplane.departure")
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - LOCK SCREEN

    private func lockScreenView(context: ActivityViewContext<FlowActivityAttributes>) -> some View {

        let status = resolvedStatus(context.state.statusText)

        return VStack(alignment: .leading, spacing: 10) {

            Text(context.attributes.route)
                .font(.caption)
                .foregroundColor(.white)

            HStack(alignment: .firstTextBaseline, spacing: 8) {

                Text("Leave")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "7C3AED"))

                Text(context.state.leaveTimeText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack(spacing: 10) {

                centeredInfoCard(
                    title: "Departs",
                    value: context.state.departureTimeText
                )

                centeredInfoCard(
                    title: "Security",
                    value: context.state.securityText
                )

                centeredInfoCard(
                    title: "Terminal",
                    value: context.state.terminalText
                )

                centeredStatusInfoCard(
                    title: "Status",
                    status: status
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "08050F"),
                            Color(hex: "12081F"),
                            Color(hex: "1D0C36")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - CARDS

    private func centeredInfoCard(title: String, value: String) -> some View {

        VStack(spacing: 6) {

            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func centeredStatusInfoCard(title: String, status: StatusDisplay) -> some View {

        VStack(spacing: 6) {

            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            Text(status.text)
                .font(.headline)
                .foregroundColor(status.color) // ✅ THIS is now perfectly synced
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - STATUS ENGINE (SINGLE SOURCE OF TRUTH)

    struct StatusDisplay {
        let text: String
        let color: Color
    }

    private func resolvedStatus(_ rawValue: String) -> StatusDisplay {

        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = raw.lowercased()

        switch normalized {

        case "expected", "scheduled", "active":
            return StatusDisplay(text: "On Time", color: .green)

        case "boarding":
            return StatusDisplay(text: "Boarding", color: .yellow)

        case "gateopen", "gate_open", "gate open":
            return StatusDisplay(text: "Gate Open", color: .green)

        case "gateclosed", "gate_closed", "gate closed",
             "finalcall", "final_call", "final call",
             "lastcall", "last_call", "last call":
            return StatusDisplay(text: "Gate Closing", color: .red)

        case "delayed":
            return StatusDisplay(text: "Delayed", color: .red)

        case "departed":
            return StatusDisplay(text: "Departed", color: .white.opacity(0.9))

        case "arrived", "landed":
            return StatusDisplay(text: "Arrived", color: .white.opacity(0.9))

        case "cancelled":
            return StatusDisplay(text: "Cancelled", color: .red)

        case "incident", "diverted":
            return StatusDisplay(text: "Disrupted", color: .red)

        default:
            let cleaned = raw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .capitalized

            return StatusDisplay(text: cleaned, color: .white.opacity(0.9))
        }
    }
}

// MARK: - HEX

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}

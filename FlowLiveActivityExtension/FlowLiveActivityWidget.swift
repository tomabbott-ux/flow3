import ActivityKit
import WidgetKit
import SwiftUI

struct FlowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowLiveActivityAttributes.self) { context in

            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Label(
                        "\(context.state.flightNumber) \(context.state.route)",
                        systemImage: "airplane"
                    )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                    Spacer()

                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Leave in")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))

                        Text(
                            timerInterval: Date()...context.state.leaveTime,
                            countsDown: true
                        )
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    }

                    Text("Leave at \(timeString(context.state.leaveTime))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.82))
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(context.state.securityRoute)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(context.state.securityMinutes)m security wait")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.18, green: 0.08, blue: 0.38))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in

            DynamicIsland {

                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.flightNumber)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text(context.state.route)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Leave")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Text(timeString(context.state.leaveTime))
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.state.securityRoute)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)

                            Text("\(context.state.securityMinutes)m security")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Spacer()

                        Text(
                            timerInterval: Date()...context.state.leaveTime,
                            countsDown: true
                        )
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    }
                }

            } compactLeading: {
                Text(context.state.flightNumber)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            } compactTrailing: {
                Text(
                    timerInterval: Date()...context.state.leaveTime,
                    countsDown: true
                )
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
            } minimal: {
                Image(systemName: "airplane")
                    .foregroundColor(.white)
            }
            .keylineTint(.white)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

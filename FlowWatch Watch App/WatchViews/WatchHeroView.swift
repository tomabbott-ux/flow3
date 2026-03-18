import SwiftUI

struct WatchHeroView: View {
    let flight: WatchTrackedFlight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)

                Text("Tracking Flight")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(flight.flightNumber)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text(flight.route)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("Leave at")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Text(flight.leaveTimeText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(flight.leaveStatusText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: flight.leaveStatusColorHex))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "5B2AA8").opacity(0.88),
                            Color(hex: "34125E").opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

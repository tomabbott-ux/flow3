import SwiftUI

struct WatchDetailView: View {
    let flight: WatchTrackedFlight

    var body: some View {
        VStack(spacing: 10) {

            WatchInfoPill(
                title: "Security",
                value: flight.securityText,
                icon: "timer",
                accent: .green
            )

            WatchInfoPill(
                title: "Gate",
                value: flight.gateText,
                icon: "mappin.and.ellipse",
                accent: .white
            )

            WatchInfoPill(
                title: "Bags",
                value: flight.bagText,
                icon: "suitcase",
                accent: .white
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(flight.alertTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(flight.alertBody)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

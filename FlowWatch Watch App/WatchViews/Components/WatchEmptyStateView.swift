import SwiftUI

struct WatchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Flow")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("No tracked flight")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text("Track a flight on your iPhone to see departure timing here.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

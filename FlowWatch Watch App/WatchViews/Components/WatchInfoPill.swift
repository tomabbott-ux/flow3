import SwiftUI

struct WatchInfoPill: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

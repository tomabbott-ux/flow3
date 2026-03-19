import SwiftUI

struct WatchMiniRow: View {
    let title: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .default))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "2A0C5A"),
                    Color(hex: "3B136E"),
                    Color(hex: "14062F")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Settings")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.white)

                Text("Travel preferences like arrival buffer, lounge time, and baggage settings will live here.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}

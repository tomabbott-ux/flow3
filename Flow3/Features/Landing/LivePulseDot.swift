import SwiftUI

struct LivePulseDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(animate ? 1.6 : 0.8)
                .opacity(animate ? 0.0 : 0.9)

            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

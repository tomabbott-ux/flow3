import SwiftUI

struct WatchFlowBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "14062F"),
                Color(hex: "2A0C5A"),
                Color(hex: "090312")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

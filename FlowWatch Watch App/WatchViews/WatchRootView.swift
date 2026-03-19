import SwiftUI

struct WatchRootView: View {
    @StateObject private var session = WatchSessionManager.shared

    var body: some View {
        ZStack {
            WatchFlowBackground()

            if let flight = session.trackedFlight {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        WatchHeroView(flight: flight)

                        WatchDetailView(flight: flight)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                }
            } else {
                WatchEmptyStateView()
                    .padding(.horizontal, 8)
            }
        }
        .onAppear {
            WatchSessionManager.shared.activateSession()
        }
    }
}

#Preview {
    WatchRootView()
}

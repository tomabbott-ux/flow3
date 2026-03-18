import SwiftUI

struct WatchRootView: View {
    @StateObject private var session = WatchSessionManager.shared

    var body: some View {
        ZStack {
            WatchFlowBackground()

            if let flight = session.trackedFlight {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        WatchHeroView(flight: flight)
                            .padding(.top, 4)

                        WatchDetailView(flight: flight)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            } else {
                VStack(spacing: 6) {
                    Text("Flow")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("No tracked flight")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    Text("Start tracking a flight on your iPhone to see live departure timing here.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding()
            }
        }
        .onAppear {
            print("⌚️ WatchRootView onAppear")
            WatchSessionManager.shared.activateSession()
        }
    }
}

#Preview {
    WatchRootView()
}

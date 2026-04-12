import SwiftUI

struct FlightTabView: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowRootView.FlowTab

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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection

                    if store.trackedFlight != nil {
                        TrackedFlightPill(store: store)
                    } else {
                        emptyStateCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flight")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)

            Text(store.trackedFlight == nil ? "Track a flight to see live status and leave time." : "Your tracked journey.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "CBA8FF"))

                Text("No tracked flight")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Search for a flight in Plan to start tracking. Flow will calculate your leave time and keep your journey updated.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                selectedTab = .planner
            } label: {
                HStack {
                    Spacer()

                    Text("Find flight")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "9B6CFF"),
                            Color(hex: "C45CFF")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .flowGlassCard()
    }
}

import SwiftUI

struct AirportSelectorView: View {

    @ObservedObject var store: LandingStore
    @State private var showLanding = false

    private let backgroundTop = Color(hex: "2A0C5A")
    private let backgroundMid = Color(hex: "3B136E")
    private let backgroundBottom = Color(hex: "14062F")

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    backgroundTop,
                    backgroundMid,
                    backgroundBottom
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {

                    Text("Select Airport")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.top, 12)

                    VStack(spacing: 12) {
                        ForEach(AirportRegistry.airports) { airportDef in
                            airportRow(for: airportDef)
                        }
                    }

                    NavigationLink(
                        destination: LandingView(store: store),
                        isActive: $showLanding
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Select Airport")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func airportRow(for airportDef: AirportDefinition) -> some View {
        Button {
            store.selectedAirport = airportDef.airport
            showLanding = true
        } label: {
            HStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(airportDef.airport.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text(airportDef.airport.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                if airportDef.isLive {
                    HStack(spacing: 6) {
                        LivePulseDot()

                        Text("LIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                } else {
                    Text("EST")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                }

                if store.selectedAirport == airportDef.airport {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

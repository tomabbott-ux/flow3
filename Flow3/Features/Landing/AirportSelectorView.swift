import SwiftUI

struct AirportSelectorView: View {

    @ObservedObject var store: LandingStore

    private var airports: [AirportDefinition] {
        AirportRegistry.all.sorted { a, b in
            if a.isLive != b.isLive {
                return a.isLive && !b.isLive
            }
            return a.airport.rawValue < b.airport.rawValue
        }
    }

    private var liveAirports: [AirportDefinition] {
        airports.filter { $0.isLive }
    }

    private var comingSoonAirports: [AirportDefinition] {
        airports.filter { !$0.isLive }
    }

    var body: some View {
        ZStack {
            FlowBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {

                    headerSection

                    if !liveAirports.isEmpty {
                        sectionTitle("Live now")

                        VStack(spacing: 12) {
                            ForEach(liveAirports) { definition in
                                airportCard(definition)
                            }
                        }
                    }

                    if !comingSoonAirports.isEmpty {
                        sectionTitle("Coming soon")

                        VStack(spacing: 12) {
                            ForEach(comingSoonAirports) { definition in
                                airportCard(definition)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flow")
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(.white)

            Text("Airport Security Wait Times")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            HStack(spacing: 8) {
                LivePulseDot()

                Text("Live airports available now")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.82))
            }
            .padding(.top, 4)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
    }

    private func airportCard(_ definition: AirportDefinition) -> some View {
        NavigationLink {
            LandingView(store: store)
                .onAppear {
                    store.selectedAirport = definition.airport
                }
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.airport.rawValue)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white)

                    Text(definition.airport.shortName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Spacer()

                HStack(spacing: 10) {
                    if definition.isLive {
                        livePill
                    } else {
                        comingSoonPill
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var livePill: some View {
        HStack(spacing: 6) {
            LivePulseDot()

            Text("LIVE")
                .font(.system(size: 11, weight: .bold))
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
    }

    private var comingSoonPill: some View {
        Text("SOON")
            .font(.system(size: 11, weight: .bold))
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
}

private enum FlowBrand {
    static let backgroundTop = Color(hex: "2A0C5A")
    static let backgroundMid = Color(hex: "3B136E")
    static let backgroundBottom = Color(hex: "14062F")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                backgroundTop,
                backgroundMid,
                backgroundBottom
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

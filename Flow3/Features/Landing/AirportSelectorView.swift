import SwiftUI

struct AirportSelectorView: View {

    @ObservedObject var store: LandingStore
    let onAirportSelected: () -> Void

    private let airports = AirportRegistry.airports

    var body: some View {
        ZStack {
            FlowSelectorBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Select Airport")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    VStack(spacing: 12) {
                        ForEach(airports) { definition in
                            airportRow(definition)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Select Airport")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func airportRow(_ definition: AirportDefinition) -> some View {
        Button {
            store.selectedAirport = definition.airport
            onAirportSelected()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.airport.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Text(definition.airport.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                badge(for: definition)

                Image(systemName: store.selectedAirport == definition.airport ? "checkmark" : "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.20), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func badge(for definition: AirportDefinition) -> some View {
        if definition.isLive {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

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

        } else if definition.isEstimated {
            Text("ESTIMATE")
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

        } else {
            Text("COMING SOON")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
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
}

private enum FlowSelectorBrand {
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

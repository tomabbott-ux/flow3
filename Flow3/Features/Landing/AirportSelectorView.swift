import SwiftUI

struct AirportSelectorView: View {

    @ObservedObject var store: LandingStore
    let onAirportSelected: () -> Void

    @State private var searchText = ""
    @AppStorage("flow.favoriteAirports") private var favoriteAirportCodesStorage: String = ""

    private let airports = AirportRegistry.airports

    private var filteredAndSortedAirports: [AirportDefinition] {

        let filtered = airports.filter { definition in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard !query.isEmpty else { return true }

            return definition.airport.displayName.lowercased().contains(query)
                || definition.airport.rawValue.lowercased().contains(query)
                || definition.airport.shortName.lowercased().contains(query)
        }

        let favorites = filtered
            .filter { isFavorite($0.airport) }
            .sorted { $0.airport.displayName < $1.airport.displayName }

        let nonFavorites = filtered
            .filter { !isFavorite($0.airport) }
            .sorted { $0.airport.displayName < $1.airport.displayName }

        return favorites + nonFavorites
    }

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

                    searchBar

                    VStack(spacing: 12) {

                        if filteredAndSortedAirports.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredAndSortedAirports) { definition in
                                airportRow(definition)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Select Airport")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {

        HStack(spacing: 12) {

            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))

            TextField("Search airport or code", text: $searchText)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .foregroundColor(.white)

            if !searchText.isEmpty {

                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.10))
                )
        )
    }

    @ViewBuilder
    private func airportRow(_ definition: AirportDefinition) -> some View {

        HStack(spacing: 14) {

            Button {
                toggleFavorite(for: definition.airport)
            } label: {
                Image(systemName: isFavorite(definition.airport) ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(
                        isFavorite(definition.airport)
                        ? Color(hex: "9B6CFF")
                        : .white.opacity(0.55)
                    )
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button {

                store.selectedAirport = definition.airport
                onAirportSelected()

            } label: {

                HStack(spacing: 14) {

                    VStack(alignment: .leading, spacing: 4) {

                        Text(definition.airport.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

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
            }
            .buttonStyle(.plain)
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

    private var emptyState: some View {

        VStack(spacing: 12) {

            Image(systemName: "airplane.circle")
                .font(.system(size: 34))
                .foregroundColor(.white.opacity(0.75))

            Text("Airport not found")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("""
We couldn’t find that airport yet.

Flow is expanding rapidly and new airports are added regularly.
Check back soon — your airport may be next.
""")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
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
                            .stroke(Color.white.opacity(0.10))
                    )
            )

        } else if definition.isEstimated {

            HStack(spacing: 6) {

                SelectorOrangePulseDot()

                Text("ESTIMATE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10))
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
                                .stroke(Color.white.opacity(0.10))
                        )
                )
        }
    }

    private var favoriteAirports: Set<String> {
        Set(
            favoriteAirportCodesStorage
                .split(separator: ",")
                .map { String($0) }
        )
    }

    private func isFavorite(_ airport: FlowAirport) -> Bool {
        favoriteAirports.contains(airport.rawValue)
    }

    private func toggleFavorite(for airport: FlowAirport) {

        var updated = favoriteAirports

        if updated.contains(airport.rawValue) {
            updated.remove(airport.rawValue)
        } else {
            updated.insert(airport.rawValue)
        }

        favoriteAirportCodesStorage = updated
            .sorted()
            .joined(separator: ",")
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

private struct SelectorOrangePulseDot: View {

    @State private var animate = false

    var body: some View {

        ZStack {

            Circle()
                .fill(Color.orange.opacity(0.22))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.35 : 0.85)
                .opacity(animate ? 0.20 : 0.65)

            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
        }
        .onAppear {

            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

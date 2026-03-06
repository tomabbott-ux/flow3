import SwiftUI

struct WelcomeView: View {

    @ObservedObject var store: LandingStore
    @State private var searchText: String = ""

    var filteredAirports: [AirportRegistryItem] {
        let source = AirportRegistry.enabled

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return source
        }

        let q = searchText.lowercased()

        return source.filter {
            $0.airport.rawValue.lowercased().contains(q) ||
            $0.airport.displayName.lowercased().contains(q) ||
            $0.airport.shortName.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            FlowBrand.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {

                Spacer()

                VStack(spacing: 8) {
                    Text("Flow")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundColor(.white)

                    Text("Airport Security Wait Times")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                searchBar

                liveNowSection

                airportList

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Search

extension WelcomeView {

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))

            TextField("Search airport", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundColor(.white)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Live Now

extension WelcomeView {

    var liveNowSection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text("Live now")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Text(AirportRegistry.live.map { $0.airport.rawValue }.joined(separator: " • "))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.70))

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - List

extension WelcomeView {

    var airportList: some View {
        VStack(spacing: 14) {
            ForEach(filteredAirports) { item in
                airportRow(item)
            }
        }
    }

    func airportRow(_ item: AirportRegistryItem) -> some View {
        let airport = item.airport

        return NavigationLink {
            LandingView(store: store)
                .onAppear {
                    store.selectedAirport = airport
                }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(airport.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text(airport.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                if item.isLive {
                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                        )
                } else {
                    Text("COMING SOON")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                        )
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Brand

private enum FlowBrand {

    static let accent = Color(hex: "8B5CF6")
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


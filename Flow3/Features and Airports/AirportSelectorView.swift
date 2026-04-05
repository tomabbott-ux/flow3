import SwiftUI

struct AirportSelectorView: View {

    @ObservedObject var store: LandingStore
    let onAirportSelected: () -> Void

    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var searchText: String = ""
    @State private var favourites: Set<FlowAirport> = FavouriteAirports.shared.load()
    @State private var recents: [FlowAirport] = RecentAirports.shared.load()

    var body: some View {
        ZStack {
            SelectorBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    headerSection
                    searchSection

                    if !recentDefinitions.isEmpty {
                        AirportSectionHeader(title: "RECENT")
                            .padding(.top, 6)

                        ForEach(recentDefinitions) { definition in
                            airportRow(definition)
                        }
                    }

                    if !pinnedFavouriteDefinitions.isEmpty {
                        AirportSectionHeader(title: "FAVOURITES")
                            .padding(.top, 6)

                        ForEach(pinnedFavouriteDefinitions) { definition in
                            airportRow(definition)
                        }
                    }

                    if !remainingAirportDefinitions.isEmpty {
                        AirportSectionHeader(title: "AIRPORTS")
                            .padding(.top, 6)

                        ForEach(remainingAirportDefinitions) { definition in
                            airportRow(definition)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Header

private extension AirportSelectorView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Airport")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Search

private extension AirportSelectorView {

    var searchSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))

            TextField("Search airport or code", text: $searchText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Airport Row

private extension AirportSelectorView {

    func airportRow(_ definition: AirportDefinition) -> some View {
        let airport = definition.airport
        let isFavourite = favourites.contains(airport)
        let isUnlocked = FlowEntitlements.canAccessAirport(
            airportCode: airport.rawValue,
            subscriptionTier: subscriptionManager.tier
        )

        return Button {
            handleAirportTapped(airport: airport, isUnlocked: isUnlocked)
        } label: {
            HStack(spacing: 12) {
                Button {
                    toggleFavourite(airport)
                } label: {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(
                            isFavourite
                            ? Color(hex: "C9B6FF")
                            : .white.opacity(0.45)
                        )
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isFavourite ? 0.12 : 0.06))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(isFavourite ? 0.12 : 0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(airport.rawValue)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        if !isUnlocked {
                            premiumLockBadge
                        }
                    }

                    Text(airport.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if isUnlocked {
                    feedBadge(for: definition.feedType)
                } else {
                    lockedBadge
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
            .opacity(isUnlocked ? 1.0 : 0.92)
        }
        .buttonStyle(.plain)
    }

    func handleAirportTapped(airport: FlowAirport, isUnlocked: Bool) {
        guard isUnlocked else {
            NotificationCenter.default.post(
                name: .showProPaywall,
                object: PaywallView.PaywallSource.lockedAirport(code: airport.rawValue.uppercased())
            )
            return
        }

        store.selectedAirport = airport
        RecentAirports.shared.add(airport)
        recents = RecentAirports.shared.load()
        onAirportSelected()
    }

    var premiumLockBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))

            Text("PRO")
                .font(.system(size: 10, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(hex: "9B6CFF").opacity(0.95))
        )
    }

    var lockedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.92))

            Text("PRO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "9B6CFF").opacity(0.22))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

// MARK: - Favourite Logic

private extension AirportSelectorView {

    func toggleFavourite(_ airport: FlowAirport) {
        if favourites.contains(airport) {
            favourites.remove(airport)
        } else {
            favourites.insert(airport)
        }

        FavouriteAirports.shared.save(favourites)
        recents = RecentAirports.shared.load()
    }
}

// MARK: - Feed Badge

private extension AirportSelectorView {

    @ViewBuilder
    func feedBadge(for feedType: AirportFeedType) -> some View {
        switch feedType {
        case .live:
            staticBadge(
                text: "LIVE",
                textColor: .green,
                dotColor: .green
            )

        case .highConfidence:
            staticBadge(
                text: "HIGH CONFIDENCE",
                textColor: Color(hex: "9B6CFF"),
                dotColor: Color(hex: "9B6CFF")
            )

        case .estimated:
            staticBadge(
                text: "ESTIMATED",
                textColor: .orange,
                dotColor: .orange
            )

        case .comingSoon:
            staticBadge(
                text: "COMING SOON",
                textColor: .gray,
                dotColor: .gray
            )
        }
    }

    func staticBadge(text: String, textColor: Color, dotColor: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(textColor)
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
}

// MARK: - Sorting + Filtering

private extension AirportSelectorView {

    var uniqueDefinitions: [AirportDefinition] {
        var seen: Set<FlowAirport> = []
        var unique: [AirportDefinition] = []

        for definition in AirportRegistry.airports {
            if !seen.contains(definition.airport) {
                seen.insert(definition.airport)
                unique.append(definition)
            }
        }

        return unique
    }

    var filteredDefinitions: [AirportDefinition] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return uniqueDefinitions
        }

        return uniqueDefinitions.filter { definition in
            let airport = definition.airport

            let haystack = [
                airport.rawValue,
                airport.displayName,
                airport.shortName
            ].joined(separator: " ")

            return haystack.localizedCaseInsensitiveContains(query)
        }
    }

    var canonicalRecents: [FlowAirport] {
        var seen: Set<FlowAirport> = []
        var ordered: [FlowAirport] = []

        for airport in recents.reversed() {
            if !seen.contains(airport) {
                seen.insert(airport)
                ordered.append(airport)
            }
        }

        return Array(ordered.prefix(4))
    }

    var recentDefinitions: [AirportDefinition] {
        let recentSet = Set(canonicalRecents)

        return filteredDefinitions
            .filter { recentSet.contains($0.airport) }
            .sorted { lhs, rhs in
                let lhsIndex = canonicalRecents.firstIndex(of: lhs.airport) ?? .max
                let rhsIndex = canonicalRecents.firstIndex(of: rhs.airport) ?? .max
                return lhsIndex < rhsIndex
            }
    }

    var pinnedFavouriteDefinitions: [AirportDefinition] {
        let recentSet = Set(canonicalRecents)

        return filteredDefinitions
            .filter { favourites.contains($0.airport) && !recentSet.contains($0.airport) }
            .sorted { lhs, rhs in
                lhs.airport.displayName.localizedCaseInsensitiveCompare(
                    rhs.airport.displayName
                ) == .orderedAscending
            }
    }

    var remainingAirportDefinitions: [AirportDefinition] {
        let favouriteSet = favourites
        let recentSet = Set(canonicalRecents)

        return filteredDefinitions
            .filter { !favouriteSet.contains($0.airport) && !recentSet.contains($0.airport) }
            .sorted { lhs, rhs in
                let lhsPriority = priority(lhs.feedType)
                let rhsPriority = priority(rhs.feedType)

                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }

                return lhs.airport.displayName.localizedCaseInsensitiveCompare(
                    rhs.airport.displayName
                ) == .orderedAscending
            }
    }

    func priority(_ feedType: AirportFeedType) -> Int {
        switch feedType {
        case .live:
            return 0
        case .highConfidence:
            return 1
        case .estimated:
            return 2
        case .comingSoon:
            return 3
        }
    }
}

// MARK: - Section Header

private struct AirportSectionHeader: View {

    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.65))
                .tracking(1.2)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Background

private enum SelectorBrand {

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

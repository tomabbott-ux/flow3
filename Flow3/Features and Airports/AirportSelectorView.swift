import SwiftUI

struct AirportSelectorView: View {

    @ObservedObject var store: LandingStore
    let onAirportSelected: () -> Void

    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""

    @State private var favourites: Set<FlowAirport> = FavouriteAirports.shared.load()
    @State private var recents: [FlowAirport] = RecentAirports.shared.load()

    @State private var recentSection: [AirportDefinition] = []
    @State private var favouriteSection: [AirportDefinition] = []
    @State private var airportSection: [AirportDefinition] = []

    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            SelectorBrand.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    headerSection
                    searchSection

                    if showingEmptySearchState {
                        emptySearchState
                            .padding(.top, 8)
                    } else {
                        if !recentSection.isEmpty {
                            AirportSectionHeader(title: "RECENT")
                                .padding(.top, 6)

                            VStack(spacing: 12) {
                                ForEach(recentSection) { definition in
                                    airportRow(definition)
                                }
                            }
                        }

                        if !favouriteSection.isEmpty {
                            AirportSectionHeader(title: "FAVOURITES")
                                .padding(.top, 6)

                            VStack(spacing: 12) {
                                ForEach(favouriteSection) { definition in
                                    airportRow(definition)
                                }
                            }
                        }

                        if !airportSection.isEmpty {
                            AirportSectionHeader(title: "AIRPORTS")
                                .padding(.top, 6)

                            VStack(spacing: 12) {
                                ForEach(airportSection) { definition in
                                    airportRow(definition)
                                }
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
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rebuildSections()
        }
        .onChange(of: searchText) { newValue in
            scheduleDebouncedSearch(newValue)
        }
        .onChange(of: favourites) { _ in
            rebuildSections()
        }
        .onChange(of: recents) { _ in
            rebuildSections()
        }
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
                .submitLabel(.search)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchTask?.cancel()
                    searchText = ""
                    debouncedSearchText = ""
                    rebuildSections()
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = true
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
        .zIndex(10)
    }

    func scheduleDebouncedSearch(_ value: String) {
        searchTask?.cancel()

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }

            await MainActor.run {
                debouncedSearchText = value
                rebuildSections()
            }
        }
    }
}

// MARK: - Airport Row

private extension AirportSelectorView {

    func airportRow(_ definition: AirportDefinition) -> some View {
        let airport = definition.airport
        let isFavourite = favourites.contains(airport)

        return Button {
            store.selectedAirport = airport
            RecentAirports.shared.add(airport)
            recents = RecentAirports.shared.load()
            onAirportSelected()
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
                    Text(airport.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(airport.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer(minLength: 12)

                feedBadge(for: definition.feedType)
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

private extension AirportSelectorView {

    var showingEmptySearchState: Bool {
        !debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        recentSection.isEmpty &&
        favouriteSection.isEmpty &&
        airportSection.isEmpty
    }

    var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(.white.opacity(0.75))

            Text("We’re not covering that airport yet.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Try another airport, or check back soon as Flow continues to expand.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Text("Search: \(debouncedSearchText)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.58))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
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
            animatedBadge(
                text: "LIVE",
                textColor: .green,
                dot: AnyView(LiveStatusDot())
            )

        case .highConfidence:
            animatedBadge(
                text: "HIGH CONFIDENCE",
                textColor: Color(hex: "9B6CFF"),
                dot: AnyView(HighConfidenceStatusDot())
            )

        case .estimated:
            animatedBadge(
                text: "ESTIMATED",
                textColor: .orange,
                dot: AnyView(EstimatedStatusDot())
            )

        case .comingSoon:
            animatedBadge(
                text: "COMING SOON",
                textColor: .gray,
                dot: AnyView(ComingSoonStatusDot())
            )
        }
    }

    func animatedBadge(text: String, textColor: Color, dot: AnyView) -> some View {
        HStack(spacing: 6) {
            dot

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

    func rebuildSections() {
        let filtered = filteredDefinitions(for: debouncedSearchText)
        let recentSet = Set(canonicalRecents)
        let favouriteSet = favourites

        recentSection = filtered
            .filter { recentSet.contains($0.airport) }
            .sorted { lhs, rhs in
                let lhsIndex = canonicalRecents.firstIndex(of: lhs.airport) ?? .max
                let rhsIndex = canonicalRecents.firstIndex(of: rhs.airport) ?? .max
                return lhsIndex < rhsIndex
            }

        favouriteSection = filtered
            .filter { favouriteSet.contains($0.airport) && !recentSet.contains($0.airport) }
            .sorted { lhs, rhs in
                lhs.airport.displayName.localizedCaseInsensitiveCompare(
                    rhs.airport.displayName
                ) == .orderedAscending
            }

        airportSection = filtered
            .filter { !recentSet.contains($0.airport) && !favouriteSet.contains($0.airport) }
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

    func filteredDefinitions(for queryText: String) -> [AirportDefinition] {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)

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

// MARK: - Status Dots

private struct LiveStatusDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.22))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.35 : 0.85)
                .opacity(animate ? 0.20 : 0.65)

            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

private struct HighConfidenceStatusDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "9B6CFF").opacity(0.22))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.35 : 0.85)
                .opacity(animate ? 0.20 : 0.65)

            Circle()
                .fill(Color(hex: "9B6CFF"))
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

private struct EstimatedStatusDot: View {
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

private struct ComingSoonStatusDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.15 : 0.90)
                .opacity(animate ? 0.18 : 0.45)

            Circle()
                .fill(Color.gray.opacity(0.85))
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
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

import SwiftUI

struct FlightTabView: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowRootView.FlowTab

    @State private var otherCheckpointsExpanded = false

    private struct SecurityCheckpointGroup: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let detail: String
        let generalMinutes: Int?
        let precheckMinutes: Int?

        var subtitleDisplay: String {
            let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Security" : trimmed
        }

        var bestMinutes: Int {
            min(generalMinutes ?? .max, precheckMinutes ?? .max)
        }

        var hasMultipleMetrics: Bool {
            generalMinutes != nil && precheckMinutes != nil
        }
    }

    // MARK: - Core Data

    private var trackedFlight: TrackedFlight? {
        store.trackedFlight
    }

    private var trackedAirport: FlowAirport? {
        guard let flight = trackedFlight else { return nil }
        return flowAirport(for: flight)
    }

    private var availableRoutes: [SecurityRouteOption] {
        guard let airport = trackedAirport else { return [] }
        return store.availableSecurityRoutes(for: airport)
    }

    // MARK: - Route Matching

    private var currentRoute: SecurityRouteOption? {
        guard let flight = trackedFlight else { return nil }

        if let routeID = flight.securityRouteID,
           let matchedByID = availableRoutes.first(where: { $0.id == routeID }) {
            return matchedByID
        }

        let title = flight.securityRouteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = flight.securityRouteSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !title.isEmpty {
            if !subtitle.isEmpty,
               let exactMatch = availableRoutes.first(where: {
                   $0.title.caseInsensitiveCompare(title) == .orderedSame &&
                   $0.subtitle.caseInsensitiveCompare(subtitle) == .orderedSame
               }) {
                return exactMatch
            }

            if let titleMatch = availableRoutes.first(where: {
                $0.title.caseInsensitiveCompare(title) == .orderedSame
            }) {
                return titleMatch
            }
        }

        let terminalText = cleanedText(flight.terminal) ?? ""

        if !terminalText.isEmpty,
           let terminalMatch = availableRoutes.first(where: { route in
               route.title.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
               route.subtitle.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
               route.detail.localizedCaseInsensitiveContains("Terminal \(terminalText)")
           }) {
            return terminalMatch
        }

        return availableRoutes.first
    }

    // MARK: - Grouping

    private var groupedCheckpoints: [SecurityCheckpointGroup] {
        let grouped = Dictionary(grouping: availableRoutes) { route in
            checkpointGroupKey(title: route.title, subtitle: route.subtitle)
        }

        return grouped.compactMap { key, routes in
            guard let first = routes.first else { return nil }

            let generalRoute = routes
                .filter { !$0.isPreCheckOnly }
                .min(by: { $0.minutes < $1.minutes })

            let precheckRoute = routes
                .filter { $0.isPreCheckOnly }
                .min(by: { $0.minutes < $1.minutes })

            let detail = generalRoute?.detail ?? precheckRoute?.detail ?? first.detail

            return SecurityCheckpointGroup(
                id: key,
                title: first.title,
                subtitle: first.subtitle,
                detail: detail,
                generalMinutes: generalRoute?.minutes,
                precheckMinutes: precheckRoute?.minutes
            )
        }
        .sorted { lhs, rhs in
            if lhs.bestMinutes == rhs.bestMinutes {
                return lhs.title < rhs.title
            }
            return lhs.bestMinutes < rhs.bestMinutes
        }
    }

    // MARK: - Stable Fallback

    private var savedTrackedCheckpointGroup: SecurityCheckpointGroup? {
        guard let flight = trackedFlight else { return nil }

        let title = cleanedText(flight.securityRouteTitle) ?? "Security"
        let subtitle = cleanedText(flight.securityRouteSubtitle) ?? departureAirportCode(for: flight)
        let detail = cleanedText(flight.securityRouteDetail) ?? ""

        return SecurityCheckpointGroup(
            id: "saved-\(flight.securityRouteID ?? flight.flightNumber)",
            title: title,
            subtitle: subtitle,
            detail: detail,
            generalMinutes: flight.securityRouteIsPreCheckOnly ? nil : max(0, flight.securityMinutes),
            precheckMinutes: flight.securityRouteIsPreCheckOnly ? max(0, flight.securityMinutes) : nil
        )
    }

    private var currentCheckpointGroup: SecurityCheckpointGroup? {
        if let currentRoute {
            let currentKey = checkpointGroupKey(
                title: currentRoute.title,
                subtitle: currentRoute.subtitle
            )

            if let matched = groupedCheckpoints.first(where: { $0.id == currentKey }) {
                return matched
            }
        }

        guard let flight = trackedFlight else { return groupedCheckpoints.first }

        if let terminal = cleanedText(flight.terminal) {
            if let matchedTerminal = groupedCheckpoints.first(where: { group in
                group.title.localizedCaseInsensitiveContains("Terminal \(terminal)") ||
                group.subtitle.localizedCaseInsensitiveContains("Terminal \(terminal)") ||
                group.detail.localizedCaseInsensitiveContains("Terminal \(terminal)")
            }) {
                return matchedTerminal
            }
        }

        // If only a generic fallback row exists, prefer the saved tracked checkpoint
        if let first = groupedCheckpoints.first,
           groupedCheckpoints.count == 1,
           first.title.caseInsensitiveCompare("Security") == .orderedSame {
            return savedTrackedCheckpointGroup ?? first
        }

        return groupedCheckpoints.first ?? savedTrackedCheckpointGroup
    }

    private var otherCheckpointGroups: [SecurityCheckpointGroup] {
        guard let currentCheckpointGroup else { return groupedCheckpoints }

        // Hide "other checkpoints" if only generic fallback exists
        if groupedCheckpoints.count <= 1,
           let first = groupedCheckpoints.first,
           first.title.caseInsensitiveCompare("Security") == .orderedSame {
            return []
        }

        return groupedCheckpoints.filter { $0.id != currentCheckpointGroup.id }
    }

    // MARK: - Body

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

                    if let flight = trackedFlight {
                        TrackedFlightPill(store: store)

                        if usesFlowAirport(flight) {
                            securityCheckpointSection(for: flight)
                        } else {
                            unsupportedCheckpointCard(for: flight)
                        }
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
        .onChange(of: store.trackedFlight?.flightNumber) { _, _ in
            otherCheckpointsExpanded = false
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tracked")
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)

            Text(
                store.trackedFlight == nil
                ? "Track a flight to see live status, leave time, and your security route."
                : "Your tracked journey and checkpoint plan."
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Security Section

    private func securityCheckpointSection(for flight: TrackedFlight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Security Checkpoint")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.leading, 2)

            if let currentCheckpointGroup {
                currentCheckpointCard(
                    group: currentCheckpointGroup,
                    airportCode: departureAirportCode(for: flight)
                )
            }

            if !otherCheckpointGroups.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        otherCheckpointsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Other checkpoints")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)

                            Text(
                                otherCheckpointsExpanded
                                ? "Hide other options"
                                : "View other options"
                            )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.70))
                        }

                        Spacer()

                        Image(systemName: otherCheckpointsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.82))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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

                if otherCheckpointsExpanded {
                    VStack(spacing: 12) {
                        ForEach(otherCheckpointGroups) { group in
                            otherCheckpointCard(group)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Card

    private func currentCheckpointCard(
        group: SecurityCheckpointGroup,
        airportCode: String
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(hex: "9B6CFF").opacity(0.95), lineWidth: 1.4)
                )

            Text(airportCode)
                .font(.system(size: 82, weight: .heavy))
                .foregroundColor(.white.opacity(0.06))

            checkpointHeroContent(group)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(height: 150)
    }

    // MARK: - Hero Content

    @ViewBuilder
    private func checkpointHeroContent(_ group: SecurityCheckpointGroup) -> some View {
        if group.hasMultipleMetrics {
            VStack(spacing: 8) {
                HStack(spacing: 30) {
                    heroMetric(value: group.generalMinutes, label: "General")
                    heroMetric(value: group.precheckMinutes, label: "PreCheck")
                }

                Text(group.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text(group.subtitleDisplay)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        } else {
            let primaryMinutes = group.generalMinutes ?? group.precheckMinutes
            let primaryLabel = group.generalMinutes != nil ? "General" : "PreCheck"

            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(primaryMinutes == nil ? "--" : "\(primaryMinutes!)")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    if primaryMinutes != nil {
                        Text("minutes")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.72))
                            .padding(.bottom, 7)
                    }
                }

                Text(group.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text(group.subtitleDisplay)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text(primaryLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.54))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Other Checkpoint Card

    private func otherCheckpointCard(_ group: SecurityCheckpointGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Text(group.subtitleDisplay)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                if let generalMinutes = group.generalMinutes {
                    miniMetricCard(
                        label: "General",
                        valueText: "\(max(0, generalMinutes)) min"
                    )
                }

                if let precheckMinutes = group.precheckMinutes {
                    miniMetricCard(
                        label: "PreCheck",
                        valueText: "\(max(0, precheckMinutes)) min"
                    )
                }
            }

            if !group.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(group.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    // MARK: - Metric Helpers

    @ViewBuilder
    private func heroMetric(value: Int?, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(value == nil ? "--" : "\(value!)")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.white)
                    .monospacedDigit()

                if value != nil {
                    Text("min")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
        }
    }

    private func miniMetricCard(label: String, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(valueText)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Unsupported / Empty

    private func unsupportedCheckpointCard(for flight: TrackedFlight) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "CBA8FF"))

                Text("Security checkpoint")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Flow does not yet provide a selectable checkpoint list for \(departureAirportCode(for: flight)). Your leave time still uses travel time and standard airport buffers.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .flowGlassCard()
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

    // MARK: - Helpers

    private func checkpointGroupKey(title: String, subtitle: String) -> String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedTitle)|\(normalizedSubtitle)"
    }

    private func usesFlowAirport(_ flight: TrackedFlight) -> Bool {
        let code = departureAirportCode(for: flight)

        return AirportRegistry.airports.contains {
            $0.airport.rawValue.caseInsensitiveCompare(code) == .orderedSame
        }
    }

    private func departureAirportCode(for flight: TrackedFlight) -> String {
        flight.route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
    }

    private func flowAirport(for flight: TrackedFlight) -> FlowAirport? {
        let code = departureAirportCode(for: flight)

        return AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.caseInsensitiveCompare(code) == .orderedSame })
    }

    private func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" {
            return nil
        }
        return trimmed
    }
}

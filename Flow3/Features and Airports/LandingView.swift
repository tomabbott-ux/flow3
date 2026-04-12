import SwiftUI

struct LandingView: View {
    @ObservedObject var store: LandingStore
    @Binding var selectedTab: FlowRootView.FlowTab
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @AppStorage("flow_use_celsius")
    private var useCelsius: Bool = true
    
    @State private var selectedRowID: String? = nil
    @State private var otherCheckpointsExpanded = false
    @State private var hasPerformedInitialLoad = false
    @State private var lastRefreshDate: Date? = nil
    @State private var isRefreshInFlight = false
    
    private let refreshTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let autoRefreshInterval: TimeInterval = 60
    
    private var displayRows: [AirportDisplayRow] {
        store.displayRowsForSelectedAirport()
    }
    
    private var isSelectedAirportUnlocked: Bool {
        FlowEntitlements.canAccessAirport(
            airportCode: store.selectedAirport.rawValue,
            subscriptionTier: subscriptionManager.tier
        )
    }
    
    private var preferredTrackedFlightRowID: String? {
        guard let trackedFlight = store.trackedFlight else { return nil }
        guard store.selectedAirport == trackedAirportIfKnown else { return nil }
        
        if let routeID = trackedFlight.securityRouteID,
           let matchedByID = displayRows.first(where: { rowMatchesID($0, routeID) })?.id {
            return matchedByID
        }
        
        let terminalText = trackedFlight.terminal
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !terminalText.isEmpty {
            if let matchedByTerminal = displayRows.first(where: { row in
                row.title.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
                row.subtitle.localizedCaseInsensitiveContains("Terminal \(terminalText)")
            })?.id {
                return matchedByTerminal
            }
        }
        
        let title = trackedFlight.securityRouteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = trackedFlight.securityRouteSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !title.isEmpty else { return nil }
        
        if subtitle.isEmpty {
            return displayRows.first(where: {
                $0.title.caseInsensitiveCompare(title) == .orderedSame
            })?.id
        }
        
        return displayRows.first(where: {
            $0.title.caseInsensitiveCompare(title) == .orderedSame &&
            $0.subtitle.caseInsensitiveCompare(subtitle) == .orderedSame
        })?.id
    }
    
    private var trackedAirportIfKnown: FlowAirport? {
        store.trackedFlight == nil ? nil : store.selectedAirport
    }
    
    private var selectedRow: AirportDisplayRow? {
        if let tracked = store.trackedFlight {
            print("   routeID:", tracked.securityRouteID ?? "nil")
            print("   title:", tracked.securityRouteTitle)
            print("   subtitle:", tracked.securityRouteSubtitle)
            print("   selectedAirport:", store.selectedAirport.rawValue)
            print("   displayRows:", displayRows.map { "\($0.id) | \($0.title) | \($0.subtitle)" })
        }
        
        if let tracked = store.trackedFlight,
           let routeID = tracked.securityRouteID,
           let row = displayRows.first(where: { rowMatchesID($0, routeID) }) {
            return row
        }
        
        if let preferredTrackedFlightRowID,
           let trackedRow = displayRows.first(where: { rowMatchesID($0, preferredTrackedFlightRowID) }) {
            return trackedRow
        }
        
        if let selectedRowID,
           let row = displayRows.first(where: { rowMatchesID($0, selectedRowID) }) {
            return row
        }
        
        if let first = displayRows.first {
            return first
        }
        
        return nil
    }
    
    private var usesAverageWaitPresentation: Bool {
        AirportRegistry.definition(for: store.selectedAirport)?.feedType == .highConfidence
    }
    
    private var confidenceLevel: FlowConfidenceLevel {
        guard let definition = AirportRegistry.definition(for: store.selectedAirport) else {
            return .comingSoon
        }
        
        if store.selectedAirport == .lax {
            let selectedRows = store.displayRowsForSelectedAirport()
            let selectedRow = selectedRows.first(where: { rowMatchesID($0, selectedRowID) }) ?? selectedRows.first
            
            if selectedRow?.title == "Terminal B" {
                return .live
            } else {
                return .highConfidence
            }
        }
        
        switch definition.feedType {
        case .live:
            return .live
        case .highConfidence:
            return .highConfidence
        case .estimated:
            return .lowConfidence
        case .comingSoon:
            return .comingSoon
        }
    }
    
    private var secondaryCheckpointRows: [AirportDisplayRow] {
        guard let primary = selectedRow else {
            return displayRows
        }
        
        return displayRows.filter { !rowMatchesID($0, primary.id) }
    }
    
    private var hasTrackedFlight: Bool {
        store.trackedFlight != nil
    }
    
    private var displayAirportCode: String {
        if let flight = store.trackedFlight {
            return flight.route
                .components(separatedBy: "→")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? store.selectedAirport.rawValue
        }
        
        return store.selectedAirport.rawValue
    }
    private var trackedFlightUsesFlowAirport: Bool {
        guard let trackedFlight = store.trackedFlight else { return false }
        
        let departureCode = trackedFlight.route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        
        return AirportRegistry.airports.contains {
            $0.airport.rawValue.caseInsensitiveCompare(departureCode) == .orderedSame
        }
    }
    
    private var shouldShowTrackedSecurityUI: Bool {
        hasTrackedFlight && trackedFlightUsesFlowAirport
    }
    
    private var isLoadingCurrentAirport: Bool {
        store.allWaitTimes()
            .filter { $0.airport == store.selectedAirport }
            .isEmpty
    }
    
    var body: some View {
        ZStack {
            FlowBrand.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    airportSelectorPill
                    headerSection
                    
                    if isSelectedAirportUnlocked {
                        weatherRow
                        
                        if store.trackedFlight != nil {
                            TrackedFlightPill(store: store)
                        }
                        
                        if shouldShowTrackedSecurityUI || store.trackedFlight == nil {
                            securityHero
                            checkpointsSection
                        }
                        
                        errorSection
                    } else {
                        lockedAirportView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasPerformedInitialLoad else { return }
            hasPerformedInitialLoad = true
            
            guard isSelectedAirportUnlocked else { return }
            
            Task {
                await refreshNow(
                    prefetchNeighbors: false,
                    shouldRefreshTrackedFlight: false
                )
            }
        }
        .onAppear {
            print("👀 LandingView onAppear")
            print("   selectedAirport:", store.selectedAirport.rawValue)
            print("   trackedFlight routeID:", store.trackedFlight?.securityRouteID ?? "nil")
            print("   trackedFlight title:", store.trackedFlight?.securityRouteTitle ?? "nil")
            print("   trackedFlight subtitle:", store.trackedFlight?.securityRouteSubtitle ?? "nil")
            print("   displayRows at appear:", displayRows.map { "\($0.id) | \($0.title) | \($0.subtitle)" })
            
            syncSelectedRowWithTrackedFlight()
            
            Task {
                await FlowNotificationManager.shared.requestPermission()
            }
        }
        .onReceive(refreshTick) { now in
            guard isSelectedAirportUnlocked else { return }
            guard hasPerformedInitialLoad else { return }
            guard !isRefreshInFlight else { return }
            guard let lastRefreshDate else { return }
            
            if now.timeIntervalSince(lastRefreshDate) >= autoRefreshInterval {
                Task {
                    await refreshNow(
                        prefetchNeighbors: false,
                        shouldRefreshTrackedFlight: store.trackedFlight != nil
                    )
                }
            }
        }
        .onChange(of: store.selectedAirport) {
            otherCheckpointsExpanded = false
            selectedRowID = nil
            
            guard isSelectedAirportUnlocked else { return }
            
            Task {
                await refreshNow(
                    prefetchNeighbors: false,
                    shouldRefreshTrackedFlight: false
                )
            }
        }
        .onChange(of: store.trackedFlight?.securityRouteID) {
            guard isSelectedAirportUnlocked else { return }
            otherCheckpointsExpanded = false
            syncSelectedRowWithTrackedFlight()
        }
        .onChange(of: store.trackedFlight?.securityRouteTitle) {
            guard isSelectedAirportUnlocked else { return }
            otherCheckpointsExpanded = false
            syncSelectedRowWithTrackedFlight()
        }
        .onChange(of: store.trackedFlight?.securityRouteSubtitle) {
            guard isSelectedAirportUnlocked else { return }
            otherCheckpointsExpanded = false
            syncSelectedRowWithTrackedFlight()
        }
        .onChange(of: subscriptionManager.tier) { _, _ in
            guard isSelectedAirportUnlocked else { return }
            
            Task {
                await refreshNow(
                    prefetchNeighbors: false,
                    shouldRefreshTrackedFlight: false
                )
            }
        }
    }
    
    private func refreshNow(
        prefetchNeighbors: Bool,
        shouldRefreshTrackedFlight: Bool
    ) async {
        guard isSelectedAirportUnlocked else { return }
        guard !isRefreshInFlight else { return }
        
        isRefreshInFlight = true
        defer { isRefreshInFlight = false }
        
        await store.refresh(
            prefetchNeighbors: prefetchNeighbors,
            shouldRefreshTrackedFlight: shouldRefreshTrackedFlight
        )
        
        lastRefreshDate = Date()
        
        let latestRows = store.displayRowsForSelectedAirport()
        
        print("   selectedAirport:", store.selectedAirport.rawValue)
        print("   tracked routeID:", store.trackedFlight?.securityRouteID ?? "nil")
        print("   latestRows:", latestRows.map { "\($0.id) | \($0.title) | \($0.subtitle)" })
        
        if let preferredTrackedFlightRowID,
           let matchedPreferred = latestRows.first(where: { rowMatchesID($0, preferredTrackedFlightRowID) }) {
            selectedRowID = matchedPreferred.id
            return
        }
        
        if let selectedRowID,
           let matchedSelected = latestRows.first(where: { rowMatchesID($0, selectedRowID) }) {
            self.selectedRowID = matchedSelected.id
        } else {
            self.selectedRowID = latestRows.first?.id
        }
    }
    
    private func syncSelectedRowWithTrackedFlight() {
        if let preferredTrackedFlightRowID {
            selectedRowID = preferredTrackedFlightRowID
            return
        }
        
        guard let trackedFlight = store.trackedFlight else { return }
        
        let terminalText = trackedFlight.terminal
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !terminalText.isEmpty else { return }
        
        if let matchedTerminalRow = displayRows.first(where: { row in
            row.title.localizedCaseInsensitiveContains("Terminal \(terminalText)") ||
            row.subtitle.localizedCaseInsensitiveContains("Terminal \(terminalText)")
        }) {
            selectedRowID = matchedTerminalRow.id
        }
    }
    
    private func normalizedRowID(_ value: String?) -> String? {
        guard let value else { return nil }
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let parts = trimmed
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        if parts.count <= 1 {
            return parts.first
        }
        
        return parts.joined(separator: "|")
    }
    
    private func rowMatchesID(_ row: AirportDisplayRow, _ id: String?) -> Bool {
        normalizedRowID(row.id) == normalizedRowID(id)
    }
}
// MARK: - Top Pill

private extension LandingView {

    var airportSelectorPill: some View {
        Button {
            selectedTab = .explore
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))

                Text("Select Airport")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Header

private extension LandingView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text(displayAirportCode)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.white)

                if !isSelectedAirportUnlocked {
                    premiumPill
                }
            }

            Text(store.selectedAirport.displayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    var premiumPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))

            Text("PRO")
                .font(.system(size: 11, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "9B6CFF").opacity(0.92))
        )
    }
}

// MARK: - Locked Airport View

private extension LandingView {

    var lockedAirportView: some View {
        VStack(alignment: .leading, spacing: 16) {
            lockedHeroCard
            lockedFeatureCard
            unlockButton
        }
    }

    var lockedHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Flow Pro required")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)

                    Text("LOCKED")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
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

            Text("Unlock live airport intelligence for \(store.selectedAirport.rawValue), plus full airport access, flight tracking, and smarter alerts.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                Text(store.selectedAirport.rawValue)
                    .font(.system(size: 84, weight: .heavy))
                    .foregroundColor(.white.opacity(0.06))

                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "DAB8FF"))

                    Text("Upgrade to view this airport")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("Premium airport access is included with Flow Pro.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .frame(height: 180)
        }
        .flowGlassCard()
    }

    var lockedFeatureCard: some View {
        VStack(spacing: 14) {
            lockedFeatureRow(
                icon: "globe",
                title: "Full airport access",
                subtitle: "Unlock all premium airports across Flow."
            )

            lockedFeatureRow(
                icon: "airplane.departure",
                title: "Flight tracking",
                subtitle: "Track flights and keep leave times in sync."
            )

            lockedFeatureRow(
                icon: "bell.badge.fill",
                title: "Smarter alerts",
                subtitle: "Get premium reminders and travel updates."
            )
        }
        .flowGlassCard()
    }

    func lockedFeatureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "9B6CFF").opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "CBA8FF"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    var unlockButton: some View {
        Button {
            NotificationCenter.default.post(
                name: .showProPaywall,
                object: PaywallView.PaywallSource.lockedAirport(code: store.selectedAirport.rawValue)
            )
        } label: {
            HStack {
                Spacer()

                Text("Unlock \(store.selectedAirport.rawValue)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }
            .frame(height: 56)
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
}

// MARK: - Weather + Time

private extension LandingView {

    var displayAirportCodeForHeader: String {
        if let flight = store.trackedFlight {
            return flight.route
                .components(separatedBy: "→")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() ?? store.selectedAirport.rawValue
        }

        return store.selectedAirport.rawValue
    }

    func timeZoneForDisplayAirport() -> TimeZone {
        if let flowAirport = AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue.caseInsensitiveCompare(displayAirportCodeForHeader) == .orderedSame }) {
            return flowAirport.timeZone
        }

        if displayAirportCodeForHeader == "PER" {
            return TimeZone(identifier: "Australia/Perth") ?? store.selectedAirport.timeZone
        }

        return store.selectedAirport.timeZone
    }

    var weatherRow: some View {
        HStack(spacing: 12) {
            weatherSection
                .frame(maxWidth: .infinity)
                .frame(height: 110)

            timeSection
                .frame(maxWidth: .infinity)
                .frame(height: 110)
        }
    }

    var weatherSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weather")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: weatherSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                Text(weatherTemperatureLine)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }

            Text(weatherConditionLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .flowGlassCard()
    }

    var timeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                timeClock
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .monospacedDigit()
            }

            Text(timeZoneAbbreviation)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.82))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .flowGlassCard()
    }

    var timeClock: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            Text(timeString(for: context.date))
        }
    }

    func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZoneForDisplayAirport()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var timeZoneAbbreviation: String {
        timeZoneForDisplayAirport().abbreviation() ?? ""
    }

    var weatherTemperatureLine: String {
        if displayAirportCodeForHeader != store.selectedAirport.rawValue {
            return "—"
        }

        guard let weather = store.weather else { return "—" }

        if useCelsius {
            return "\(weather.temperatureC)°C"
        } else {
            let fahrenheit = Int(round((Double(weather.temperatureC) * 9.0 / 5.0) + 32.0))
            return "\(fahrenheit)°F"
        }
    }

    var weatherConditionLine: String {
        if displayAirportCodeForHeader != store.selectedAirport.rawValue {
            return "Live weather unavailable"
        }

        guard let weather = store.weather else { return "--" }

        let cond = weather.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return cond.isEmpty ? "Clear" : cond
    }

    var weatherSymbolName: String {
        if displayAirportCodeForHeader != store.selectedAirport.rawValue {
            return "cloud.sun.fill"
        }

        let s = (store.weather?.summary ?? "").lowercased()

        if s.contains("thunder") || s.contains("storm") { return "cloud.bolt.rain.fill" }
        if s.contains("snow") || s.contains("sleet") || s.contains("ice") || s.contains("hail") {
            return "cloud.snow.fill"
        }
        if s.contains("rain") || s.contains("shower") || s.contains("drizzle") {
            return "cloud.rain.fill"
        }
        if s.contains("fog") || s.contains("mist") || s.contains("haze") {
            return "cloud.fog.fill"
        }
        if s.contains("overcast") || s.contains("broken clouds") {
            return "smoke.fill"
        }
        if s.contains("scattered") || s.contains("few clouds") || s.contains("cloud") {
            return "cloud.sun.fill"
        }
        if s.contains("clear") || s.contains("sunny") {
            return "sun.max.fill"
        }

        return "cloud.sun.fill"
    }
}
// MARK: - Security Hero

private extension LandingView {

    var securityHero: some View {
        Group {
            if !hasTrackedFlight || trackedFlightUsesFlowAirport {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(hasTrackedFlight ? "Your Security Checkpoint" : "Security wait")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        refreshButton
                        statusBadge
                    }

                    heroCard

                    if hasTrackedFlight, let row = selectedRow, !isLoadingCurrentAirport {
                        trackedCheckpointSummary(for: row)
                    }

                    updatedRelativeTextView
                }
                .flowGlassCard()
            }
        }
    }

    var updatedRelativeTextView: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            Text(updatedRelativeText(for: context.date))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    var refreshButton: some View {
        Button {
            Task {
                await refreshNow(
                    prefetchNeighbors: true,
                    shouldRefreshTrackedFlight: store.trackedFlight != nil
                )
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var statusBadge: some View {
        switch confidenceLevel {
        case .live:
            confidenceBadge(
                text: "LIVE",
                textColor: .green,
                dot: AnyView(LivePulseDot())
            )

        case .highConfidence:
            confidenceBadge(
                text: "HIGH CONFIDENCE",
                textColor: Color(hex: "9B6CFF"),
                dot: AnyView(ConfidencePurpleDot())
            )

        case .lowConfidence:
            confidenceBadge(
                text: "ESTIMATED",
                textColor: .orange,
                dot: AnyView(OrangePulseDot())
            )

        case .comingSoon:
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

    func confidenceBadge(text: String, textColor: Color, dot: AnyView) -> some View {
        HStack(spacing: 6) {
            dot

            Text(text)
                .font(.system(size: 12, weight: .bold))
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

    var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            Text(store.selectedAirport.rawValue)
                .font(.system(size: 84, weight: .heavy))
                .foregroundColor(.white.opacity(0.06))

            heroContent
        }
        .frame(height: 140)
    }

    @ViewBuilder
    var heroContent: some View {
        if isLoadingCurrentAirport {
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.white)

                Text("Loading live airport data")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Please wait a moment")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        } else if let row = selectedRow {
            if row.metrics.count > 1 {
                VStack {
                    HStack(spacing: 34) {
                        ForEach(row.metrics) { metric in
                            heroMetric(value: metric.minutes, label: metric.label)
                        }
                    }

                    Spacer()

                    Text(row.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 14)
                }
                .padding(.top, 18)
            } else {
                let metric = row.metrics.first

                VStack(spacing: 4) {
                    if row.isClosed {
                        Text("Closed")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundColor(.red)
                    } else if let minutes = metric?.minutes, minutes == 0 {
                        HStack(spacing: 10) {
                            LivePulseDot()

                            Text("No wait")
                                .font(.system(size: 40, weight: .heavy))
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(metric?.minutes == nil ? "--" : "\(metric!.minutes!)")
                                .font(.system(size: 60, weight: .heavy))
                                .foregroundColor(.white)
                                .monospacedDigit()

                            if metric?.minutes != nil {
                                Text("minutes")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.70))
                                    .padding(.bottom, 8)
                            }
                        }
                    }

                    if usesAverageWaitPresentation {
                        Text("Average wait time")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "9B6CFF").opacity(0.95))
                            .padding(.bottom, 2)
                    }

                    Text(row.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(row.isClosed ? "Closed" : row.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))

                Text("Airport data unavailable")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Refresh and try again shortly")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
    }

    @ViewBuilder
    func heroMetric(value: Int?, label: String) -> some View {
        VStack(spacing: 6) {
            if let value, value == 0 {
                HStack(spacing: 6) {
                    LivePulseDot()

                    Text("No wait")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(value == nil ? "--" : "\(value!)")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    if value != nil {
                        Text("min")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
            }

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    func trackedCheckpointSummary(for row: AirportDisplayRow) -> some View {
        HStack(spacing: 12) {
            summaryChip(title: "Checkpoint", value: row.title)

            if !row.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summaryChip(title: "Area", value: row.subtitle)
            }
        }
    }

    func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.58))

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var feedTimestamp: Date {
        let selectedAirportRows = store
            .allWaitTimes()
            .filter { $0.airport == store.selectedAirport }

        return selectedAirportRows
            .map(\.observedAt)
            .max() ?? Date()
    }

    private func updatedRelativeText(for now: Date) -> String {
        if isLoadingCurrentAirport {
            return "Fetching latest airport feed"
        }

        if isRefreshInFlight {
            return "Refreshing latest airport feed"
        }

        let referenceDate = lastRefreshDate ?? feedTimestamp
        let elapsed = max(0, Int(now.timeIntervalSince(referenceDate)))
        let elapsedText = relativeAgeString(for: elapsed)

        switch confidenceLevel {
        case .live:
            return "Live feed · Updated \(elapsedText) ago"
        case .highConfidence:
            return "High confidence feed · Checked \(elapsedText) ago"
        case .lowConfidence:
            return "Estimated feed · Refreshed \(elapsedText) ago"
        case .comingSoon:
            return "Coming soon"
        }
    }

    func relativeAgeString(for seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }

        let days = hours / 24
        return "\(days)d"
    }
}

// MARK: - Checkpoints

private extension LandingView {

    var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasTrackedFlight {
                if !secondaryCheckpointRows.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.90)) {
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
                                    ? "Tap to hide other terminals"
                                    : "Tap to view all terminals"
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
                            ForEach(secondaryCheckpointRows) { row in
                                checkpointCard(
                                    row: row,
                                    isSelected: rowMatchesID(row, selectedRowID)
                                )
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(displayRows) { row in
                        checkpointCard(
                            row: row,
                            isSelected: rowMatchesID(row, selectedRowID)
                        )
                    }
                }
            }
        }
    }

    func checkpointCard(
        row: AirportDisplayRow,
        isSelected: Bool
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                selectedRowID = row.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)

                        Text(row.isClosed ? "Closed" : row.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? Color(hex: "9B6CFF") : .white.opacity(0.28))
                }

                checkpointMetricsRow(for: row)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                isSelected
                                    ? Color(hex: "9B6CFF").opacity(0.95)
                                    : Color.white.opacity(0.10),
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func checkpointMetricsRow(for row: AirportDisplayRow) -> some View {
        if row.metrics.count > 1 {
            HStack(spacing: 12) {
                ForEach(row.metrics) { metric in
                    miniMetricCard(
                        label: metric.label,
                        value: row.isClosed ? nil : metric.minutes,
                        isClosed: row.isClosed
                    )
                }
            }
        } else {
            let metric = row.metrics.first

            HStack(spacing: 12) {
                miniMetricCard(
                    label: metric?.label ?? "Wait",
                    value: row.isClosed ? nil : metric?.minutes,
                    isClosed: row.isClosed
                )
            }
        }
    }

    func miniMetricCard(label: String, value: Int?, isClosed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isClosed {
                Text("Closed")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
            } else if let value, value == 0 {
                Text("No wait")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
            } else {
                Text(value == nil ? "--" : "\(value!) min")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

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
}

// MARK: - Error

private extension LandingView {

    @ViewBuilder
    var errorSection: some View {
        if let error = store.errorText, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 6)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Flow Brand

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

private enum FlowConfidenceLevel {
    case live
    case highConfidence
    case lowConfidence
    case comingSoon
}

// MARK: - Purple Confidence Dot

private struct ConfidencePurpleDot: View {
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

// MARK: - Orange Pulse Dot

private struct OrangePulseDot: View {
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

// MARK: - Glass Card

extension View {
    func flowGlassCard() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

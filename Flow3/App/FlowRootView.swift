import SwiftUI
import UIKit

struct FlowRootView: View {

    enum FlowTab: Hashable {
        case explore
        case planner
        case flight
        case alerts
        case settings
    }

    @ObservedObject var store: LandingStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @AppStorage("flow_default_airport")
    private var defaultAirportRawValue: String = FlowAirport.atl.rawValue

    @AppStorage("flow_calendar_flight_detection")
    private var calendarFlightDetectionEnabled: Bool = true

    @State private var selectedTab: FlowTab = .flight
    @State private var hasAppliedStartupAirport = false

    @State private var isShowingPaywall = false
    @State private var paywallSource: PaywallView.PaywallSource = .general

    init(store: LandingStore) {
        self.store = store

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 20 / 255,
            green: 6 / 255,
            blue: 47 / 255,
            alpha: 0.96
        )

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.65)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.65)
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(
            red: 155 / 255,
            green: 108 / 255,
            blue: 255 / 255,
            alpha: 1.0
        )

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(
                red: 155 / 255,
                green: 108 / 255,
                blue: 255 / 255,
                alpha: 1.0
            )
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            NavigationStack {
                AirportSelectorView(
                    store: store,
                    onAirportSelected: {
                        selectedTab = .flight
                    }
                )
            }
            .tabItem {
                Image(systemName: "location.fill")
                Text("Airports")
            }
            .tag(FlowTab.explore)

            NavigationStack {
                PlannerView(
                    store: store,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Plan")
            }
            .tag(FlowTab.planner)

            NavigationStack {
                LandingView(
                    store: store,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Image(systemName: "airplane")
                Text("Flight")
            }
            .tag(FlowTab.flight)

            NavigationStack {
                AlertsView(
                    store: store,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Alerts")
            }
            .tag(FlowTab.alerts)

            NavigationStack {
                SettingsView()
                    .environmentObject(store)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(FlowTab.settings)
        }
        .tint(Color(hex: "9B6CFF"))
        .fullScreenCover(isPresented: $isShowingPaywall) {
            PaywallView(
                source: paywallSource,
                isPresented: $isShowingPaywall
            )
            .environmentObject(subscriptionManager)
        }
        .task {
            guard !hasAppliedStartupAirport else { return }
            hasAppliedStartupAirport = true
            applyDefaultAirportFromSettings()
            await runCalendarFlightScanIfNeeded(force: false)
        }
        .onChange(of: defaultAirportRawValue) { _, _ in
            applyDefaultAirportFromSettings()
        }
        .onChange(of: subscriptionManager.tier) { _, _ in
            applyDefaultAirportFromSettings()
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .flight else { return }

            Task {
                await runCalendarFlightScanIfNeeded(force: false)
            }
        }
        .onChange(of: store.trackedFlight?.id) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                Task {
                    await runCalendarFlightScanIfNeeded(force: true)
                }
            }
        }
        .onChange(of: calendarFlightDetectionEnabled) { _, isEnabled in
            if isEnabled {
                Task {
                    await runCalendarFlightScanIfNeeded(force: true)
                }
            } else {
                store.dismissPendingCalendarFlight()
                store.reviewCalendarFlight = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSearchTab)) { _ in
            selectedTab = .planner
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAirportTab)) { _ in
            selectedTab = .explore
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFlightTab)) { _ in
            selectedTab = .flight
        }
        .onReceive(NotificationCenter.default.publisher(for: .showProPaywall)) { notification in
            if let source = notification.object as? PaywallView.PaywallSource {
                presentPaywall(source: source)
            } else {
                presentPaywall(source: .general)
            }
        }
    }

    private func runCalendarFlightScanIfNeeded(force: Bool) async {
        guard calendarFlightDetectionEnabled else {
            print("📆 Calendar scan skipped: toggle off")
            return
        }

        print("📆 Calendar scan requested")
        await store.scanCalendarForFlightsIfNeeded(force: force)
    }

    private func applyDefaultAirportFromSettings() {
        let trackedAirport = trackedFlightDepartureAirport()

        let requestedAirport = AirportRegistry.airports
            .map(\.airport)
            .first(where: { $0.rawValue == defaultAirportRawValue })

        let airportToApply: FlowAirport

        if let trackedAirport {
            airportToApply = trackedAirport
        } else if let requestedAirport,
                  FlowEntitlements.canAccessAirport(
                    airportCode: requestedAirport.rawValue,
                    subscriptionTier: subscriptionManager.tier
                  ) {
            airportToApply = requestedAirport
        } else {
            airportToApply = fallbackAirport()
        }

        if store.selectedAirport != airportToApply {
            store.selectedAirport = airportToApply
        }
    }

    private func trackedFlightDepartureAirport() -> FlowAirport? {
        guard let trackedFlight = store.trackedFlight else { return nil }

        let route = trackedFlight.route.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !route.isEmpty else { return nil }

        let parts = route.components(separatedBy: "→")
        guard let originPart = parts.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !originPart.isEmpty else {
            return nil
        }

        return AirportRegistry.airports
            .map(\.airport)
            .first {
                $0.rawValue.caseInsensitiveCompare(originPart) == .orderedSame
            }
    }

    private func fallbackAirport() -> FlowAirport {
        if let matched = AirportRegistry.airports
            .map(\.airport)
            .first(where: {
                $0.rawValue.caseInsensitiveCompare(FreeAirportConfig.fallbackFreeAirportCode) == .orderedSame
            }) {
            return matched
        }

        if let firstFreeAirport = AirportRegistry.airports
            .map(\.airport)
            .first(where: {
                FreeAirportConfig.isFreeAirport(code: $0.rawValue)
            }) {
            return firstFreeAirport
        }

        return .lax
    }

    private func presentPaywall(source: PaywallView.PaywallSource) {
        paywallSource = source
        isShowingPaywall = true
    }
}

extension Notification.Name {
    static let showProPaywall = Notification.Name("showProPaywall")
}

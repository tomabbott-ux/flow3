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
    @State private var selectedTab: FlowTab = .flight

    init(store: LandingStore) {
        self.store = store

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 20/255,
            green: 6/255,
            blue: 47/255,
            alpha: 0.96
        )

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.65)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.65)
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(
            red: 155/255,
            green: 108/255,
            blue: 255/255,
            alpha: 1.0
        )

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(
                red: 155/255,
                green: 108/255,
                blue: 255/255,
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
                PlannerPlaceholderView(
                    store: store,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
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
                AlertsView(store: store)
            }
            .tabItem {
                Image(systemName: "bell.fill")
                Text("Alerts")
            }
            .tag(FlowTab.alerts)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(FlowTab.settings)
        }
        .tint(Color(hex: "9B6CFF"))
        .onReceive(NotificationCenter.default.publisher(for: .openSearchTab)) { _ in
            selectedTab = .planner
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAirportTab)) { _ in
            selectedTab = .explore
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFlightTab)) { _ in
            selectedTab = .flight
        }
    }
}

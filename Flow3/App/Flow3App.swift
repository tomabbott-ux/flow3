import SwiftUI

@main
struct Flow3App: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @StateObject private var store = LandingStore(
        waitTimeService: WaitTimeService(provider: AirportWaitTimeRouter(trackedFlight: nil)),
        weatherService: WeatherService(provider: AviationWeatherMETARProvider())
    )
    
    var body: some Scene {
        WindowGroup {
            FlowRootView(store: store)
                .environmentObject(subscriptionManager)
                .task {
                    print("🚀 App launched — initializing subscriptions")
                    await subscriptionManager.initialize()
                    
                    FlowReviewPrompter.shared.recordAppOpen()
                    
                    print("⚡️ Preloading initial airport data")
                    
                    // ✅ ALWAYS load selected airport first
                    await store.refresh(
                        prefetchNeighbors: true,
                        shouldRefreshTrackedFlight: false
                    )
                    
                    // 🔥 NEW: Force load tracked airport if different
                    if let flight = store.trackedFlight,
                       let trackedAirport = store.trackedDepartureAirport(from: flight.route),
                       trackedAirport != store.selectedAirport {
                        
                        print("✈️ Preloading tracked airport: \(trackedAirport.rawValue)")
                        
                        await store.refreshAirport(trackedAirport, updateVisibleState: false)
                    }
                }
        }
    }
}


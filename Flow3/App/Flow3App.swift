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
                    
                    // ✅ Track app opens for review logic
                    FlowReviewPrompter.shared.recordAppOpen()
                    
                    print("⚡️ Preloading initial airport data")
                    await store.refresh(
                        prefetchNeighbors: true,
                        shouldRefreshTrackedFlight: false
                    )
                }
        }
    }
}

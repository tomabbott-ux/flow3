import SwiftUI

@main
struct Flow3App: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var store = LandingStore(
        waitTimeService: WaitTimeService(
            provider: AirportWaitTimeRouter(trackedFlight: nil)
        ),
        weatherService: WeatherService(
            provider: AviationWeatherMETARProvider()
        )
    )

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            FlowRootView(store: store)
                .environmentObject(subscriptionManager)
                .task {
                    await subscriptionManager.initialize()
                }
        }
    }
}

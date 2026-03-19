import SwiftUI

@main
struct Flow3App: App {

    // ✅ AppDelegate hook (ONLY ONE)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // ✅ Core store
    @StateObject private var store = LandingStore(
        waitTimeService: WaitTimeService(provider: AirportWaitTimeRouter()),        weatherService: WeatherService(provider: AviationWeatherMETARProvider())
    )

    var body: some Scene {
        WindowGroup {
            FlowRootView(store: store)
        }
    }
}

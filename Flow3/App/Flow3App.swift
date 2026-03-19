import SwiftUI

@main
struct Flow3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var store = LandingStore(
        waitTimeService: WaitTimeService(provider: AirportWaitTimeRouter()),
        weatherService: WeatherService(provider: AviationWeatherMETARProvider())
    )

    var body: some Scene {
        WindowGroup {
            FlowRootView(store: store)
        }
    }
}

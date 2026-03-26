import SwiftUI

@main
struct Flow3App: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var store: LandingStore = {
        let store = LandingStore(
            waitTimeService: WaitTimeService(
                provider: AirportWaitTimeRouter(trackedFlight: nil)
            ),
            weatherService: WeatherService(
                provider: AviationWeatherMETARProvider()
            )
        )
        return store
    }()

    var body: some Scene {
        WindowGroup {
            FlowRootView(store: store)
                .onAppear {
                    let savedAirportRaw = UserDefaults.standard.string(forKey: "flow.defaultAirportCode")
                        ?? FlowAirport.lhr.rawValue

                    if let savedAirport = FlowAirport(rawValue: savedAirportRaw) {
                        store.selectedAirport = savedAirport
                    }
                }
        }
    }
}

import SwiftUI

@main
struct Flow3App: App {

    var body: some Scene {
        WindowGroup {

            // Airport provider router
            let router = AirportWaitTimeRouter()

            // Services
            let waitService = WaitTimeService(provider: router)
            let weatherService = WeatherService(provider: StubWeatherProvider())

            // App store
            let store = LandingStore(
                waitTimeService: waitService,
                weatherService: weatherService
            )

            // Root view
            ContentView(store: store)
        }
    }
}

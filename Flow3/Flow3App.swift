import SwiftUI

@main
struct Flow3App: App {

    var body: some Scene {
        WindowGroup {
            let router = AirportWaitTimeRouter()

            let waitService = WaitTimeService(provider: router)
            let weatherService = WeatherService(provider: StubWeatherProvider())

            let store = LandingStore(
                waitTimeService: waitService,
                weatherService: weatherService
            )

            ContentView(store: store)
        }
    }
}

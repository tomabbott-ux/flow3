import SwiftUI

@main
struct Flow3App: App {

    var body: some Scene {
        WindowGroup {

            let composite = CompositeWaitTimeProvider(providers: [
                ATLStubWaitTimeProvider(),
                LHRStubWaitTimeProvider(),
                JFKAzureAPIWaitTimeProvider()   // ✅ IMPORTANT
            ])

            let waitService = WaitTimeService(provider: composite)
            let weatherService = WeatherService(provider: StubWeatherProvider())

            let store = LandingStore(
                waitTimeService: waitService,
                weatherService: weatherService
            )

            ContentView(store: store)
        }
    }
}

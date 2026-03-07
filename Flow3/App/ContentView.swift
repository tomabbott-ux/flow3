import SwiftUI

struct ContentView: View {

    @StateObject private var store = LandingStore(
        waitTimeService: WaitTimeService(
            provider: AirportWaitTimeRouter()
        ),
        weatherService: WeatherService(
            provider: StubWeatherProvider()
        )
    )

    @State private var hasSelectedAirport = false

    var body: some View {
        NavigationStack {
            if hasSelectedAirport {
                LandingView(store: store)
            } else {
                AirportSelectorView(
                    store: store,
                    onAirportSelected: {
                        hasSelectedAirport = true
                    }
                )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

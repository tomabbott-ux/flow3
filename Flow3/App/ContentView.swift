import SwiftUI

struct ContentView: View {

    @AppStorage("flow_default_airport") private var defaultAirportRawValue: String = FlowAirport.atl.rawValue

    @StateObject private var store =
    LandingStore(
        waitTimeService: WaitTimeService(
            provider: AirportWaitTimeRouter()
        ),
        weatherService: WeatherService(
            provider: AviationWeatherMETARProvider()
        )
    )

    var body: some View {
        FlowRootView(store: store)
            .onAppear {
                applyDefaultAirportIfNeeded()
            }
    }

    private func applyDefaultAirportIfNeeded() {
        if let airport = FlowAirport(rawValue: defaultAirportRawValue) {
            store.selectedAirport = airport
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

import SwiftUI

struct ContentView: View {

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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

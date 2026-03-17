import SwiftUI

struct WelcomeView: View {
    @ObservedObject var store: LandingStore

    var body: some View {
        AirportSelectorView(
            store: store,
            onAirportSelected: {}
        )
        
    }
}

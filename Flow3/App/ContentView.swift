import SwiftUI

struct ContentView: View {
    @StateObject private var store: LandingStore

    init(store: LandingStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            AirportSelectorView(store: store)
        }
    }
}

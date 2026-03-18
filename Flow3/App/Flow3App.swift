import SwiftUI

@main
struct Flow3App: App {
    init() {
        FlowWatchConnectivityManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

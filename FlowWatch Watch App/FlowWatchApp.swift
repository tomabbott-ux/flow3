import SwiftUI

@main
struct FlowWatchApp: App {
    init() {
        print("⌚️ FlowWatchApp init")
        WatchSessionManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .onAppear {
                    print("⌚️ WatchRootView appeared")
                }
        }
    }
}

import SwiftUI

@main
struct Flow3App: App {

    init() {
        UserDefaults.standard.register(defaults: [
            "flow_notify_30": true,
            "flow_notify_15": true,
            "flow_notify_leave_now": true,
            "flow_notify_gate": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

import Foundation

final class FlowWatchConnectivityManager {

    static let shared = FlowWatchConnectivityManager()

    private init() {}

    func syncTrackedFlight(_ flight: TrackedFlight?) {
        // No-op for TestFlight build (watch removed)
    }

    func clearTrackedFlight() {
        // No-op for TestFlight build (watch removed)
    }
}

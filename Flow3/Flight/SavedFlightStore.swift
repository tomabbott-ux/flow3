import Foundation

final class SavedFlightStore {

    static let shared = SavedFlightStore()

    private let key = "flow_tracked_flight"

    private init() {}

    func save(_ flight: TrackedFlight) {
        if let data = try? JSONEncoder().encode(flight) {
            UserDefaults.standard.set(data, forKey: key)
            FlowWatchConnectivityManager.shared.syncTrackedFlight(flight)
        }
    }

    func load() -> TrackedFlight? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            FlowWatchConnectivityManager.shared.syncTrackedFlight(nil)
            return nil
        }

        let flight = try? JSONDecoder().decode(TrackedFlight.self, from: data)
        FlowWatchConnectivityManager.shared.syncTrackedFlight(flight)
        return flight
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        FlowWatchConnectivityManager.shared.syncTrackedFlight(nil)
    }
}

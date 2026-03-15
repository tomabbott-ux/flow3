import Foundation

final class SavedFlightStore {

    static let shared = SavedFlightStore()

    private let key = "flow_tracked_flight"

    func save(_ flight: TrackedFlight) {

        if let data = try? JSONEncoder().encode(flight) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> TrackedFlight? {

        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        return try? JSONDecoder().decode(TrackedFlight.self, from: data)
    }

    func clear() {

        UserDefaults.standard.removeObject(forKey: key)
    }
}

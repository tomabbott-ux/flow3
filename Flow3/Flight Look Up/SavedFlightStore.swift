import Foundation

final class SavedFlightStore {

    static let shared = SavedFlightStore()

    private let defaults = UserDefaults.standard
    private let lhrTrackedFlightKey = "flow.savedFlight.lhr"

    private init() {}

    func loadLHRTrackedFlight() -> SavedFlightPlan? {
        guard let data = defaults.data(forKey: lhrTrackedFlightKey) else {
            return nil
        }

        return try? JSONDecoder().decode(SavedFlightPlan.self, from: data)
    }

    func saveLHRTrackedFlight(_ flight: SavedFlightPlan) {
        guard let data = try? JSONEncoder().encode(flight) else { return }
        defaults.set(data, forKey: lhrTrackedFlightKey)
    }

    func clearLHRTrackedFlight() {
        defaults.removeObject(forKey: lhrTrackedFlightKey)
    }
}

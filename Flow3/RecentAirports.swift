import Foundation

final class RecentAirports {

    static let shared = RecentAirports()

    private let storageKey = "flow.recent.airports"
    private let maxRecents = 3

    private init() {}

    func load() -> [FlowAirport] {
        guard let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] else {
            return []
        }

        return saved.compactMap { FlowAirport(rawValue: $0) }
    }

    func add(_ airport: FlowAirport) {

        var recents = load()

        recents.removeAll { $0 == airport }

        recents.insert(airport, at: 0)

        if recents.count > maxRecents {
            recents.removeLast()
        }

        let codes = recents.map { $0.rawValue }

        UserDefaults.standard.set(codes, forKey: storageKey)
    }

}

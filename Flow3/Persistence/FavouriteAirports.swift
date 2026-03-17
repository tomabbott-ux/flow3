import Foundation

final class FavouriteAirports {

    static let shared = FavouriteAirports()

    private let storageKey = "flow.favourite.airports"

    private init() {}

    func load() -> Set<FlowAirport> {
        guard let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] else {
            return []
        }

        let airports = saved.compactMap { FlowAirport(rawValue: $0) }

        return Set(airports)
    }

    func save(_ favourites: Set<FlowAirport>) {

        let codes = favourites.map { $0.rawValue }

        UserDefaults.standard.set(codes, forKey: storageKey)
    }

}

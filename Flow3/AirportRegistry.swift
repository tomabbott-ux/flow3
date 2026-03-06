import Foundation

struct AirportRegistryItem: Identifiable, Hashable {
    let airport: FlowAirport
    let isEnabled: Bool
    let isLive: Bool

    var id: String { airport.id }
}

enum AirportRegistry {

    static let all: [AirportRegistryItem] = [
        AirportRegistryItem(airport: .atl, isEnabled: true, isLive: true),
        AirportRegistryItem(airport: .jfk, isEnabled: true, isLive: true),
        AirportRegistryItem(airport: .lhr, isEnabled: true, isLive: true),

        // Enabled in app, but not yet wired to live wait-time providers
        AirportRegistryItem(airport: .ams, isEnabled: true, isLive: true),
        AirportRegistryItem(airport: .cdg, isEnabled: true, isLive: false),
        AirportRegistryItem(airport: .dxb, isEnabled: true, isLive: false),
        AirportRegistryItem(airport: .sin, isEnabled: true, isLive: false),
        AirportRegistryItem(airport: .fra, isEnabled: true, isLive: false),
        AirportRegistryItem(airport: .mad, isEnabled: true, isLive: false)
    ]

    static var enabled: [AirportRegistryItem] {
        all.filter { $0.isEnabled }
    }

    static var live: [AirportRegistryItem] {
        enabled.filter { $0.isLive }
    }

    static func item(for airport: FlowAirport) -> AirportRegistryItem? {
        all.first(where: { $0.airport == airport })
    }
}

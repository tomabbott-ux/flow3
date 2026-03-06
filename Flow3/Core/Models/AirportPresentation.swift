import Foundation

enum AirportLiveStatus: String, Codable, Hashable {
    case live
    case comingSoon
}

struct AirportPresentation: Hashable {
    let airport: FlowAirport
    let liveStatus: AirportLiveStatus
    let badgeText: String
    let titleText: String
    let subtitleText: String
    let placeholderTitle: String
    let placeholderBody: String
    let placeholderFootnote: String

    var isLive: Bool {
        liveStatus == .live
    }

    static func make(for airport: FlowAirport) -> AirportPresentation {
        let isLive = AirportRegistry.definition(for: airport)?.isLive ?? false

        return AirportPresentation(
            airport: airport,
            liveStatus: isLive ? .live : .comingSoon,
            badgeText: isLive ? "LIVE" : "COMING SOON",
            titleText: airport.rawValue,
            subtitleText: airport.shortName,
            placeholderTitle: "Live data coming soon",
            placeholderBody: "\(airport.displayName) is available in Flow, but its live security wait-time feed has not been connected yet.",
            placeholderFootnote: "Estimated display only for now."
        )
    }
}

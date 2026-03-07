import Foundation

enum AirportFeedType: String, Codable, Hashable {
    case live
    case estimated
    case comingSoon
}

struct AirportDefinition: Identifiable, Hashable {

    let airport: FlowAirport
    let feedType: AirportFeedType

    var id: FlowAirport { airport }

    var isLive: Bool {
        feedType == .live
    }

    var isEstimated: Bool {
        feedType == .estimated
    }

    var isComingSoon: Bool {
        feedType == .comingSoon
    }
}

struct AirportRegistry {

    static let airports: [AirportDefinition] = [

        AirportDefinition(airport: .atl, feedType: .live),
        AirportDefinition(airport: .jfk, feedType: .live),
        AirportDefinition(airport: .lhr, feedType: .live),
        AirportDefinition(airport: .ist, feedType: .live),
        
        AirportDefinition(airport: .yyz, feedType: .live),
        AirportDefinition(airport: .yvr, feedType: .live),
        AirportDefinition(airport: .yyc, feedType: .live),

        AirportDefinition(airport: .den, feedType: .live),
        AirportDefinition(airport: .dfw, feedType: .live),
        AirportDefinition(airport: .hou, feedType: .live),
        AirportDefinition(airport: .mco, feedType: .live),
        AirportDefinition(airport: .phx, feedType: .live),
        AirportDefinition(airport: .phl, feedType: .live),

        AirportDefinition(airport: .ams, feedType: .live),

        AirportDefinition(airport: .cdg, feedType: .estimated),
        AirportDefinition(airport: .dxb, feedType: .estimated),
        AirportDefinition(airport: .sin, feedType: .estimated),
        AirportDefinition(airport: .fra, feedType: .estimated),
        AirportDefinition(airport: .mad, feedType: .estimated),

        AirportDefinition(airport: .sfo, feedType: .estimated),
        AirportDefinition(airport: .lax, feedType: .estimated),
        AirportDefinition(airport: .ord, feedType: .estimated),
        AirportDefinition(airport: .las, feedType: .estimated),
        AirportDefinition(airport: .bos, feedType: .estimated),
        AirportDefinition(airport: .sea, feedType: .estimated),
        AirportDefinition(airport: .san, feedType: .estimated),
        AirportDefinition(airport: .mia, feedType: .estimated),

        AirportDefinition(airport: .bcn, feedType: .estimated),
        AirportDefinition(airport: .fco, feedType: .estimated),
        AirportDefinition(airport: .hnd, feedType: .estimated),
        AirportDefinition(airport: .icn, feedType: .estimated),
        AirportDefinition(airport: .syd, feedType: .estimated)
    ]

    static func definition(for airport: FlowAirport) -> AirportDefinition? {
        airports.first(where: { $0.airport == airport })
    }
}

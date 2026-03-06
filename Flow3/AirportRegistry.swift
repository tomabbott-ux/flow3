import Foundation

struct AirportDefinition: Identifiable, Hashable {

    let airport: FlowAirport
    let isLive: Bool

    var id: FlowAirport {
        airport
    }
}

struct AirportRegistry {

    static let airports: [AirportDefinition] = [

        AirportDefinition(airport: .atl, isLive: true),
        AirportDefinition(airport: .jfk, isLive: true),
        AirportDefinition(airport: .lhr, isLive: true),
        AirportDefinition(airport: .yyz, isLive: true),
        AirportDefinition(airport: .yvr, isLive: true),
        AirportDefinition(airport: .yyc, isLive: true),
        AirportDefinition(airport: .den, isLive: true),
        AirportDefinition(airport: .dfw, isLive: true),
        
        
        AirportDefinition(airport: .ams, isLive: false),
        AirportDefinition(airport: .cdg, isLive: false),
        AirportDefinition(airport: .dxb, isLive: false),
        AirportDefinition(airport: .sin, isLive: false),
        AirportDefinition(airport: .fra, isLive: false),
        AirportDefinition(airport: .mad, isLive: false),

        AirportDefinition(airport: .sfo, isLive: false),
        AirportDefinition(airport: .lax, isLive: false),
        AirportDefinition(airport: .ord, isLive: false),
        
        
        AirportDefinition(airport: .bcn, isLive: false),
        AirportDefinition(airport: .fco, isLive: false),
        AirportDefinition(airport: .hnd, isLive: false),
        AirportDefinition(airport: .icn, isLive: false),
        AirportDefinition(airport: .syd, isLive: false)
    ]

    static var all: [AirportDefinition] {
        airports
    }

    static func definition(for airport: FlowAirport) -> AirportDefinition? {
        airports.first(where: { $0.airport == airport })
    }
}

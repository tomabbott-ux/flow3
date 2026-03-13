import Foundation

enum AirportFeedType: String, Codable, Hashable {
    case live
    case highConfidence
    case estimated
    case comingSoon
}

enum AirportProviderKind: String, Codable, Hashable {
    case atl
    case jfk
    case lhr
    case ist
    case lga
    case ham
    case cph
    case dus
    case edi
    case str
    case bru
    case fco
    case fra
    case doh
    case arn
    case got
    case osl
    case zrh
    case hel
    case icn
    case aena

    case yyz
    case yvr
    case yyc

    case den
    case dfw
    case hou
    case iah
    case mco
    case phx
    case phl
    case slc
    case ord
    case ams

    case clt
    case ewr
    case bwi
    case dca
    case pdx
    case tsaWebsite
    case estimated
    case none
}

struct AirportDefinition: Identifiable, Hashable {

    let airport: FlowAirport
    let feedType: AirportFeedType
    let providerKind: AirportProviderKind

    var id: FlowAirport { airport }

    var isLive: Bool {
        feedType == .live
    }

    var isHighConfidence: Bool {
        feedType == .highConfidence
    }

    var isEstimated: Bool {
        feedType == .estimated
    }

    var isComingSoon: Bool {
        feedType == .comingSoon
    }
}

struct AirportRegistry {

    private static let baseAirports: [AirportDefinition] = [

        AirportDefinition(airport: .atl, feedType: .live, providerKind: .atl),
        AirportDefinition(airport: .jfk, feedType: .live, providerKind: .jfk),
        AirportDefinition(airport: .lhr, feedType: .live, providerKind: .lhr),
        AirportDefinition(airport: .ist, feedType: .live, providerKind: .ist),
        AirportDefinition(airport: .lga, feedType: .live, providerKind: .lga),
        AirportDefinition(airport: .ham, feedType: .live, providerKind: .ham),
        AirportDefinition(airport: .cph, feedType: .live, providerKind: .cph),
        AirportDefinition(airport: .dus, feedType: .live, providerKind: .dus),
        AirportDefinition(airport: .edi, feedType: .live, providerKind: .edi),
        AirportDefinition(airport: .str, feedType: .live, providerKind: .str),
        AirportDefinition(airport: .bru, feedType: .live, providerKind: .bru),

        AirportDefinition(airport: .yyz, feedType: .live, providerKind: .yyz),
        AirportDefinition(airport: .yvr, feedType: .live, providerKind: .yvr),
        AirportDefinition(airport: .yyc, feedType: .live, providerKind: .yyc),

        AirportDefinition(airport: .den, feedType: .live, providerKind: .den),
        AirportDefinition(airport: .dfw, feedType: .live, providerKind: .dfw),
        AirportDefinition(airport: .hou, feedType: .live, providerKind: .hou),
        AirportDefinition(airport: .iah, feedType: .live, providerKind: .iah),
        AirportDefinition(airport: .mco, feedType: .live, providerKind: .mco),
        AirportDefinition(airport: .phx, feedType: .live, providerKind: .phx),
        AirportDefinition(airport: .phl, feedType: .live, providerKind: .phl),
        AirportDefinition(airport: .slc, feedType: .live, providerKind: .slc),
        AirportDefinition(airport: .ord, feedType: .live, providerKind: .ord),
        AirportDefinition(airport: .ams, feedType: .live, providerKind: .ams),
        AirportDefinition(airport: .fco, feedType: .live, providerKind: .fco),
        AirportDefinition(airport: .fra, feedType: .live, providerKind: .fra),
        AirportDefinition(airport: .doh, feedType: .live, providerKind: .doh),
        AirportDefinition(airport: .arn, feedType: .live, providerKind: .arn),
        AirportDefinition(airport: .got, feedType: .live, providerKind: .got),
        AirportDefinition(airport: .osl, feedType: .live, providerKind: .osl),
        AirportDefinition(airport: .zrh, feedType: .live, providerKind: .zrh),
        AirportDefinition(airport: .hel, feedType: .live, providerKind: .hel),
        AirportDefinition(airport: .icn, feedType: .live, providerKind: .icn),

        // AENA live
        AirportDefinition(airport: .mad, feedType: .live, providerKind: .aena),
        AirportDefinition(airport: .bcn, feedType: .live, providerKind: .aena),
        AirportDefinition(airport: .pmi, feedType: .live, providerKind: .aena),
        AirportDefinition(airport: .agp, feedType: .live, providerKind: .aena),
        AirportDefinition(airport: .alc, feedType: .live, providerKind: .aena),
        AirportDefinition(airport: .tfs, feedType: .live, providerKind: .aena),
        AirportDefinition(airport: .lpa, feedType: .live, providerKind: .aena),

        // AENA coming soon
        AirportDefinition(airport: .svq, feedType: .comingSoon, providerKind: .none),
        AirportDefinition(airport: .bio, feedType: .comingSoon, providerKind: .none),
        AirportDefinition(airport: .ibz, feedType: .comingSoon, providerKind: .none),
        AirportDefinition(airport: .vlc, feedType: .comingSoon, providerKind: .none),

        AirportDefinition(airport: .clt, feedType: .live, providerKind: .clt),
        AirportDefinition(airport: .ewr, feedType: .live, providerKind: .ewr),
        AirportDefinition(airport: .bwi, feedType: .live, providerKind: .bwi),
        AirportDefinition(airport: .dca, feedType: .live, providerKind: .dca),
        AirportDefinition(airport: .pdx, feedType: .live, providerKind: .pdx),

        AirportDefinition(airport: .san, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .las, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .bos, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .sea, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .mia, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .sfo, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .bna, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .tpa, feedType: .highConfidence, providerKind: .tsaWebsite),
        AirportDefinition(airport: .dtw, feedType: .highConfidence, providerKind: .tsaWebsite),

        AirportDefinition(airport: .msp, feedType: .comingSoon, providerKind: .none),

        AirportDefinition(airport: .cdg, feedType: .estimated, providerKind: .estimated),
        AirportDefinition(airport: .dxb, feedType: .estimated, providerKind: .estimated),
        AirportDefinition(airport: .sin, feedType: .estimated, providerKind: .estimated),
        AirportDefinition(airport: .lax, feedType: .estimated, providerKind: .estimated),
        AirportDefinition(airport: .hnd, feedType: .estimated, providerKind: .estimated),
        AirportDefinition(airport: .syd, feedType: .estimated, providerKind: .estimated)
    ]

    static var airports: [AirportDefinition] {
        var seen: Set<FlowAirport> = []
        var unique: [AirportDefinition] = []

        for definition in baseAirports {
            if !seen.contains(definition.airport) {
                seen.insert(definition.airport)
                unique.append(definition)
            }
        }

        return unique
    }

    static func definition(for airport: FlowAirport) -> AirportDefinition? {
        airports.first(where: { $0.airport == airport })
    }
}

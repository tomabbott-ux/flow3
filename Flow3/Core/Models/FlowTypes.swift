import Foundation

enum FlowAirport: String, CaseIterable, Identifiable, Codable, Hashable {

    case atl = "ATL"
    case jfk = "JFK"
    case lhr = "LHR"
    case ist = "IST"
    case lga = "LGA"

    case phl = "PHL"
    case mco = "MCO"
    case slc = "SLC"
    case iah = "IAH"

    case yyz = "YYZ"
    case yvr = "YVR"
    case yyc = "YYC"

    case den = "DEN"
    case dfw = "DFW"
    case hou = "HOU"
    case phx = "PHX"

    case ams = "AMS"
    case cdg = "CDG"
    case dxb = "DXB"
    case sin = "SIN"
    case fra = "FRA"
    case mad = "MAD"

    case sfo = "SFO"
    case lax = "LAX"
    case ord = "ORD"
    case las = "LAS"
    case bos = "BOS"
    case sea = "SEA"
    case san = "SAN"
    case mia = "MIA"

    case bcn = "BCN"
    case fco = "FCO"
    case hnd = "HND"
    case icn = "ICN"
    case syd = "SYD"

    var id: String { rawValue }

    var displayName: String {
        switch self {

        case .atl: return "Atlanta"
        case .jfk: return "New York JFK"
        case .lhr: return "London Heathrow"
        case .ist: return "Istanbul Airport"
        case .lga: return "New York LaGuardia"

        case .phl: return "Philadelphia"
        case .mco: return "Orlando"
        case .slc: return "Salt Lake City"
        case .iah: return "Houston Intercontinental"

        case .yyz: return "Toronto Pearson"
        case .yvr: return "Vancouver"
        case .yyc: return "Calgary"

        case .den: return "Denver"
        case .dfw: return "Dallas Fort Worth"
        case .hou: return "Houston Hobby"
        case .phx: return "Phoenix Sky Harbor"

        case .ams: return "Amsterdam Schiphol"
        case .cdg: return "Paris Charles de Gaulle"
        case .dxb: return "Dubai"
        case .sin: return "Singapore"
        case .fra: return "Frankfurt"
        case .mad: return "Madrid"

        case .sfo: return "San Francisco"
        case .lax: return "Los Angeles"
        case .ord: return "Chicago O'Hare"
        case .las: return "Las Vegas"
        case .bos: return "Boston Logan"
        case .sea: return "Seattle Tacoma"
        case .san: return "San Diego"
        case .mia: return "Miami"

        case .bcn: return "Barcelona"
        case .fco: return "Rome Fiumicino"
        case .hnd: return "Tokyo Haneda"
        case .icn: return "Seoul Incheon"
        case .syd: return "Sydney"
        }
    }

    var shortName: String {
        switch self {

        case .atl: return "Atlanta (ATL)"
        case .jfk: return "New York (JFK)"
        case .lhr: return "London Heathrow (LHR)"
        case .ist: return "Istanbul (IST)"
        case .lga: return "New York LaGuardia (LGA)"

        case .phl: return "Philadelphia (PHL)"
        case .mco: return "Orlando (MCO)"
        case .slc: return "Salt Lake City (SLC)"
        case .iah: return "Houston IAH (IAH)"

        case .yyz: return "Toronto (YYZ)"
        case .yvr: return "Vancouver (YVR)"
        case .yyc: return "Calgary (YYC)"

        case .den: return "Denver (DEN)"
        case .dfw: return "Dallas (DFW)"
        case .hou: return "Houston (HOU)"
        case .phx: return "Phoenix (PHX)"

        case .ams: return "Amsterdam (AMS)"
        case .cdg: return "Paris (CDG)"
        case .dxb: return "Dubai (DXB)"
        case .sin: return "Singapore (SIN)"
        case .fra: return "Frankfurt (FRA)"
        case .mad: return "Madrid (MAD)"

        case .sfo: return "San Francisco (SFO)"
        case .lax: return "Los Angeles (LAX)"
        case .ord: return "Chicago (ORD)"
        case .las: return "Las Vegas (LAS)"
        case .bos: return "Boston (BOS)"
        case .sea: return "Seattle (SEA)"
        case .san: return "San Diego (SAN)"
        case .mia: return "Miami (MIA)"

        case .bcn: return "Barcelona (BCN)"
        case .fco: return "Rome (FCO)"
        case .hnd: return "Tokyo (HND)"
        case .icn: return "Seoul (ICN)"
        case .syd: return "Sydney (SYD)"
        }
    }

    var timeZone: TimeZone {
        switch self {

        case .atl, .jfk, .lga, .phl, .mco, .bos, .mia, .yyz:
            return TimeZone(identifier: "America/New_York")!

        case .dfw, .hou, .ord, .iah:
            return TimeZone(identifier: "America/Chicago")!

        case .den, .yyc, .slc:
            return TimeZone(identifier: "America/Denver")!

        case .phx:
            return TimeZone(identifier: "America/Phoenix")!

        case .lax, .sfo, .las, .sea, .san, .yvr:
            return TimeZone(identifier: "America/Los_Angeles")!

        case .lhr:
            return TimeZone(identifier: "Europe/London")!

        case .ist:
            return TimeZone(identifier: "Europe/Istanbul")!

        case .ams:
            return TimeZone(identifier: "Europe/Amsterdam")!

        case .cdg:
            return TimeZone(identifier: "Europe/Paris")!

        case .fra:
            return TimeZone(identifier: "Europe/Berlin")!

        case .mad, .bcn:
            return TimeZone(identifier: "Europe/Madrid")!

        case .fco:
            return TimeZone(identifier: "Europe/Rome")!

        case .dxb:
            return TimeZone(identifier: "Asia/Dubai")!

        case .sin:
            return TimeZone(identifier: "Asia/Singapore")!

        case .hnd:
            return TimeZone(identifier: "Asia/Tokyo")!

        case .icn:
            return TimeZone(identifier: "Asia/Seoul")!

        case .syd:
            return TimeZone(identifier: "Australia/Sydney")!
        }
    }
}

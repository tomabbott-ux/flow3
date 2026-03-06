import Foundation

enum FlowAirport: String, CaseIterable, Identifiable, Codable, Hashable {

    case atl = "ATL"
    case jfk = "JFK"
    case lhr = "LHR"
    case yyz = "YYZ"
    case yvr = "YVR"
    case yyc = "YYC"
    case den = "DEN"
    case dfw = "DFW"
    case hou = "HOU"

    case ams = "AMS"
    case cdg = "CDG"
    case dxb = "DXB"
    case sin = "SIN"
    case fra = "FRA"
    case mad = "MAD"

    case sfo = "SFO"
    case lax = "LAX"
    case ord = "ORD"

    case bcn = "BCN"
    case fco = "FCO"
    case hnd = "HND"
    case icn = "ICN"
    case syd = "SYD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .atl: return "Atlanta ATL"
        case .jfk: return "New York JFK"
        case .lhr: return "London Heathrow"
        case .yyz: return "Toronto Pearson"
        case .yvr: return "Vancouver"
        case .yyc: return "Calgary"
        case .den: return "Denver"
        case .dfw: return "Dallas Fort Worth"
        case .hou: return "Houston Hobby"

        case .ams: return "Amsterdam Schiphol"
        case .cdg: return "Paris CDG"
        case .dxb: return "Dubai"
        case .sin: return "Singapore"
        case .fra: return "Frankfurt"
        case .mad: return "Madrid"

        case .sfo: return "San Francisco"
        case .lax: return "Los Angeles"
        case .ord: return "Chicago O'Hare"

        case .bcn: return "Barcelona"
        case .fco: return "Rome Fiumicino"
        case .hnd: return "Tokyo Haneda"
        case .icn: return "Seoul Incheon"
        case .syd: return "Sydney"
        }
    }

    var shortName: String {
        switch self {
        case .atl: return "Atlanta ATL (ATL)"
        case .jfk: return "New York JFK (JFK)"
        case .lhr: return "London Heathrow (LHR)"
        case .yyz: return "Toronto Pearson (YYZ)"
        case .yvr: return "Vancouver (YVR)"
        case .yyc: return "Calgary (YYC)"
        case .den: return "Denver (DEN)"
        case .dfw: return "Dallas Fort Worth (DFW)"
        case .hou: return "Houston Hobby (HOU)"

        case .ams: return "Amsterdam Schiphol (AMS)"
        case .cdg: return "Paris CDG (CDG)"
        case .dxb: return "Dubai (DXB)"
        case .sin: return "Singapore (SIN)"
        case .fra: return "Frankfurt (FRA)"
        case .mad: return "Madrid (MAD)"

        case .sfo: return "San Francisco (SFO)"
        case .lax: return "Los Angeles (LAX)"
        case .ord: return "Chicago O'Hare (ORD)"

        case .bcn: return "Barcelona (BCN)"
        case .fco: return "Rome Fiumicino (FCO)"
        case .hnd: return "Tokyo Haneda (HND)"
        case .icn: return "Seoul Incheon (ICN)"
        case .syd: return "Sydney (SYD)"
        }
    }

    var timeZone: TimeZone {
        switch self {
        case .atl, .jfk:
            return TimeZone(identifier: "America/New_York")!

        case .lax, .sfo, .yvr:
            return TimeZone(identifier: "America/Los_Angeles")!

        case .ord, .dfw, .den, .hou, .yyc:
            return TimeZone(identifier: "America/Chicago")!

        case .yyz:
            return TimeZone(identifier: "America/Toronto")!

        case .lhr:
            return TimeZone(identifier: "Europe/London")!

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

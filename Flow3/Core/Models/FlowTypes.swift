import Foundation

enum FlowAirport: String, CaseIterable, Identifiable, Codable, Hashable {
    case atl = "ATL"
    case jfk = "JFK"
    case lhr = "LHR"

    // Future-ready airports
    case ams = "AMS"
    case cdg = "CDG"
    case dxb = "DXB"
    case sin = "SIN"
    case fra = "FRA"
    case mad = "MAD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .atl:
            return "Atlanta ATL (ATL)"
        case .jfk:
            return "New York JFK (JFK)"
        case .lhr:
            return "London Heathrow (LHR)"
        case .ams:
            return "Amsterdam Schiphol (AMS)"
        case .cdg:
            return "Paris Charles de Gaulle (CDG)"
        case .dxb:
            return "Dubai International (DXB)"
        case .sin:
            return "Singapore Changi (SIN)"
        case .fra:
            return "Frankfurt Airport (FRA)"
        case .mad:
            return "Madrid Barajas (MAD)"
        }
    }

    var shortName: String {
        switch self {
        case .atl:
            return "Atlanta"
        case .jfk:
            return "New York JFK"
        case .lhr:
            return "London Heathrow"
        case .ams:
            return "Amsterdam Schiphol"
        case .cdg:
            return "Paris CDG"
        case .dxb:
            return "Dubai"
        case .sin:
            return "Singapore Changi"
        case .fra:
            return "Frankfurt"
        case .mad:
            return "Madrid"
        }
    }

    var subtitleLine: String {
        switch self {
        case .atl:
            return "Atlanta (ATL)"
        case .jfk:
            return "New York JFK (JFK)"
        case .lhr:
            return "London Heathrow (LHR)"
        case .ams:
            return "Amsterdam Schiphol (AMS)"
        case .cdg:
            return "Paris Charles de Gaulle (CDG)"
        case .dxb:
            return "Dubai International (DXB)"
        case .sin:
            return "Singapore Changi (SIN)"
        case .fra:
            return "Frankfurt Airport (FRA)"
        case .mad:
            return "Madrid Barajas (MAD)"
        }
    }

    var timeZoneIdentifier: String {
        switch self {
        case .atl:
            return "America/New_York"
        case .jfk:
            return "America/New_York"
        case .lhr:
            return "Europe/London"
        case .ams:
            return "Europe/Amsterdam"
        case .cdg:
            return "Europe/Paris"
        case .dxb:
            return "Asia/Dubai"
        case .sin:
            return "Asia/Singapore"
        case .fra:
            return "Europe/Berlin"
        case .mad:
            return "Europe/Madrid"
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var isCurrentlyLiveInApp: Bool {
        switch self {
        case .atl, .jfk, .lhr:
            return true
        case .ams, .cdg, .dxb, .sin, .fra, .mad:
            return false
        }
    }
}

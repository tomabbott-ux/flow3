import Foundation

enum FlowAirport: String, CaseIterable, Identifiable, Codable, Hashable {
    case atl = "ATL"
    case jfk = "JFK"
    case lhr = "LHR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .atl: return "Atlanta ATL (ATL)"
        case .jfk: return "New York JFK (JFK)"
        case .lhr: return "London Heathrow (LHR)"
        }
    }
}

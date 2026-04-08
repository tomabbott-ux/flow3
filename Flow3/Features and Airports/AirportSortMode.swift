import Foundation

enum AirportSortMode: String, CaseIterable {
    case `default` = "default"
    case code = "code"
    case name = "name"

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .code:
            return "Airport code"
        case .name:
            return "Airport name"
        }
    }
}

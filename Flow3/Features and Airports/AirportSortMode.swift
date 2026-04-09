import Foundation

enum AirportSortMode: String, CaseIterable {
    case code = "code"
    case name = "name"

    static let `default`: AirportSortMode = .code

    var title: String {
        switch self {
        case .code:
            return "Airport code"
        case .name:
            return "Airport name"
        }
    }
}

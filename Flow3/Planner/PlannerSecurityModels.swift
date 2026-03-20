import Foundation

enum SecurityRouteMode: String, Codable {
    case auto
    case manual
}

struct SecurityRouteOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let minutes: Int
    let isPreCheckOnly: Bool
}

struct PlannerSecuritySelection: Equatable {
    let option: SecurityRouteOption
    let mode: SecurityRouteMode
}

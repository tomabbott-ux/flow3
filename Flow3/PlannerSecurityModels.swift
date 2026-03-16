import Foundation

enum SecurityRouteMode: String, Codable {
    case automatic
    case manual
}

struct SecurityRouteOption: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let minutes: Int
    let isPreCheckOnly: Bool
}

struct PlannerSecuritySelection {
    let mode: SecurityRouteMode
    let option: SecurityRouteOption
}

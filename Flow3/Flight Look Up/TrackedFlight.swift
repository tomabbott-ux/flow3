import Foundation

enum LeaveTimeTrend: String, Codable {
    case unchanged
    case earlier
    case later
}

struct TrackedFlight: Codable, Identifiable {

    var id: String { flightNumber }

    let flightNumber: String
    let route: String
    let airline: String
    let terminal: String

    let departureTime: Date
    let leaveTime: Date
    let gateTargetTime: Date

    let travelMinutes: Int
    let securityMinutes: Int
    let airportBufferMinutes: Int
    let bagBufferMinutes: Int

    let leaveTimeTrend: LeaveTimeTrend

    let securityRouteMode: SecurityRouteMode
    let securityRouteID: String?
    let securityRouteTitle: String
    let securityRouteSubtitle: String
    let securityRouteDetail: String
    let securityRouteIsPreCheckOnly: Bool
}

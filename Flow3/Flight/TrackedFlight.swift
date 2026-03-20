import Foundation

enum LeaveTimeTrend: String, Codable {
    case earlier
    case unchanged
    case later
}

struct TrackedFlight: Identifiable, Codable, Equatable {
    var id: String {
        "\(flightNumber)-\(departureTime.timeIntervalSince1970)"
    }

    let flightNumber: String
    let route: String
    let airline: String
    let terminal: String
    let gate: String?
    let status: String?
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

    init(
        flightNumber: String,
        route: String,
        airline: String,
        terminal: String,
        gate: String?,
        status: String?,
        departureTime: Date,
        leaveTime: Date,
        gateTargetTime: Date,
        travelMinutes: Int,
        securityMinutes: Int,
        airportBufferMinutes: Int,
        bagBufferMinutes: Int,
        leaveTimeTrend: LeaveTimeTrend,
        securityRouteMode: SecurityRouteMode,
        securityRouteID: String?,
        securityRouteTitle: String,
        securityRouteSubtitle: String,
        securityRouteDetail: String,
        securityRouteIsPreCheckOnly: Bool
    ) {
        self.flightNumber = flightNumber
        self.route = route
        self.airline = airline
        self.terminal = terminal
        self.gate = gate
        self.status = status
        self.departureTime = departureTime
        self.leaveTime = leaveTime
        self.gateTargetTime = gateTargetTime
        self.travelMinutes = travelMinutes
        self.securityMinutes = securityMinutes
        self.airportBufferMinutes = airportBufferMinutes
        self.bagBufferMinutes = bagBufferMinutes
        self.leaveTimeTrend = leaveTimeTrend
        self.securityRouteMode = securityRouteMode
        self.securityRouteID = securityRouteID
        self.securityRouteTitle = securityRouteTitle
        self.securityRouteSubtitle = securityRouteSubtitle
        self.securityRouteDetail = securityRouteDetail
        self.securityRouteIsPreCheckOnly = securityRouteIsPreCheckOnly
    }
}

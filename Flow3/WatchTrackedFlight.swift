import Foundation

struct WatchTrackedFlight: Codable, Equatable, Hashable, Identifiable {
    var id: String { flightNumber }

    let flightNumber: String
    let route: String
    let airportCode: String
    let airportName: String

    let leaveTimeText: String
    let leaveStatusText: String
    let leaveStatusColorHex: String

    let departureTimeText: String
    let terminalText: String
    let checkpointText: String
    let securityText: String
    let gateText: String
    let bagText: String

    let alertTitle: String
    let alertBody: String
}

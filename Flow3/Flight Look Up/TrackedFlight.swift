import Foundation

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
}

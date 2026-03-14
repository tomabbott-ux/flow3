import Foundation

struct DeparturePlan {
    let departureTime: Date
    let gateTargetTime: Date
    let recommendedLeaveTime: Date

    let travelMinutes: Int
    let securityMinutes: Int
    let airportBufferMinutes: Int
    let bagBufferMinutes: Int
}

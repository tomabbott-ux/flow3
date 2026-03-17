import Foundation

struct DeparturePlan {
    let recommendedLeaveTime: Date
    let gateTargetTime: Date
    let travelMinutes: Int
    let securityMinutes: Int
    let airportBufferMinutes: Int
    let bagBufferMinutes: Int
}

import ActivityKit
import Foundation

struct FlowActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let airportCode: String
        let flightNumber: String
        let route: String
        let statusText: String
        let leaveTimeText: String
        let departureTimeText: String
        let securityText: String
        let checkpointText: String
        let terminalText: String
        let gateText: String
    }

    let flightNumber: String
    let route: String
}

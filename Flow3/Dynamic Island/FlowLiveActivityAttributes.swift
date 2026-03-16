import ActivityKit
import Foundation

struct FlowLiveActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var flightNumber: String
        var route: String
        var leaveTime: Date
        var departureTime: Date
        var securityRoute: String
        var securityMinutes: Int
        var isLive: Bool
    }

    var trackingID: String
}

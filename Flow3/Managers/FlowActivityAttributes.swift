import ActivityKit

struct FlowActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var airportCode: String
        var leaveTimeText: String
        var securityText: String
        var checkpointText: String
        var terminalText: String
    }

    var flightNumber: String
    var route: String
}

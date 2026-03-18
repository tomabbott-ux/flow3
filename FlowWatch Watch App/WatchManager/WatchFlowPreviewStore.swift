import Foundation

enum WatchFlowPreviewStore {
    static let sampleFlight = WatchTrackedFlight(
        flightNumber: "DL2707",
        route: "ATL → OMA",
        airportCode: "ATL",
        airportName: "Atlanta",
        leaveTimeText: "17:50",
        leaveStatusText: "Leave in 15 minutes",
        leaveStatusColorHex: "FF7A59",
        departureTimeText: "19:36",
        terminalText: "TS",
        checkpointText: "SOUTH",
        securityText: "No wait",
        gateText: "A12",
        bagText: "Carry-on only",
        alertTitle: "Smart reminder",
        alertBody: "Traffic and security look good. Leave in 15 minutes."
    )
}

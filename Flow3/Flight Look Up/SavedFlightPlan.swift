import Foundation

enum TrackedLeaveTimeTrend: String, Codable {
    case unchanged
    case earlier
    case later
}

struct SavedFlightPlan: Codable {
    let flightNumber: String
    let airline: String
    let originIATA: String
    let destinationIATA: String
    let terminal: String?
    let departureTime: Date

    let checkedBags: Bool

    let leaveTime: Date
    let gateTargetTime: Date

    let travelMinutes: Int
    let securityMinutes: Int
    let terminalBufferMinutes: Int
    let bagBufferMinutes: Int

    let lastUpdated: Date
    let lastMonitorMessages: [String]
    let leaveTimeTrend: TrackedLeaveTimeTrend

    init(
        flightNumber: String,
        airline: String,
        originIATA: String,
        destinationIATA: String,
        terminal: String?,
        departureTime: Date,
        checkedBags: Bool,
        leaveTime: Date,
        gateTargetTime: Date,
        travelMinutes: Int,
        securityMinutes: Int,
        terminalBufferMinutes: Int,
        bagBufferMinutes: Int,
        lastUpdated: Date,
        lastMonitorMessages: [String] = [],
        leaveTimeTrend: TrackedLeaveTimeTrend = .unchanged
    ) {
        self.flightNumber = flightNumber
        self.airline = airline
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.terminal = terminal
        self.departureTime = departureTime
        self.checkedBags = checkedBags
        self.leaveTime = leaveTime
        self.gateTargetTime = gateTargetTime
        self.travelMinutes = travelMinutes
        self.securityMinutes = securityMinutes
        self.terminalBufferMinutes = terminalBufferMinutes
        self.bagBufferMinutes = bagBufferMinutes
        self.lastUpdated = lastUpdated
        self.lastMonitorMessages = lastMonitorMessages
        self.leaveTimeTrend = leaveTimeTrend
    }

    enum CodingKeys: String, CodingKey {
        case flightNumber
        case airline
        case originIATA
        case destinationIATA
        case terminal
        case departureTime
        case checkedBags
        case leaveTime
        case gateTargetTime
        case travelMinutes
        case securityMinutes
        case terminalBufferMinutes
        case bagBufferMinutes
        case lastUpdated
        case lastMonitorMessages
        case leaveTimeTrend
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        flightNumber = try container.decode(String.self, forKey: .flightNumber)
        airline = try container.decode(String.self, forKey: .airline)
        originIATA = try container.decode(String.self, forKey: .originIATA)
        destinationIATA = try container.decode(String.self, forKey: .destinationIATA)
        terminal = try container.decodeIfPresent(String.self, forKey: .terminal)
        departureTime = try container.decode(Date.self, forKey: .departureTime)
        checkedBags = try container.decode(Bool.self, forKey: .checkedBags)
        leaveTime = try container.decode(Date.self, forKey: .leaveTime)
        gateTargetTime = try container.decode(Date.self, forKey: .gateTargetTime)
        travelMinutes = try container.decode(Int.self, forKey: .travelMinutes)
        securityMinutes = try container.decode(Int.self, forKey: .securityMinutes)
        terminalBufferMinutes = try container.decode(Int.self, forKey: .terminalBufferMinutes)
        bagBufferMinutes = try container.decode(Int.self, forKey: .bagBufferMinutes)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        lastMonitorMessages = try container.decodeIfPresent([String].self, forKey: .lastMonitorMessages) ?? []
        leaveTimeTrend = try container.decodeIfPresent(TrackedLeaveTimeTrend.self, forKey: .leaveTimeTrend) ?? .unchanged
    }
}

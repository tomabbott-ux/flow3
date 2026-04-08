import Foundation

enum FlowAlertSeverity: String, Codable, CaseIterable, Hashable {
    case critical
    case warning
    case info

    var displayTitle: String {
        switch self {
        case .critical:
            return "Critical"
        case .warning:
            return "Warning"
        case .info:
            return "Info"
        }
    }
}

enum FlowAlertKind: String, Codable, CaseIterable, Hashable {
    case leaveNow
    case leaveSoon
    case onTrack
    case securityHigh
    case securityRising
    case checkpointClosed
    case weatherImpact
    case trackedFlight
    case calendarFlightDetected
}

struct FlowAlert: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: FlowAlertKind
    let severity: FlowAlertSeverity
    let title: String
    let message: String
    let airportCode: String
    let createdAt: Date
    let relatedFlightID: String?

    init(
        id: UUID = UUID(),
        kind: FlowAlertKind,
        severity: FlowAlertSeverity,
        title: String,
        message: String,
        airportCode: String,
        createdAt: Date = Date(),
        relatedFlightID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.message = message
        self.airportCode = airportCode
        self.createdAt = createdAt
        self.relatedFlightID = relatedFlightID
    }
}

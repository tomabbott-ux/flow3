import Foundation

enum QueueType: String, Codable, CaseIterable, Hashable {
    case general
    case precheck

    var displayTitle: String {
        switch self {
        case .general:
            return "General"
        case .precheck:
            return "PreCheck"
        }
    }
}

enum WaitTimeSourceType: String, Codable, CaseIterable, Hashable {
    case live
    case estimated
    case predicted

    var displayTitle: String {
        switch self {
        case .live:
            return "Live"
        case .estimated:
            return "Estimated"
        case .predicted:
            return "Predicted"
        }
    }
}

struct WaitTimeEstimate: Identifiable, Codable, Hashable {
    let id: UUID
    let airport: FlowAirport
    let terminal: Int?
    let queueType: QueueType
    let minutes: Int
    let observedAt: Date

    let checkpointName: String?
    let areaName: String?
    let sourceType: WaitTimeSourceType

    init(
        id: UUID = UUID(),
        airport: FlowAirport,
        terminal: Int?,
        queueType: QueueType,
        minutes: Int,
        observedAt: Date,
        checkpointName: String? = nil,
        areaName: String? = nil,
        sourceType: WaitTimeSourceType = .live
    ) {
        self.id = id
        self.airport = airport
        self.terminal = terminal
        self.queueType = queueType
        self.minutes = minutes
        self.observedAt = observedAt
        self.checkpointName = checkpointName
        self.areaName = areaName
        self.sourceType = sourceType
    }
}

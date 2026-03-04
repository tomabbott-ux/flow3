import Foundation

enum QueueType: String, Codable, CaseIterable, Hashable {
    case general
    case precheck
}

struct WaitTimeEstimate: Identifiable, Codable, Hashable {
    let id: UUID
    let airport: FlowAirport
    let terminal: Int?          // nil for airports with no terminal breakdown
    let queueType: QueueType
    let minutes: Int
    let observedAt: Date

    init(
        id: UUID = UUID(),
        airport: FlowAirport,
        terminal: Int?,
        queueType: QueueType,
        minutes: Int,
        observedAt: Date
    ) {
        self.id = id
        self.airport = airport
        self.terminal = terminal
        self.queueType = queueType
        self.minutes = minutes
        self.observedAt = observedAt
    }
}

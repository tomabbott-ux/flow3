import Foundation

struct EstimatedAirportWaitTimeProvider: WaitTimeProviding {

    let airport: FlowAirport
    let terminalMinutes: [(terminal: Int, minutes: Int)]

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == self.airport else { return [] }

        let now = Date()

        return terminalMinutes.map { item in
            WaitTimeEstimate(
                airport: self.airport,
                terminal: item.terminal,
                queueType: .general,
                minutes: item.minutes,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .estimated
            )
        }
    }
}

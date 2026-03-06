import Foundation

struct AMSWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard airport == .ams else { return [] }

        let now = Date()

        // Terminal aware stub data
        return [
            WaitTimeEstimate(
                airport: .ams,
                terminal: 1,
                queueType: .general,
                minutes: 12,
                observedAt: now
            ),

            WaitTimeEstimate(
                airport: .ams,
                terminal: 2,
                queueType: .general,
                minutes: 18,
                observedAt: now
            ),

            WaitTimeEstimate(
                airport: .ams,
                terminal: 3,
                queueType: .general,
                minutes: 9,
                observedAt: now
            )
        ]
    }
}

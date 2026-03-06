import Foundation

struct AMSWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .ams else { return [] }

        let now = Date()

        return [
            WaitTimeEstimate(
                airport: .ams,
                terminal: 1,
                queueType: .general,
                minutes: 12,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .estimated
            ),
            WaitTimeEstimate(
                airport: .ams,
                terminal: 2,
                queueType: .general,
                minutes: 18,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .estimated
            ),
            WaitTimeEstimate(
                airport: .ams,
                terminal: 3,
                queueType: .general,
                minutes: 9,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .estimated
            )
        ]
    }
}

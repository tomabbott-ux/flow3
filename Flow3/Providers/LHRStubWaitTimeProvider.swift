import Foundation

struct LHRStubWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lhr else { return [] }

        let now = Date()

        return [
            WaitTimeEstimate(
                airport: .lhr,
                terminal: 2,
                queueType: .general,
                minutes: 4,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .live
            ),
            WaitTimeEstimate(
                airport: .lhr,
                terminal: 3,
                queueType: .general,
                minutes: 4,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .live
            ),
            WaitTimeEstimate(
                airport: .lhr,
                terminal: 4,
                queueType: .general,
                minutes: 4,
                observedAt: now,
                checkpointName: "Security",
                sourceType: .live
            ),
            WaitTimeEstimate(
                airport: .lhr,
                terminal: 5,
                queueType: .general,
                minutes: 4,
                observedAt: now,
                checkpointName: "North",
                sourceType: .live
            ),
            WaitTimeEstimate(
                airport: .lhr,
                terminal: 5,
                queueType: .precheck,
                minutes: 4,
                observedAt: now,
                checkpointName: "South",
                sourceType: .live
            )
        ]
    }
}

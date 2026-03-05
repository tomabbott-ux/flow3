import Foundation

struct LHRStubWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lhr else { return [] }

        let now = Date()

        // Simple stub: T2/T3/T4 -> 4m, T5 North/South -> 4m
        return [
            WaitTimeEstimate(airport: .lhr, terminal: 2, queueType: .general, minutes: 4, observedAt: now),
            WaitTimeEstimate(airport: .lhr, terminal: 3, queueType: .general, minutes: 4, observedAt: now),
            WaitTimeEstimate(airport: .lhr, terminal: 4, queueType: .general, minutes: 4, observedAt: now),

            // T5 North -> .general
            WaitTimeEstimate(airport: .lhr, terminal: 5, queueType: .general, minutes: 4, observedAt: now),

            // T5 South -> .precheck (mapped slot)
            WaitTimeEstimate(airport: .lhr, terminal: 5, queueType: .precheck, minutes: 4, observedAt: now)
        ]
    }
}

import Foundation

struct ATLStubWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .atl else { return [] }

        let now = Date()

        return [
            WaitTimeEstimate(airport: .atl, terminal: nil, queueType: .general, minutes: 12, observedAt: now),
            WaitTimeEstimate(airport: .atl, terminal: nil, queueType: .precheck, minutes: 5, observedAt: now)
        ]
    }
}

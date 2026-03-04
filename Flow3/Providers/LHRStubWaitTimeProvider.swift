import Foundation

struct LHRStubWaitTimeProvider: WaitTimeProviding {

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lhr else { return [] }

        let now = Date()

        return [
            WaitTimeEstimate(airport: .lhr, terminal: nil, queueType: .general, minutes: 18, observedAt: now)
        ]
    }
}

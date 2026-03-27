import Foundation

struct LAXTBITLiveWaitTimeProvider: WaitTimeProviding {
    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        return []
    }
}

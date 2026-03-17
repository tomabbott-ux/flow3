import Foundation

protocol WaitTimeProviding {
    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate]
}

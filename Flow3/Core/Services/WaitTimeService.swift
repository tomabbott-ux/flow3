import Foundation

final class WaitTimeService {
    private let provider: WaitTimeProviding

    init(provider: WaitTimeProviding) {
        self.provider = provider
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        try await provider.fetchWaitTimes(for: airport)
    }
}

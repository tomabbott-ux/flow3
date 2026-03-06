import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {

    private let providers: [FlowAirport: any WaitTimeProviding]

    init(
        providers: [FlowAirport: any WaitTimeProviding] = [
            .atl: ATLStubWaitTimeProvider(),
            .jfk: JFKAzureAPIWaitTimeProvider(),
            .lhr: LHRStubWaitTimeProvider(),
            .ams: AMSWaitTimeProvider()
        ]
    ) {
        self.providers = providers
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard let provider = providers[airport] else {
            return []
        }

        return try await provider.fetchWaitTimes(for: airport)
    }
}

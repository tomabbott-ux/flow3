import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {

    private let liveProviders: [FlowAirport: any WaitTimeProviding]
    private let estimatedProvider = EstimatedWaitTimeProvider()

    init(
        liveProviders: [FlowAirport: any WaitTimeProviding] = [

            .atl: ATLStubWaitTimeProvider(),
            .jfk: JFKAzureAPIWaitTimeProvider(),
            .lhr: LHRStubWaitTimeProvider(),

            .ist: ISTLiveWaitTimeProvider(),

            .yyz: YYZLiveWaitTimeProvider(),
            .yvr: YVRLiveWaitTimeProvider(),
            .yyc: YYCLiveWaitTimeProvider(),

            .den: DENLiveWaitTimeProvider(),
            .dfw: DFWLiveWaitTimeProvider(),
            .hou: HOULiveWaitTimeProvider(),
            .mco: MCOLiveWaitTimeProvider(),
            .phx: PHXLiveWaitTimeProvider(),
            .phl: PHLLiveWaitTimeProvider(),

            .ams: AMSWaitTimeProvider()
        ]
    ) {
        self.liveProviders = liveProviders
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        if let provider = liveProviders[airport] {
            return try await provider.fetchWaitTimes(for: airport)
        }

        if AirportRegistry.definition(for: airport)?.feedType == .estimated {
            return try await estimatedProvider.fetchWaitTimes(for: airport)
        }

        return []
    }
}

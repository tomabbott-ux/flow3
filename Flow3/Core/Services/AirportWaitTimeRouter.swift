import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {

    private let providers: [FlowAirport: any WaitTimeProviding]
    private let estimatedProvider = EstimatedWaitTimeProvider()

    init(
        providers: [FlowAirport: any WaitTimeProviding] = AirportWaitTimeRouter.defaultProviders
    ) {
        self.providers = providers
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        // Priority 1 — Dedicated provider (live APIs or TSA providers)
        if let provider = providers[airport] {
            return try await provider.fetchWaitTimes(for: airport)
        }

        // Priority 2 — Estimated airport profiles
        if AirportRegistry.definition(for: airport)?.feedType == .estimated {
            return try await estimatedProvider.fetchWaitTimes(for: airport)
        }

        // Priority 3 — No data available
        return []
    }
}

extension AirportWaitTimeRouter {

    static let defaultProviders: [FlowAirport: any WaitTimeProviding] = [

        // Core live airports
        .atl: ATLStubWaitTimeProvider(),
        .jfk: JFKAzureAPIWaitTimeProvider(),
        .lhr: LHRStubWaitTimeProvider(),
        .ist: ISTLiveWaitTimeProvider(),
        .lga: LGALiveWaitTimeProvider(),
        .ham: HAMLiveWaitTimeProvider(),
        .cph: CPHLiveWaitTimeProvider(),
        .dus: DUSLiveWaitTimeProvider(),
        .edi: EDILiveWaitTimeProvider(),
        .str: STRLiveWaitTimeProvider(),
        .bru: BRULiveWaitTimeProvider(),
        .fco: FCOLiveWaitTimeProvider(),

        // Canada
        .yyz: YYZLiveWaitTimeProvider(),
        .yvr: YVRLiveWaitTimeProvider(),
        .yyc: YYCLiveWaitTimeProvider(),

        // US live feeds
        .den: DENLiveWaitTimeProvider(),
        .dfw: DFWLiveWaitTimeProvider(),
        .hou: HOULiveWaitTimeProvider(),
        .iah: IAHLiveWaitTimeProvider(),
        .mco: MCOLiveWaitTimeProvider(),
        .phx: PHXLiveWaitTimeProvider(),
        .phl: PHLLiveWaitTimeProvider(),
        .slc: SLCLiveWaitTimeProvider(),

        // TSA-based estimate feeds
        .san: TSAAverageWaitTimeProvider(),
        .las: TSAAverageWaitTimeProvider(),
        .bos: TSAAverageWaitTimeProvider(),
        .sea: TSAAverageWaitTimeProvider(),
        .mia: TSAAverageWaitTimeProvider(),
        .sfo: TSAAverageWaitTimeProvider(),

        // Other live providers
        .ord: ORDLiveWaitTimeProvider(),
        .ams: AMSWaitTimeProvider()
    ]
}

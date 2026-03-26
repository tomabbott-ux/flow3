import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {
    let trackedFlight: TrackedFlight?
    
    private let estimatedProvider = EstimatedWaitTimeProvider()
    private let tsaWebsiteProvider = TSAWebsiteWaitTimeProvider()
    private let cltProvider = CLTLiveWaitTimeProvider()
    private let ewrProvider = EWRLiveWaitTimeProvider()
    private let bwiProvider = BWILiveWaitTimeProvider()
    private let dcaProvider = DCALiveWaitTimeProvider()
    private let pdxProvider = PDXLiveWaitTimeProvider()
    private let miaProvider = MIALiveWaitTimeProvider()
    private let seaProvider = SEALiveWaitTimeProvider()
    private let dubProvider = DUBLiveWaitTimeProvider()
    
    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard let definition = AirportRegistry.definition(for: airport) else {
            return []
        }

        switch definition.providerKind {

        case .atl:
            return try await ATLStubWaitTimeProvider().fetchWaitTimes(for: airport)
            
        case .ams:
            return try await AMSWaitTimeProvider(trackedFlight: trackedFlight)
                .fetchWaitTimes(for: airport)
            
        case .icn:
            return try await ICNLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .fco:
            return try await FcoWaitTimeProvider.fetchWaitTimes()

        case .jfk:
            return try await JFKAzureAPIWaitTimeProvider().fetchWaitTimes(for: airport)

        case .lhr:
            return try await LHRLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ist:
            return try await ISTLiveWaitTimeProvider().fetchWaitTimes(for: airport)
            
        case .dub:
            return try await dubProvider.fetchWaitTimes(for: airport)
            
        case .sea:
            return try await SEALiveWaitTimeProvider().fetchWaitTimes(for: airport)
            
        case .lga:
            return try await LGALiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ham:
            return try await HAMLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .cph:
            return try await CPHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .dus:
            return try await DUSLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .edi:
            return try await EDILiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .str:
            return try await STRLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .bru:
            return try await BRULiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .fra:
            return try await FRALiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .doh:
            return try await DOHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .arn, .got:
            return try await SwedaviaLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .osl:
            return try await OSLLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .zrh:
            return try await ZRHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .hel:
            return try await HELLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .yyz:
            return try await YYZLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .yvr:
            return try await YVRLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .yyc:
            return try await YYCLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .den:
            return try await DENLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .dfw:
            return try await DFWLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .hou:
            return try await HOULiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .iah:
            return try await IAHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .mco:
            return try await MCOLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .phx:
            return try await PHXLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .phl:
            return try await PHLLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .slc:
            return try await SLCLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ord:
            return try await ORDLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .aena:
            return try await AenaLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ber:
            return try await BERLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .clt:
            return try await cltProvider.fetchWaitTimes(for: airport)

        case .pit:
            return try await PITLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .cle:
            return try await CLELiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ewr:
            return try await ewrProvider.fetchWaitTimes(for: airport)

        case .bwi:
            return try await bwiProvider.fetchWaitTimes(for: airport)

        case .dca:
            return try await dcaProvider.fetchWaitTimes(for: airport)

        case .pdx:
            return try await pdxProvider.fetchWaitTimes(for: airport)

        case .tsaWebsite:
            return try await tsaWebsiteProvider.fetchWaitTimes(for: airport)

        case .estimated:
            return try await estimatedProvider.fetchWaitTimes(for: airport)

        case .lax:
            return try await estimatedProvider.fetchWaitTimes(for: airport)
            
        case .mia:
            return try await miaProvider.fetchWaitTimes(for: airport)
            
        case .none:
            return []

        default:
            return try await estimatedProvider.fetchWaitTimes(for: airport)
        }
    }
}

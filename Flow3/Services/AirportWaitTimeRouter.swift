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
    private let delProvider = DELLiveWaitTimeProvider()
    private let chsProvider = CHSWebsiteWaitTimeProvider()
    
    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {

        guard let definition = AirportRegistry.definition(for: airport) else {
            return fallbackEstimate(for: airport)
        }

        do {
            let results: [WaitTimeEstimate]

            switch definition.providerKind {

            case .atl:
                results = try await ATLStubWaitTimeProvider().fetchWaitTimes(for: airport)

            case .ams:
                results = try await AMSWaitTimeProvider(trackedFlight: trackedFlight)
                    .fetchWaitTimes(for: airport)

            case .icn:
                results = try await ICNLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .fco:
                results = try await FcoWaitTimeProvider.fetchWaitTimes()

            case .jfk:
                results = try await JFKAzureAPIWaitTimeProvider().fetchWaitTimes(for: airport)

            case .lhr:
                results = try await LHRLiveWaitTimeProvider().fetchWaitTimes(for: airport)
                
            case .chs:
                results = try await chsProvider.fetchWaitTimes(for: airport)
                
            case .dtw:   //
                results = try await DTWLiveWaitTimeProvider().fetchWaitTimes(for: airport)
                
            case .bna:
                results = try await BNAWebsiteWaitTimeProvider().fetchWaitTimes(for: airport)
                
            case .ist:
                results = try await ISTLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .dub:
                results = try await dubProvider.fetchWaitTimes(for: airport)

            case .sea:
                results = try await seaProvider.fetchWaitTimes(for: airport)

            case .lga:
                results = try await LGALiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .ham:
                results = try await HAMLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .cph:
                results = try await CPHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .del:
                results = try await delProvider.fetchWaitTimes(for: airport)

            case .dus:
                results = try await DUSLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .edi:
                results = try await EDILiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .str:
                results = try await STRLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .bru:
                results = try await BRULiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .fra:
                results = try await FRALiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .doh:
                results = try await DOHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .arn, .got:
                results = try await SwedaviaLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .osl:
                results = try await OSLLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .zrh:
                results = try await ZRHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .hel:
                results = try await HELLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .yyz:
                results = try await YYZLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .yvr:
                results = try await YVRLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .yyc:
                results = try await YYCLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .den:
                results = try await DENLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .dfw:
                results = try await DFWLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .hou:
                results = try await HOULiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .iah:
                results = try await IAHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .mco:
                results = try await MCOLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .phx:
                results = try await PHXLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .phl:
                results = try await PHLLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .slc:
                results = try await SLCLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .ord:
                results = try await ORDLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .aena:
                results = try await AenaLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .ber:
                results = try await BERLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .clt:
                results = try await cltProvider.fetchWaitTimes(for: airport)

            case .pit:
                results = try await PITLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .cle:
                results = try await CLELiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .ewr:
                results = try await ewrProvider.fetchWaitTimes(for: airport)

            case .bwi:
                results = try await bwiProvider.fetchWaitTimes(for: airport)

            case .dca:
                results = try await dcaProvider.fetchWaitTimes(for: airport)

            case .pdx:
                results = try await pdxProvider.fetchWaitTimes(for: airport)

            case .tsaWebsite:
                results = try await tsaWebsiteProvider.fetchWaitTimes(for: airport)

            case .estimated:
                results = try await estimatedProvider.fetchWaitTimes(for: airport)

            case .lax:
                results = try await estimatedProvider.fetchWaitTimes(for: airport)

            case .laxTBIT:
                results = try await LAXTBITLiveWaitTimeProvider().fetchWaitTimes(for: airport)

            case .mia:
                results = try await miaProvider.fetchWaitTimes(for: airport)

            case .none:
                results = []
            }

            if results.isEmpty {
                switch definition.feedType {
                case .estimated, .comingSoon:
                    return fallbackEstimate(for: airport)
                case .live, .highConfidence:
                    return []
                }
            }

            return results

        } catch {
            switch definition.feedType {
            case .estimated, .comingSoon:
                return fallbackEstimate(for: airport)
            case .live:
                throw error

            case .highConfidence:
                return fallbackEstimate(for: airport)
            }
        }
    }

    private func fallbackEstimate(for airport: FlowAirport) -> [WaitTimeEstimate] {
        let now = Date()

        switch airport {

        case .bos:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 22,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal A",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .precheck,
                    minutes: 12,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal A",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 24,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal B",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .precheck,
                    minutes: 13,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal B",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 23,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal C",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .precheck,
                    minutes: 12,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal C",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 25,
                    observedAt: now,
                    checkpointName: "Checkpoint",
                    areaName: "Terminal E",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .san:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 18,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "San Diego",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .tpa:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 17,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Tampa",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .las:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 19,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Las Vegas",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .sfo:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 21,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "San Francisco",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .bna:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 16,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Nashville",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .dtw:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 20,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Detroit",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        case .del:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: 3,
                    queueType: .general,
                    minutes: 14,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Terminal 3",
                    sourceType: .predicted,
                    isClosed: false
                )
            ]

        default:
            return [
                WaitTimeEstimate(
                    airport: airport,
                    terminal: nil,
                    queueType: .general,
                    minutes: 15,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: airport.displayName,
                    sourceType: .predicted,
                    isClosed: false
                )
            ]
        }
    }
}

import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {
    let trackedFlight: TrackedFlight?

    private let estimatedProvider = EstimatedWaitTimeProvider()
    private let tsaWebsiteProvider = TSAWebsiteWaitTimeProvider()
    private let deltaNewsHubProvider = DeltaNewsHubWaitTimeProvider()
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

    enum RouterError: Error {
        case timeout
    }

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard let definition = AirportRegistry.definition(for: airport) else {
            return fallbackEstimate(for: airport)
        }

        do {
            let results: [WaitTimeEstimate] = try await withTimeout(seconds: timeoutSeconds(for: definition.providerKind)) {
                try await fetchPrimaryResults(for: airport, providerKind: definition.providerKind)
            }

            if results.isEmpty {
                switch definition.feedType {
                case .estimated, .comingSoon, .live, .highConfidence:
                    return fallbackEstimate(for: airport)
                }
            }

            return results

        } catch {
            switch definition.feedType {
            case .estimated, .comingSoon, .live, .highConfidence:
                return fallbackEstimate(for: airport)
            }
        }
    }

    private func fetchPrimaryResults(for airport: FlowAirport, providerKind: AirportProviderKind) async throws -> [WaitTimeEstimate] {
        switch providerKind {

        case .atl:
            return try await ATLStubWaitTimeProvider().fetchWaitTimes(for: airport)

        case .deltaNewsHub:
            return try await deltaNewsHubProvider.fetchWaitTimes(for: airport)

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

        case .chs:
            return try await chsProvider.fetchWaitTimes(for: airport)

        case .dtw:
            return try await DTWLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .bna:
            return try await BNAWebsiteWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ist:
            return try await ISTLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .dub:
            return try await dubProvider.fetchWaitTimes(for: airport)

        case .sea:
            return try await seaProvider.fetchWaitTimes(for: airport)

        case .lga:
            return try await LGALiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .ham:
            return try await HAMLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .cph:
            return try await CPHLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .del:
            return try await delProvider.fetchWaitTimes(for: airport)

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

        case .laxTBIT:
            return try await LAXTBITLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .mia:
            return try await miaProvider.fetchWaitTimes(for: airport)

        case .syd:
            return try await SYDLiveWaitTimeProvider().fetchWaitTimes(for: airport)

        case .none:
            return []
        }
    }

    private func timeoutSeconds(for providerKind: AirportProviderKind) -> TimeInterval {
        switch providerKind {
        case .jfk, .lhr, .ams, .ist, .syd:
            return 8
        default:
            return 6
        }
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw RouterError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
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
                    terminal: 1,
                    queueType: .general,
                    minutes: 18,
                    observedAt: now,
                    checkpointName: "Evans",
                    areaName: "Detroit",
                    sourceType: .predicted,
                    isClosed: false
                ),
                WaitTimeEstimate(
                    airport: airport,
                    terminal: 2,
                    queueType: .general,
                    minutes: 22,
                    observedAt: now,
                    checkpointName: "McNamara",
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

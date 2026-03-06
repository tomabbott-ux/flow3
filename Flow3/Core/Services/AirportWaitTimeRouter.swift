import Foundation

struct AirportWaitTimeRouter: WaitTimeProviding {

    private let providers: [FlowAirport: any WaitTimeProviding]

    init(
        providers: [FlowAirport: any WaitTimeProviding] = [
            .atl: ATLStubWaitTimeProvider(),
            .jfk: JFKAzureAPIWaitTimeProvider(),
            .lhr: LHRStubWaitTimeProvider(),
            .yyz: YYZLiveWaitTimeProvider(),
            .yvr: YVRLiveWaitTimeProvider(),
            .yyc: YYCLiveWaitTimeProvider(),
            .den: DENLiveWaitTimeProvider(),
            .dfw: DFWLiveWaitTimeProvider(),
            .hou: HOULiveWaitTimeProvider(),

            .ams: AMSWaitTimeProvider(),
            .cdg: EstimatedAirportWaitTimeProvider(
                airport: .cdg,
                terminalMinutes: [
                    (1, 14),
                    (2, 18),
                    (3, 11)
                ]
            ),
            .dxb: EstimatedAirportWaitTimeProvider(
                airport: .dxb,
                terminalMinutes: [
                    (1, 16),
                    (2, 12),
                    (3, 20)
                ]
            ),
            .sin: EstimatedAirportWaitTimeProvider(
                airport: .sin,
                terminalMinutes: [
                    (1, 10),
                    (2, 8),
                    (3, 12),
                    (4, 9)
                ]
            ),
            .fra: EstimatedAirportWaitTimeProvider(
                airport: .fra,
                terminalMinutes: [
                    (1, 15),
                    (2, 13)
                ]
            ),
            .mad: EstimatedAirportWaitTimeProvider(
                airport: .mad,
                terminalMinutes: [
                    (1, 17),
                    (2, 11),
                    (4, 14)
                ]
            ),

            .sfo: EstimatedAirportWaitTimeProvider(
                airport: .sfo,
                terminalMinutes: [
                    (1, 12),
                    (2, 14),
                    (3, 9)
                ]
            ),
            .lax: EstimatedAirportWaitTimeProvider(
                airport: .lax,
                terminalMinutes: [
                    (1, 15),
                    (2, 18),
                    (3, 12),
                    (4, 10)
                ]
            ),
            .ord: EstimatedAirportWaitTimeProvider(
                airport: .ord,
                terminalMinutes: [
                    (1, 16),
                    (2, 11),
                    (3, 13)
                ]
            ),

            .bcn: EstimatedAirportWaitTimeProvider(
                airport: .bcn,
                terminalMinutes: [
                    (1, 9),
                    (2, 12)
                ]
            ),
            .fco: EstimatedAirportWaitTimeProvider(
                airport: .fco,
                terminalMinutes: [
                    (1, 10),
                    (3, 14)
                ]
            ),
            .hnd: EstimatedAirportWaitTimeProvider(
                airport: .hnd,
                terminalMinutes: [
                    (1, 8),
                    (2, 7),
                    (3, 10)
                ]
            ),
            .icn: EstimatedAirportWaitTimeProvider(
                airport: .icn,
                terminalMinutes: [
                    (1, 9),
                    (2, 11)
                ]
            ),
            .syd: EstimatedAirportWaitTimeProvider(
                airport: .syd,
                terminalMinutes: [
                    (1, 12),
                    (2, 10),
                    (3, 14)
                ]
            )
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

import Foundation

struct ATLStubWaitTimeProvider: WaitTimeProviding {

    private let provider = ATLLiveWaitTimeProvider()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .atl else { return [] }

        let now = Date()
        let waits = try await provider.fetch()

        return waits
            .map { item in
                let isSouth = item.checkpointName.uppercased().contains("SOUTH")

                return WaitTimeEstimate(
                    airport: .atl,
                    terminal: nil,
                    queueType: isSouth ? .precheck : .general,
                    minutes: item.minutes,
                    observedAt: now,
                    checkpointName: item.checkpointName.uppercased(),
                    areaName: item.terminal == .domestic ? "Domestic" : "International",
                    sourceType: .live
                )
            }
            .sorted { lhs, rhs in
                let lhsArea = lhs.areaName ?? ""
                let rhsArea = rhs.areaName ?? ""

                if lhsArea != rhsArea {
                    if lhsArea == "Domestic" { return true }
                    if rhsArea == "Domestic" { return false }
                }

                return (lhs.checkpointName ?? "") < (rhs.checkpointName ?? "")
            }
    }
}

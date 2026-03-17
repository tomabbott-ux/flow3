import Foundation

struct ATLStubWaitTimeProvider: WaitTimeProviding {

    private let provider = ATLLiveWaitTimeProvider()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .atl else { return [] }

        let now = Date()
        let waits = try await provider.fetch()

        return waits
            .map { item in
                let checkpointName = item.checkpointName.uppercased()
                let isSouth = checkpointName.contains("SOUTH")

                return WaitTimeEstimate(
                    airport: .atl,
                    terminal: nil,
                    queueType: isSouth ? .precheck : .general,
                    minutes: item.isClosed ? 0 : (item.minutes ?? 0),
                    observedAt: now,
                    checkpointName: checkpointName,
                    areaName: item.terminal == .domestic ? "Domestic" : "International",
                    sourceType: .live,
                    isClosed: item.isClosed
                )
            }
            .sorted { lhs, rhs in
                let lhsArea = lhs.areaName ?? ""
                let rhsArea = rhs.areaName ?? ""

                if lhsArea != rhsArea {
                    if lhsArea == "Domestic" { return true }
                    if rhsArea == "Domestic" { return false }
                }

                let lhsName = lhs.checkpointName ?? ""
                let rhsName = rhs.checkpointName ?? ""

                let order = ["MAIN", "NORTH", "LOWER NORTH", "SOUTH"]
                if lhsArea == "Domestic", rhsArea == "Domestic" {
                    let lhsIndex = order.firstIndex(of: lhsName) ?? 999
                    let rhsIndex = order.firstIndex(of: rhsName) ?? 999
                    if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                }

                return lhsName < rhsName
            }
    }
}

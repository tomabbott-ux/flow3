import Foundation

struct ATLStubWaitTimeProvider: WaitTimeProviding {

    private let provider = ATLLiveWaitTimeProvider()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .atl else { return [] }

        let now = Date()

        // Try live first
        let liveWaits = (try? await provider.fetch()) ?? []

        if !liveWaits.isEmpty {
            return liveWaits
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
                .sorted(by: atlSort)
        }

        // Graceful fallback
        return fallbackWaits(observedAt: now).sorted(by: atlSort)
    }

    private func fallbackWaits(observedAt: Date) -> [WaitTimeEstimate] {
        [
            WaitTimeEstimate(
                airport: .atl,
                terminal: nil,
                queueType: .general,
                minutes: 15,
                observedAt: observedAt,
                checkpointName: "MAIN",
                areaName: "Domestic",
                sourceType: .estimated,
                isClosed: false
            ),
            WaitTimeEstimate(
                airport: .atl,
                terminal: nil,
                queueType: .general,
                minutes: 22,
                observedAt: observedAt,
                checkpointName: "NORTH",
                areaName: "Domestic",
                sourceType: .estimated,
                isClosed: false
            ),
            WaitTimeEstimate(
                airport: .atl,
                terminal: nil,
                queueType: .general,
                minutes: 0,
                observedAt: observedAt,
                checkpointName: "LOWER NORTH",
                areaName: "Domestic",
                sourceType: .estimated,
                isClosed: true
            ),
            WaitTimeEstimate(
                airport: .atl,
                terminal: nil,
                queueType: .precheck,
                minutes: 12,
                observedAt: observedAt,
                checkpointName: "SOUTH",
                areaName: "Domestic",
                sourceType: .estimated,
                isClosed: false
            ),
            WaitTimeEstimate(
                airport: .atl,
                terminal: nil,
                queueType: .general,
                minutes: 11,
                observedAt: observedAt,
                checkpointName: "MAIN",
                areaName: "International",
                sourceType: .estimated,
                isClosed: false
            )
        ]
    }

    private func atlSort(_ lhs: WaitTimeEstimate, _ rhs: WaitTimeEstimate) -> Bool {
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

        if lhsArea == "International", rhsArea == "International" {
            return lhsName < rhsName
        }

        return lhsName < rhsName
    }
}

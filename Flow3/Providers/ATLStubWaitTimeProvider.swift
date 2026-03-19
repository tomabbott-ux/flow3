import Foundation

struct ATLStubWaitTimeProvider: WaitTimeProviding {

    private let provider = ATLLiveWaitTimeProvider()
    private let tsaService = TSAWaitTimeService()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .atl else { return [] }

        let now = Date()

        // 1. Try ATL official source first
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

        // 2. TSA fallback
        if let tsaRows = try? await fetchTSAFallback(observedAt: now), !tsaRows.isEmpty {
            return tsaRows.sorted(by: atlSort)
        }

        // 3. Final hardcoded fallback
        return fallbackWaits(observedAt: now).sorted(by: atlSort)
    }

    private func fetchTSAFallback(observedAt: Date) async throws -> [WaitTimeEstimate] {
        let response = try await tsaService.fetchWaitTimes(for: "ATL")

        guard let general = response.resolvedGeneralMinutes else {
            return []
        }

        let precheckMinutes = response.resolvedPrecheckMinutes

        // ✅ DEBUG (SAFE POSITION)
        print("ATL TSA fallback general:", general)
        print("ATL TSA fallback precheck:", precheckMinutes as Any)

        return [
            WaitTimeEstimate(
                airport: .atl,
                terminal: nil,
                queueType: .general,
                minutes: general,
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
                minutes: max(5, general + 2),
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
                minutes: precheckMinutes ?? max(2, general - 3),
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
                minutes: max(3, general - 1),
                observedAt: observedAt,
                checkpointName: "MAIN",
                areaName: "International",
                sourceType: .estimated,
                isClosed: false
            )
        ]
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

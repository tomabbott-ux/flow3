import Foundation

struct LAXTBITLiveWaitTimeProvider: WaitTimeProviding {

    private let service = TSAWaitTimeService()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .lax else { return [] }

        let response = try await service.fetchWaitTimes(for: "LAX")
        let now = Date()

        var results: [WaitTimeEstimate] = []

        if let general = response.resolvedGeneralMinutes {
            results.append(
                WaitTimeEstimate(
                    airport: .lax,
                    terminal: 100,
                    queueType: .general,
                    minutes: general,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Tom Bradley International Terminal",
                    sourceType: .live
                )
            )
        }

        if let precheck = response.resolvedPrecheckMinutes {
            results.append(
                WaitTimeEstimate(
                    airport: .lax,
                    terminal: 100,
                    queueType: .precheck,
                    minutes: precheck,
                    observedAt: now,
                    checkpointName: "Security",
                    areaName: "Tom Bradley International Terminal",
                    sourceType: .live
                )
            )
        }

        return results
    }
}

import Foundation

struct ATLStubWaitTimeProvider: WaitTimeProviding {

    private let provider = ATLLiveWaitTimeProvider()

    func fetchWaitTimes(for airport: FlowAirport) async throws -> [WaitTimeEstimate] {
        guard airport == .atl else { return [] }

        let now = Date()
        let waits = try await provider.fetch()

        // South is PreCheck-only on ATL's display
        let south = waits.first { $0.checkpointName.uppercased().contains("SOUTH") }?.minutes

        // General = minimum of the remaining checkpoints
        let general = waits
            .filter { !$0.checkpointName.uppercased().contains("SOUTH") }
            .map { $0.minutes }
            .min()

        var results: [WaitTimeEstimate] = []

        if let general {
            results.append(
                WaitTimeEstimate(
                    airport: .atl,
                    terminal: nil,
                    queueType: .general,
                    minutes: general,
                    observedAt: now
                )
            )
        }

        if let south, let precheckType = QueueType.precheckOrNil() {
            results.append(
                WaitTimeEstimate(
                    airport: .atl,
                    terminal: nil,
                    queueType: precheckType,
                    minutes: south,
                    observedAt: now
                )
            )
        }

        return results
    }
}

// MARK: - Detect your PreCheck enum case safely
private extension QueueType {

    /// Attempts to find the enum case that represents TSA Pre / PreCheck.
    /// This requires QueueType to be CaseIterable.
    static func precheckOrNil() -> QueueType? {
        // If this line fails to compile, QueueType isn't CaseIterable.
        for c in QueueType.allCases {
            let s = String(describing: c).lowercased()
            if s.contains("pre") { return c }
        }
        return nil
    }
}

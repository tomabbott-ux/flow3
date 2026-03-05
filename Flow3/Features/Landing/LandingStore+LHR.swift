import Foundation

extension LandingStore {

    /// LHR minutes by terminal + category.
    /// Category mapping:
    /// - T2/T3/T4 use `.general`
    /// - T5 North -> `.general`
    /// - T5 South -> `.precheck`
    func lhrMinutes(terminal: Int, category: QueueType) -> Int? {
        let values = waitTimes
            .filter { $0.airport == .lhr }
            .filter { ($0.terminal ?? -1) == terminal }
            .filter { $0.queueType == category }
            .map { $0.minutes }

        return values.min()
    }

    /// Terminals present based on live data.
    /// Safely unwraps optional terminals.
    func lhrTerminalsPresent() -> [Int] {
        let terminals: [Int] = waitTimes
            .filter { $0.airport == .lhr }
            .compactMap { $0.terminal }          // ✅ unwrap Int?
        let unique = Array(Set(terminals))      // now Set<Int>
        let sorted = unique.sorted()            // ✅ works (Int is Comparable)

        return sorted.isEmpty ? [2, 3, 4, 5] : sorted
    }
}

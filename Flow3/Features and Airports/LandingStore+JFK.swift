import Foundation

extension LandingStore {

    /// Minutes for a specific JFK terminal + queue type
    func jfkMinutes(terminal: Int, category: QueueType) -> Int? {
        let values = waitTimes
            .filter { $0.airport == .jfk }
            .filter { ($0.terminal ?? -1) == terminal }
            .filter { $0.queueType == category }
            .map { $0.minutes }

        return values.min()
    }

    /// List of JFK terminals present in the dataset
    func jfkTerminalsPresent() -> [Int] {
        let terminals: [Int] = waitTimes
            .filter { $0.airport == .jfk }
            .compactMap { $0.terminal }

        let unique = Array(Set(terminals))
        let sorted = unique.sorted()

        return sorted.isEmpty ? [1,2,4,5,7,8] : sorted
    }
}

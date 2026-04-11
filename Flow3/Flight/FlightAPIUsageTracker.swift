import Foundation

struct FlightAPIUsageSnapshot: Codable {
    var dayKey: String
    var monthKey: String
    var callsToday: Int
    var callsThisMonth: Int
    var cacheHitsToday: Int
    var cacheMissesToday: Int
    var failuresToday: Int
    var trackedRefreshesToday: Int
    var lastCallAt: Date?
}

@MainActor
final class FlightAPIUsageTracker: ObservableObject {
    static let shared = FlightAPIUsageTracker()

    @Published private(set) var snapshot: FlightAPIUsageSnapshot

    private let defaults = UserDefaults.standard
    private let storageKey = "flow.flightAPIUsageSnapshot"

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FlightAPIUsageSnapshot.self, from: data) {
            snapshot = decoded
        } else {
            let now = Date()
            snapshot = FlightAPIUsageSnapshot(
                dayKey: Self.dayKey(from: now),
                monthKey: Self.monthKey(from: now),
                callsToday: 0,
                callsThisMonth: 0,
                cacheHitsToday: 0,
                cacheMissesToday: 0,
                failuresToday: 0,
                trackedRefreshesToday: 0,
                lastCallAt: nil
            )
            persist()
        }

        rollIfNeeded()
    }

    func recordCall() {
        rollIfNeeded()
        snapshot.callsToday += 1
        snapshot.callsThisMonth += 1
        snapshot.lastCallAt = Date()
        persist()
    }

    func recordCacheHit() {
        rollIfNeeded()
        snapshot.cacheHitsToday += 1
        persist()
    }

    func recordCacheMiss() {
        rollIfNeeded()
        snapshot.cacheMissesToday += 1
        persist()
    }

    func recordFailure() {
        rollIfNeeded()
        snapshot.failuresToday += 1
        persist()
    }

    func recordTrackedRefresh() {
        rollIfNeeded()
        snapshot.trackedRefreshesToday += 1
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func rollIfNeeded() {
        let now = Date()
        let currentDayKey = Self.dayKey(from: now)
        let currentMonthKey = Self.monthKey(from: now)

        if snapshot.monthKey != currentMonthKey {
            snapshot.monthKey = currentMonthKey
            snapshot.callsThisMonth = 0
        }

        if snapshot.dayKey != currentDayKey {
            snapshot.dayKey = currentDayKey
            snapshot.callsToday = 0
            snapshot.cacheHitsToday = 0
            snapshot.cacheMissesToday = 0
            snapshot.failuresToday = 0
            snapshot.trackedRefreshesToday = 0
        }

        persist()
    }

    private static func dayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

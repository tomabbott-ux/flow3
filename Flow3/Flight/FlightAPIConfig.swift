import Foundation

enum FlightAPIConfig {

    // Cache identical searches (same flight/date)
    static let identicalSearchCacheTTL: TimeInterval = 5 * 60   // 5 minutes

    // Tracked flight refresh control
    static let activeTrackedRefreshMinimumInterval: TimeInterval = 5 * 60
    static let inactiveTrackedRefreshMinimumInterval: TimeInterval = 10 * 60

    // 🚨 CRITICAL FIX (was 10 mins → now 60s)
    static let failureBackoffInterval: TimeInterval = 60
}

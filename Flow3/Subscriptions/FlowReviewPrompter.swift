import Foundation
import StoreKit
import UIKit

@MainActor
final class FlowReviewPrompter: ObservableObject {

    static let shared = FlowReviewPrompter()

    private enum Keys {
        static let appOpenCount = "flow_review_app_open_count"
        static let trackedFlightCount = "flow_review_tracked_flight_count"
        static let hasRequestedReview = "flow_review_has_requested_review"
        static let lastRequestedAt = "flow_review_last_requested_at"
    }

    private init() {}

    var appOpenCount: Int {
        UserDefaults.standard.integer(forKey: Keys.appOpenCount)
    }

    var trackedFlightCount: Int {
        UserDefaults.standard.integer(forKey: Keys.trackedFlightCount)
    }

    var hasRequestedReview: Bool {
        UserDefaults.standard.bool(forKey: Keys.hasRequestedReview)
    }

    var lastRequestedAt: Date? {
        UserDefaults.standard.object(forKey: Keys.lastRequestedAt) as? Date
    }

    func recordAppOpen() {
        let newValue = appOpenCount + 1
        UserDefaults.standard.set(newValue, forKey: Keys.appOpenCount)
    }

    func recordTrackedFlight() {
        let newValue = trackedFlightCount + 1
        UserDefaults.standard.set(newValue, forKey: Keys.trackedFlightCount)
    }

    func shouldRequestReview() -> Bool {
        if hasRequestedReview {
            return false
        }

        if appOpenCount < 5 {
            return false
        }

        if trackedFlightCount < 1 {
            return false
        }

        if let lastRequestedAt,
           Date().timeIntervalSince(lastRequestedAt) < 60 * 60 * 24 * 120 {
            return false
        }

        return true
    }

    func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        SKStoreReviewController.requestReview(in: scene)

        UserDefaults.standard.set(true, forKey: Keys.hasRequestedReview)
        UserDefaults.standard.set(Date(), forKey: Keys.lastRequestedAt)
    }

    func forceResetForTesting() {
        UserDefaults.standard.set(0, forKey: Keys.appOpenCount)
        UserDefaults.standard.set(0, forKey: Keys.trackedFlightCount)
        UserDefaults.standard.set(false, forKey: Keys.hasRequestedReview)
        UserDefaults.standard.removeObject(forKey: Keys.lastRequestedAt)
    }
}

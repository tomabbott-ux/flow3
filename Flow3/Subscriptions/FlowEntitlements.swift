import Foundation

final class FlowEntitlements {

    static func canAccessAirport(
        airportCode: String,
        subscriptionTier: SubscriptionTier
    ) -> Bool {
        if subscriptionTier == .pro {
            return true
        }

        return FreeAirportConfig.isFreeAirport(code: airportCode)
    }

    static func canUseFlightTracking(
        subscriptionTier: SubscriptionTier
    ) -> Bool {
        subscriptionTier == .pro
    }

    static func canUseSmartAlerts(
        subscriptionTier: SubscriptionTier
    ) -> Bool {
        subscriptionTier == .pro
    }
}

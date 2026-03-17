import Foundation
import ActivityKit

@MainActor
final class FlowLiveActivityManager {

    static let shared = FlowLiveActivityManager()

    private var currentActivity: Activity<FlowLiveActivityAttributes>?

    func start(for flight: TrackedFlight) async {

        print("🚀 Attempting to start Flow Live Activity")

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities disabled")
            return
        }

        if currentActivity != nil {
            await end()
        }

        let attributes = FlowLiveActivityAttributes(
            trackingID: flight.flightNumber
        )

        let contentState = FlowLiveActivityAttributes.ContentState(
            flightNumber: flight.flightNumber,
            route: flight.route,
            leaveTime: flight.leaveTime,
            departureTime: flight.departureTime,
            securityRoute: securityRouteText(for: flight),
            securityMinutes: flight.securityMinutes,
            isLive: true
        )

        do {
            let activity = try Activity<FlowLiveActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(
                    state: contentState,
                    staleDate: nil
                ),
                pushType: nil
            )

            currentActivity = activity
            print("✅ Live Activity started")

        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    func update(for flight: TrackedFlight) async {

        guard let activity = currentActivity else {
            print("⚠️ No Live Activity to update")
            return
        }

        let updatedState = FlowLiveActivityAttributes.ContentState(
            flightNumber: flight.flightNumber,
            route: flight.route,
            leaveTime: flight.leaveTime,
            departureTime: flight.departureTime,
            securityRoute: securityRouteText(for: flight),
            securityMinutes: flight.securityMinutes,
            isLive: true
        )

        await activity.update(
            ActivityContent(
                state: updatedState,
                staleDate: nil
            )
        )

        print("🔄 Live Activity updated")
    }

    func end() async {

        guard let activity = currentActivity else { return }

        let finalState = activity.content.state

        await activity.end(
            ActivityContent(
                state: finalState,
                staleDate: nil
            ),
            dismissalPolicy: .immediate
        )

        currentActivity = nil

        print("🛑 Live Activity ended")
    }

    private func securityRouteText(for flight: TrackedFlight) -> String {
        if flight.securityRouteSubtitle.isEmpty {
            return flight.securityRouteTitle
        }
        return "\(flight.securityRouteTitle) · \(flight.securityRouteSubtitle)"
    }
}

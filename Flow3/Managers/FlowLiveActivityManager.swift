import Foundation
import ActivityKit

@MainActor
final class FlowLiveActivityManager {

    static let shared = FlowLiveActivityManager()

    private var currentActivity: Activity<FlowActivityAttributes>?

    private init() {}

    func start(for flight: TrackedFlight) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        let attributes = FlowActivityAttributes(
            flightNumber: flight.flightNumber,
            route: flight.route
        )

        let state = FlowActivityAttributes.ContentState(
            airportCode: flight.departureAirportCode,
            leaveTimeText: formattedTime(flight.leaveTime),
            securityText: securityText(for: flight),
            checkpointText: flight.securityRouteTitle,
            terminalText: displayTerminal(for: flight)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity")
        } catch {
            print("Failed to start Live Activity:", error.localizedDescription)
        }
    }

    func update(for flight: TrackedFlight) async {
        if currentActivity == nil {
            let existing = Activity<FlowActivityAttributes>.activities.first
            currentActivity = existing
        }

        guard let currentActivity else {
            print("⚠️ No Live Activity to update")
            return
        }

        let newState = FlowActivityAttributes.ContentState(
            airportCode: flight.departureAirportCode,
            leaveTimeText: formattedTime(flight.leaveTime),
            securityText: securityText(for: flight),
            checkpointText: flight.securityRouteTitle,
            terminalText: displayTerminal(for: flight)
        )

        await currentActivity.update(
            .init(state: newState, staleDate: nil)
        )
        print("Updated Live Activity")
    }

    func end() async {
        if currentActivity == nil {
            currentActivity = Activity<FlowActivityAttributes>.activities.first
        }

        guard let currentActivity else { return }

        let finalState = currentActivity.content.state
        await currentActivity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        self.currentActivity = nil
        print("Ended Live Activity")
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func securityText(for flight: TrackedFlight) -> String {
        if flight.securityMinutes <= 0 {
            return "No wait"
        }
        return "\(flight.securityMinutes) min"
    }

    private func displayTerminal(for flight: TrackedFlight) -> String {
        let t = flight.terminal.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "TBD" : t
    }
}

private extension TrackedFlight {
    var departureAirportCode: String {
        route
            .components(separatedBy: "→")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? "AIRPORT"
    }
}

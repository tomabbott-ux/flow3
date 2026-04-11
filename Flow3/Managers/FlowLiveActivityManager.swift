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

        if currentActivity == nil {
            currentActivity = Activity<FlowActivityAttributes>.activities.first
        }

        if currentActivity != nil {
            await update(for: flight)
            return
        }

        let attributes = FlowActivityAttributes(
            flightNumber: flight.flightNumber,
            route: flight.route
        )

        let state = makeState(from: flight)

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
            currentActivity = Activity<FlowActivityAttributes>.activities.first
        }

        guard let currentActivity else {
            
            return
        }

        let newState = makeState(from: flight)

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

        await currentActivity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        self.currentActivity = nil
        print("Ended Live Activity")
    }

    private func makeState(from flight: TrackedFlight) -> FlowActivityAttributes.ContentState {
        FlowActivityAttributes.ContentState(
            airportCode: flight.departureAirportCode,
            flightNumber: flight.flightNumber,
            route: flight.route,
            statusText: displayStatus(for: flight),
            leaveTimeText: formattedTime(flight.leaveTime),
            departureTimeText: formattedTime(flight.departureTime),
            securityText: securityText(for: flight),
            checkpointText: flight.securityRouteTitle,
            terminalText: displayTerminal(for: flight),
            gateText: displayGate(for: flight)
        )
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
        return t.isEmpty ? "TBD" : "T\(t)"
    }

    private func displayGate(for flight: TrackedFlight) -> String {
        let g = flight.gate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return g.isEmpty ? "TBD" : g
    }

    private func displayStatus(for flight: TrackedFlight) -> String {
        let raw = flight.status?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if raw.isEmpty {
            return "Status unavailable"
        }

        let normalized = raw.lowercased()

        switch normalized {
        case "expected", "scheduled", "active":
            return "On Time"
        case "boarding":
            return "Boarding"
        case "gateopen", "gate_open", "gate open":
            return "Gate Open"
        case "gateclosed", "gate_closed", "gate closed", "finalcall", "final_call", "final call":
            return "Gate Closing"
        case "delayed":
            return "Delayed"
        case "departed":
            return "Departed"
        case "landed", "arrived":
            return "Arrived"
        case "cancelled":
            return "Cancelled"
        case "incident", "diverted":
            return "Disrupted"
        default:
            return raw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .capitalized
        }
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

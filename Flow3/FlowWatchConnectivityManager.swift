import Foundation
import WatchConnectivity

final class FlowWatchConnectivityManager: NSObject {
    
    static let shared = FlowWatchConnectivityManager()

    private let session = WCSession.default
    private var pendingFlight: TrackedFlight?

    private override init() {
        super.init()
        activateSession()
    }

    func activateSession() {
        guard WCSession.isSupported() else {
            print("📱 WCSession not supported on iPhone")
            return
        }

        print("📱 Activating iPhone watch session")
        session.delegate = self
        session.activate()
    }

    func syncTrackedFlight(_ flight: TrackedFlight?) {
        guard WCSession.isSupported() else {
            print("📱 WCSession not supported when syncing")
            return
        }

        print("📱 syncTrackedFlight called")
        print("📱 activationState:", session.activationState.rawValue)
        print("📱 isReachable:", session.isReachable)
        print("📱 isPaired:", session.isPaired)
        print("📱 isWatchAppInstalled:", session.isWatchAppInstalled)

        if session.activationState != .activated {
            print("📱 Session not activated yet, storing pending flight")
            pendingFlight = flight
            return
        }

        do {
            if let flight {
                let watchFlight = makeWatchTrackedFlight(from: flight)
                let data = try JSONEncoder().encode(watchFlight)

                let payload: [String: Any] = [
                    "hasTrackedFlight": true,
                    "trackedFlightData": data
                ]

                if session.isReachable {
                    session.sendMessage(payload, replyHandler: nil)
                    print("📱 sendMessage sent")
                } else {
                    print("📱 sendMessage skipped, not reachable")
                }

                session.transferUserInfo(payload)
                print("📱 transferUserInfo queued")

                try session.updateApplicationContext(payload)
                print("📱 updateApplicationContext set")

                print("📱 Sent tracked flight to watch:", watchFlight.flightNumber)
            } else {
                let payload: [String: Any] = [
                    "hasTrackedFlight": false
                ]

                if session.isReachable {
                    session.sendMessage(payload, replyHandler: nil)
                    print("📱 clear sendMessage sent")
                } else {
                    print("📱 clear sendMessage skipped, not reachable")
                }

                session.transferUserInfo(payload)
                print("📱 clear transferUserInfo queued")

                try session.updateApplicationContext(payload)
                print("📱 clear updateApplicationContext set")

                print("📱 Cleared tracked flight on watch")
            }
        } catch {
            print("📱 Watch sync error:", error.localizedDescription)
        }
    }

    private func makeWatchTrackedFlight(from flight: TrackedFlight) -> WatchTrackedFlight {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let leaveTimeText = timeFormatter.string(from: flight.leaveTime)
        let departureTimeText = timeFormatter.string(from: flight.departureTime)

        let minutesUntilLeave = Int(flight.leaveTime.timeIntervalSinceNow / 60)

        let statusText: String
        let statusColorHex: String

        if minutesUntilLeave > 1 {
            statusText = "Leave in \(minutesUntilLeave) minutes"
            statusColorHex = "FF9F0A"
        } else if minutesUntilLeave == 1 {
            statusText = "Leave in 1 minute"
            statusColorHex = "FF9F0A"
        } else {
            statusText = "Leave now"
            statusColorHex = "FF5A5F"
        }

        let checkpoint = flight.securityRouteTitle.isEmpty ? "TBD" : flight.securityRouteTitle
        let terminal = flight.terminal.isEmpty ? "—" : flight.terminal
        let gate = (flight.gate?.isEmpty == false) ? flight.gate! : "TBD"

        let securityText: String
        if flight.securityMinutes <= 0 {
            securityText = "No wait"
        } else {
            securityText = "\(flight.securityMinutes)m"
        }

        let bagText: String = flight.bagBufferMinutes > 0 ? "Checked bag" : "Carry-on only"

        let airportCode = extractAirportCode(from: flight.route)
        let airportName = airportDisplayName(for: airportCode)

        return WatchTrackedFlight(
            flightNumber: flight.flightNumber,
            route: flight.route,
            airportCode: airportCode,
            airportName: airportName,
            leaveTimeText: leaveTimeText,
            leaveStatusText: statusText,
            leaveStatusColorHex: statusColorHex,
            departureTimeText: departureTimeText,
            terminalText: terminal,
            checkpointText: checkpoint,
            securityText: securityText,
            gateText: gate,
            bagText: bagText,
            alertTitle: "Smart reminder",
            alertBody: makeAlertBody(
                leaveStatusText: statusText,
                securityText: securityText
            )
        )
    }

    private func makeAlertBody(leaveStatusText: String, securityText: String) -> String {
        if securityText == "No wait" {
            return "Security is clear. \(leaveStatusText)."
        } else {
            return "Security is \(securityText). \(leaveStatusText)."
        }
    }

    private func extractAirportCode(from route: String) -> String {
        let parts = route.components(separatedBy: "→")
        guard let first = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty else {
            return "—"
        }
        return first
    }

    private func airportDisplayName(for code: String) -> String {
        switch code.uppercased() {
        case "ATL": return "Atlanta"
        case "JFK": return "New York"
        case "LHR": return "London Heathrow"
        case "CLE": return "Cleveland"
        case "PIT": return "Pittsburgh"
        case "OMA": return "Omaha"
        default: return code.uppercased()
        }
    }
}

extension FlowWatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("📱 iPhone WCSession activation error:", error.localizedDescription)
            return
        }

        print("📱 iPhone WCSession activated:", activationState.rawValue)

        if let pendingFlight {
            print("📱 Syncing pending flight after activation")
            syncTrackedFlight(pendingFlight)
            self.pendingFlight = nil
        } else {
            let savedFlight = SavedFlightStore.shared.load()
            print("📱 No pending flight, re-syncing saved flight:", savedFlight?.flightNumber ?? "nil")
            syncTrackedFlight(savedFlight)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}

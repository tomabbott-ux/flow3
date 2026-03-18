import Foundation
import Combine
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var trackedFlight: WatchTrackedFlight?

    private let session = WCSession.default

    private override init() {
        super.init()
        print("⌚️ WatchSessionManager init")
    }

    func activateSession() {
        guard WCSession.isSupported() else {
            print("⌚️ WCSession not supported on watch")
            return
        }

        print("⌚️ Activating watch session")
        session.delegate = self
        session.activate()

        apply(context: session.receivedApplicationContext, source: "initial applicationContext")
    }

    private func apply(context: [String: Any], source: String) {
        print("⌚️ apply(context:) from \(source). Keys:", Array(context.keys))

        guard !context.isEmpty else { return }

        let hasTrackedFlight = (context["hasTrackedFlight"] as? Bool) ?? false

        guard hasTrackedFlight else {
            DispatchQueue.main.async {
                self.trackedFlight = nil
            }
            print("⌚️ No tracked flight in payload")
            return
        }

        guard let data = context["trackedFlightData"] as? Data else {
            DispatchQueue.main.async {
                self.trackedFlight = nil
            }
            print("⌚️ trackedFlightData missing")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(WatchTrackedFlight.self, from: data)
            DispatchQueue.main.async {
                self.trackedFlight = decoded
            }
            print("⌚️ Watch received tracked flight:", decoded.flightNumber)
        } catch {
            DispatchQueue.main.async {
                self.trackedFlight = nil
            }
            print("⌚️ Watch decode error:", error.localizedDescription)
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("⌚️ Watch WCSession activation error:", error.localizedDescription)
        } else {
            print("⌚️ Watch WCSession activated:", activationState.rawValue)
        }

        apply(context: session.receivedApplicationContext, source: "activationDidComplete")
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("⌚️ didReceiveApplicationContext")
        apply(context: applicationContext, source: "didReceiveApplicationContext")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚️ didReceiveMessage")
        apply(context: message, source: "didReceiveMessage")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("⌚️ didReceiveUserInfo")
        apply(context: userInfo, source: "didReceiveUserInfo")
    }
}

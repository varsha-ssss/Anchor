import SwiftUI
import WatchConnectivity

@main
struct AnchorWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

class WatchAppDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate {
    func applicationDidFinishLaunching() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[Watch] WCSession activated: \(activationState.rawValue)")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["messageType"] as? String else { return }

        switch type {
        case "emergency_cancelled":
            DispatchQueue.main.async {
                WatchHealthMonitor.shared.fallDetected = false
            }
        case "monitoring_started":
            let types = (message["addictionTypes"] as? [String] ?? []).compactMap(AddictionType.init(rawValue:))
            DispatchQueue.main.async {
                if !types.isEmpty { WatchHealthMonitor.shared.activeAddictionTypes = types }
                WatchHealthMonitor.shared.startMonitoring()
            }
        case "monitoring_stopped":
            DispatchQueue.main.async {
                WatchHealthMonitor.shared.stopMonitoring()
            }
        case "contacts_updated":
            break
        default:
            break
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        self.session(session, didReceiveMessage: userInfo)
    }
}

import Foundation
import Combine
import WatchConnectivity

enum WatchMessage: String {
    case crisisDetected = "crisis_detected"
    case vitalsUpdate = "vitals_update"
    case crisisTriggered = "crisis_triggered"
    case emergencyCancelled = "emergency_cancelled"
    case contactsUpdated = "contacts_updated"
    case monitoringStarted = "monitoring_started"
    case monitoringStopped = "monitoring_stopped"
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isWatchReachable = false
    @Published var latestVitals: [String: Any] = [:]
    @Published var crisisAlert: Bool = false

    var onCrisisDetected: (([String: Any]) -> Void)?
    var onVitalsUpdate: (([String: Any]) -> Void)?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendMessage(_ type: WatchMessage, data: [String: Any] = [:]) {
        guard WCSession.default.isReachable else {
            var payload = data
            payload["messageType"] = type.rawValue
            WCSession.default.transferUserInfo(payload)
            return
        }
        var payload = data
        payload["messageType"] = type.rawValue
        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("WatchConnectivity send error: \(error.localizedDescription)")
        }
    }

    func sendEmergencyContacts(_ contacts: [[String: String]]) {
        sendMessage(.contactsUpdated, data: ["contacts": contacts])
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleMessage(userInfo)
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let typeStr = message["messageType"] as? String,
              let type = WatchMessage(rawValue: typeStr) else { return }

        DispatchQueue.main.async {
            switch type {
            case .crisisDetected:
                self.crisisAlert = true
                self.onCrisisDetected?(message)
            case .vitalsUpdate:
                self.latestVitals = message
                self.onVitalsUpdate?(message)
            case .emergencyCancelled:
                self.crisisAlert = false
            default:
                break
            }
        }
    }
}

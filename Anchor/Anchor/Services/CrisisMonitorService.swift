import Foundation
import Combine

class CrisisMonitorService: ObservableObject {
    static let shared = CrisisMonitorService()

    private let algorithm = CrisisAlgorithm()
    private let healthKit = HealthKitManager.shared

    @Published var isMonitoring = false
    @Published var currentRisk: CrisisRiskLevel = .normal
    @Published var currentScore: Double = 0
    @Published var latestAssessment: CrisisAssessment?
    @Published var fallDetected = false

    var activeAddictionTypes: [AddictionType] = []

    var onCriticalRisk: ((CrisisAssessment) -> Void)?

    func startMonitoring(for types: [AddictionType]) {
        guard !isMonitoring else { return }
        guard !types.isEmpty else {
            print("[CrisisMonitor] No addiction types to monitor")
            return
        }

        isMonitoring = true
        activeAddictionTypes = types

        // Ask up front so no permission prompt can appear in the middle of an emergency.
        EmergencyService.requestNotificationPermission()
        LocationProvider.shared.requestPermission()

        // Judge each new reading as it arrives instead of re-checking old values on a timer.
        healthKit.onNewVitals = { [weak self] in self?.performAssessment() }
        healthKit.startMonitoring()

        WatchConnectivityManager.shared.sendMessage(.monitoringStarted, data: [
            "addictionTypes": types.map(\.rawValue)
        ])

        print("[CrisisMonitor] Monitoring started for: \(types.map(\.displayName).joined(separator: ", "))")
    }

    func stopMonitoring() {
        isMonitoring = false
        healthKit.onNewVitals = nil
        healthKit.stopMonitoring()
        algorithm.reset()
        currentRisk = .normal
        currentScore = 0
        latestAssessment = nil
        fallDetected = false
        WatchConnectivityManager.shared.sendMessage(.monitoringStopped)
        print("[CrisisMonitor] Monitoring stopped")
    }

    private func performAssessment() {
        let snapshot = healthKit.freshSnapshot(fallDetected: fallDetected)
        fallDetected = false

        guard let assessment = algorithm.assess(snapshot, for: activeAddictionTypes) else { return }

        currentRisk = assessment.riskLevel
        currentScore = assessment.score
        latestAssessment = assessment

        if assessment.shouldCallEmergency {
            onCriticalRisk?(assessment)
        }
    }

    func reportFall() {
        fallDetected = true
        performAssessment()
    }

    /// The Watch runs the same algorithm on its live heart-rate stream and tells the phone when it
    /// finds a crisis.
    func reportWatchCrisis(data: [String: Any]) {
        let type = (data["addictionType"] as? String).flatMap(AddictionType.init(rawValue:))
            ?? activeAddictionTypes.first ?? .drugs
        let triggers = (data["triggers"] as? [String]).map { $0.map { "Apple Watch: \($0)" } }
            ?? ["Crisis detected by Apple Watch"]
        let score = data["score"] as? Double ?? 100

        let assessment = CrisisAssessment(
            riskLevel: .critical,
            score: score,
            triggers: triggers,
            shouldCallEmergency: true,
            timestamp: Date(),
            addictionType: type
        )
        currentRisk = .critical
        currentScore = score
        latestAssessment = assessment
        onCriticalRisk?(assessment)
    }
}

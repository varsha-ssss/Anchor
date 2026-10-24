import Foundation
import HealthKit
import WatchConnectivity

class WatchHealthMonitor: NSObject, ObservableObject {
    static let shared = WatchHealthMonitor()

    private let healthStore = HKHealthStore()
    private let algorithm = CrisisAlgorithm()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    @Published var heartRate: Double = 0
    @Published var bloodOxygen: Double = 0
    @Published var respiratoryRate: Double = 0
    @Published var isMonitoring = false
    @Published var currentRisk: CrisisRiskLevel = .normal
    @Published var riskScore: Double = 0
    @Published var fallDetected = false

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var oxygenQuery: HKAnchoredObjectQuery?
    private var assessmentTimer: Timer?

    /// When each value was measured, so old readings aren't judged as if they were current.
    private var heartRateDate: Date?
    private var bloodOxygenDate: Date?

    /// Set by the iPhone app when monitoring starts (see `WatchAppDelegate`).
    var activeAddictionTypes: [AddictionType] = [.drugs]

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let types: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [HKQuantityType.workoutType()], read: types)
            return true
        } catch {
            print("[WatchMonitor] Auth error: \(error)")
            return false
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        startWorkoutSession()
        startHeartRateQuery()
        startOxygenQuery()

        assessmentTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.runAssessment()
        }

        print("[WatchMonitor] Started monitoring")
    }

    func stopMonitoring() {
        isMonitoring = false
        assessmentTimer?.invalidate()
        assessmentTimer = nil

        if let query = heartRateQuery { healthStore.stop(query) }
        if let query = oxygenQuery { healthStore.stop(query) }

        workoutSession?.end()
        workoutSession = nil
        algorithm.reset()

        DispatchQueue.main.async {
            self.currentRisk = .normal
            self.riskScore = 0
        }

        print("[WatchMonitor] Stopped monitoring")
    }

    private func startWorkoutSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self

            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("[WatchMonitor] Builder error: \(error)")
                }
            }
        } catch {
            print("[WatchMonitor] Workout session error: \(error)")
        }
    }

    private func startHeartRateQuery() {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let query = HKAnchoredObjectQuery(
            type: hrType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRate(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRate(samples)
        }
        heartRateQuery = query
        healthStore.execute(query)
    }

    private func processHeartRate(_ samples: [HKSample]?) {
        guard let sample = (samples as? [HKQuantitySample])?.max(by: { $0.endDate < $1.endDate }) else { return }
        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        DispatchQueue.main.async {
            self.heartRate = bpm
            self.heartRateDate = sample.endDate
        }
    }

    private func startOxygenQuery() {
        let o2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let query = HKAnchoredObjectQuery(
            type: o2Type, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processOxygen(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processOxygen(samples)
        }
        oxygenQuery = query
        healthStore.execute(query)
    }

    private func processOxygen(_ samples: [HKSample]?) {
        guard let sample = (samples as? [HKQuantitySample])?.max(by: { $0.endDate < $1.endDate }) else { return }
        let spo2 = sample.quantity.doubleValue(for: .percent()) * 100
        DispatchQueue.main.async {
            self.bloodOxygen = spo2
            self.bloodOxygenDate = sample.endDate
        }
    }

    private func runAssessment() {
        let now = Date()
        func fresh(_ value: Double, _ date: Date?, maxAge: TimeInterval) -> Double? {
            guard value > 0, let date, now.timeIntervalSince(date) <= maxAge else { return nil }
            return value
        }
        let snapshot = VitalSnapshot(
            heartRate: fresh(heartRate, heartRateDate, maxAge: 2 * 60),
            bloodOxygen: fresh(bloodOxygen, bloodOxygenDate, maxAge: 15 * 60),
            respiratoryRate: nil, // watchOS doesn't stream breathing rate outside of sleep
            fallDetected: fallDetected,
            isUnresponsive: false,
            timestamp: now
        )

        guard let assessment = algorithm.assess(snapshot, for: activeAddictionTypes) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentRisk = assessment.riskLevel
            self?.riskScore = assessment.score

            if self?.fallDetected == true { self?.fallDetected = false }
        }

        sendVitalsToPhone()

        if assessment.shouldCallEmergency {
            sendCrisisAlert(assessment)
        }
    }

    private func sendVitalsToPhone() {
        guard WCSession.default.isReachable else { return }

        let data: [String: Any] = [
            "messageType": "vitals_update",
            "heartRate": heartRate,
            "bloodOxygen": bloodOxygen,
            "respiratoryRate": respiratoryRate,
            "riskLevel": currentRisk.rawValue,
            "riskScore": riskScore,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(data, replyHandler: nil) { error in
            print("[WatchMonitor] Send error: \(error)")
        }
    }

    private func sendCrisisAlert(_ assessment: CrisisAssessment) {
        let data: [String: Any] = [
            "messageType": "crisis_detected",
            "score": assessment.score,
            "triggers": assessment.triggers,
            "addictionType": assessment.addictionType.rawValue,
            "heartRate": heartRate,
            "bloodOxygen": bloodOxygen,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.transferUserInfo(data)

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(data, replyHandler: nil, errorHandler: nil)
        }

        print("[WatchMonitor] CRISIS ALERT SENT - Score: \(assessment.score)")
    }

    func reportFall() {
        fallDetected = true
        runAssessment()
    }
}

extension WatchHealthMonitor: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("[WatchMonitor] Workout state: \(fromState.rawValue) -> \(toState.rawValue)")
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[WatchMonitor] Workout error: \(error)")
    }
}

extension WatchHealthMonitor: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let qType = type as? HKQuantityType else { continue }

            let stats = workoutBuilder.statistics(for: qType)

            switch qType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                if let hr = stats?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    let date = stats?.mostRecentQuantityDateInterval()?.end ?? Date()
                    DispatchQueue.main.async {
                        self.heartRate = hr
                        self.heartRateDate = date
                    }
                }
            case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
                if let spo2 = stats?.mostRecentQuantity()?.doubleValue(for: .percent()) {
                    let date = stats?.mostRecentQuantityDateInterval()?.end ?? Date()
                    DispatchQueue.main.async {
                        self.bloodOxygen = spo2 * 100
                        self.bloodOxygenDate = date
                    }
                }
            default:
                break
            }
        }
    }
}

import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var oxygenQuery: HKAnchoredObjectQuery?
    private var respiratoryQuery: HKAnchoredObjectQuery?
    private var temperatureQuery: HKAnchoredObjectQuery?
    private var observerQueries: [HKObserverQuery] = []

    @Published var currentMetrics = HealthMetrics.empty
    @Published var isAuthorized = false
    @Published var heartRateHistory: [(Date, Double)] = []
    @Published var oxygenHistory: [(Date, Double)] = []

    // main thread, also fires on background wakes
    var onNewVitals: (() -> Void)?

    // max age to count as current. HR streams every few sec, SpO2/breathing are way less often
    struct Freshness {
        static let heartRate: TimeInterval = 5 * 60
        static let bloodOxygen: TimeInterval = 15 * 60
        static let respiratoryRate: TimeInterval = 15 * 60
    }

    private let heartRateType = HKQuantityType(.heartRate)
    private let oxygenType = HKQuantityType(.oxygenSaturation)
    private let respiratoryType = HKQuantityType(.respiratoryRate)
    private let temperatureType = HKQuantityType(.appleSleepingWristTemperature)

    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    private var crisisTypes: [HKQuantityType] { [heartRateType, oxygenType, respiratoryType] }

    private var readTypes: Set<HKSampleType> {
        Set(crisisTypes + [temperatureType])
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] Health data not available on this device")
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            await MainActor.run { self.isAuthorized = true }
            print("[HealthKit] Authorization granted")
            return true
        } catch {
            print("[HealthKit] Auth error: \(error.localizedDescription)")
            return false
        }
    }

    func startMonitoring() {
        stopMonitoring()

        heartRateQuery = startAnchoredQuery(for: heartRateType) { [weak self] value, date in
            self?.currentMetrics.heartRate = value
            self?.currentMetrics.heartRateDate = date
            self?.appendHistory(\.heartRateHistory, date, value)
        }
        oxygenQuery = startAnchoredQuery(for: oxygenType, scale: 100) { [weak self] value, date in
            self?.currentMetrics.bloodOxygen = value
            self?.currentMetrics.bloodOxygenDate = date
            self?.appendHistory(\.oxygenHistory, date, value)
        }
        respiratoryQuery = startAnchoredQuery(for: respiratoryType) { [weak self] value, date in
            self?.currentMetrics.respiratoryRate = value
            self?.currentMetrics.respiratoryRateDate = date
        }
        temperatureQuery = startAnchoredQuery(for: temperatureType, unit: .degreeCelsius(), notify: false) { [weak self] value, _ in
            self?.currentMetrics.wristTemperature = value
        }

        startBackgroundDelivery()
        print("[HealthKit] Started all vital monitors")
    }

    func stopMonitoring() {
        ([heartRateQuery, oxygenQuery, respiratoryQuery, temperatureQuery].compactMap { $0 } + observerQueries)
            .forEach { healthStore.stop($0) }
        heartRateQuery = nil
        oxygenQuery = nil
        respiratoryQuery = nil
        temperatureQuery = nil
        observerQueries = []
        healthStore.disableAllBackgroundDelivery { _, _ in }
    }

    // drop stale readings so we don't keep re-judging old data
    func freshSnapshot(fallDetected: Bool, now: Date = Date()) -> VitalSnapshot {
        func fresh(_ value: Double?, _ date: Date?, _ maxAge: TimeInterval) -> Double? {
            guard let value, let date, now.timeIntervalSince(date) <= maxAge else { return nil }
            return value
        }
        let m = currentMetrics
        return VitalSnapshot(
            heartRate: fresh(m.heartRate, m.heartRateDate, Freshness.heartRate),
            bloodOxygen: fresh(m.bloodOxygen, m.bloodOxygenDate, Freshness.bloodOxygen),
            respiratoryRate: fresh(m.respiratoryRate, m.respiratoryRateDate, Freshness.respiratoryRate),
            fallDetected: fallDetected,
            isUnresponsive: false,
            timestamp: now
        )
    }


    private func appendHistory(_ history: ReferenceWritableKeyPath<HealthKitManager, [(Date, Double)]>, _ date: Date, _ value: Double) {
        self[keyPath: history].append((date, value))
        if self[keyPath: history].count > 100 { self[keyPath: history].removeFirst() }
    }

    private func startAnchoredQuery(
        for type: HKQuantityType,
        unit: HKUnit? = nil,
        scale: Double = 1,
        notify: Bool = true,
        apply: @escaping (Double, Date) -> Void
    ) -> HKAnchoredObjectQuery {
        let unit = unit ?? (type == oxygenType ? .percent() : bpmUnit)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .hour, value: -1, to: Date()),
            end: nil,
            options: .strictStartDate
        )

        let handler: ([HKSample]?, Error?) -> Void = { [weak self] samples, error in
            if let error {
                print("[HealthKit] Query error for \(type.identifier): \(error.localizedDescription)")
                return
            }
            guard let newest = (samples as? [HKQuantitySample])?.max(by: { $0.endDate < $1.endDate }) else { return }
            let value = newest.quantity.doubleValue(for: unit) * scale
            DispatchQueue.main.async {
                apply(value, newest.endDate)
                self?.currentMetrics.lastUpdated = Date()
                if notify { self?.onNewVitals?() }
            }
        }

        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, error in
            handler(samples, error)
        }
        query.updateHandler = { _, samples, _, _, error in
            handler(samples, error)
        }
        healthStore.execute(query)
        return query
    }

    // iOS decides how often background delivery actually fires, so this is just a backup.
    // the watch workout session is the real time monitor
    private func startBackgroundDelivery() {
        for type in crisisTypes {
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard let self, error == nil else { completion(); return }
                Task {
                    await self.refreshLatestVitals()
                    completion()
                }
            }
            healthStore.execute(observer)
            observerQueries.append(observer)

            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    print("[HealthKit] Background delivery error for \(type.identifier): \(error.localizedDescription)")
                }
            }
        }
    }

    func refreshLatestVitals() async {
        async let hr = fetchLatest(type: heartRateType, unit: bpmUnit)
        async let spo2 = fetchLatest(type: oxygenType, unit: .percent())
        async let rr = fetchLatest(type: respiratoryType, unit: bpmUnit)
        let (heartRate, oxygen, breathing) = await (hr, spo2, rr)

        await MainActor.run {
            if let heartRate {
                currentMetrics.heartRate = heartRate.value
                currentMetrics.heartRateDate = heartRate.date
            }
            if let oxygen {
                currentMetrics.bloodOxygen = oxygen.value * 100
                currentMetrics.bloodOxygenDate = oxygen.date
            }
            if let breathing {
                currentMetrics.respiratoryRate = breathing.value
                currentMetrics.respiratoryRateDate = breathing.date
            }
            currentMetrics.lastUpdated = Date()
            onNewVitals?()
        }
    }

    private func fetchLatest(type: HKQuantityType, unit: HKUnit) async -> (value: Double, date: Date)? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .hour, value: -1, to: Date()),
            end: Date(), options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: 1, sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    print("[HealthKit] Fetch error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            self.healthStore.execute(query)
        }
    }
}

import Foundation

// used by both the phone and watch targets
//
// NOT a medical device. thresholds are from public guidance, and a critical alert
// needs 2+ separate danger signs so one bad sensor reading can't trigger it.
// sources:
//   AHA "Bradycardia: Slow Heart Rate" - resting HR 60-100, <60 slow, <40 severe
//   MedlinePlus (NIH) "Vital signs" - breathing 12-20/min
//   NIAAA "Understanding the Dangers of Alcohol Overdose" - <8 breaths/min
//   SAMHSA "Opioid Overdose Prevention and Response Toolkit" - slow/stopped breathing, low O2
//   WHO "Pulse Oximetry Training Manual" - SpO2 <90% is hypoxemia, normal 95-100
//   Apple says watch SpO2 isn't for medical use, so SpO2 alone never makes it critical

struct VitalSnapshot {
    let heartRate: Double?
    let bloodOxygen: Double?
    let respiratoryRate: Double?
    let fallDetected: Bool
    let isUnresponsive: Bool
    let timestamp: Date

    var hasAnyVital: Bool {
        heartRate != nil || bloodOxygen != nil || respiratoryRate != nil || fallDetected
    }
}

enum CrisisRiskLevel: Int, Comparable {
    case normal = 0
    case elevated = 1
    case high = 2
    case critical = 3

    static func < (lhs: CrisisRiskLevel, rhs: CrisisRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .high: return "High"
        case .critical: return "CRITICAL"
        }
    }

    var color: String {
        switch self {
        case .normal: return "4ade80"
        case .elevated: return "facc15"
        case .high: return "fb923c"
        case .critical: return "ef4444"
        }
    }
}

struct CrisisAssessment {
    let riskLevel: CrisisRiskLevel
    let score: Double
    let triggers: [String]
    let shouldCallEmergency: Bool
    let timestamp: Date
    let addictionType: AddictionType
}

class CrisisAlgorithm {

    struct Thresholds {
        // bradycardia (AHA: <60 slow, <40 severe)
        static let heartRateCritical: Double = 40
        static let heartRateWarning: Double = 50
        static let heartRateElevated: Double = 55

        // WHO: <90% = hypoxemia
        static let bloodOxygenCritical: Double = 85
        static let bloodOxygenWarning: Double = 90
        static let bloodOxygenElevated: Double = 93

        // normal 12-20, NIAAA says <8 is an alcohol overdose sign
        static let respiratoryRateCritical: Double = 6
        static let respiratoryRateWarning: Double = 8
        static let respiratoryRateElevated: Double = 10

        // really high HR + other signs can mean alcohol toxicity or withdrawal
        static let heartRateHighCritical: Double = 150
        static let heartRateHighWarning: Double = 130
        static let heartRateHighElevated: Double = 110

        static let nicotineHeartRateCritical: Double = 160
        static let nicotineHeartRateWarning: Double = 140
        static let nicotineRespiratoryLow: Double = 8

        static let criticalScoreThreshold: Double = 70
        static let highScoreThreshold: Double = 45
        static let elevatedScoreThreshold: Double = 25

        static let minimumSignsForCritical = 2
    }

    struct Weights {
        static let heartRate: Double = 25
        static let bloodOxygen: Double = 30
        static let respiratoryRate: Double = 25
        static let fallDetected: Double = 10
        static let unresponsive: Double = 15
    }

    private struct Tally {
        var score: Double = 0
        var triggers: [String] = []
        var signs = 0
        var criticalSigns = 0

        // points >= fullWeight means that vital is at its critical level
        mutating func add(_ points: Double, _ trigger: String, fullWeight: Double? = nil) {
            score += points
            triggers.append(trigger)
            signs += 1
            if let fullWeight, points >= fullWeight { criticalSigns += 1 }
        }
    }

    private var recentSnapshots: [VitalSnapshot] = []
    private let maxSnapshotHistory = 30

    // returns the worst result across all tracked addictions, nil if no fresh data
    func assess(_ snapshot: VitalSnapshot, for addictionTypes: [AddictionType]) -> CrisisAssessment? {
        guard snapshot.hasAnyVital, !addictionTypes.isEmpty else { return nil }

        recentSnapshots.append(snapshot)
        if recentSnapshots.count > maxSnapshotHistory {
            recentSnapshots.removeFirst()
        }
        let declineBonus = assessRapidDecline()

        return addictionTypes
            .map { assess(snapshot, for: $0, declineBonus: declineBonus) }
            .max { $0.score < $1.score }
    }

    private func assess(_ snapshot: VitalSnapshot, for addictionType: AddictionType, declineBonus: Double) -> CrisisAssessment {
        var tally = Tally()

        switch addictionType {
        case .drugs: scoreDrugs(snapshot, &tally)
        case .alcohol: scoreAlcohol(snapshot, &tally)
        case .nicotine: scoreNicotine(snapshot, &tally)
        }

        scoreFallAndUnresponsive(snapshot, &tally)

        if addictionType != .nicotine, declineBonus > 0 {
            tally.score += declineBonus
            tally.triggers.append("Vitals falling quickly over the last few minutes")
        }

        return buildAssessment(tally, type: addictionType, timestamp: snapshot.timestamp)
    }

    // MARK: - Per-addiction scoring

    private func scoreDrugs(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        scoreLowHeartRate(snapshot, &tally)
        scoreBloodOxygen(snapshot, &tally)
        scoreSlowBreathing(snapshot, &tally)
    }

    private func scoreAlcohol(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        if let hr = snapshot.heartRate {
            if hr < Thresholds.heartRateCritical {
                tally.add(Weights.heartRate, "Heart rate critically low: \(Int(hr)) bpm", fullWeight: Weights.heartRate)
            } else if hr < Thresholds.heartRateWarning {
                tally.add(Weights.heartRate * 0.7, "Heart rate dangerously low: \(Int(hr)) bpm")
            } else if hr > Thresholds.heartRateHighCritical {
                tally.add(Weights.heartRate, "Heart rate critically high: \(Int(hr)) bpm", fullWeight: Weights.heartRate)
            } else if hr > Thresholds.heartRateHighWarning {
                tally.add(Weights.heartRate * 0.7, "Heart rate dangerously high: \(Int(hr)) bpm")
            } else if hr > Thresholds.heartRateHighElevated {
                tally.add(Weights.heartRate * 0.3, "Heart rate high: \(Int(hr)) bpm")
            }
        }
        scoreBloodOxygen(snapshot, &tally)
        scoreSlowBreathing(snapshot, &tally)
    }

    private func scoreNicotine(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        if let hr = snapshot.heartRate {
            if hr > Thresholds.nicotineHeartRateCritical {
                tally.add(Weights.heartRate, "Heart rate critically high: \(Int(hr)) bpm", fullWeight: Weights.heartRate)
            } else if hr > Thresholds.nicotineHeartRateWarning {
                tally.add(Weights.heartRate * 0.7, "Heart rate dangerously high: \(Int(hr)) bpm")
            } else if hr < Thresholds.heartRateCritical {
                tally.add(Weights.heartRate, "Heart rate critically low: \(Int(hr)) bpm", fullWeight: Weights.heartRate)
            }
        }

        if let rr = snapshot.respiratoryRate, rr < Thresholds.nicotineRespiratoryLow {
            tally.add(Weights.respiratoryRate * 0.5, "Breathing rate low: \(Int(rr)) breaths/min")
        }

        if let spo2 = snapshot.bloodOxygen {
            if spo2 < Thresholds.bloodOxygenCritical {
                tally.add(Weights.bloodOxygen, "Blood oxygen critically low: \(Int(spo2))%", fullWeight: Weights.bloodOxygen)
            } else if spo2 < Thresholds.bloodOxygenWarning {
                tally.add(Weights.bloodOxygen * 0.5, "Blood oxygen low: \(Int(spo2))%")
            }
        }
    }

    // MARK: - Shared vital checks

    private func scoreLowHeartRate(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        guard let hr = snapshot.heartRate else { return }
        if hr < Thresholds.heartRateCritical {
            tally.add(Weights.heartRate, "Heart rate critically low: \(Int(hr)) bpm", fullWeight: Weights.heartRate)
        } else if hr < Thresholds.heartRateWarning {
            tally.add(Weights.heartRate * 0.7, "Heart rate dangerously low: \(Int(hr)) bpm")
        } else if hr < Thresholds.heartRateElevated {
            tally.add(Weights.heartRate * 0.3, "Heart rate below normal: \(Int(hr)) bpm")
        }
    }

    private func scoreBloodOxygen(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        guard let spo2 = snapshot.bloodOxygen else { return }
        if spo2 < Thresholds.bloodOxygenCritical {
            tally.add(Weights.bloodOxygen, "Blood oxygen critically low: \(Int(spo2))%", fullWeight: Weights.bloodOxygen)
        } else if spo2 < Thresholds.bloodOxygenWarning {
            tally.add(Weights.bloodOxygen * 0.7, "Blood oxygen dangerously low: \(Int(spo2))%")
        } else if spo2 < Thresholds.bloodOxygenElevated {
            tally.add(Weights.bloodOxygen * 0.3, "Blood oxygen below normal: \(Int(spo2))%")
        }
    }

    private func scoreSlowBreathing(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        guard let rr = snapshot.respiratoryRate else { return }
        if rr < Thresholds.respiratoryRateCritical {
            tally.add(Weights.respiratoryRate, "Breathing critically slow: \(Int(rr)) breaths/min", fullWeight: Weights.respiratoryRate)
        } else if rr < Thresholds.respiratoryRateWarning {
            tally.add(Weights.respiratoryRate * 0.7, "Breathing dangerously slow: \(Int(rr)) breaths/min")
        } else if rr < Thresholds.respiratoryRateElevated {
            tally.add(Weights.respiratoryRate * 0.3, "Breathing below normal: \(Int(rr)) breaths/min")
        }
    }

    private func scoreFallAndUnresponsive(_ snapshot: VitalSnapshot, _ tally: inout Tally) {
        if snapshot.fallDetected {
            tally.add(Weights.fallDetected, "Fall detected")
        }
        if snapshot.isUnresponsive {
            tally.add(Weights.unresponsive, "No movement detected - possibly unresponsive")
        }
    }


    private func buildAssessment(_ tally: Tally, type: AddictionType, timestamp: Date) -> CrisisAssessment {
        let clampedScore = min(100, max(0, tally.score))

        var riskLevel: CrisisRiskLevel
        if clampedScore >= Thresholds.criticalScoreThreshold {
            riskLevel = .critical
        } else if clampedScore >= Thresholds.highScoreThreshold {
            riskLevel = .high
        } else if clampedScore >= Thresholds.elevatedScoreThreshold {
            riskLevel = .elevated
        } else {
            riskLevel = .normal
        }

        // one sensor alone isn't enough (loose band = bad SpO2 readings)
        if riskLevel == .critical && tally.signs < Thresholds.minimumSignsForCritical {
            riskLevel = .high
        }
        // 2 vitals both critical counts even w/o breathing rate, since the watch
        // can't measure that while you're awake
        if tally.criticalSigns >= Thresholds.minimumSignsForCritical {
            riskLevel = .critical
        }

        return CrisisAssessment(
            riskLevel: riskLevel,
            score: clampedScore,
            triggers: tally.triggers,
            shouldCallEmergency: riskLevel == .critical,
            timestamp: timestamp,
            addictionType: type
        )
    }

    // bonus points if HR or O2 dropped fast vs earlier readings
    private func assessRapidDecline() -> Double {
        guard recentSnapshots.count >= 6 else { return 0 }

        let recent = Array(recentSnapshots.suffix(6))
        let older = Array(recentSnapshots.prefix(min(6, recentSnapshots.count - 6)))
        guard !older.isEmpty else { return 0 }

        var bonus: Double = 0

        if let avgRecent = recent.compactMap(\.heartRate).average,
           let avgOlder = older.compactMap(\.heartRate).average {
            let drop = avgOlder - avgRecent
            if drop > 15 { bonus += 10 }
            else if drop > 8 { bonus += 5 }
        }

        if let avgRecent = recent.compactMap(\.bloodOxygen).average,
           let avgOlder = older.compactMap(\.bloodOxygen).average {
            let drop = avgOlder - avgRecent
            if drop > 5 { bonus += 10 }
            else if drop > 3 { bonus += 5 }
        }

        return bonus
    }

    func reset() {
        recentSnapshots.removeAll()
    }
}

extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

import Foundation
import Combine
import SwiftUI

struct UserData: Codable, Identifiable {
    var id = UUID()
    var name: String
    var age: Int
    var addictionTypes: [AddictionType]
    var sobrietyDates: [AddictionType: Date]
    var usageDurations: [AddictionType: String]
    var usageFrequencies: [AddictionType: String]
    var attendsMeetings: String
    var motivation: String
    var reminderFrequency: String
    var contacts: [EmergencyContact]
    var additionalInfo: String
    var appStartDate: Date = Date()

    var ageGroup: String {
        if age < 18 { return "12-18" }
        if age < 25 { return "18-25" }
        if age < 45 { return "25-45" }
        if age < 70 { return "45-70" }
        return "70+"
    }

    var daysUsingApp: Int {
        Calendar.current.dateComponents([.day], from: appStartDate, to: Date()).day ?? 0
    }

    func daysSober(for type: AddictionType) -> Int {
        guard let date = sobrietyDates[type] else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    var primaryAddiction: AddictionType {
        addictionTypes.first ?? .drugs
    }

    var totalMoneySaved: Double {
        addictionTypes.reduce(0) { total, type in
            total + moneySaved(for: type)
        }
    }

    func moneySaved(for type: AddictionType) -> Double {
        Double(daysSober(for: type)) * type.estimatedDailyCost(usageFrequency: usageFrequencies[type])
    }

    static let empty = UserData(
        name: "", age: 25, addictionTypes: [],
        sobrietyDates: [:], usageDurations: [:], usageFrequencies: [:],
        attendsMeetings: "", motivation: "",
        reminderFrequency: "Daily", contacts: [], additionalInfo: ""
    )
}

struct EmergencyContact: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var phone: String

    var isValid: Bool { !name.isEmpty && !phone.isEmpty }

    var cleanPhone: String {
        phone.filter { $0.isNumber || $0 == "+" }
    }
}

struct HealthMetrics: Codable {
    var heartRate: Double?
    var bloodOxygen: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var fallDetected: Bool
    var lastUpdated: Date
    var heartRateDate: Date?
    var bloodOxygenDate: Date?
    var respiratoryRateDate: Date?

    static let empty = HealthMetrics(
        heartRate: nil, bloodOxygen: nil, respiratoryRate: nil,
        wristTemperature: nil, fallDetected: false, lastUpdated: Date()
    )

    var heartRateStatus: VitalStatus {
        guard let hr = heartRate else { return .unknown }
        if hr < 40 { return .critical }
        if hr < 50 { return .warning }
        if hr < 55 { return .elevated }
        return .normal
    }

    var bloodOxygenStatus: VitalStatus {
        guard let spo2 = bloodOxygen else { return .unknown }
        if spo2 < 85 { return .critical }
        if spo2 < 90 { return .warning }
        if spo2 < 93 { return .elevated }
        return .normal
    }

    var respiratoryRateStatus: VitalStatus {
        guard let rr = respiratoryRate else { return .unknown }
        if rr < 6 { return .critical }
        if rr < 8 { return .warning }
        if rr < 10 { return .elevated }
        return .normal
    }

    var heartRateElevatedStatus: VitalStatus {
        guard let hr = heartRate else { return .unknown }
        if hr > 120 { return .critical }
        if hr > 100 { return .warning }
        if hr > 90 { return .elevated }
        return .normal
    }
}

enum VitalStatus {
    case normal, elevated, warning, critical, unknown

    var color: String {
        switch self {
        case .normal: return "4ade80"
        case .elevated: return "facc15"
        case .warning: return "fb923c"
        case .critical: return "ef4444"
        case .unknown: return "94a3b8"
        }
    }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .unknown: return "No data"
        }
    }
}

struct MoodEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var mood: Int // 1-5
}

struct JournalEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var content: String
}

struct CravingEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var intensity: Int // 1-5
    var trigger: String
    var notes: String
    var addictionType: AddictionType?
}

struct SelfMessage: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var content: String
}

struct DailyGoal: Codable, Identifiable {
    var id = UUID()
    var text: String
    var completed: Bool = false
    var dateCreated: Date = Date()
}

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class DataStore: ObservableObject {
    @Published var userData: UserData? {
        didSet { save("anchor_user", userData) }
    }
    @Published var moods: [MoodEntry] = [] {
        didSet { save("anchor_moods", moods) }
    }
    @Published var journal: [JournalEntry] = [] {
        didSet { save("anchor_journal", journal) }
    }
    @Published var cravings: [CravingEntry] = [] {
        didSet { save("anchor_cravings", cravings) }
    }
    @Published var selfMessages: [SelfMessage] = [] {
        didSet { save("anchor_messages", selfMessages) }
    }
    @Published var dailyGoals: [DailyGoal] = [] {
        didSet { save("anchor_goals", dailyGoals) }
    }
    @Published var isMonitoringEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isMonitoringEnabled, forKey: "anchor_monitoring") }
    }

    init() {
        userData = load("anchor_user")
        moods = load("anchor_moods") ?? []
        journal = load("anchor_journal") ?? []
        cravings = load("anchor_cravings") ?? []
        selfMessages = load("anchor_messages") ?? []
        dailyGoals = load("anchor_goals") ?? []
        isMonitoringEnabled = UserDefaults.standard.bool(forKey: "anchor_monitoring")
        cleanupOldGoals()
    }

    private func save<T: Codable>(_ key: String, _ value: T) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Codable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func cleanupOldGoals() {
        let today = Calendar.current.startOfDay(for: Date())
        dailyGoals.removeAll { Calendar.current.startOfDay(for: $0.dateCreated) < today }
    }

    func reset() {
        userData = nil
        moods = []
        journal = []
        cravings = []
        selfMessages = []
        dailyGoals = []
        isMonitoringEnabled = false
    }
}

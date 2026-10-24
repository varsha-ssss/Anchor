import Foundation

enum AddictionType: String, Codable, CaseIterable, Identifiable, Hashable {
    case nicotine
    case alcohol
    case drugs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nicotine: return "Nicotine"
        case .alcohol: return "Alcohol"
        case .drugs: return "Drugs"
        }
    }

    var icon: String {
        switch self {
        case .nicotine: return "smoke.fill"
        case .alcohol: return "wineglass.fill"
        case .drugs: return "pills.fill"
        }
    }

    var emoji: String {
        switch self {
        case .nicotine: return "🚬"
        case .alcohol: return "🍷"
        case .drugs: return "💊"
        }
    }

    var crisisLabel: String {
        switch self {
        case .nicotine: return "HEALTH ALERT"
        case .alcohol: return "POSSIBLE ALCOHOL EMERGENCY"
        case .drugs: return "POSSIBLE OVERDOSE"
        }
    }

    /// Spoken to the user at the start of the 30-second check.
    var crisisSpeechAlert: String {
        switch self {
        case .nicotine: return "Health alert. Are you okay? Tap I'm okay on your phone."
        case .alcohol: return "Alcohol emergency alert. Are you okay? Tap I'm okay on your phone."
        case .drugs: return "Possible overdose alert. Are you okay? Tap I'm okay on your phone."
        }
    }

    /// Spoken on repeat once the user hasn't responded, aimed at anyone who can hear the phone.
    var bystanderSpeech: String {
        switch self {
        case .nicotine:
            return "This person may need medical help and is not responding. Please tap Call 911 on their phone, and stay with them."
        case .alcohol:
            return "This person may have alcohol poisoning and is not responding. Please tap Call 911 on their phone. Turn them on their side and do not leave them alone."
        case .drugs:
            return "This person may be overdosing and is not responding. Please tap Call 911 on their phone. If you have naloxone, also called Narcan, give it now."
        }
    }

    /// On-screen version of `bystanderSpeech`. Steps follow SAMHSA (overdose) and NIAAA (alcohol) guidance.
    var bystanderInstructions: String {
        switch self {
        case .nicotine:
            return "No response from the user.\nIf you're nearby: call 911, check that they're breathing, and stay with them."
        case .alcohol:
            return "No response from the user.\nIf you're nearby: call 911. Turn them on their side so they can't choke, keep them warm, and don't leave them alone."
        case .drugs:
            return "No response from the user.\nIf you're nearby: call 911. Give naloxone (Narcan) if you have it. Turn them on their side and stay with them.\nCalifornia's Good Samaritan law protects people who call 911 for an overdose."
        }
    }

    /// Flat fallback used when no usage-frequency answer was collected (e.g. data saved before this existed).
    var moneySavedPerDay: Double {
        switch self {
        case .nicotine: return 7.50
        case .alcohol: return 8.00
        case .drugs: return 10.50
        }
    }

    /// Rough US-average daily cost per `usageFrequencyOptions` answer, keyed to what the user reported at onboarding.
    private static let dailyCostByFrequency: [AddictionType: [String: Double]] = [
        .nicotine: [
            "1-5 cigarettes/day": 1.50,
            "Half a pack/day": 4.50,
            "1 pack/day": 9.00,
            "More than 1 pack/day": 13.50,
            "Vape throughout the day": 6.00,
        ],
        .alcohol: [
            "1-3 drinks/week": 1.75,
            "4-7 drinks/week": 4.75,
            "8-14 drinks/week": 9.50,
            "15+ drinks/week": 15.50,
            "Daily heavy drinking": 24.00,
        ],
        .drugs: [
            "Daily": 15.00,
            "Several times a week": 10.00,
            "Weekly": 4.00,
            "Occasionally": 2.00,
        ],
    ]

    func estimatedDailyCost(usageFrequency: String?) -> Double {
        guard let usageFrequency, let rate = Self.dailyCostByFrequency[self]?[usageFrequency] else {
            return moneySavedPerDay
        }
        return rate
    }

    var moneyLabel: String {
        switch self {
        case .nicotine: return "cigarettes/vapes"
        case .alcohol: return "alcohol"
        case .drugs: return "substances"
        }
    }

    var usageDurationQuestion: String {
        switch self {
        case .nicotine: return "How long have you been using nicotine?"
        case .alcohol: return "How long have you been drinking?"
        case .drugs: return "How long did you use drugs before starting recovery?"
        }
    }

    var usageFrequencyQuestion: String {
        switch self {
        case .nicotine: return "How much do you typically use per day?"
        case .alcohol: return "How much do you typically drink per week?"
        case .drugs: return "How often were you using before recovery?"
        }
    }

    var usageFrequencyOptions: [String] {
        switch self {
        case .nicotine: return ["1-5 cigarettes/day", "Half a pack/day", "1 pack/day", "More than 1 pack/day", "Vape throughout the day"]
        case .alcohol: return ["1-3 drinks/week", "4-7 drinks/week", "8-14 drinks/week", "15+ drinks/week", "Daily heavy drinking"]
        case .drugs: return ["Daily", "Several times a week", "Weekly", "Occasionally"]
        }
    }

    var usageDurationOptions: [String] {
        switch self {
        case .nicotine: return ["Less than 1 year", "1-3 years", "3-5 years", "5-10 years", "10+ years"]
        case .alcohol: return ["Less than 1 year", "1-3 years", "3-5 years", "5-10 years", "10+ years"]
        case .drugs: return ["Less than 1 year", "1-3 years", "3-5 years", "5-10 years", "10+ years"]
        }
    }

    var sobrietyDateQuestion: String {
        switch self {
        case .nicotine: return "When did you quit nicotine? I'll track your body's recovery from day one."
        case .alcohol: return "When did you stop drinking? Even if it's today — that counts."
        case .drugs: return "When did you get clean? No judgment, just your starting line."
        }
    }

    var meetingsQuestion: String {
        switch self {
        case .nicotine: return "Do you attend any support groups? (QuitNet, Nicotine Anonymous, etc.)"
        case .alcohol: return "Do you attend recovery meetings? (AA, SMART Recovery, etc.)"
        case .drugs: return "Do you attend recovery meetings? (AA, NA, SMART Recovery, etc.)"
        }
    }

    var sobrietyLabel: String {
        switch self {
        case .nicotine: return "Smoke-free for"
        case .alcohol: return "Sober for"
        case .drugs: return "Clean for"
        }
    }

    var totalDaysLabel: String {
        switch self {
        case .nicotine: return "total smoke-free days"
        case .alcohol: return "total sober days"
        case .drugs: return "total clean days"
        }
    }

    var healthDescription: String {
        let alertFlow = "If danger signs show up, Anchor asks \"Are you okay?\" for 30 seconds. If you don't answer, it sounds an alarm and tells anyone nearby how to help, with one-tap buttons to call 911 and text your emergency contacts your location. (iOS requires a tap before any call or text goes out.)"
        let limits = "Apple Watch heart rate is near-continuous while monitoring is on; blood oxygen and breathing rate are measured less often. Anchor is not a medical device and can miss emergencies or raise false alarms — it's an extra layer of safety, not a replacement for people or 911."
        switch self {
        case .nicotine:
            return "Anchor tracks how your heart rate and breathing recover after quitting. " + alertFlow + "\n\n" + limits
        case .alcohol:
            return "Anchor watches your Apple Watch vitals for signs of alcohol poisoning — very slow breathing, low oxygen, or a heart rate that's far too low or high. It only raises a full alert when at least two signs appear together. " + alertFlow + "\n\n" + limits
        case .drugs:
            return "Anchor watches your Apple Watch vitals for the signs of an opioid overdose — slow breathing, falling oxygen, and a dropping heart rate. It only raises a full alert when at least two signs appear together. " + alertFlow + "\n\n" + limits
        }
    }

    var monitoringLabel: String {
        switch self {
        case .nicotine: return "Health Tracking"
        case .alcohol: return "Crisis Monitoring"
        case .drugs: return "Overdose Monitoring"
        }
    }

    var monitoringDescription: String {
        switch self {
        case .nicotine: return "Tracking heart rate and breathing as your body recovers"
        case .alcohol: return "Watching heart rate, blood oxygen & breathing for danger signs"
        case .drugs: return "Watching heart rate, blood oxygen & breathing for danger signs"
        }
    }

    var crisisHotlineName: String {
        switch self {
        case .nicotine: return "National Quitline"
        case .alcohol: return "SAMHSA National Helpline"
        case .drugs: return "SAMHSA National Helpline"
        }
    }

    var crisisHotlineNumber: String {
        switch self {
        case .nicotine: return "1-800-784-8669"
        case .alcohol: return "1-800-662-4357"
        case .drugs: return "1-800-662-4357"
        }
    }

    var crisisHotlineTel: String {
        switch self {
        case .nicotine: return "tel://18007848669"
        case .alcohol: return "tel://18006624357"
        case .drugs: return "tel://18006624357"
        }
    }

    var crisisHotlineDescription: String {
        switch self {
        case .nicotine: return "1-800-QUIT-NOW - free coaching & support"
        case .alcohol: return "Free, confidential, 24/7"
        case .drugs: return "Free, confidential, 24/7"
        }
    }
}

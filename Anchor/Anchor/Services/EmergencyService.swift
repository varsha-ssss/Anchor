import Foundation
import Combine
import AVFoundation
import UIKit
import UserNotifications

/// Runs the on-phone emergency flow.
///
/// iOS never lets a third-party app place a phone call or send a text on its own — the user
/// (or someone nearby) always has to confirm. So instead of pretending to "auto-call 911",
/// Anchor does the things an app *can* do to get a person help fast:
///   1. `.checking`  – 30-second "Are you okay?" countdown with a loud alarm and spoken alert.
///   2. `.needsHelp` – no response, so the alarm keeps going and the phone speaks to anyone
///      nearby, puts the 911 call prompt on screen, and offers a pre-written text (with location)
///      for the person's emergency contacts.
class EmergencyService: ObservableObject {
    static let shared = EmergencyService()

    enum Phase {
        case checking
        case needsHelp
    }

    static let countdownSeconds = 30

    @Published var isEmergencyActive = false
    @Published var phase: Phase = .checking
    @Published var emergencyCountdown: Int = EmergencyService.countdownSeconds
    @Published private(set) var activeAssessment: CrisisAssessment?
    /// Practice run from the Health screen: same screens and alarm, but never opens the 911 prompt on its own.
    @Published private(set) var isTest = false

    private var audioPlayer: AVAudioPlayer?
    private var countdownTimer: Timer?
    private var alarmTimer: Timer?
    private var bystanderTimer: Timer?
    private var hapticTimer: Timer?
    private var synthesizer = AVSpeechSynthesizer()

    private static let notificationID = "anchor_emergency"

    func triggerEmergency(assessment: CrisisAssessment, isTest: Bool = false) {
        guard !isEmergencyActive else { return }

        self.isTest = isTest
        isEmergencyActive = true
        phase = .checking
        emergencyCountdown = Self.countdownSeconds
        activeAssessment = assessment

        LocationProvider.shared.requestCurrentLocation()
        postBackgroundNotification(for: assessment)
        configureAudioSession()
        startAlarm()
        speakAlert(assessment.addictionType.crisisSpeechAlert)

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.emergencyCountdown -= 1
            if self.emergencyCountdown <= 0 {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.escalate()
            } else if [20, 10, 5].contains(self.emergencyCountdown) {
                self.speakAlert("Are you okay? Tap I'm okay within \(self.emergencyCountdown) seconds.")
            }
        }

        startHaptics()
    }

    func cancelEmergency() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        bystanderTimer?.invalidate()
        bystanderTimer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
        stopAlarm()
        synthesizer.stopSpeaking(at: .immediate)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationID])

        isEmergencyActive = false
        phase = .checking
        emergencyCountdown = Self.countdownSeconds
        activeAssessment = nil
        isTest = false

        WatchConnectivityManager.shared.sendMessage(.emergencyCancelled)
    }

    /// No response during the countdown: switch to bystander mode.
    private func escalate() {
        phase = .needsHelp
        let script = activeAssessment?.addictionType.bystanderSpeech ?? AddictionType.drugs.bystanderSpeech
        speakAlert(script)
        bystanderTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.speakAlert(script)
        }
        // Puts the system "Call 911?" confirmation on screen so anyone nearby only needs one tap.
        call911()
    }

    func call911() {
        guard !isTest, let url = URL(string: "tel://911") else { return }
        UIApplication.shared.open(url)
    }

    func call(_ contact: EmergencyContact) {
        guard !isTest, let url = URL(string: "tel://\(contact.cleanPhone)") else { return }
        UIApplication.shared.open(url)
    }

    /// Text for the emergency contacts, including a map link when a location fix is available.
    func emergencyTextBody(userName: String) -> String {
        let name = userName.isEmpty ? "I" : userName
        var body = (isTest ? "TEST ONLY, NOT A REAL EMERGENCY. " : "") + "EMERGENCY: \(name) may need help right now. Anchor detected a possible health emergency and got no response. Please call or come check on them. If you can't reach them, call 911."
        if let link = LocationProvider.shared.mapsLink {
            body += "\n\nLast location: \(link)"
        }
        return body
    }

    // MARK: - Notification (for when the app isn't on screen)

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postBackgroundNotification(for assessment: CrisisAssessment) {
        let content = UNMutableNotificationContent()
        content.title = assessment.addictionType.crisisLabel
        content.body = "Are you okay? Open Anchor now to cancel the alert or get help."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Alarm

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func startAlarm() {
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.playAlarmSound()
        }
        playAlarmSound()
    }

    private func playAlarmSound() {
        AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(1304)) {}
        AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) {}

        if audioPlayer == nil {
            generateAlarmTone()
        }
    }

    private func generateAlarmTone() {
        let sampleRate: Double = 44100
        let duration: Double = 1.5
        let frequency1: Double = 880
        let frequency2: Double = 1320
        let samples = Int(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples)),
              let channelData = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(samples)

        for i in 0..<samples {
            let t = Double(i) / sampleRate
            let freq = t.truncatingRemainder(dividingBy: 0.5) < 0.25 ? frequency1 : frequency2
            channelData[i] = 0.8 * sin(Float(2.0 * Double.pi * freq * t))
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("alarm.caf")
        if let audioFile = try? AVAudioFile(forWriting: tempURL, settings: format.settings) {
            try? audioFile.write(from: buffer)

            audioPlayer = try? AVAudioPlayer(contentsOf: tempURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        }
    }

    private func stopAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func speakAlert(_ text: String) {
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func startHaptics() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            generator.notificationOccurred(.error)
        }
    }
}

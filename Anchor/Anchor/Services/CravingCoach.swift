import Foundation
import Combine
import FoundationModels

/// "Talk to Tide" — an AI craving coach that runs entirely on the iPhone using Apple's
/// on-device model (Foundation Models framework). Nothing the person types leaves the phone,
/// and the conversation is never saved.
///
/// Safety design:
/// 1. `SafetyCheck` runs on every message *before* the AI sees it. Mentions of self-harm or a
///    medical emergency skip the AI completely and show 988 / 911 / emergency contacts.
/// 2. The AI is scoped to one job — getting through the next few minutes of a craving — using
///    motivational interviewing (questions + the person's own reasons), never lectures,
///    medical advice, or arguments.
/// 3. The screen always says Tide is an AI, not a counselor.
struct CoachMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case tide
        /// A fixed, non-AI card with crisis resources.
        case safety(SafetyCheck.Flag)
    }

    let id = UUID()
    let role: Role
    var text: String
}

enum SafetyCheck {
    enum Flag: Equatable {
        /// Self-harm or suicidal thoughts → 988 Suicide & Crisis Lifeline.
        case selfHarm
        /// Overdose or other medical danger → 911.
        case medicalEmergency
        /// They used/drank after a stretch of sobriety. Not an emergency, but needs a
        /// no-shame response and (for drugs) the lowered-tolerance safety warning.
        case slip
    }

    private static let selfHarmPhrases = [
        "kill myself", "killing myself", "suicide", "suicidal", "want to die", "wanna die",
        "end my life", "end it all", "hurt myself", "self harm", "self-harm", "cut myself",
        "don't want to be alive", "dont want to be alive", "better off dead", "no reason to live",
        "don't want to live", "dont want to live",
    ]

    private static let medicalPhrases = [
        "overdose", "overdosed", "overdosing", "od'd", "took too many", "took too much",
        "can't breathe", "cant breathe", "not breathing", "chest pain", "passed out",
        "seizure", "unresponsive", "lips are blue", "turning blue", "won't wake up", "wont wake up",
    ]

    private static let slipPhrases = [
        "relapsed", "i relapsed", "i drank", "i smoked", "i vaped", "i slipped",
        "had a drink", "got drunk", "got high", "i caved", "i gave in", "used again", "drank again",
    ]

    /// Most serious match wins. Plain phrase matching on purpose: it's predictable,
    /// testable, and doesn't depend on the AI noticing.
    static func classify(_ text: String) -> Flag? {
        let normalized = " " + text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'-")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ") + " "

        func matches(_ phrases: [String]) -> Bool {
            phrases.contains { normalized.contains(" \($0) ") }
        }

        if matches(selfHarmPhrases) { return .selfHarm }
        if matches(medicalPhrases) { return .medicalEmergency }
        if matches(slipPhrases) { return .slip }
        return nil
    }
}

@MainActor
final class CravingCoach: ObservableObject {
    enum Availability: Equatable {
        case available
        case unavailable(String)
    }

    @Published private(set) var messages: [CoachMessage] = []
    @Published private(set) var isResponding = false

    let availability: Availability
    private let instructions: String
    /// The person's own reason for recovery, quoted back in hand-written replies.
    private let reason: String?
    private let userName: String?
    private var session: LanguageModelSession?
    /// Games get their own short session: the small on-device model plays much better without the
    /// coaching rules and personal details mixed in.
    private var gameSession: LanguageModelSession?
    private var activeSession: LanguageModelSession? { mode == .game ? gameSession : session }

    private static let gameInstructions = """
    You are Tide, a playful sea turtle, playing "would you rather" with a teenager to give their \
    mind a break. Each turn: react to their answer in one short, fun sentence, then ask a NEW \
    would-you-rather question you haven't asked yet. If they ask what you'd pick, tell them your \
    pick first. If they don't really answer, skip to a different question. Under 40 words, plain \
    text, no lists. Never mention cravings, recovery, drugs, alcohol, or vaping.
    """

    private static let options = GenerationOptions(temperature: 0.6, maximumResponseTokens: 110)

    init(user: UserData?, store: DataStore) {
        switch SystemLanguageModel.default.availability {
        case .available:
            availability = .available
        case .unavailable(.deviceNotEligible):
            availability = .unavailable("Talking with Tide needs an iPhone that supports Apple Intelligence (iPhone 15 Pro or newer).")
        case .unavailable(.appleIntelligenceNotEnabled):
            availability = .unavailable("Turn on Apple Intelligence in Settings to talk with Tide. Everything stays on your phone.")
        case .unavailable(.modelNotReady):
            availability = .unavailable("Tide is still downloading to your phone. Try again in a few minutes.")
        case .unavailable:
            availability = .unavailable("Tide isn't available on this device right now.")
        }

        instructions = Self.buildInstructions(user: user, store: store)
        reason = user?.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = user?.name.isEmpty == false ? user?.name : nil

        let name = user?.name.isEmpty == false ? ", \(user!.name)" : ""
        messages = [CoachMessage(role: .tide, text: "Hey\(name). I'm here. What's going on right now?")]

        if availability == .available {
            let session = LanguageModelSession(instructions: instructions)
            session.prewarm()
            self.session = session
        }
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }

        messages.append(CoachMessage(role: .user, text: text))

        let flag = SafetyCheck.classify(text)
        if let flag {
            messages.append(CoachMessage(role: .safety(flag), text: ""))
            // Emergencies never go to the AI — the safety card is the whole response.
            if flag != .slip { return }
        }

        guard session != nil else { return }
        var prompt = text
        if flag == .slip {
            mode = .urge
            prompt += "\n\n(Note for Tide: they just told you they slipped. Respond with zero judgment. Ask if they're safe right now and gently ask what happened.)"
        } else if mode == .urge && !Self.wantsDistraction(text) {
            // Later turns of a craving conversation. A small model loses track and re-asks
            // "what's making you feel that way?", so each turn gets one concrete next step.
            prompt += Self.urgeFollowUpNote(turn: urgeTurn, isQuestion: text.contains("?"))
            urgeTurn += 1
        } else if Self.isUrge(text) {
            mode = .urge
            urgeTurn = 0
            prompt += "\n\n(Note for Tide: they're telling you about a craving. Don't lecture, warn, or list resources, and don't guess feelings they didn't name. In one short sentence, acknowledge the craving. Then ask what's happening right now that's bringing it on. Don't bring up their goals or reasons yet. Under 40 words.)"
        } else if Self.wantsDistraction(text) && mode != .game {
            mode = .game
            urgeTurn = 0
            gameSession = LanguageModelSession(instructions: Self.gameInstructions)
            prompt = "Let's play! Ask me the first question."
        } else if mode == .game && Self.wantsToStopGame(text) {
            mode = .talking
        }
        Task { await respond(to: prompt, isUrge: mode == .urge) }
    }

    private func respond(to prompt: String, isUrge: Bool = false, isRetry: Bool = false) async {
        guard let session = activeSession else { return }
        isResponding = true
        messages.append(CoachMessage(role: .tide, text: ""))
        let index = messages.count - 1

        do {
            for try await snapshot in session.streamResponse(to: prompt, options: Self.options) {
                messages[index].text = Self.plainText(snapshot.content)
            }
            let previous = messages[..<index].last(where: { $0.role == .tide })?.text ?? ""
            var reply = Self.trimToLastSentence(messages[index].text)
            reply = Self.removingRepeats(reply, previous: previous)
            reply = Self.removingCheerleading(reply)
            if let name = userName, previous.contains(name) {
                reply = Self.removingName(name, from: reply)
            }
            messages[index].text = reply
            // Second safety layer, on the AI's output: never let a reply okay using.
            if Self.okaysUsing(messages[index].text) {
                messages[index].text = nextUrgeFallback()
            }
            isResponding = false
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Long chat: start a fresh session with the same instructions and try once more.
            messages.remove(at: index)
            isResponding = false
            if mode == .game {
                gameSession = LanguageModelSession(instructions: Self.gameInstructions)
            } else {
                self.session = LanguageModelSession(instructions: instructions)
            }
            if !isRetry { await respond(to: prompt, isUrge: isUrge, isRetry: true) }
        } catch {
            // Apple's built-in safety filter sometimes blocks replies about drugs or alcohol, even
            // supportive ones. Never answer an urge with "I can't help" — use a written reply instead.
            messages[index].text = isUrge ? nextUrgeFallback() : "I'm still here with you. Can you tell me a little more about what's going on right now?"
            isResponding = false
        }
    }

    private var urgeFallbackIndex = 0
    private enum Mode {
        case talking
        /// They said they want to use (or slipped): blocked replies fall back to written MI replies.
        case urge
        /// Playing a distraction game: no interviewing, just the next round.
        case game
    }
    private var mode: Mode = .talking
    private var urgeTurn = 0

    /// Next steps for a craving conversation, in order: their reasons, a plan for the
    /// situation, riding out the urge, then tomorrow. This mirrors how a counselor moves from
    /// listening to planning.
    private static let urgeMoves = [
        "ask what made them want to stop in the first place.",
        "help them make one simple plan for this exact situation, like what they'll say if someone offers them something, who they can stick with, or when they'll leave.",
        "remind them cravings peak and pass in about 15 to 30 minutes, and suggest ONE of the app's tools: Breathe, Ground, or Ride it out.",
        "ask how they think they'll feel tomorrow morning if they get through tonight.",
    ]

    static func urgeFollowUpNote(turn: Int, isQuestion: Bool) -> String {
        let move = urgeMoves[turn % urgeMoves.count]
        let answerFirst = isQuestion ? " First, answer their question." : ""
        return "\n\n(Note for Tide: they already told you what's going on, so do NOT ask what's causing it or how they feel about it again.\(answerFirst) Briefly reflect the heart of their latest message in your own natural words (don't restate it all, don't repeat anything you said before). Then \(move) Under 50 words.)"
    }

    private static let stopGamePhrases = ["stop playing", "stop the game", "i'm done", "im done", "no more", "can we talk", "enough"]

    static func wantsToStopGame(_ text: String) -> Bool {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return stopGamePhrases.contains { lowered.contains($0) }
    }

    private static let permissivePhrases = [
        "okay to use", "ok to use", "okay to want to use", "fine to use", "okay to drink", "ok to drink",
        "fine to drink", "okay to vape", "okay to smoke", "go ahead and", "one won't hurt", "one time won't hurt",
        "just this once", "you deserve a drink", "treat yourself",
    ]

    static func okaysUsing(_ text: String) -> Bool {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return permissivePhrases.contains { lowered.contains($0) }
    }

    /// Hand-written motivational-interviewing replies, used when the AI's reply gets blocked.
    private func nextUrgeFallback() -> String {
        var replies = [
            "Thank you for telling me instead of just doing it. That pull sounds really strong right now. What's making today so hard?",
            "That urge is real, and it makes sense you're feeling it. What made you decide to stop in the first place?",
            "I hear you. If a friend told you this, what would you want them to remember right now?",
        ]
        if let reason, !reason.isEmpty {
            replies.insert("That sounds really hard. You once said: \"\(reason.prefix(200))\" How does that feel to read right now?", at: 1)
        }
        defer { urgeFallbackIndex += 1 }
        return replies[urgeFallbackIndex % replies.count]
    }

    private static let urgePhrases = [
        "craving", "cravings", "tempted", "an urge", "the urge",
        "want to use", "wanna use", "want to take drugs", "want to take pills", "want to take something", "want to get high", "wanna get high",
        "want a drink", "want to drink", "wanna drink", "want to vape", "wanna vape", "want to smoke",
        "wanna smoke", "want a hit", "gonna use", "going to use", "thinking about using",
        "thinking about drinking", "want drugs", "need a drink", "need a hit", "need to use",
        "what's the point of staying", "whats the point of staying", "point of staying clean",
        "point of staying sober", "give up on recovery", "just one drink", "just one hit",
    ]

    static func isUrge(_ text: String) -> Bool {
        let lowered = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return urgePhrases.contains { lowered.contains($0) }
    }

    /// Drops sentences copied word for word from Tide's previous reply (the small model
    /// sometimes repeats itself when the person just says "ok").
    static func removingRepeats(_ text: String, previous: String) -> String {
        let sentences = sentenceSplit(text)
        let earlier = Set(sentenceSplit(previous).map { $0.lowercased() })
        let kept = sentences.filter { !earlier.contains($0.lowercased()) }
        return kept.isEmpty ? text : kept.joined(separator: " ")
    }

    private static let cheerleadingPhrases = [
        "you've got this", "you got this", "proud of you", "you're doing great", "you are doing great",
        "doing amazing", "i believe in you", "i'm confident you",
    ]

    /// Motivational interviewing avoids empty praise; the model adds it anyway, so drop those
    /// sentences (as long as something else is left).
    static func removingCheerleading(_ text: String) -> String {
        let kept = sentenceSplit(text).filter { sentence in
            let lowered = sentence.lowercased().replacingOccurrences(of: "’", with: "'")
            return !cheerleadingPhrases.contains { lowered.contains($0) }
        }
        return kept.isEmpty ? text : kept.joined(separator: " ")
    }

    /// Saying someone's name in every message feels scripted, so only allow it every other reply.
    static func removingName(_ name: String, from text: String) -> String {
        guard !name.isEmpty else { return text }
        var result = text
        for pattern in [", \(name)!", ", \(name).", ", \(name)?", ", \(name),"] {
            result = result.replacingOccurrences(of: pattern, with: String(pattern.last!))
        }
        if result.hasPrefix("\(name), ") {
            result = String(result.dropFirst(name.count + 2))
            result = result.prefix(1).uppercased() + result.dropFirst()
        }
        return result
    }

    private static func sentenceSplit(_ text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, _ in
            if let sub = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !sub.isEmpty { result.append(sub) }
        }
        return result
    }

    /// The token limit can cut a reply mid-sentence; end it at the last full sentence instead.
    static func trimToLastSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".?!\"')".contains(last),
              let cut = trimmed.lastIndex(where: { ".?!".contains($0) }) else { return trimmed }
        return String(trimmed[...cut])
    }

    private static let distractionPhrases = [
        "game", "distract", "distraction", "bored", "something else", "take my mind off",
        "riddle", "trivia", "would you rather", "tell me a story", "tell me a joke", "joke", "fun fact",
    ]

    /// Small on-device models follow a direct nudge more reliably than general instructions,
    /// so distraction requests get an explicit note added to the prompt.
    static func wantsDistraction(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return distractionPhrases.contains { lowered.contains($0) }
    }

    /// The model sometimes answers in markdown (bold, tables). The chat bubble shows plain text,
    /// so strip the symbols instead of showing them raw.
    static func plainText(_ text: String) -> String {
        text
            .components(separatedBy: "\n")
            .filter { line in
                // Drop table divider rows like "|:-----|" or "------".
                let stripped = line.trimmingCharacters(in: .whitespaces)
                return stripped.isEmpty || stripped.contains(where: { $0.isLetter || $0.isNumber })
            }
            .map { line in
                line.replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "__", with: "")
                    .replacingOccurrences(of: "|", with: " ")
                    .replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            }
            .map { line in
                for label in ["Me: ", "Tide: "] where line.hasPrefix(label) {
                    return String(line.dropFirst(label.count))
                }
                return line
            }
            .joined(separator: "\n")
    }

    // MARK: - Instructions

    private static func buildInstructions(user: UserData?, store: DataStore) -> String {
        var text = """
        You are Tide, a calm, warm sea turtle in Anchor, a recovery app. You are an AI, not a \
        therapist, and you say so if asked. Your job: help this person through a craving or hard moment.

        How to reply:
        - 2 or 3 short, plain sentences. Under 50 words. No lists, bold, or markdown.
        - When they're struggling: reflect what they feel in one sentence, then ask ONE open question \
        about their own reasons for staying sober. Don't argue, lecture, warn, or cheerlead.
        - When they say a reason to stay sober, repeat it back in their words and ask how they can \
        protect it tonight.
        - If they ask you something, answer it. Never ask about something they already told you.
        - Sound like a caring friend texting, not a robot. Don't restate their whole message back. \
        Use their name rarely, never in back-to-back replies. Never repeat a sentence you already said.
        - Later in the chat you may suggest ONE of the app's tools: "Breathe", "Ground", or \
        "Ride it out", or texting someone they trust.
        - You may say an urge makes sense, but never say it's okay to use or drink.
        - Never give medical advice or anything about getting or using substances.
        - If they mention danger to themselves or a medical emergency, tell them to call 911 or text 988.

        Example:
        Person: everyone else will be drinking anyway
        Tide: So it feels like you'd be the only one left out. What made you decide to stop in the first place?
        """

        guard let user else { return text }

        text += "\n\nBackground on this person. Use one detail only when it helps. Never list or summarize these facts:"
        text += "\n- Name: \(user.name). Age group: \(user.ageGroup)."
        for type in user.addictionTypes {
            text += "\n- Recovering from \(type.displayName.lowercased()): \(user.daysSober(for: type)) days so far."
        }
        if user.totalMoneySaved >= 1 {
            text += "\n- Money saved so far: $\(Int(user.totalMoneySaved))."
        }
        let motivation = user.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !motivation.isEmpty {
            text += "\n- Their reason for recovery, in their words: \"\(motivation.prefix(300))\""
        }

        let letters = store.selfMessages.suffix(2)
        if !letters.isEmpty {
            text += "\n- Letters they wrote to their future self for hard moments. Quoting a line back to them can really help:"
            for letter in letters {
                text += "\n  \"\(letter.content.prefix(300))\""
            }
        }

        let triggers = store.cravings.suffix(10).map(\.trigger).filter { !$0.isEmpty }
        if !triggers.isEmpty {
            text += "\n- Their recent craving triggers: \(Array(Set(triggers)).prefix(5).joined(separator: ", "))."
        }

        return text
    }
}

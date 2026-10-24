import SwiftUI

struct CravingCoachView: View {
    @ObservedObject var store: DataStore
    @StateObject private var coach: CravingCoach
    @State private var draft = ""
    @State private var activeTool: ToolkitView.ActiveTool? = nil
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    init(store: DataStore) {
        self.store = store
        _coach = StateObject(wrappedValue: CravingCoach(user: store.userData, store: store))
    }

    private var foreground: Color { colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground }
    private var muted: Color { colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground }
    private var cardColor: Color { colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card }

    private static let starters = ["I'm having a craving", "Distract me", "I'm really stressed", "I slipped up"]

    var body: some View {
        ZStack {
            (colorScheme == .dark ? AnchorTheme.backgroundDark : AnchorTheme.background)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                disclaimer

                switch coach.availability {
                case .available:
                    conversation
                    toolRow
                    inputBar
                case .unavailable(let reason):
                    unavailableView(reason)
                }
            }
        }
        .fullScreenCover(item: $activeTool) { tool in
            switch tool {
            case .breathing: BreathingExerciseView()
            case .grounding: GroundingExerciseView()
            case .urgeSurfing: UrgeSurfingView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            TideSeaTurtle(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Talk to Tide")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(foreground)
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("AI · runs only on your phone")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AnchorTheme.kelp)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(muted)
                    .padding(10)
                    .background(cardColor)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var disclaimer: some View {
        Text("Tide is an AI, not a counselor. Your chat is never saved or sent anywhere. In danger? Call 911 or text 988.")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(coach.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }

                    if coach.messages.count == 1 {
                        starterChips
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: coach.messages) {
                if let last = coach.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: CoachMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AnchorTheme.kelp)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        case .tide:
            HStack(alignment: .bottom, spacing: 8) {
                TideSeaTurtle(size: 26)
                Group {
                    if message.text.isEmpty {
                        TypingDots(color: muted)
                    } else {
                        Text(message.text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(foreground)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
                )
                Spacer(minLength: 32)
            }
        case .safety(let flag):
            SafetyCard(flag: flag, user: store.userData)
        }
    }

    private var starterChips: some View {
        FlowChips(items: Self.starters) { coach.send($0) }
            .padding(.top, 4)
    }

    // MARK: - Tools + input

    private var toolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                toolChip("wind", "Breathe", AnchorTheme.seafoam) { activeTool = .breathing }
                toolChip("hand.raised.fingers.spread.fill", "Ground", AnchorTheme.sand) { activeTool = .grounding }
                toolChip("water.waves", "Ride it out", AnchorTheme.coral) { activeTool = .urgeSurfing }
                if let contact = store.userData?.contacts.first(where: \.isValid),
                   let url = URL(string: "sms:\(contact.cleanPhone)") {
                    Link(destination: url) {
                        chipLabel("message.fill", "Text \(contact.name)", AnchorTheme.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
    }

    private func toolChip(_ icon: String, _ label: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(icon, label, color) }
    }

    private func chipLabel(_ icon: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(label).font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Tell Tide what's going on…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? AnchorTheme.kelp : muted.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var canSend: Bool {
        !coach.isResponding && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        coach.send(draft)
        draft = ""
    }

    // MARK: - Unavailable

    private func unavailableView(_ reason: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(reason)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(foreground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("These still work right now:")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundColor(muted)

                VStack(spacing: 10) {
                    toolChip("wind", "Breathe", AnchorTheme.seafoam) { activeTool = .breathing }
                    toolChip("hand.raised.fingers.spread.fill", "Ground", AnchorTheme.sand) { activeTool = .grounding }
                    toolChip("water.waves", "Ride it out", AnchorTheme.coral) { activeTool = .urgeSurfing }
                }

                SafetyCard(flag: nil, user: store.userData)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Safety card (fixed text, never AI-generated)

struct SafetyCard: View {
    /// nil = the general "help is available" card.
    let flag: SafetyCheck.Flag?
    let user: UserData?

    private var title: String {
        switch flag {
        case .selfHarm: return "You don't have to carry this alone"
        case .medicalEmergency: return "This could be an emergency"
        case .slip: return "A slip doesn't erase your progress"
        case nil: return "Real people, any time"
        }
    }

    private var message: String {
        switch flag {
        case .selfHarm:
            return "Please reach out to the 988 Suicide & Crisis Lifeline. It's free, confidential, and open 24/7 — call or text. If you're in danger right now, call 911."
        case .medicalEmergency:
            return "Call 911 now. If someone may be overdosing and you have naloxone (Narcan), give it. Don't leave them alone. California's Good Samaritan law protects people who call for help."
        case .slip:
            var text = "One slip is information, not failure. Your sober days still count."
            if user?.addictionTypes.contains(where: { $0 != .nicotine }) ?? true {
                text += " Please stay safe: after a break your tolerance is lower than before, so don't use alone and keep naloxone (Narcan) nearby."
            }
            return text
        case nil:
            return "Tide is an AI. For a real person, call or text 988, or call the SAMHSA National Helpline at 1-800-662-4357."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: flag == .slip ? "heart.fill" : "lifepreserver.fill")
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundColor(AnchorTheme.rose)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AnchorTheme.foreground)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                switch flag {
                case .medicalEmergency:
                    actionButton("phone.fill", "Call 911", "tel://911", filled: true)
                    contactButton
                case .selfHarm:
                    HStack(spacing: 8) {
                        actionButton("phone.fill", "Call 988", "tel://988", filled: true)
                        actionButton("message.fill", "Text 988", "sms:988", filled: true)
                    }
                    contactButton
                case .slip:
                    contactButton
                    actionButton("phone.fill", "SAMHSA Helpline", "tel://18006624357", filled: false)
                case nil:
                    HStack(spacing: 8) {
                        actionButton("phone.fill", "Call 988", "tel://988", filled: true)
                        actionButton("message.fill", "Text 988", "sms:988", filled: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorTheme.roseBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AnchorTheme.roseBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var contactButton: some View {
        if let contact = user?.contacts.first(where: \.isValid) {
            actionButton("person.fill", "Call \(contact.name)", "tel://\(contact.cleanPhone)", filled: false)
        }
    }

    @ViewBuilder
    private func actionButton(_ icon: String, _ label: String, _ urlString: String, filled: Bool) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                    Text(label).font(.system(size: 14, weight: .heavy))
                }
                .foregroundColor(filled ? .white : AnchorTheme.rose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(filled ? AnchorTheme.rose : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AnchorTheme.roseBorder, lineWidth: filled ? 0 : 1))
            }
        }
    }
}

// MARK: - Small helpers

private struct TypingDots: View {
    let color: Color

    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 20, weight: .heavy))
            .foregroundColor(color)
            .symbolEffect(.variableColor.iterative)
            .accessibilityLabel("Tide is typing")
    }
}

private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button(action: { onTap(item) }) {
                    Text(item)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AnchorTheme.kelp)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(AnchorTheme.kelp.opacity(0.6), lineWidth: 1.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

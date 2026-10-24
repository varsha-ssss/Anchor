import SwiftUI

struct ToolkitView: View {
    @ObservedObject var store: DataStore
    @State private var activeTool: ActiveTool? = nil
    @Environment(\.colorScheme) var colorScheme

    enum ActiveTool: Identifiable {
        case breathing, grounding, urgeSurfing
        var id: String {
            switch self {
            case .breathing: return "breathing"
            case .grounding: return "grounding"
            case .urgeSurfing: return "urgeSurfing"
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    TideSeaTurtle(size: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your Toolkit")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Text(toolkitSubtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                    Spacer()
                }
                .padding(.top, 24)

                if let user = store.userData {
                    dailyTipCard(user: user)
                }

                Text("When you need help right now")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                toolCard(
                    icon: "wind",
                    title: "Breathing Exercise",
                    subtitle: "4-7-8 technique to calm your body down",
                    color: AnchorTheme.primary
                ) { activeTool = .breathing }

                toolCard(
                    icon: "hand.raised.fingers.spread.fill",
                    title: "5-4-3-2-1 Grounding",
                    subtitle: "Bring yourself back to the present moment",
                    color: Color(hex: "8B5CF6")
                ) { activeTool = .grounding }

                toolCard(
                    icon: "water.waves",
                    title: "Urge Surfing",
                    subtitle: "Ride the wave — cravings peak then pass",
                    color: Color(hex: "0EA5E9")
                ) { activeTool = .urgeSurfing }

                if let user = store.userData {
                    Text("Crisis support")
                        .font(.system(size: 10, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(user.addictionTypes) { type in
                        crisisCard(type: type)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .fullScreenCover(item: $activeTool) { tool in
            switch tool {
            case .breathing: BreathingExerciseView()
            case .grounding: GroundingExerciseView()
            case .urgeSurfing: UrgeSurfingView()
            }
        }
    }

    private var toolkitSubtitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "Can't sleep? These tools can help." }
        if hour < 12 { return "Start your day grounded." }
        if hour < 17 { return "Struggling? You have tools for this." }
        if hour < 21 { return "Evenings can be tough. You've got this." }
        return "Late night? Try a breathing exercise."
    }

    private func dailyTipCard(user: UserData) -> some View {
        let tip = RecoveryTips.dailyTip(for: user)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                Text("Today's Tip")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(tip)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorTheme.oceanGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: AnchorTheme.primary.opacity(0.3), radius: 8)
    }

    private func toolCard(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
            .padding(16)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
            )
        }
    }

    private func crisisCard(type: AddictionType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(type.displayName) Crisis Support")
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AnchorTheme.rose)

            Text("\(type.crisisHotlineName) - \(type.crisisHotlineDescription)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor((colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground).opacity(0.8))

            if let url = URL(string: type.crisisHotlineTel) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 12))
                        Text(type.crisisHotlineNumber)
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AnchorTheme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color(hex: "3b0d0d").opacity(0.3) : AnchorTheme.roseBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AnchorTheme.roseBorder, lineWidth: 1)
        )
    }
}

struct BreathingExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var phase: BreathPhase = .ready
    @State private var circleScale: CGFloat = 0.5
    @State private var timer: Timer?
    @State private var secondsLeft = 0
    @State private var cyclesCompleted = 0
    @State private var phaseLabel = "Tap to begin"

    enum BreathPhase {
        case ready, breatheIn, hold, breatheOut, done
    }

    var body: some View {
        ZStack {
            AnchorTheme.deepOceanGradient
                .ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Spacer()
                    Button(action: { stopAndDismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Text(phaseLabel)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)

                if phase != .ready && phase != .done {
                    Text("\(secondsLeft)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()
                }

                ZStack {
                    Circle()
                        .fill(AnchorTheme.primary.opacity(0.15))
                        .frame(width: 220, height: 220)

                    Circle()
                        .fill(AnchorTheme.primary.opacity(0.3))
                        .frame(width: 220, height: 220)
                        .scaleEffect(circleScale)
                        .animation(.easeInOut(duration: phaseAnimationDuration), value: circleScale)

                    Circle()
                        .fill(AnchorTheme.primary.opacity(0.6))
                        .frame(width: 100, height: 100)
                        .scaleEffect(circleScale)
                        .animation(.easeInOut(duration: phaseAnimationDuration), value: circleScale)
                }

                if phase == .ready {
                    Button(action: startBreathing) {
                        Text("Begin")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(AnchorTheme.primary)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                } else if phase == .done {
                    VStack(spacing: 8) {
                        Text("\(cyclesCompleted) cycles completed")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Button(action: { stopAndDismiss() }) {
                            Text("Done")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(AnchorTheme.primary)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }

                Spacer()

                if phase == .ready {
                    Text("4-7-8 breathing: Breathe in for 4, hold for 7, out for 8.\nThis activates your body's calm response.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }

    private var phaseAnimationDuration: Double {
        switch phase {
        case .breatheIn: return 4
        case .hold: return 0.3
        case .breatheOut: return 8
        default: return 0.5
        }
    }

    private func startBreathing() {
        cyclesCompleted = 0
        beginInhale()
    }

    private func beginInhale() {
        phase = .breatheIn
        phaseLabel = "Breathe in"
        secondsLeft = 4
        circleScale = 1.0
        startCountdown(seconds: 4) { beginHold() }
    }

    private func beginHold() {
        phase = .hold
        phaseLabel = "Hold"
        secondsLeft = 7
        startCountdown(seconds: 7) { beginExhale() }
    }

    private func beginExhale() {
        phase = .breatheOut
        phaseLabel = "Breathe out"
        secondsLeft = 8
        circleScale = 0.5
        startCountdown(seconds: 8) {
            cyclesCompleted += 1
            if cyclesCompleted >= 4 {
                phase = .done
                phaseLabel = "Nice work. You did it."
            } else {
                beginInhale()
            }
        }
    }

    private func startCountdown(seconds: Int, then next: @escaping () -> Void) {
        timer?.invalidate()
        secondsLeft = seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            secondsLeft -= 1
            if secondsLeft <= 0 {
                t.invalidate()
                next()
            }
        }
    }

    private func stopAndDismiss() {
        timer?.invalidate()
        dismiss()
    }
}

struct GroundingExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0

    private let steps: [(count: Int, sense: String, prompt: String, icon: String)] = [
        (5, "SEE", "Look around. Name 5 things you can see right now.", "eye.fill"),
        (4, "TOUCH", "Name 4 things you can physically feel.", "hand.raised.fill"),
        (3, "HEAR", "Close your eyes. Name 3 things you can hear.", "ear.fill"),
        (2, "SMELL", "Name 2 things you can smell.", "nose.fill"),
        (1, "TASTE", "Name 1 thing you can taste.", "mouth.fill"),
    ]

    var body: some View {
        ZStack {
            Color(hex: "8B5CF6").opacity(0.15)
                .ignoresSafeArea()
            LinearGradient(colors: [Color(hex: "4C1D95"), Color(hex: "6D28D9")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                if currentStep < steps.count {
                    let step = steps[currentStep]

                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i <= currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 10, height: 10)
                        }
                    }

                    Text("\(step.count)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Image(systemName: step.icon)
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.8))

                    Text(step.sense)
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.6))

                    Text(step.prompt)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }) {
                        Text(currentStep < steps.count - 1 ? "Next" : "Finish")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(Color(hex: "6D28D9"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)

                    Text("You're here. You're present.")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.white)

                    Text("That craving doesn't control you.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(Color(hex: "6D28D9"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }

                Spacer()
            }
        }
    }
}

struct UrgeSurfingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var started = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var waveOffset: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0C4A6E"), Color(hex: "0EA5E9")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            WaveShape(offset: waveOffset)
                .fill(Color.white.opacity(0.05))
                .frame(height: 300)
                .offset(y: 200)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: { stopAndDismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                if !started {
                    VStack(spacing: 16) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Urge Surfing")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.white)

                        Text("A craving is like a wave.\nIt builds, peaks, and always passes.\nDon't fight it — just ride it out.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 30)
                    }

                    Spacer()

                    Button(action: startSurfing) {
                        Text("Start the timer")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(Color(hex: "0EA5E9"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                } else {
                    Text("Riding the wave...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    Text(timeString(elapsed))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Text(encouragement)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .animation(.easeInOut, value: encouragement)

                    Spacer()

                    Button(action: { stopAndDismiss() }) {
                        Text("I made it through")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(Color(hex: "0EA5E9"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                }

                Spacer()

                if started {
                    Text("Most cravings pass within 15-30 minutes.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
                waveOffset = 100
            }
        }
    }

    private var encouragement: String {
        let mins = Int(elapsed) / 60
        if mins < 1 { return "You're doing great. Stay with it." }
        if mins < 3 { return "The wave is building. You're stronger than it." }
        if mins < 5 { return "Still here? That's real strength." }
        if mins < 10 { return "The peak is passing. You're winning." }
        if mins < 15 { return "Most cravings don't last this long. You crushed it." }
        return "You rode the entire wave. Incredible."
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startSurfing() {
        started = true
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private func stopAndDismiss() {
        timer?.invalidate()
        dismiss()
    }
}

struct WaveShape: Shape {
    var offset: CGFloat

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.5))

        for x in stride(from: 0, through: w, by: 1) {
            let relX = x / w
            let y = sin((relX * 4 * .pi) + Double(offset) * 0.05) * 20 + h * 0.5
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

struct RecoveryTips {
    static func dailyTip(for user: UserData) -> String {
        let dayIndex = Int(Date().timeIntervalSince1970 / 86400)
        let primaryType = user.primaryAddiction
        let maxDays = user.addictionTypes.map { user.daysSober(for: $0) }.max() ?? 0

        if maxDays <= 30 {
            let earlyTips = earlyRecoveryTips(for: primaryType)
            return earlyTips[dayIndex % earlyTips.count]
        }

        let tips = generalTips(for: primaryType)
        return tips[dayIndex % tips.count]
    }

    private static func earlyRecoveryTips(for type: AddictionType) -> [String] {
        switch type {
        case .nicotine:
            return [
                "Cravings usually last 3-5 minutes. When one hits, try drinking cold water slowly.",
                "Your blood oxygen is already improving. The discomfort you feel is your body healing.",
                "Keep your hands busy. Fidget toys, doodling, even squeezing ice — it helps.",
                "Avoid your usual smoking spots for now. New routines break old patterns.",
                "If you slip, don't restart the clock mentally. One cigarette doesn't erase your progress.",
                "After 48 hours nicotine-free, your nerve endings start regrowing. You're literally rebuilding.",
                "The irritability is withdrawal, not you. It peaks around day 3 and gets easier.",
            ]
        case .alcohol:
            return [
                "If evenings are hardest, plan something specific for 5-8 PM. Empty time is risky time.",
                "Your liver starts recovering within days. The fog lifts faster than you'd expect.",
                "Stock your fridge with something you actually like — sparkling water, fancy juice, anything.",
                "It's okay to skip social events right now. Protecting your recovery isn't weak, it's smart.",
                "Sleep might be rough for a week or two. It gets dramatically better — hang in there.",
                "HALT: check if you're Hungry, Angry, Lonely, or Tired before any craving decision.",
                "Tell at least one person what you're doing. Accountability isn't pressure — it's backup.",
            ]
        case .drugs:
            return [
                "Your brain is rewiring right now. The flatness you might feel is temporary — emotions come back.",
                "Avoid people, places, and things connected to using. It's not forever, just for now.",
                "If you're prescribed medication-assisted treatment, take it. It's not trading one for another.",
                "Physical exercise floods your brain with the same chemicals you're missing. Even a walk counts.",
                "Boredom is one of the biggest relapse triggers. Have a list of 5 things to do when it hits.",
                "HALT: check if you're Hungry, Angry, Lonely, or Tired before any craving decision.",
                "Every day clean, your brain heals a little more. The first month is the steepest climb.",
            ]
        }
    }

    private static func generalTips(for type: AddictionType) -> [String] {
        switch type {
        case .nicotine:
            return [
                "After 1 month smoke-free, your lung capacity is already noticeably better. Keep it going.",
                "Cravings still pop up — that's normal even months in. They just get shorter and weaker.",
                "Your sense of taste and smell are sharper now. Notice the food you've been missing.",
                "The money you're saving adds up fast. Check your stats — that's real.",
                "Exercise is easier now that your lungs are clearing. Try pushing yourself a little further.",
                "Nicotine rewired your stress response. Learning new coping takes time but it sticks.",
                "You're not 'quitting' anymore — you're someone who doesn't smoke. That's different.",
                "If someone offers, you don't need a reason. 'No thanks' is a complete sentence.",
            ]
        case .alcohol:
            return [
                "Your sleep quality improves massively after the first few weeks. Notice the difference.",
                "Social situations get easier with practice. The awkwardness is temporary.",
                "Your skin, weight, and energy levels are all changing. The mirror doesn't lie.",
                "It's okay to mourn drinking. You're allowed to miss it and still know it was the right call.",
                "Find your replacement ritual. Tea, a walk, a podcast — something that marks the end of your day.",
                "If you're counting days and it feels heavy, try just focusing on today.",
                "Recovery isn't linear. A hard week after a good month doesn't mean you're going backward.",
                "The clarity you have now? That's the real you. You were always this sharp.",
            ]
        case .drugs:
            return [
                "Your emotions might feel intense — that's because you're actually feeling them now.",
                "Post-acute withdrawal can last months. Knowing it's temporary makes it easier to ride out.",
                "You've survived 100% of your worst days so far. That's not luck — that's you.",
                "If therapy is available to you, use it. Recovery without processing is just white-knuckling.",
                "Build a life you don't need to escape from. That's the long game.",
                "Celebrate the small stuff. Woke up clear-headed? That's worth something.",
                "Relapse doesn't mean failure. It means the plan needs adjusting, not that you're broken.",
                "The people who stuck around through the worst of it? Hold onto them tight.",
            ]
        }
    }
}

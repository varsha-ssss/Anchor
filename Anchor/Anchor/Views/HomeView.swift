import SwiftUI

struct HomeView: View {
    @ObservedObject var store: DataStore
    @State private var activeTool: ToolkitView.ActiveTool? = nil
    @State private var showCoach = false
    @State private var newGoalText = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        guard let user = store.userData else { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        AnchorTheme.oceanGradient
                            .frame(height: 196)
                            .clipShape(WaveBottomShape())

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tideGreeting(user: user))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                Text(user.name)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            TideSeaTurtle(size: 72)
                                .rotationEffect(.degrees(-6))
                                .offset(y: -8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 48)
                    }

                    VStack(spacing: 16) {
                        dailyCheckIn(user: user)

                        ForEach(user.addictionTypes) { type in
                            compactSobrietyRow(user: user, type: type)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Need help right now?")

                            talkToTideCard

                            HStack(spacing: 10) {
                                quickToolButton(
                                    icon: "wind",
                                    label: "Breathe",
                                    color: AnchorTheme.seafoam
                                ) { activeTool = .breathing }

                                quickToolButton(
                                    icon: "hand.raised.fingers.spread.fill",
                                    label: "Ground",
                                    color: AnchorTheme.sand
                                ) { activeTool = .grounding }

                                quickToolButton(
                                    icon: "water.waves",
                                    label: "Ride it out",
                                    color: AnchorTheme.coral
                                ) { activeTool = .urgeSurfing }
                            }
                        }

                        dailyGoalsSection

                        dailyTipCard(user: user)

                        if !user.motivation.trimmingCharacters(in: .whitespaces).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("Your why", color: AnchorTheme.rose)
                                Text("\"\(user.motivation)\"")
                                    .font(.system(size: 14, weight: .medium))
                                    .italic()
                                    .foregroundColor((colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground).opacity(0.8))
                                    .lineSpacing(4)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(AnchorTheme.roseBorder, lineWidth: 1)
                            )
                        }

                        compactMoneySaved(user: user)

                        affirmationCard(user: user)

                        ForEach(user.addictionTypes) { type in
                            compactCrisisCard(type: type)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .fullScreenCover(isPresented: $showCoach) {
                CravingCoachView(store: store)
            }
            .fullScreenCover(item: $activeTool) { tool in
                switch tool {
                case .breathing: BreathingExerciseView()
                case .grounding: GroundingExerciseView()
                case .urgeSurfing: UrgeSurfingView()
                }
            }
        )
    }

    private func sectionLabel(_ text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(color ?? (colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground))
    }

    private func tideGreeting(user: UserData) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let maxDays = user.addictionTypes.map { user.daysSober(for: $0) }.max() ?? 0

        if maxDays == 1 { return "Day one. You showed up." }
        if maxDays == 7 { return "One whole week. That's real." }
        if maxDays == 30 { return "One month. Look at you." }
        if maxDays == 90 { return "90 days. That's no accident." }
        if maxDays == 365 { return "One year. You changed your life." }

        if hour < 5 { return "Late night? You're still here." }
        if hour < 9 { return "New day, same strength." }
        if hour < 12 { return "Good morning," }
        if hour < 17 { return "Still going strong," }
        if hour < 21 { return "Good evening," }
        return "Another day down,"
    }

    private func dailyCheckIn(user: UserData) -> some View {
        let hasCheckedInToday = store.moods.contains {
            Calendar.current.isDateInToday($0.date)
        }

        return Group {
            if !hasCheckedInToday {
                VStack(spacing: 12) {
                    sectionLabel("Daily check-in")

                    Text("How are you feeling today?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)

                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    store.moods.append(MoodEntry(date: Date(), mood: mood))
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(AnchorTheme.moodEmoji(mood))
                                        .font(.system(size: 32))
                                    Text(AnchorTheme.moodLabel(mood))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
                .anchorCard()
            } else {
                let todayMood = store.moods.last(where: { Calendar.current.isDateInToday($0.date) })?.mood ?? 3
                HStack(spacing: 12) {
                    Text(AnchorTheme.moodEmoji(todayMood))
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        sectionLabel("Today's check-in")
                        Text("Feeling \(AnchorTheme.moodLabel(todayMood).lowercased())")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    }
                    Spacer()
                    Circle()
                        .fill(AnchorTheme.moodColor(todayMood))
                        .frame(width: 10, height: 10)
                }
                .padding(16)
                .anchorCard()
            }
        }
    }

    private func compactSobrietyRow(user: UserData, type: AddictionType) -> some View {
        let days = user.daysSober(for: type)
        let years = days / 365
        let months = (days % 365) / 30
        let remainingDays = (days % 365) % 30
        let isFirstDay = days <= 1

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isFirstDay ? AnchorTheme.accent : AnchorTheme.primary)
                    .frame(width: 38, height: 38)
                Image(systemName: milestoneIcon(for: days))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(type.sobrietyLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    if isFirstDay {
                        Text("DAY 1")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AnchorTheme.accent))
                    }
                }
                Text(isFirstDay ? "Your journey begins today" : compactTimeString(years: years, months: months, days: remainingDays))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isFirstDay ? AnchorTheme.accent : (colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground))
            }

            Spacer()

            Text("\(days)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(isFirstDay ? AnchorTheme.accent : AnchorTheme.primary)
            Text(days == 1 ? "day" : "days")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
        }
        .padding(16)
        .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isFirstDay ? AnchorTheme.accent.opacity(0.4) : (colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border), lineWidth: isFirstDay ? 2 : 1)
        )
    }

    private func milestoneIcon(for days: Int) -> String {
        switch days {
        case ..<7: return "sparkle"
        case 7..<30: return "drop.fill"
        case 30..<90: return "water.waves"
        case 90..<365: return "sailboat.fill"
        default: return "tortoise.fill"
        }
    }

    private func compactTimeString(years: Int, months: Int, days: Int) -> String {
        var parts: [String] = []
        if years > 0 { parts.append("\(years)y") }
        if months > 0 { parts.append("\(months)mo") }
        if days > 0 || parts.isEmpty { parts.append("\(days)d") }
        return parts.joined(separator: " ")
    }

    private func quickToolButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func dailyTipCard(user: UserData) -> some View {
        let tip = RecoveryTips.dailyTip(for: user)

        return HStack(alignment: .bottom, spacing: 8) {
            TideSeaTurtle(size: 36)

            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("Tide's tip for today", color: AnchorTheme.sand)
                Text(tip)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(BubbleShape(cornerRadius: 20, tailSide: .leading))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactMoneySaved(user: UserData) -> some View {
        let totalSaved = user.totalMoneySaved

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Money saved")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                Text(String(format: "$%.2f", totalSaved))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(user.addictionTypes) { type in
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 9))
                        Text(String(format: "$%.0f", user.moneySaved(for: type)))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(20)
        .background(AnchorTheme.amberGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func affirmationCard(user: UserData) -> some View {
        let affirmations = Affirmations.forAgeGroup(user.ageGroup)
        let todayIndex = Int(Date().timeIntervalSince1970 / 86400) % affirmations.count

        return VStack(alignment: .leading, spacing: 10) {
            Text(affirmations[todayIndex])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                .lineSpacing(4)

            HStack(spacing: 8) {
                TideSeaTurtle(size: 22)
                Text(tideFooter(user: user))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
        }
        .padding(16)
        .anchorCard()
    }

    private func tideFooter(user: UserData) -> String {
        let maxDays = user.addictionTypes.map { user.daysSober(for: $0) }.max() ?? 0
        if maxDays < 7 { return "One day at a time. \u{2014} Tide" }
        if maxDays < 30 { return "Keep showing up. \u{2014} Tide" }
        if maxDays < 90 { return "Look how far you've come. \u{2014} Tide" }
        return "Built for this. \u{2014} Tide"
    }

    private var dailyGoalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Today's goals")

            ForEach(store.dailyGoals) { goal in
                HStack(spacing: 10) {
                    Button(action: {
                        if let idx = store.dailyGoals.firstIndex(where: { $0.id == goal.id }) {
                            store.dailyGoals[idx].completed.toggle()
                        }
                    }) {
                        Image(systemName: goal.completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(goal.completed ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground))
                    }

                    Text(goal.text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        .strikethrough(goal.completed, color: AnchorTheme.mutedForeground)
                        .opacity(goal.completed ? 0.5 : 1)

                    Spacer()

                    Button(action: {
                        store.dailyGoals.removeAll { $0.id == goal.id }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(AnchorTheme.primary.opacity(0.5))

                TextField("Add a goal for today...", text: $newGoalText, onCommit: addGoal)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
            }

            if !store.dailyGoals.isEmpty {
                let done = store.dailyGoals.filter(\.completed).count
                let total = store.dailyGoals.count
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AnchorTheme.primary)
                                .frame(width: total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0, height: 6)
                                .animation(.easeOut(duration: 0.3), value: done)
                        }
                    }
                    .frame(height: 6)

                    Text("\(done)/\(total)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
        )
    }

    private func addGoal() {
        let text = newGoalText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        store.dailyGoals.append(DailyGoal(text: text))
        newGoalText = ""
    }

    private var talkToTideCard: some View {
        Button(action: { showCoach = true }) {
            HStack(spacing: 14) {
                TideSeaTurtle(size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Talk to Tide")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Having a craving? Talk it through. Private, on your phone.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
            .background(AnchorTheme.oceanGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: AnchorTheme.primary.opacity(0.25), radius: 8, y: 2)
        }
        .accessibilityHint("Opens a private AI chat for getting through a craving")
    }

    private func compactCrisisCard(type: AddictionType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 14))
                .foregroundColor(AnchorTheme.rose)
                .frame(width: 32, height: 32)
                .background(AnchorTheme.rose.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(type.crisisHotlineName)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                Text(type.crisisHotlineNumber)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }

            Spacer()

            if let url = URL(string: type.crisisHotlineTel) {
                Link(destination: url) {
                    Text("Call")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AnchorTheme.rose)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AnchorTheme.roseBorder.opacity(0.5), lineWidth: 1)
        )
    }
}

struct Affirmations {
    static func forAgeGroup(_ group: String) -> [String] {
        switch group {
        case "18-25": return [
            "You're rewriting your story before it's even halfway told.",
            "Your potential is unlimited. Don't let anything shrink it.",
            "The version of you that keeps going is the one that wins.",
            "Every day free is an investment in the person you're becoming.",
            "Your 20s are hard enough - choosing recovery makes you extraordinary.",
            "Setbacks don't define you. Your response to them does.",
            "You have your whole life ahead - and you're choosing to live it fully.",
            "The courage it takes to recover will take you anywhere you want to go.",
        ]
        case "25-45": return [
            "Recovery shows the people you love what strength really looks like.",
            "You can't undo the past, but you can build something incredible from here.",
            "Every day you choose recovery, you choose your future.",
            "Your career, your relationships, your life - they're all waiting for you.",
            "You are more than your hardest chapter. This one has a great ending.",
            "The hard work you put in now pays off in ways you can't yet imagine.",
            "You're not just surviving. You're learning how to truly live.",
            "The people who love you need the real you - and you're showing up.",
        ]
        case "45-70": return [
            "It's never too late to become who you were always meant to be.",
            "Your wisdom and experience make your recovery journey remarkable.",
            "You've already survived so much. This is your time to thrive.",
            "The legacy you leave starts with the choice you make today.",
            "You deserve peace, health, and joy - recovery is the path there.",
            "Your strength inspires others more than you will ever know.",
            "Every day free is a gift to yourself and everyone who loves you.",
            "Life has so many beautiful chapters still ahead. Keep turning the pages.",
        ]
        default: return [
            "Your resilience across a lifetime is something to be deeply proud of.",
            "You've seen the world change - and changing yourself is the greatest feat.",
            "Every sunrise you greet free is a victory worth celebrating.",
            "The depth of your spirit brought you this far. It will carry you further.",
            "You've earned peace. Recovery is how you claim it.",
            "Your journey gives hope to people of every age.",
            "The love you carry shines brightest when you are well.",
            "Health and clarity at any age are worth fighting for. You're fighting.",
        ]
        }
    }
}

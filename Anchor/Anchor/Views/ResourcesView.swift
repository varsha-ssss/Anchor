import SwiftUI

struct ResourcesView: View {
    @ObservedObject var store: DataStore
    @State private var activeTool: ToolkitView.ActiveTool? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        guard let user = store.userData else { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Coping Exercises")
                            .font(.system(size: 10, weight: .heavy))
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)

                        toolCard(icon: "wind", title: "4-7-8 Breathing", subtitle: "Calm your nervous system in under 2 minutes", color: AnchorTheme.primary) {
                            activeTool = .breathing
                        }
                        toolCard(icon: "hand.raised.fingers.spread.fill", title: "5-4-3-2-1 Grounding", subtitle: "Come back to the present when you're spiraling", color: Color(hex: "8B5CF6")) {
                            activeTool = .grounding
                        }
                        toolCard(icon: "water.waves", title: "Urge Surfing", subtitle: "Ride the craving wave until it passes", color: Color(hex: "0EA5E9")) {
                            activeTool = .urgeSurfing
                        }
                    }

                    ForEach(user.addictionTypes) { type in
                        addictionResourcesCard(type: type)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Support Organizations")
                            .font(.system(size: 10, weight: .heavy))
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)

                        ForEach(supportOrgs(for: user.addictionTypes), id: \.name) { org in
                            orgCard(org: org)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Crisis Hotlines")
                            .font(.system(size: 10, weight: .heavy))
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(AnchorTheme.rose)

                        hotlineCard(name: "988 Suicide & Crisis Lifeline", number: "988", tel: "tel://988", detail: "Call or text 988 — 24/7, free, confidential")

                        ForEach(user.addictionTypes) { type in
                            hotlineCard(name: type.crisisHotlineName, number: type.crisisHotlineNumber, tel: type.crisisHotlineTel, detail: type.crisisHotlineDescription)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
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

    private func toolCard(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
            .padding(14)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
            )
        }
    }

    private func addictionResourcesCard(type: AddictionType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(AnchorTheme.primary)
                Text("\(type.displayName) Recovery Tips")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)
            }

            ForEach(recoveryTips(for: type), id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AnchorTheme.primary)
                        .padding(.top, 3)
                    Text(tip)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        .lineSpacing(2)
                }
            }
        }
        .padding(20)
        .anchorCard()
    }

    private func recoveryTips(for type: AddictionType) -> [String] {
        switch type {
        case .nicotine:
            return [
                "Delay: When a craving hits, wait 10 minutes. Most pass in 3-5.",
                "Deep breaths: 4-7-8 breathing mimics the inhale/exhale pattern of smoking.",
                "Drink water: Cold water through a straw satisfies the oral fixation.",
                "Distract: Move your body — even a 5-minute walk resets the urge.",
                "Avoid triggers: Change your routine around your usual smoke breaks.",
            ]
        case .alcohol:
            return [
                "HALT: Before a craving, check — are you Hungry, Angry, Lonely, or Tired?",
                "Play the tape forward: Imagine how you'll feel tomorrow if you drink tonight.",
                "Have a go-to drink: Keep a non-alcoholic option you genuinely enjoy.",
                "Tell someone: Text a friend or call your sponsor when urges spike.",
                "Change the scene: Leave the environment that's triggering you.",
            ]
        case .drugs:
            return [
                "Remove access: Delete contacts, avoid old neighborhoods, clear out paraphernalia.",
                "Urge surf: Cravings peak in 15-30 minutes. Ride it out — it will pass.",
                "Move your body: Exercise releases the same endorphins your brain is craving.",
                "Call before you use: Reach out to anyone — a hotline, a friend, your sponsor.",
                "One hour at a time: If a whole day feels too long, just get through the next hour.",
            ]
        }
    }

    struct SupportOrg {
        let name: String
        let description: String
        let icon: String
    }

    private func supportOrgs(for types: [AddictionType]) -> [SupportOrg] {
        var orgs: [SupportOrg] = []

        if types.contains(.nicotine) {
            orgs.append(SupportOrg(name: "Nicotine Anonymous", description: "12-step fellowship for nicotine addiction", icon: "person.3.fill"))
            orgs.append(SupportOrg(name: "BecomeAnEX", description: "Free quit plan and community support", icon: "star.fill"))
        }
        if types.contains(.alcohol) {
            orgs.append(SupportOrg(name: "Alcoholics Anonymous (AA)", description: "12-step recovery meetings worldwide", icon: "person.3.fill"))
            orgs.append(SupportOrg(name: "SMART Recovery", description: "Science-based mutual support groups", icon: "brain.head.profile.fill"))
        }
        if types.contains(.drugs) {
            orgs.append(SupportOrg(name: "Narcotics Anonymous (NA)", description: "12-step recovery for drug addiction", icon: "person.3.fill"))
            orgs.append(SupportOrg(name: "SMART Recovery", description: "Science-based mutual support groups", icon: "brain.head.profile.fill"))
        }

        orgs.append(SupportOrg(name: "SAMHSA Treatment Locator", description: "Find treatment facilities near you", icon: "map.fill"))

        var seen = Set<String>()
        return orgs.filter { seen.insert($0.name).inserted }
    }

    private func orgCard(org: SupportOrg) -> some View {
        HStack(spacing: 12) {
            Image(systemName: org.icon)
                .font(.system(size: 14))
                .foregroundColor(AnchorTheme.primary)
                .frame(width: 32, height: 32)
                .background(AnchorTheme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(org.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                Text(org.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
            Spacer()
        }
        .padding(14)
        .anchorCard()
    }

    private func hotlineCard(name: String, number: String, tel: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 14))
                .foregroundColor(AnchorTheme.rose)
                .frame(width: 32, height: 32)
                .background(AnchorTheme.rose.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }

            Spacer()

            if let url = URL(string: tel) {
                Link(destination: url) {
                    Text("Call")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
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

import SwiftUI

struct StatsView: View {
    @ObservedObject var store: DataStore
    @State private var showResetConfirm = false
    @Environment(\.colorScheme) var colorScheme

    private let milestones: [(days: Int, label: String, emoji: String)] = [
        (1, "Day One", "🌱"), (7, "1 Week", "⭐"), (30, "30 Days", "🏅"),
        (90, "90 Days", "🎖️"), (180, "6 Months", "💎"), (365, "1 Year", "🏆"),
        (730, "2 Years", "👑"), (1825, "5 Years", "🌟"),
    ]

    var body: some View {
        guard let user = store.userData else { return AnyView(EmptyView()) }
        let totalSaved = user.totalMoneySaved

        let maxDays = user.addictionTypes.map { user.daysSober(for: $0) }.max() ?? 0
        let earned = milestones.filter { maxDays >= $0.days }

        return AnyView(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Progress")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Text("Every day counts. Look how far you've come.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)

                    ForEach(user.addictionTypes) { type in
                        let days = user.daysSober(for: type)
                        HStack {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(AnchorTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                                Text(type.sobrietyLabel.lowercased())
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            }

                            Spacer()

                            Text("\(days.formatted()) days")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(AnchorTheme.primary)
                        }
                        .padding(16)
                        .anchorCard()
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statTile(label: "Money Saved", value: String(format: "$%.2f", totalSaved), bg: AnchorTheme.amber)
                        statTileCard(label: "Milestones", value: "\(earned.count)/\(milestones.count)")
                        statTileCard(label: "Check-ins", value: "\(store.moods.count)")
                        statTileCard(label: "Cravings Logged", value: "\(store.cravings.count)")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestone Badges")
                            .font(.system(size: 10, weight: .heavy))
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                            ForEach(milestones, id: \.days) { m in
                                let isEarned = maxDays >= m.days
                                VStack(spacing: 4) {
                                    Text(m.emoji)
                                        .font(.system(size: 28))
                                    Text(m.label)
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    isEarned
                                    ? (colorScheme == .dark ? Color(hex: "78350F").opacity(0.2) : Color(hex: "FFFBEB"))
                                    : (colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            isEarned ? Color(hex: "FCD34D").opacity(0.5) : (colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border),
                                            lineWidth: 1
                                        )
                                )
                                .opacity(isEarned ? 1 : 0.4)
                                .grayscale(isEarned ? 0 : 1)
                            }
                        }
                    }

                    if !store.cravings.isEmpty {
                        cravingStats
                    }

                    Button(action: { showResetConfirm = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                            Text("Start Over")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
                        )
                    }
                    .alert("Start Over?", isPresented: $showResetConfirm) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) { store.reset() }
                    } message: {
                        Text("This will clear all your saved data.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        )
    }

    private func statTile(label: String, value: String, bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statTileCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .anchorCard()
    }

    private var cravingStats: some View {
        let total = store.cravings.count
        let avgIntensity = Double(store.cravings.reduce(0) { $0 + $1.intensity }) / Double(total)
        let triggerCounts = Dictionary(grouping: store.cravings, by: \.trigger).mapValues(\.count)
        let topTrigger = triggerCounts.max(by: { $0.value < $1.value })?.key ?? "-"

        return VStack(alignment: .leading, spacing: 12) {
            Text("Craving Patterns")
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AnchorTheme.primary)

            Text("\(total) urge\(total != 1 ? "s" : "") logged - recognizing them is a superpower.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)

            HStack(spacing: 12) {
                miniStat(value: "\(total)", label: "Total")
                miniStat(value: String(format: "%.1f", avgIntensity), label: "Avg Intensity")
                VStack(spacing: 2) {
                    Text(topTrigger)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    Text("Top trigger")
                        .font(.system(size: 9, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(20)
        .anchorCard()
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
        }
        .padding(8)
        .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

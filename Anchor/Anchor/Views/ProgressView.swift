import SwiftUI

struct ProgressView: View {
    @ObservedObject var store: DataStore
    @ObservedObject var healthKit = HealthKitManager.shared
    @ObservedObject var monitor = CrisisMonitorService.shared
    @ObservedObject var connectivity = WatchConnectivityManager.shared
    @State private var section: Section = .stats
    @State private var showResetConfirm = false
    @Environment(\.colorScheme) var colorScheme

    enum Section { case stats, health }

    private var addictionTypes: [AddictionType] {
        store.userData?.addictionTypes ?? []
    }

    private let milestones: [(days: Int, label: String, emoji: String)] = [
        (1, "Day One", "🌱"), (7, "1 Week", "⭐"), (30, "30 Days", "🏅"),
        (90, "90 Days", "🎖️"), (180, "6 Months", "💎"), (365, "1 Year", "🏆"),
        (730, "2 Years", "👑"), (1825, "5 Years", "🌟"),
    ]

    var body: some View {
        guard let user = store.userData else { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Progress")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)

                    HStack(spacing: 8) {
                        sectionButton("Milestones", selected: section == .stats) { section = .stats }
                        sectionButton("Health", selected: section == .health) { section = .health }
                    }

                    if section == .stats {
                        statsContent(user: user)
                    } else {
                        healthContent(user: user)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        )
    }

    private func sectionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(selected ? .white : (colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selected ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func statsContent(user: UserData) -> some View {
        let maxDays = user.daysUsingApp
        let earned = milestones.filter { maxDays >= $0.days }
        let totalSaved = user.totalMoneySaved

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(label: "Money Saved", value: String(format: "$%.2f", totalSaved), bg: AnchorTheme.amber)
            statTileCard(label: "Milestones", value: "\(earned.count)/\(milestones.count)")
            statTileCard(label: "Journal Entries", value: "\(store.journal.count)")
            statTileCard(label: "Cravings Logged", value: "\(store.cravings.count)")
        }

        ForEach(user.addictionTypes) { type in
            let days = user.daysSober(for: type)
            let saved = user.moneySaved(for: type)
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(AnchorTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    Text("\(days) days \u{00B7} \(String(format: "$%.2f", saved)) saved")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }

                Spacer()
            }
            .padding(14)
            .anchorCard()
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
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

    private func enableMonitoring() {
        Task {
            let authorized = await healthKit.requestAuthorization()
            await MainActor.run {
                if authorized {
                    store.isMonitoringEnabled = true
                    monitor.startMonitoring(for: addictionTypes)
                }
            }
        }
    }

    @ViewBuilder
    private func healthContent(user: UserData) -> some View {
        if monitor.isMonitoring {
            RiskBadge(risk: monitor.currentRisk, score: monitor.currentScore)
                .frame(maxWidth: .infinity)

            if let assessment = monitor.latestAssessment, !assessment.triggers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(assessment.triggers, id: \.self) { trigger in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: assessment.riskLevel.color))
                            Text(trigger)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: monitor.latestAssessment!.riskLevel.color).opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AnchorTheme.mutedForeground)
                Text("Monitoring is paused. Enable it below.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .anchorCard()
        }

        let metrics = healthKit.currentMetrics
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            VitalCard(title: "Heart Rate", value: metrics.heartRate.map { "\(Int($0))" } ?? "--", unit: "bpm", icon: "heart.fill", status: metrics.heartRateStatus)
            VitalCard(title: "Blood Oxygen", value: metrics.bloodOxygen.map { "\(Int($0))" } ?? "--", unit: "SpO2 %", icon: "lungs.fill", status: metrics.bloodOxygenStatus)
            VitalCard(title: "Breathing", value: metrics.respiratoryRate.map { "\(Int($0))" } ?? "--", unit: "br/min", icon: "wind", status: metrics.respiratoryRateStatus)
            VitalCard(title: "Temperature", value: metrics.wristTemperature.map { String(format: "%.1f", $0) } ?? "--", unit: "C", icon: "thermometer.medium", status: metrics.wristTemperature != nil ? .normal : .unknown)
        }

        if addictionTypes.contains(.nicotine) {
            nicotineRecoveryCard
        }

        MonitoringToggleCard(
            isEnabled: Binding(
                get: { store.isMonitoringEnabled },
                set: { newValue in
                    if newValue {
                        enableMonitoring()
                    } else {
                        monitor.stopMonitoring()
                        store.isMonitoringEnabled = false
                    }
                }
            ),
            watchConnected: connectivity.isWatchReachable,
            addictionTypes: addictionTypes
        )

        if let user = store.userData, !user.contacts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Emergency Contacts")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)

                ForEach(user.contacts) { contact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                            Text(contact.phone)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        }
                        Spacer()
                        if let url = URL(string: "tel://\(contact.cleanPhone)") {
                            Link(destination: url) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(AnchorTheme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .anchorCard()
        }

        let type = store.userData?.primaryAddiction ?? .drugs
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AnchorTheme.primary)
                Text("How it works")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
            }
            Text(type.healthDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                .lineSpacing(3)
        }
        .padding(20)
        .anchorCard()
    }

    private var nicotineRecoveryCard: some View {
        let days = store.userData?.daysSober(for: .nicotine) ?? 0
        let recoveryMilestones: [(days: Int, label: String, detail: String)] = [
            (1, "20 min", "Heart rate and blood pressure drop"),
            (1, "12 hours", "Carbon monoxide levels normalize"),
            (3, "3 days", "Nicotine fully leaves your body"),
            (14, "2 weeks", "Circulation and lung function improve"),
            (30, "1 month", "Coughing and shortness of breath decrease"),
            (90, "3 months", "Lung function significantly improved"),
            (270, "9 months", "Lungs have healed significantly"),
            (365, "1 year", "Heart disease risk cut in half"),
        ]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lungs.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AnchorTheme.primary)
                Text("Lung & Health Recovery")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)
            }

            ForEach(recoveryMilestones, id: \.label) { milestone in
                let achieved = days >= milestone.days
                HStack(spacing: 10) {
                    Image(systemName: achieved ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(achieved ? AnchorTheme.primary : AnchorTheme.mutedForeground)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Text(milestone.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                    Spacer()
                }
                .opacity(achieved ? 1 : 0.5)
            }
        }
        .padding(20)
        .anchorCard()
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

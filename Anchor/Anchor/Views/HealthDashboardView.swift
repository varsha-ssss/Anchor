import SwiftUI
import HealthKit
import UIKit

struct HealthDashboardView: View {
    @ObservedObject var healthKit = HealthKitManager.shared
    @ObservedObject var monitor = CrisisMonitorService.shared
    @ObservedObject var connectivity = WatchConnectivityManager.shared
    @ObservedObject var store: DataStore
    @Environment(\.colorScheme) var colorScheme

    @State private var isAuthorizing = false
    @State private var authError: String?

    private var addictionTypes: [AddictionType] {
        store.userData?.addictionTypes ?? []
    }

    private var hasNicotine: Bool {
        addictionTypes.contains(.nicotine)
    }

    private var healthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                headerSection

                if !healthDataAvailable {
                    unavailableCard
                } else {
                    riskSection
                    vitalsGrid

                    if hasNicotine {
                        nicotineRecoveryCard
                    }

                    monitoringToggle

                    if let error = authError {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AnchorTheme.amber)
                                Text(error)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            }
                            Button(action: openSettings) {
                                Text("Open Settings")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(AnchorTheme.amber)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .anchorCard()
                    }

                    contactsSection
                    infoCard

                    testAlertButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health Monitor")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                Text("Real-time vitals from Apple Watch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
            Spacer()
            Image(systemName: "applewatch.watchface")
                .font(.system(size: 28))
                .foregroundColor(AnchorTheme.primary)
        }
        .padding(.top, 24)
    }

    private var unavailableCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 32))
                .foregroundColor(AnchorTheme.mutedForeground)
            Text("HealthKit Not Available")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
            Text("Health monitoring requires a device with HealthKit support and a paired Apple Watch.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .anchorCard()
    }

    private var monitoringToggle: some View {
        VStack(spacing: 12) {
            MonitoringToggleCard(
                isEnabled: Binding(
                    get: { store.isMonitoringEnabled },
                    set: { newValue in
                        if newValue {
                            enableMonitoring()
                        } else {
                            disableMonitoring()
                        }
                    }
                ),
                watchConnected: connectivity.isWatchReachable,
                addictionTypes: addictionTypes
            )

            if isAuthorizing {
                HStack(spacing: 8) {
                    SwiftUI.ProgressView()
                        .scaleEffect(0.8)
                    Text("Requesting health access...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }
                .padding(8)
            }
        }
    }

    private func enableMonitoring() {
        guard !isAuthorizing else { return }
        isAuthorizing = true
        authError = nil

        Task {
            let authorized = await healthKit.requestAuthorization()
            await MainActor.run {
                isAuthorizing = false
                if authorized {
                    store.isMonitoringEnabled = true
                    monitor.startMonitoring(for: addictionTypes)
                } else {
                    authError = "Health access was denied. Go to Settings > Privacy & Security > Health > Anchor to enable."
                }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func disableMonitoring() {
        monitor.stopMonitoring()
        store.isMonitoringEnabled = false
    }

    private var riskSection: some View {
        VStack(spacing: 12) {
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
                    .background(Color(hex: assessment.riskLevel.color).opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AnchorTheme.mutedForeground)
                    Text("Monitoring is paused. Enable it below to track your vitals.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .anchorCard()
            }
        }
    }

    private var vitalsGrid: some View {
        let metrics = healthKit.currentMetrics
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            VitalCard(
                title: "Heart Rate",
                value: metrics.heartRate.map { "\(Int($0))" } ?? "--",
                unit: "bpm",
                icon: "heart.fill",
                status: metrics.heartRateStatus
            )
            VitalCard(
                title: "Blood Oxygen",
                value: metrics.bloodOxygen.map { "\(Int($0))" } ?? "--",
                unit: "SpO2 %",
                icon: "lungs.fill",
                status: metrics.bloodOxygenStatus
            )
            VitalCard(
                title: "Breathing",
                value: metrics.respiratoryRate.map { "\(Int($0))" } ?? "--",
                unit: "br/min",
                icon: "wind",
                status: metrics.respiratoryRateStatus
            )
            VitalCard(
                title: "Temperature",
                value: metrics.wristTemperature.map { String(format: "%.1f", $0) } ?? "--",
                unit: "C",
                icon: "thermometer.medium",
                status: metrics.wristTemperature != nil ? .normal : .unknown
            )
        }
    }

    private var nicotineRecoveryCard: some View {
        let days = store.userData?.daysSober(for: .nicotine) ?? 0
        let milestones: [(days: Int, label: String, detail: String)] = [
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

            ForEach(milestones, id: \.label) { milestone in
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

    private var contactsSection: some View {
        Group {
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
        }
    }

    /// Lets people (and their families) see exactly what happens in an alert before they need it.
    private var testAlertButton: some View {
        Button(action: runTestAlert) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                Text("Test the emergency alert")
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundColor(AnchorTheme.rose)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AnchorTheme.roseBorder, lineWidth: 1))
        }
    }

    private func runTestAlert() {
        let type = store.userData?.primaryAddiction ?? .drugs
        EmergencyService.shared.triggerEmergency(assessment: CrisisAssessment(
            riskLevel: .critical,
            score: 0,
            triggers: ["TEST ALERT - this is only a practice run", "Tap I'M OKAY to stop it"],
            shouldCallEmergency: true,
            timestamp: Date(),
            addictionType: type
        ), isTest: true)
    }

    private var infoCard: some View {
        let type = store.userData?.primaryAddiction ?? .drugs

        return VStack(alignment: .leading, spacing: 8) {
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
}

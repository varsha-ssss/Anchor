import SwiftUI

struct VitalCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let status: VitalStatus
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AnchorTheme.primary)
                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: status.color))
                Text(unit)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: status.color))
                    .frame(width: 6, height: 6)
                Text(status.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: status.color))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .anchorCard()
    }
}

struct RiskBadge: View {
    let risk: CrisisRiskLevel
    let score: Double

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: risk.color))
                .frame(width: 10, height: 10)
                .overlay(
                    risk == .critical ?
                    Circle()
                        .stroke(Color(hex: risk.color).opacity(0.4), lineWidth: 4)
                        .scaleEffect(1.5)
                    : nil
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(risk.label)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Color(hex: risk.color))
                Text("Risk Score: \(Int(score))/100")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: risk.color).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: risk.color).opacity(0.3), lineWidth: 1)
        )
    }
}

struct MonitoringToggleCard: View {
    @Binding var isEnabled: Bool
    let watchConnected: Bool
    var addictionTypes: [AddictionType] = []
    @Environment(\.colorScheme) var colorScheme

    private var monitoringLabel: String {
        if addictionTypes.count == 1 {
            return addictionTypes[0].monitoringLabel
        }
        return "Health Monitoring"
    }

    private var monitoringDetail: String {
        if addictionTypes.count == 1 {
            return addictionTypes[0].monitoringDescription
        }
        return "Watching heart rate, blood oxygen & breathing for danger signs"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitoringLabel)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(watchConnected ? Color(hex: "4ade80") : Color(hex: "94a3b8"))
                            .frame(width: 6, height: 6)
                        Text(watchConnected ? "Apple Watch connected" : "Apple Watch not detected")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .tint(AnchorTheme.primary)
                    .labelsHidden()
            }

            if isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12))
                        .foregroundColor(AnchorTheme.primary)
                    Text(monitoringDetail)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(AnchorTheme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .anchorCard()
    }
}

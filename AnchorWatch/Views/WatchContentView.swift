import SwiftUI

struct WatchContentView: View {
    @ObservedObject var monitor = WatchHealthMonitor.shared
    @State private var showingEmergency = false

    var body: some View {
        TabView {
            vitalsView
            controlView
        }
        .tabViewStyle(.verticalPage)
        .sheet(isPresented: $showingEmergency) {
            WatchEmergencyView()
        }
        .onChange(of: monitor.currentRisk) { _, newValue in
            if newValue == .critical {
                showingEmergency = true
            }
        }
    }

    private var vitalsView: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: monitor.currentRisk.color))
                        .frame(width: 8, height: 8)
                    Text(monitor.isMonitoring ? monitor.currentRisk.label : "Off")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Color(hex: monitor.currentRisk.color))
                }

                vitalRow(
                    icon: "heart.fill",
                    label: "Heart Rate",
                    value: monitor.heartRate > 0 ? "\(Int(monitor.heartRate))" : "--",
                    unit: "bpm",
                    color: vitalColor(for: monitor.heartRate, critical: 40, warning: 50, elevated: 55)
                )

                vitalRow(
                    icon: "lungs.fill",
                    label: "SpO2",
                    value: monitor.bloodOxygen > 0 ? "\(Int(monitor.bloodOxygen))" : "--",
                    unit: "%",
                    color: vitalColor(for: monitor.bloodOxygen, critical: 85, warning: 90, elevated: 93, inverted: false)
                )

                vitalRow(
                    icon: "wind",
                    label: "Breathing",
                    value: monitor.respiratoryRate > 0 ? "\(Int(monitor.respiratoryRate))" : "--",
                    unit: "br/m",
                    color: vitalColor(for: monitor.respiratoryRate, critical: 6, warning: 8, elevated: 10)
                )

                if monitor.isMonitoring {
                    HStack {
                        Text("Risk")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(monitor.riskScore))/100")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: monitor.currentRisk.color))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(hex: monitor.currentRisk.color).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func vitalRow(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(color)
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func vitalColor(for value: Double, critical: Double, warning: Double, elevated: Double, inverted: Bool = true) -> Color {
        guard value > 0 else { return .gray }
        if value < critical { return Color(hex: "ef4444") }
        if value < warning { return Color(hex: "fb923c") }
        if value < elevated { return Color(hex: "facc15") }
        return Color(hex: "4ade80")
    }

    private var controlView: some View {
        VStack(spacing: 12) {
            Image(systemName: monitor.isMonitoring ? "waveform.path.ecg" : "heart.text.clipboard")
                .font(.system(size: 30))
                .foregroundColor(AnchorTheme.primary)

            Text(monitor.isMonitoring ? "Monitoring Active" : "Monitoring Off")
                .font(.system(size: 14, weight: .heavy))

            Button(action: {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    Task {
                        await monitor.requestAuthorization()
                        monitor.startMonitoring()
                    }
                }
            }) {
                Text(monitor.isMonitoring ? "Stop" : "Start")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(monitor.isMonitoring ? Color(hex: "ef4444") : AnchorTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: { showingEmergency = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "sos")
                        .font(.system(size: 10, weight: .heavy))
                    Text("SOS")
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(hex: "ef4444"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 8)
    }
}

struct WatchEmergencyView: View {
    @Environment(\.dismiss) var dismiss
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseScale)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.red)
            }

            Text("EMERGENCY")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.red)

            Text("Alerting iPhone...")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            Button("I'm OK") {
                dismiss()
            }
            .font(.system(size: 14, weight: .heavy))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(hex: "4ade80"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.4
            }
            WatchHealthMonitor.shared.reportFall()
        }
    }
}

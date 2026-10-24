import SwiftUI

struct ContentView: View {
    @StateObject var store = DataStore()
    @ObservedObject var emergency = EmergencyService.shared
    @ObservedObject var monitor = CrisisMonitorService.shared
    @State private var selectedPage: AppPage = .home
    @State private var showSidebar = false
    @Environment(\.colorScheme) var colorScheme

    enum AppPage: String, CaseIterable {
        case home, journal, health, progress, resources, messages, settings

        var label: String {
            switch self {
            case .home: return "Home"
            case .journal: return "Journal"
            case .health: return "Health"
            case .progress: return "Progress"
            case .resources: return "Resources"
            case .messages: return "Messages"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .journal: return "book.fill"
            case .health: return "heart.fill"
            case .progress: return "chart.bar.fill"
            case .resources: return "folder.fill"
            case .messages: return "envelope.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? AnchorTheme.backgroundDark : AnchorTheme.background)
                .ignoresSafeArea()

            if store.userData == nil {
                OnboardingView(store: store)
            } else {
                mainApp
            }

            if emergency.isEmergencyActive {
                EmergencyView(
                    userName: store.userData?.name ?? "",
                    contacts: store.userData?.contacts ?? [],
                    motivation: store.userData?.motivation ?? ""
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onAppear {
            setupCrisisCallbacks()
            WatchConnectivityManager.shared.activate()
            resumeMonitoringIfEnabled()
        }
    }

    private var mainApp: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                topBar

                Group {
                    switch selectedPage {
                    case .home:
                        HomeView(store: store)
                    case .journal:
                        JournalView(store: store)
                    case .health:
                        HealthDashboardView(store: store)
                    case .progress:
                        ProgressView(store: store)
                    case .resources:
                        ResourcesView(store: store)
                    case .messages:
                        MessagesView(store: store)
                    case .settings:
                        SettingsView(store: store)
                    }
                }
            }

            if showSidebar {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { showSidebar = false } }
                    .zIndex(10)

                sidebarView
                    .transition(.move(edge: .leading))
                    .zIndex(11)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: {
                withAnimation(.easeOut(duration: 0.25)) { showSidebar.toggle() }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                    .padding(10)
            }

            Spacer()

            Text(selectedPage.label)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border),
            alignment: .bottom
        )
    }

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let user = store.userData {
                HStack(spacing: 12) {
                    TideSeaTurtle(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        let maxDays = user.addictionTypes.map { user.daysSober(for: $0) }.max() ?? 0
                        Text("Day \(maxDays)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AnchorTheme.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 24)
            }

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 4) {
                ForEach(AppPage.allCases, id: \.self) { page in
                    sidebarButton(page: page)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)

            Spacer()

            if let user = store.userData, !user.contacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emergency Contacts")
                        .font(.system(size: 9, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)

                    ForEach(user.contacts) { contact in
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AnchorTheme.primary)
                            Text(contact.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                            Spacer()
                            if let url = URL(string: "tel://\(contact.cleanPhone)") {
                                Link(destination: url) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(AnchorTheme.primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 280)
        .background(colorScheme == .dark ? AnchorTheme.backgroundDark : AnchorTheme.background)
    }

    private func sidebarButton(page: AppPage) -> some View {
        Button(action: {
            selectedPage = page
            withAnimation(.easeOut(duration: 0.25)) { showSidebar = false }
        }) {
            HStack(spacing: 14) {
                Image(systemName: page.icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                Text(page.label)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundColor(selectedPage == page ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground))
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(selectedPage == page ? AnchorTheme.primary.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Monitoring is a saved setting, so turn it back on after the app relaunches.
    private func resumeMonitoringIfEnabled() {
        guard store.isMonitoringEnabled, let types = store.userData?.addictionTypes else { return }
        monitor.startMonitoring(for: types)
    }

    private func setupCrisisCallbacks() {
        monitor.onCriticalRisk = { [self] assessment in
            emergency.triggerEmergency(assessment: assessment)

            WatchConnectivityManager.shared.sendMessage(.crisisTriggered, data: [
                "score": assessment.score,
                "triggers": assessment.triggers
            ])
        }

        WatchConnectivityManager.shared.onCrisisDetected = { [self] data in
            monitor.reportWatchCrisis(data: data)
        }
    }
}

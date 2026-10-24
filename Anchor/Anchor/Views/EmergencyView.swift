import SwiftUI
import MessageUI

struct EmergencyView: View {
    @ObservedObject var emergency = EmergencyService.shared
    let userName: String
    let contacts: [EmergencyContact]
    var motivation: String = ""

    @State private var pulseScale: CGFloat = 1.0
    @State private var flashOpacity: Double = 0.0
    @State private var showMotivation = false
    @State private var showTextComposer = false

    private var assessment: CrisisAssessment? { emergency.activeAssessment }
    private var addictionType: AddictionType { assessment?.addictionType ?? .drugs }
    private var validContacts: [EmergencyContact] { contacts.filter(\.isValid) }

    var body: some View {
        ZStack {
            Color(hex: "DC2626")
                .ignoresSafeArea()

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if emergency.isTest {
                        Text("TEST ALERT · NOTHING WILL BE SENT")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1)
                            .foregroundColor(Color(hex: "DC2626"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .padding(.top, 16)
                    }

                    alertIcon
                        .padding(.top, emergency.isTest ? 20 : 48)

                    Text(addictionType.crisisLabel)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)

                    switch emergency.phase {
                    case .checking: checkingContent
                    case .needsHelp: needsHelpContent
                    }

                    triggerList
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            VStack {
                Spacer()
                cancelButton
            }
        }
        .sheet(isPresented: $showTextComposer) {
            MessageComposer(
                recipients: validContacts.map(\.cleanPhone),
                body: emergency.emergencyTextBody(userName: userName)
            )
        }
        .onAppear(perform: startAnimations)
    }

    // MARK: - Phase 1: "Are you okay?"

    private var checkingContent: some View {
        VStack(spacing: 0) {
            Text("Are you okay?")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 6)

            if !motivation.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("\"\(motivation)\"")
                    .font(.system(size: 16, weight: .heavy))
                    .italic()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .opacity(showMotivation ? 1 : 0.3)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: showMotivation)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 6)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(emergency.emergencyCountdown) / CGFloat(EmergencyService.countdownSeconds))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: emergency.emergencyCountdown)

                VStack(spacing: 0) {
                    Text("\(emergency.emergencyCountdown)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("seconds")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)
                }
            }
            .padding(.top, 24)

            Text("If you don't respond, Anchor will sound the alarm for people nearby and get 911 and your contacts ready.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
        }
    }

    // MARK: - Phase 2: no response, ask anyone nearby for help

    private var needsHelpContent: some View {
        VStack(spacing: 12) {
            Text(addictionType.bystanderInstructions)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.bottom, 8)

            emergencyButton(icon: "phone.fill", title: "CALL 911", filled: true) {
                emergency.call911()
            }

            if !validContacts.isEmpty {
                emergencyButton(icon: "message.fill", title: "TEXT MY EMERGENCY CONTACTS", filled: false) {
                    sendTextToContacts()
                }

                ForEach(validContacts) { contact in
                    emergencyButton(icon: "person.fill", title: "Call \(contact.name)", filled: false) {
                        emergency.call(contact)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var triggerList: some View {
        Group {
            if let assessment, !assessment.triggers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why Anchor raised this alert")
                        .font(.system(size: 10, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.7))
                    ForEach(assessment.triggers, id: \.self) { trigger in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .padding(.top, 2)
                            Text(trigger)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 20)
                .padding(.bottom, 110)
            } else {
                Color.clear.frame(height: 110)
            }
        }
    }

    private var alertIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)

            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 104, height: 104)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44, weight: .heavy))
                .foregroundColor(.white)
        }
    }

    private var cancelButton: some View {
        VStack(spacing: 8) {
            Button(action: { emergency.cancelEmergency() }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text("I'M OKAY")
                        .font(.system(size: 16, weight: .heavy))
                }
                .foregroundColor(Color(hex: "DC2626"))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.2), radius: 10)
            }

            Text("Tap if this is a false alarm")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(
            LinearGradient(colors: [Color(hex: "DC2626").opacity(0), Color(hex: "DC2626")], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private func emergencyButton(icon: String, title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundColor(filled ? Color(hex: "DC2626") : .white)
            .padding(.vertical, filled ? 20 : 14)
            .frame(maxWidth: .infinity)
            .background(filled ? Color.white : Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(filled ? 0 : 0.5), lineWidth: 1.5)
            )
        }
    }

    private func sendTextToContacts() {
        if MFMessageComposeViewController.canSendText() {
            showTextComposer = true
        } else if let first = validContacts.first,
                  let body = emergency.emergencyTextBody(userName: userName)
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "sms:\(first.cleanPhone)&body=\(body)") {
            UIApplication.shared.open(url)
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            flashOpacity = 0.15
        }
        showMotivation = true
    }
}

/// Pre-filled iMessage/SMS sheet. iOS requires a person to tap Send — apps can't text silently.
struct MessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}

import SwiftUI

// letters to future self
struct MessagesView: View {
    @ObservedObject var store: DataStore
    @State private var writing = false
    @State private var messageText = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    TideSeaTurtle(size: 60)

                    Text("Messages to yourself")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)

                    Text("Write something for the version of you that's struggling. You'll thank yourself later.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 16)

                if writing {
                    VStack(spacing: 12) {
                        HStack {
                            Text("New Message")
                                .font(.system(size: 10, weight: .heavy))
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(AnchorTheme.primary)
                            Spacer()
                            Button(action: { writing = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            }
                        }

                        TextEditor(text: $messageText)
                            .font(.system(size: 14, weight: .medium))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                Group {
                                    if messageText.isEmpty {
                                        Text("Dear future me...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                                            .padding(.leading, 12)
                                            .padding(.top, 16)
                                    }
                                }, alignment: .topLeading
                            )

                        Button(action: saveMessage) {
                            Text("Save Message")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? AnchorTheme.primary.opacity(0.3) : AnchorTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                    .anchorCard()
                } else {
                    Button(action: { writing = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AnchorTheme.primary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "pencil.line")
                                    .font(.system(size: 16))
                                    .foregroundColor(AnchorTheme.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Write a message")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                                Text("For the you that needs it most")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundColor(AnchorTheme.primary.opacity(0.4))
                        )
                    }
                }

                if store.selfMessages.isEmpty && !writing {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        Text("No messages yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        Text("On a good day, write something to remind yourself why you're doing this.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor((colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground).opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(store.selfMessages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(message.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                                Spacer()
                                Button(action: { store.selfMessages.removeAll { $0.id == message.id } }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                                }
                            }

                            Text(message.content)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .anchorCard()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func saveMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.selfMessages.insert(
            SelfMessage(date: Date(), content: messageText.trimmingCharacters(in: .whitespaces)),
            at: 0
        )
        messageText = ""
        writing = false
    }
}

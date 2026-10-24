import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: DataStore

    @State private var isEditingProfile = false
    @State private var isEditingSobriety = false
    @State private var isEditingContacts = false

    @State private var editingName = ""
    @State private var editingAge = ""
    @State private var editingMotivation = ""
    @State private var editingAdditionalInfo = ""

    @State private var editingSobrietyDates: [AddictionType: Date] = [:]

    @State private var editingContact1Name = ""
    @State private var editingContact1Phone = ""
    @State private var editingContact2Name = ""
    @State private var editingContact2Phone = ""

    @State private var showResetConfirm = false
    @State private var showSignOutConfirm = false
    @AppStorage("anchor_appearance") private var appearanceMode: String = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) var colorScheme

    private var isEditing: Bool {
        isEditingProfile || isEditingSobriety || isEditingContacts
    }

    var body: some View {
        guard let user = store.userData else { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    profileSection(user: user)

                    sobrietySection(user: user)

                    contactsSection(user: user)

                    appearanceSection

                    if isEditing {
                        Button(action: { saveAllChanges() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Save Changes")
                                    .font(.system(size: 16, weight: .heavy))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AnchorTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    accountSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        )
    }

    private func profileSection(user: UserData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Profile")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)
                Spacer()
                Button(action: {
                    if !isEditingProfile { startEditingProfile(user: user) }
                    isEditingProfile.toggle()
                }) {
                    Text(isEditingProfile ? "Cancel" : "Edit")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(isEditingProfile ? AnchorTheme.rose : AnchorTheme.primary)
                }
            }

            if isEditingProfile {
                editableField("Name", text: $editingName)
                editableField("Age", text: $editingAge, keyboard: .numberPad)
                editableTextArea("Your Why", text: $editingMotivation)
                editableTextArea("Additional Info", text: $editingAdditionalInfo)
            } else {
                infoRow(label: "Name", value: user.name)
                infoRow(label: "Age", value: "\(user.age)")
                infoRow(label: "Tracking", value: user.addictionTypes.map { $0.displayName }.joined(separator: ", "))
                infoRow(label: "Your Why", value: user.motivation.isEmpty ? "Not set" : user.motivation)
                if !user.additionalInfo.trimmingCharacters(in: .whitespaces).isEmpty {
                    infoRow(label: "Additional Info", value: user.additionalInfo)
                }
                infoRow(label: "Reminders", value: user.reminderFrequency)
                infoRow(label: "Meetings", value: user.attendsMeetings.isEmpty ? "Not set" : user.attendsMeetings)
                infoRow(label: "Using Anchor since", value: user.appStartDate.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding(20)
        .anchorCard()
    }

    private func sobrietySection(user: UserData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sobriety Dates")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)
                Spacer()
                Button(action: {
                    if !isEditingSobriety { startEditingSobriety(user: user) }
                    isEditingSobriety.toggle()
                }) {
                    Text(isEditingSobriety ? "Cancel" : "Edit")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(isEditingSobriety ? AnchorTheme.rose : AnchorTheme.primary)
                }
            }

            ForEach(user.addictionTypes) { type in
                if isEditingSobriety {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14))
                                .foregroundColor(AnchorTheme.primary)
                                .frame(width: 24)
                            Text(type.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        }
                        DatePicker(
                            "Sobriety date",
                            selection: Binding(
                                get: { editingSobrietyDates[type] ?? Date() },
                                set: { editingSobrietyDates[type] = $0 }
                            ),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .tint(AnchorTheme.primary)
                    }
                    .padding(12)
                    .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let date = user.sobrietyDates[type] {
                    HStack {
                        Image(systemName: type.icon)
                            .font(.system(size: 14))
                            .foregroundColor(AnchorTheme.primary)
                            .frame(width: 24)
                        Text(type.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Spacer()
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                }
            }
        }
        .padding(20)
        .anchorCard()
    }

    private func contactsSection(user: UserData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Emergency Contacts")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(AnchorTheme.primary)
                Spacer()
                Button(action: {
                    if !isEditingContacts { startEditingContacts(user: user) }
                    isEditingContacts.toggle()
                }) {
                    Text(isEditingContacts ? "Cancel" : "Edit")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(isEditingContacts ? AnchorTheme.rose : AnchorTheme.primary)
                }
            }

            if isEditingContacts {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact 1")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    editableField("Name", text: $editingContact1Name)
                    editableField("Phone", text: $editingContact1Phone, keyboard: .phonePad)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact 2")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    editableField("Name", text: $editingContact2Name)
                    editableField("Phone", text: $editingContact2Phone, keyboard: .phonePad)
                }
            } else {
                if user.contacts.isEmpty {
                    Text("No emergency contacts set")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                } else {
                    ForEach(user.contacts) { contact in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                                Text(contact.phone)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            }
                            Spacer()
                            if let url = URL(string: "tel://\(contact.cleanPhone)") {
                                Link(destination: url) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(AnchorTheme.primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .anchorCard()
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AnchorTheme.primary)

            HStack(spacing: 10) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appearanceMode = mode.rawValue
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode == .system ? "circle.lefthalf.filled" : (mode == .light ? "sun.max.fill" : "moon.fill"))
                                .font(.system(size: 20))
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: .heavy))
                        }
                        .foregroundColor(appearanceMode == mode.rawValue ? .white : (colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(appearanceMode == mode.rawValue ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted))
                        )
                    }
                }
            }
        }
        .padding(20)
        .anchorCard()
    }

    private var accountSection: some View {
        VStack(spacing: 12) {
            Text("Account")
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AnchorTheme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { showSignOutConfirm = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
                )
            }
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { store.reset() }
            } message: {
                Text("You will be signed out and returned to the welcome screen.")
            }

            Button(action: { showResetConfirm = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                    Text("Reset All Data")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(AnchorTheme.rose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AnchorTheme.roseBorder, lineWidth: 1)
                )
            }
            .alert("Start Over?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset Everything", role: .destructive) { store.reset() }
            } message: {
                Text("This will erase all your data, journal entries, and progress. This cannot be undone.")
            }
        }
        .padding(20)
        .anchorCard()
    }

    private func startEditingProfile(user: UserData) {
        editingName = user.name
        editingAge = "\(user.age)"
        editingMotivation = user.motivation
        editingAdditionalInfo = user.additionalInfo
    }

    private func startEditingSobriety(user: UserData) {
        editingSobrietyDates = user.sobrietyDates
    }

    private func startEditingContacts(user: UserData) {
        let c1 = user.contacts.first
        let c2 = user.contacts.dropFirst().first
        editingContact1Name = c1?.name ?? ""
        editingContact1Phone = c1?.phone ?? ""
        editingContact2Name = c2?.name ?? ""
        editingContact2Phone = c2?.phone ?? ""
    }

    private func saveAllChanges() {
        guard var user = store.userData else { return }

        if isEditingProfile {
            user.name = editingName
            user.age = Int(editingAge) ?? user.age
            user.motivation = editingMotivation
            user.additionalInfo = editingAdditionalInfo
            isEditingProfile = false
        }

        if isEditingSobriety {
            user.sobrietyDates = editingSobrietyDates
            isEditingSobriety = false
        }

        if isEditingContacts {
            var contacts: [EmergencyContact] = []
            if !editingContact1Name.isEmpty {
                contacts.append(EmergencyContact(name: editingContact1Name, phone: editingContact1Phone))
            }
            if !editingContact2Name.isEmpty {
                contacts.append(EmergencyContact(name: editingContact2Name, phone: editingContact2Phone))
            }
            user.contacts = contacts
            isEditingContacts = false
        }

        store.userData = user
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeholder)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 14, weight: .medium))
                .padding(10)
                .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func editableTextArea(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeholder)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            TextEditor(text: text)
                .font(.system(size: 14, weight: .medium))
                .frame(minHeight: 60)
                .padding(6)
                .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

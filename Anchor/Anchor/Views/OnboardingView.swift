import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: DataStore
    @State private var step = 0
    @State private var name = ""
    @State private var age = ""
    @State private var selectedAddictions: Set<AddictionType> = []

    // Per-addiction states
    @State private var usageDurations: [AddictionType: String] = [:]
    @State private var usageFrequencies: [AddictionType: String] = [:]
    @State private var sobrietyMonths: [AddictionType: String] = [:]
    @State private var sobrietyYears: [AddictionType: String] = [:]

    @State private var attendsMeetings = ""
    @State private var motivation = ""
    @State private var reminderFrequency = ""
    @State private var contact1Name = ""
    @State private var contact1Phone = ""
    @State private var contact2Name = ""
    @State private var contact2Phone = ""
    @State private var additionalInfo = ""

    @State private var currentAddictionIndex = 0

    @Environment(\.colorScheme) var colorScheme

    private var sortedAddictions: [AddictionType] {
        Array(selectedAddictions).sorted { $0.rawValue < $1.rawValue }
    }

    private var perAddictionStepCount: Int { sortedAddictions.count * 3 }
    private var fixedStepsBeforeAddiction: Int { 3 }
    private var fixedStepsAfterAddiction: Int { 5 }
    private var totalSteps: Int { fixedStepsBeforeAddiction + perAddictionStepCount + fixedStepsAfterAddiction }

    private enum StepType {
        case name, age, pickAddictions
        case addictionDuration(AddictionType)
        case addictionFrequency(AddictionType)
        case addictionSobrietyDate(AddictionType)
        case meetings, motivation, reminders, contacts, additional
    }

    private var currentStepType: StepType {
        if step == 0 { return .name }
        if step == 1 { return .age }
        if step == 2 { return .pickAddictions }

        let addictionStep = step - fixedStepsBeforeAddiction
        if addictionStep < perAddictionStepCount {
            let addictionIdx = addictionStep / 3
            let subStep = addictionStep % 3
            let addiction = sortedAddictions[addictionIdx]
            switch subStep {
            case 0: return .addictionDuration(addiction)
            case 1: return .addictionFrequency(addiction)
            case 2: return .addictionSobrietyDate(addiction)
            default: return .name
            }
        }

        let postStep = step - fixedStepsBeforeAddiction - perAddictionStepCount
        switch postStep {
        case 0: return .meetings
        case 1: return .motivation
        case 2: return .reminders
        case 3: return .contacts
        case 4: return .additional
        default: return .name
        }
    }

    private var tideText: String {
        switch currentStepType {
        case .name:
            return "Hi there! I'm Tide, your recovery companion. What's your name?"
        case .age:
            return "Great to meet you, \(name.isEmpty ? "friend" : name)! How old are you?"
        case .pickAddictions:
            return "What would you like to work on? You can pick more than one."
        case .addictionDuration(let type):
            return "\(type.usageDurationQuestion)"
        case .addictionFrequency(let type):
            return "\(type.usageFrequencyQuestion)"
        case .addictionSobrietyDate(let type):
            return "\(type.sobrietyDateQuestion)"
        case .meetings:
            let type = sortedAddictions.first ?? .drugs
            return "\(type.meetingsQuestion)"
        case .motivation:
            return "This is so important. What is your biggest reason for staying on track? I'll remind you on the tough days."
        case .reminders:
            return "How often would you like check-ins and encouragement from me?"
        case .contacts:
            return "Who can I help connect you with when you need support? Add up to two people."
        case .additional:
            return "Almost done! Anything else you'd like me to know to help on your journey?"
        }
    }

    private var canProceed: Bool {
        switch currentStepType {
        case .name: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .age: return (Int(age) ?? 0) >= 18
        case .pickAddictions: return !selectedAddictions.isEmpty
        case .addictionSobrietyDate(let type):
            return !(sobrietyMonths[type] ?? "").isEmpty && !(sobrietyYears[type] ?? "").isEmpty
        case .motivation: return !motivation.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i <= step ? AnchorTheme.primary : AnchorTheme.primary.opacity(0.2))
                        .frame(height: 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)

            HStack(alignment: .bottom, spacing: 12) {
                TideSeaTurtle(size: 76)
                SpeechBubble(text: tideText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    inputForStep
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            HStack(spacing: 12) {
                if step > 0 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
                            )
                    }
                }

                Button(action: handleNext) {
                    Text(step == totalSteps - 1 ? "Start My Journey" : "Continue")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canProceed ? AnchorTheme.primary : AnchorTheme.primary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .disabled(!canProceed)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Text("Step \(step + 1) of \(totalSteps)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                .padding(.bottom, 16)
        }
        .background(colorScheme == .dark ? AnchorTheme.backgroundDark : AnchorTheme.background)
    }

    @ViewBuilder
    private var inputForStep: some View {
        switch currentStepType {
        case .name:
            styledTextField("Your first name", text: $name)
        case .age:
            VStack(alignment: .leading, spacing: 8) {
                styledTextField("Your age", text: $age, keyboard: .numberPad)
                Text("Anchor is for adults 18 and older.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
            }
        case .pickAddictions:
            addictionPicker
        case .addictionDuration(let type):
            selectOptions(type.usageDurationOptions, selected: binding(for: type, in: $usageDurations))
        case .addictionFrequency(let type):
            selectOptions(type.usageFrequencyOptions, selected: binding(for: type, in: $usageFrequencies))
        case .addictionSobrietyDate(let type):
            monthYearPicker(for: type)
        case .meetings:
            buttonOptions(["Yes", "Sometimes", "Not yet"], selected: $attendsMeetings)
        case .motivation:
            styledTextArea("My why is...", text: $motivation)
        case .reminders:
            selectOptions(["Daily", "Every few days", "Weekly", "Every two weeks"], selected: $reminderFrequency)
        case .contacts:
            contactInputs
        case .additional:
            styledTextArea("Anything else...", text: $additionalInfo)
        }
    }

    private var addictionPicker: some View {
        VStack(spacing: 12) {
            ForEach(AddictionType.allCases) { type in
                Button(action: {
                    if selectedAddictions.contains(type) {
                        selectedAddictions.remove(type)
                    } else {
                        selectedAddictions.insert(type)
                    }
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: type.icon)
                            .font(.system(size: 22))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.system(size: 16, weight: .heavy))
                            Text(addictionSubtitle(type))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(selectedAddictions.contains(type) ? .white.opacity(0.8) : (colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground))
                        }

                        Spacer()

                        if selectedAddictions.contains(type) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                    }
                    .foregroundColor(selectedAddictions.contains(type) ? .white : (colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground))
                    .padding(16)
                    .background(selectedAddictions.contains(type) ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedAddictions.contains(type) ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func addictionSubtitle(_ type: AddictionType) -> String {
        switch type {
        case .nicotine: return "Cigarettes, vapes, chewing tobacco"
        case .alcohol: return "Beer, wine, spirits"
        case .drugs: return "Opioids, stimulants, other substances"
        }
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 16, weight: .semibold))
            .padding(14)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
            )
    }

    private func styledTextArea(_ placeholder: String, text: Binding<String>) -> some View {
        TextEditor(text: text)
            .font(.system(size: 14, weight: .medium))
            .frame(minHeight: 100)
            .padding(10)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
            )
            .overlay(
                Group {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            .padding(.leading, 16)
                            .padding(.top, 18)
                    }
                }, alignment: .topLeading
            )
    }

    private func selectOptions(_ options: [String], selected: Binding<String>) -> some View {
        ForEach(options, id: \.self) { opt in
            Button(action: { selected.wrappedValue = opt }) {
                Text(opt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(selected.wrappedValue == opt ? .white : (colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(selected.wrappedValue == opt ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selected.wrappedValue == opt ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border), lineWidth: 1)
                    )
            }
        }
    }

    private func buttonOptions(_ options: [String], selected: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                Button(action: { selected.wrappedValue = opt }) {
                    Text(opt)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(selected.wrappedValue == opt ? .white : (colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selected.wrappedValue == opt ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected.wrappedValue == opt ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func monthYearPicker(for type: AddictionType) -> some View {
        let months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = (currentYear - 40...currentYear).reversed().map { String($0) }

        let monthBinding = Binding<String>(
            get: { sobrietyMonths[type] ?? "" },
            set: { sobrietyMonths[type] = $0 }
        )
        let yearBinding = Binding<String>(
            get: { sobrietyYears[type] ?? "" },
            set: { sobrietyYears[type] = $0 }
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text(type.displayName)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AnchorTheme.primary)

            HStack(spacing: 12) {
                Picker("Month", selection: monthBinding) {
                    Text("Month").tag("")
                    ForEach(months, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
                )

                Picker("Year", selection: yearBinding) {
                    Text("Year").tag("")
                    ForEach(years, id: \.self) { y in
                        Text(y).tag(y)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .padding(10)
                .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
                )
            }
        }
    }

    private var contactInputs: some View {
        VStack(spacing: 12) {
            contactCard(label: "Contact 1", name: $contact1Name, phone: $contact1Phone, optional: false)
            contactCard(label: "Contact 2", name: $contact2Name, phone: $contact2Phone, optional: true)
        }
    }

    private func contactCard(label: String, name: Binding<String>, phone: Binding<String>, optional: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(label)\(optional ? " (optional)" : "")")
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(AnchorTheme.primary)

            TextField("Full name", text: name)
                .font(.system(size: 14, weight: .semibold))
                .padding(10)
                .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("Phone number", text: phone)
                .keyboardType(.phonePad)
                .font(.system(size: 14, weight: .semibold))
                .padding(10)
                .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .anchorCard()
    }

    private func binding(for type: AddictionType, in dict: Binding<[AddictionType: String]>) -> Binding<String> {
        Binding<String>(
            get: { dict.wrappedValue[type] ?? "" },
            set: { dict.wrappedValue[type] = $0 }
        )
    }

    private func handleNext() {
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
            return
        }

        let months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
        var sobrietyDates: [AddictionType: Date] = [:]

        for type in sortedAddictions {
            let month = sobrietyMonths[type] ?? ""
            let year = sobrietyYears[type] ?? ""
            let monthIndex = months.firstIndex(of: month) ?? 0
            var components = DateComponents()
            components.year = Int(year) ?? Calendar.current.component(.year, from: Date())
            components.month = monthIndex + 1
            components.day = 1
            sobrietyDates[type] = Calendar.current.date(from: components) ?? Date()
        }

        var contacts: [EmergencyContact] = []
        if !contact1Name.isEmpty {
            contacts.append(EmergencyContact(name: contact1Name, phone: contact1Phone))
        }
        if !contact2Name.isEmpty {
            contacts.append(EmergencyContact(name: contact2Name, phone: contact2Phone))
        }

        store.userData = UserData(
            name: name,
            age: Int(age) ?? 25,
            addictionTypes: sortedAddictions,
            sobrietyDates: sobrietyDates,
            usageDurations: usageDurations,
            usageFrequencies: usageFrequencies,
            attendsMeetings: attendsMeetings,
            motivation: motivation,
            reminderFrequency: reminderFrequency,
            contacts: contacts,
            additionalInfo: additionalInfo
        )
    }
}

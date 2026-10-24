import SwiftUI

struct JournalView: View {
    @ObservedObject var store: DataStore
    @State private var view: JournalSubView = .journal
    @State private var writing = false
    @State private var entryText = ""
    @State private var expandedId: UUID?

    // Craving state
    @State private var loggingCraving = false
    @State private var cravingIntensity = 3
    @State private var cravingTrigger = ""
    @State private var cravingNotes = ""

    @Environment(\.colorScheme) var colorScheme

    private let triggers = [
        "Stress", "Boredom", "Social pressure", "Pain", "Anxiety",
        "Loneliness", "Anger", "Celebration", "Smell/sight", "Other",
    ]

    enum JournalSubView { case journal, cravings }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                        HStack(spacing: 8) {
                    subNavButton("📓 Journal", selected: view == .journal) { view = .journal }
                    subNavButton("🔥 Cravings", selected: view == .cravings) { view = .cravings }
                }
                .padding(.top, 24)

                if view == .journal {
                    journalContent
                } else {
                    cravingsContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func subNavButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
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
    private var journalContent: some View {
        if writing {
            VStack(spacing: 12) {
                HStack {
                    Text("New Entry — \(Date().formatted(date: .abbreviated, time: .omitted))")
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

                TextEditor(text: $entryText)
                    .font(.system(size: 14, weight: .medium))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        Group {
                            if entryText.isEmpty {
                                Text("Write whatever's on your mind...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                                    .padding(.leading, 12)
                                    .padding(.top, 16)
                            }
                        }, alignment: .topLeading
                    )

                Button(action: saveEntry) {
                    Text("Save Entry")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(entryText.trimmingCharacters(in: .whitespaces).isEmpty ? AnchorTheme.primary.opacity(0.3) : AnchorTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(entryText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
            .anchorCard()
        } else {
            Button(action: { writing = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AnchorTheme.primary.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "plus")
                            .font(.system(size: 16))
                            .foregroundColor(AnchorTheme.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Write today's entry")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Text("Capture your thoughts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                    Spacer()
                }
                .padding(16)
                .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundColor(AnchorTheme.primary.opacity(0.4))
                )
            }
        }

        if store.journal.isEmpty && !writing {
            VStack(spacing: 8) {
                Text("📓")
                    .font(.system(size: 30))
                Text("Your journal is empty.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                Text("Start writing to capture your journey.")
                    .font(.system(size: 12))
                    .foregroundColor((colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground).opacity(0.7))
            }
            .padding(.vertical, 32)
        }

        ForEach(store.journal) { entry in
            VStack(spacing: 0) {
                Button(action: { expandedId = expandedId == entry.id ? nil : entry.id }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            Text(entry.content)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                            .rotationEffect(.degrees(expandedId == entry.id ? 180 : 0))
                    }
                    .padding(20)
                }

                if expandedId == entry.id {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        Text(entry.content)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor((colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground).opacity(0.8))
                            .lineSpacing(4)

                        Button(action: { store.journal.removeAll { $0.id == entry.id } }) {
                            Text("Delete entry")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AnchorTheme.rose)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .anchorCard()
        }
    }

    @ViewBuilder
    private var cravingsContent: some View {
        if loggingCraving {
            VStack(spacing: 16) {
                HStack {
                    Text("Log a Craving")
                        .font(.system(size: 10, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundColor(AnchorTheme.primary)
                    Spacer()
                    Button(action: { loggingCraving = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                }

                Text("Intensity")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { n in
                        Button(action: { cravingIntensity = n }) {
                            Text("\(n)")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(cravingIntensity == n ? Color(hex: intensityColor(n)) : (colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(cravingIntensity == n ? Color(hex: intensityColor(n)).opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(cravingIntensity == n ? Color(hex: intensityColor(n)) : AnchorTheme.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }

                Text("\(intensityLabel(cravingIntensity)) intensity")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Color(hex: intensityColor(cravingIntensity)))

                Text("What triggered it?")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(triggers, id: \.self) { t in
                        Button(action: { cravingTrigger = t }) {
                            Text(t)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(cravingTrigger == t ? .white : (colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(cravingTrigger == t ? AnchorTheme.primary : (colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                TextField("Any notes? (optional)", text: $cravingNotes)
                    .font(.system(size: 14, weight: .medium))
                    .padding(12)
                    .background(colorScheme == .dark ? AnchorTheme.mutedDark : AnchorTheme.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Button(action: saveCraving) {
                    Text("Log Craving")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(cravingTrigger.isEmpty ? AnchorTheme.primary.opacity(0.3) : AnchorTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(cravingTrigger.isEmpty)
            }
            .padding(20)
            .anchorCard()
        } else {
            Button(action: { loggingCraving = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AnchorTheme.rose.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AnchorTheme.rose)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Log a craving")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Text("Identify what triggers you")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                    Spacer()
                }
                .padding(16)
                .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundColor(AnchorTheme.primary.opacity(0.4))
                )
            }
        }

        if !store.cravings.isEmpty {
            let triggerCounts = Dictionary(grouping: store.cravings, by: \.trigger).mapValues(\.count)
            let sorted = triggerCounts.sorted { $0.value > $1.value }.prefix(4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Common triggers")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)

                ForEach(Array(sorted), id: \.key) { trigger, count in
                    HStack {
                        Text(trigger)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                        Spacer()
                        Text("\(count)x")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AnchorTheme.primary)
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(store.cravings.count), height: 6)
                    }
                    .frame(height: 6)
                }
            }
            .padding(16)
            .anchorCard()

            Text("Recent cravings")
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(store.cravings.prefix(10)) { c in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: intensityColor(c.intensity)))
                                .frame(width: 8, height: 8)
                            Text(c.trigger)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
                            Text(intensityLabel(c.intensity))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        }
                        Text(c.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                        if !c.notes.isEmpty {
                            Text(c.notes)
                                .font(.system(size: 12, weight: .medium))
                                .italic()
                                .foregroundColor((colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground).opacity(0.7))
                        }
                    }
                    Spacer()
                    Button(action: { store.cravings.removeAll { $0.id == c.id } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                    }
                }
                .padding(16)
                .anchorCard()
            }
        }

        if store.cravings.isEmpty && !loggingCraving {
            VStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 30))
                Text("No cravings logged yet.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground)
                Text("Tracking them helps you see patterns.")
                    .font(.system(size: 12))
                    .foregroundColor((colorScheme == .dark ? AnchorTheme.mutedForegroundDark : AnchorTheme.mutedForeground).opacity(0.7))
            }
            .padding(.vertical, 32)
        }
    }

    private func saveEntry() {
        guard !entryText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.journal.insert(JournalEntry(date: Date(), content: entryText.trimmingCharacters(in: .whitespaces)), at: 0)
        entryText = ""
        writing = false
    }

    private func saveCraving() {
        guard !cravingTrigger.isEmpty else { return }
        store.cravings.insert(CravingEntry(date: Date(), intensity: cravingIntensity, trigger: cravingTrigger, notes: cravingNotes), at: 0)
        cravingTrigger = ""
        cravingNotes = ""
        cravingIntensity = 3
        loggingCraving = false
    }

    private func intensityColor(_ n: Int) -> String {
        if n <= 2 { return "4ade80" }
        if n == 3 { return "facc15" }
        return "f87171"
    }

    private func intensityLabel(_ n: Int) -> String {
        if n <= 2 { return "Low" }
        if n == 3 { return "Moderate" }
        return "High"
    }
}

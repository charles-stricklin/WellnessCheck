import SwiftUI
import SwiftData

/// One row in the Vitals list: either the user's own reading or one read from Apple Health.
private enum VitalEntry: Identifiable {
    case own(Reading)
    case health(HealthReading)

    var id: String {
        switch self {
        case .own(let r): "own-\(r.persistentModelID.hashValue)"
        case .health(let h): "health-\(h.id)"
        }
    }

    var value: any VitalValue {
        switch self {
        case .own(let r): r
        case .health(let h): h
        }
    }

    var kind: VitalKind { value.kind }
    var date: Date { value.date }

    /// Second line under the number: the note for own readings, the source for Health ones.
    var detail: String {
        switch self {
        case .own(let r): r.note.isEmpty ? r.kind.title : "\(r.kind.title) · \(r.note)"
        case .health(let h): "\(h.kind.title) · \(h.sourceName)"
        }
    }
}

/// The Vitals tab: the latest reading of each kind, then the full history by day.
struct VitalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @Query(sort: \Person.createdAt) private var people: [Person]
    // Remembered per device so the app reopens on whoever was last being looked at.
    @AppStorage("activePersonID") private var activePersonID = ""
    @State private var isAddingPerson = false
    @State private var health = HealthStore.shared
    @AppStorage(Onboarding.healthSkippedKey) private var healthSkipped = false
    @State private var isLogging = false
    @State private var isShowingReport = false
    @AppStorage(Preferences.openToLogReadingKey) private var openToLogReading = true
    /// Once per launch: switching tabs and coming back shouldn't pop the form again.
    @MainActor private static var didOpenLogOnLaunch = false
    /// When the app went to the background, so coming back after a long while
    /// counts like a fresh start (the morning reading after a night in the background).
    @MainActor private static var backgroundedAt: Date?
    private static let awayCountsAsNewVisit: TimeInterval = 3600
    @State private var router = AppRouter.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Latest") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(VitalKind.allCases) { kind in
                            VitalTile(kind: kind, latest: entries.first { $0.kind == kind })
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if activePerson?.isSelf == true && HealthRecords.isAvailable {
                    Section {
                        NavigationLink {
                            LabResultsView()
                        } label: {
                            Label("Lab Results", systemImage: "flask")
                        }
                    }
                }

                ForEach(days, id: \.self) { day in
                    Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                        ForEach(entries(on: day)) { entry in
                            EntryRow(entry: entry)
                                .deleteDisabled(!entry.isOwn)
                        }
                        .onDelete { offsets in delete(offsets, on: day) }
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Readings Yet",
                        systemImage: "heart.text.square",
                        description: Text("Tap + to log your first reading.")
                    )
                    .padding(.top, 200)
                }
            }
            .navigationTitle(activePerson.map { $0.isSelf ? "Vitals" : $0.name } ?? "Vitals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { personMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Report for Your Doctor", systemImage: "doc.text") { isShowingReport = true }
                        .disabled(activePerson == nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Log Reading", systemImage: "plus") { isLogging = true }
                        .disabled(activePerson == nil)
                }
            }
            .sheet(isPresented: $isLogging) {
                if let activePerson { LogReadingView(person: activePerson) }
            }
            .sheet(isPresented: $isShowingReport) {
                if let activePerson { ReportView(person: activePerson) }
            }
            .sheet(isPresented: $isAddingPerson) {
                AddPersonView { activePersonID = $0.id.uuidString }
            }
            .refreshable { await health.refresh() }
            .task {
                // Respect a Skip during setup; connecting later will live in Settings.
                if !healthSkipped { await health.requestAccess() }
                // After Apple's permission sheet, so the two never collide on screen.
                if (openToLogReading || router.openLogForm) && !Self.didOpenLogOnLaunch {
                    Self.didOpenLogOnLaunch = true
                    router.openLogForm = false
                    isLogging = true
                }
                await health.refresh()
            }
            // A tapped reminder: open the form, unless it's already up.
            .onChange(of: router.openLogForm) {
                guard router.openLogForm else { return }
                router.openLogForm = false
                isLogging = true
            }
            // Pick up readings a cuff or scale added while the app was in the background.
            .onChange(of: scenePhase) {
                switch scenePhase {
                case .background:
                    Self.backgroundedAt = .now
                case .active:
                    if openToLogReading, let away = Self.backgroundedAt,
                       Date.now.timeIntervalSince(away) >= Self.awayCountsAsNewVisit {
                        router.selectedTab = .vitals
                        isLogging = true
                    }
                    Self.backgroundedAt = nil
                    Task { await health.refresh() }
                default: break
                }
            }
        }
    }

    /// Whoever is selected, falling back to the owner.
    private var activePerson: Person? {
        people.first { $0.id.uuidString == activePersonID } ?? people.first { $0.isSelf }
    }

    private var personMenu: some View {
        Menu {
            Picker("Person", selection: Binding(get: { activePerson?.id.uuidString ?? "" }, set: { activePersonID = $0 })) {
                ForEach(people) { person in
                    Text(person.isSelf ? "\(person.name) (You)" : person.name).tag(person.id.uuidString)
                }
            }
            Divider()
            Button("Add Family Member", systemImage: "person.badge.plus") { isAddingPerson = true }
        } label: {
            Label(activePerson?.name ?? "People", systemImage: "person.crop.circle")
        }
    }

    /// The selected person's readings. Health readings belong to the phone's owner,
    /// so they appear only on the owner's profile.
    private var entries: [VitalEntry] {
        let own = readings.filter { $0.person?.id == activePerson?.id }.map(VitalEntry.own)
        let fromHealth = activePerson?.isSelf == true ? health.external.map(VitalEntry.health) : []
        return (own + fromHealth)
            .sorted { $0.date > $1.date }
    }

    private var days: [Date] {
        let calendar = Calendar.current
        var seen = Set<Date>()
        return entries.compactMap {
            let day = calendar.startOfDay(for: $0.date)
            return seen.insert(day).inserted ? day : nil
        }
    }

    private func entries(on day: Date) -> [VitalEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private func delete(_ offsets: IndexSet, on day: Date) {
        let dayEntries = entries(on: day)
        for index in offsets {
            guard case .own(let reading) = dayEntries[index] else { continue }
            if let sampleID = reading.healthSampleID {
                let kind = reading.kind
                Task { await health.delete(sampleID: sampleID, kind: kind) }
            }
            context.delete(reading)
        }
    }
}

private extension VitalEntry {
    var isOwn: Bool {
        if case .own = self { true } else { false }
    }

    var testIdentifier: String {
        switch self {
        case .own(let r): r.healthSampleID == nil ? "reading.own" : "reading.own.inHealth"
        case .health: "reading.fromHealth"
        }
    }
}

private struct VitalTile: View {
    let kind: VitalKind
    let latest: VitalEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(kind.title, systemImage: kind.symbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(latest.map { Units.formatted($0.value) } ?? "—")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                if latest != nil {
                    Text(Units.unitLabel(for: kind))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text(latest?.date.formatted(.relative(presentation: .named)) ?? "No readings")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct EntryRow: View {
    let entry: VitalEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Units.formatted(entry.value))
                        .font(.headline)
                        .monospacedDigit()
                    Text(Units.unitLabel(for: entry.kind))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        // Invisible to users; lets UI tests confirm a reading reached Apple Health.
        .accessibilityIdentifier(entry.testIdentifier)
    }
}

#Preview {
    VitalsView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

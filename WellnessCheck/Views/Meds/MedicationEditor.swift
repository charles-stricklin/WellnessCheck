import SwiftUI
import SwiftData

/// Adding or changing a medicine. Works on a draft and writes on Save, so Cancel
/// really cancels, and a changed schedule can be recorded as a dated dose change.
struct MedicationEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let person: Person
    var medication: Medication?

    @State private var name = ""
    @State private var strength = ""
    @State private var purpose = ""
    @State private var doctor: Doctor?
    @State private var unit: DoseUnit = .tablet
    @State private var frequency: MedFrequency = .daily
    @State private var weekdays: Set<Int> = []
    @State private var times: [DraftTime] = [DraftTime()]
    @State private var startDate = Date.now
    @State private var status: MedStatus = .taking
    @State private var statusNote = ""
    @State private var onHand = ""
    @State private var loaded = false
    @State private var isConfirmingDelete = false

    struct DraftTime: Identifiable {
        let id = UUID()
        var time = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
        var amount: Double = 1
        var amountText = "1"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, like Carvedilol", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Strength, like 25 mg", text: $strength)
                    TextField("What it's for", text: $purpose)
                }
                Section {
                    DoctorPicker(title: "Prescribed by", selection: $doctor)
                }

                Section("How You Take It") {
                    Picker("Comes as", selection: $unit) {
                        ForEach(DoseUnit.allCases) { Text($0.pickerLabel).tag($0) }
                    }
                    Picker("How often", selection: $frequency) {
                        ForEach(MedFrequency.allCases) { Text($0.label).tag($0) }
                    }
                    if frequency == .someDays { weekdayPicker }
                }

                if frequency != .asNeeded {
                    Section {
                        ForEach($times) { $draft in timeRow($draft) }
                            .onDelete { times.remove(atOffsets: $0) }
                        Button("Add a Time", systemImage: "plus.circle") { times.append(DraftTime()) }
                    } header: {
                        Text("Times")
                    } footer: {
                        Text("Different amounts at different times are fine, like 1 in the morning and 2 at bedtime.")
                    }
                }

                Section {
                    DatePicker("Started taking it", selection: $startDate, displayedComponents: .date)
                }

                Section {
                    LabeledContent("On hand") {
                        TextField("Optional", text: $onHand)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("How many \(unit.label(for: 2)) you have. It counts down as you check doses off, and warns you when about a week is left.")
                }

                Section {
                    Picker("Status", selection: $status) {
                        ForEach(MedStatus.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if status != .taking {
                        TextField("Why? (optional)", text: $statusNote, axis: .vertical)
                    }
                } footer: {
                    Text("Paused and stopped medicines stay on record but leave your checklist.")
                }

                if let medication, let changes = medication.changes, !changes.isEmpty {
                    Section("History") {
                        ForEach(changes.sorted { $0.date > $1.date }) { change in
                            LabeledContent(change.summary, value: change.date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }

                if medication != nil {
                    Section {
                        Button("Delete Medicine", role: .destructive) { isConfirmingDelete = true }
                    } footer: {
                        Text("To keep its history, mark it Stopped instead.")
                    }
                }
            }
            .navigationTitle(medication == nil ? "Add Medicine" : "Edit Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .confirmationDialog("Delete \(medication?.title ?? "this medicine")?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text("Its history of doses taken is deleted too.")
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Pieces

    private var weekdayPicker: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return HStack {
            ForEach(1...7, id: \.self) { day in
                let on = weekdays.contains(day)
                Button(symbols[day - 1]) {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: .circle)
                .foregroundStyle(on ? .white : .primary)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func timeRow(_ draft: Binding<DraftTime>) -> some View {
        HStack {
            DatePicker("Time", selection: draft.time, displayedComponents: .hourAndMinute)
                .labelsHidden()
            Spacer()
            if unit.isCountable {
                // Halves, because "take one-half tablet" is common.
                Stepper(value: draft.amount, in: 0.5...20, step: 0.5) {
                    Text(Dose.describe(draft.wrappedValue.amount, unit))
                        .monospacedDigit()
                }
                .fixedSize()
            } else {
                TextField("Amount", text: draft.amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .padding(.vertical, 6)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                Text(unit.label(for: 2)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Loading and saving

    private func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private func amount(of draft: DraftTime) -> Double? {
        let value = unit.isCountable ? draft.amount : parse(draft.amountText)
        return value.flatMap { $0 > 0 ? $0 : nil }
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if frequency == .someDays && weekdays.isEmpty { return false }
        if frequency != .asNeeded && (times.isEmpty || times.contains { amount(of: $0) == nil }) { return false }
        return onHand.trimmingCharacters(in: .whitespaces).isEmpty || parse(onHand) != nil
    }

    private func load() {
        guard !loaded, let med = medication else { return }
        loaded = true
        name = med.name
        strength = med.strength
        purpose = med.purpose
        doctor = med.doctor
        unit = med.unit
        frequency = med.frequency
        weekdays = Set(med.weekdays)
        startDate = med.startDate
        status = med.status
        statusNote = med.statusNote
        onHand = med.onHand.map { $0.formatted(.number.grouping(.never)) } ?? ""
        let saved = med.sortedTimes.map { time in
            DraftTime(time: time.date(on: .now), amount: time.amount, amountText: Dose.number(time.amount))
        }
        times = saved.isEmpty ? [DraftTime()] : saved
    }

    private func save() {
        let med = medication ?? {
            let new = Medication(name: "")
            context.insert(new)
            new.person = person
            return new
        }()
        let oldSchedule = medication?.scheduleSummary
        let oldStatus = medication?.status

        med.name = name.trimmingCharacters(in: .whitespaces)
        med.strength = strength.trimmingCharacters(in: .whitespaces)
        med.purpose = purpose.trimmingCharacters(in: .whitespaces)
        med.doctor = doctor
        med.unit = unit
        med.frequency = frequency
        med.weekdays = weekdays.sorted()
        med.startDate = startDate
        med.status = status
        med.statusNote = status == .taking ? "" : statusNote.trimmingCharacters(in: .whitespacesAndNewlines)
        med.onHand = parse(onHand)

        (med.times ?? []).forEach(context.delete)
        if frequency != .asNeeded {
            let calendar = Calendar.current
            for draft in times {
                guard let amount = amount(of: draft) else { continue }
                let parts = calendar.dateComponents([.hour, .minute], from: draft.time)
                let time = DoseTime(hour: parts.hour ?? 8, minute: parts.minute ?? 0, amount: amount)
                context.insert(time)
                time.medication = med
            }
        }

        // A dated trail of what changed, so "when did that dose change?" has an answer.
        if let oldSchedule, oldSchedule != med.scheduleSummary {
            addChange(to: med, "Now \(med.scheduleSummary)")
        }
        if let oldStatus, oldStatus != status {
            let reason = med.statusNote.isEmpty ? "" : " (\(med.statusNote))"
            addChange(to: med, "\(status.label)\(reason)")
        }
        try? context.save()
        dismiss()
    }

    private func addChange(to med: Medication, _ summary: String) {
        let change = DoseChange(summary: summary)
        context.insert(change)
        change.medication = med
    }

    private func delete() {
        if let medication { context.delete(medication) }
        try? context.save()
        dismiss()
    }
}

#Preview {
    MedicationEditor(person: Person(name: "Me", isSelf: true))
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

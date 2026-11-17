import SwiftUI
import SwiftData

/// The reading form: a box for each vital chosen in Settings, filled in together and
/// saved with one tap. Boxes left empty save nothing.
struct LogReadingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.formVitalsKey) private var formVitals = Preferences.defaultFormVitals

    let person: Person

    /// What's typed, by vital. Blood pressure uses both; everything else only `first`.
    @State private var first: [VitalKind: String] = [:]
    @State private var second: [VitalKind: String] = [:]
    /// Vitals not on their usual list, added for this one time only.
    @State private var extras: [VitalKind] = []
    @State private var date = Date.now
    @State private var note = ""

    private enum EntryState { case empty, complete, incomplete }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(shownKinds) { kind in row(for: kind) }
                } footer: {
                    Text("Fill in what you took. Anything left empty isn't saved.")
                }

                if !addableKinds.isEmpty {
                    Section {
                        Menu {
                            ForEach(addableKinds) { kind in
                                Button(kind.title, systemImage: kind.symbol) { extras.append(kind) }
                            }
                        } label: {
                            Label("Add another reading", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    DatePicker("Taken", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                } footer: {
                    if !person.isSelf {
                        Text("Kept in WellnessCheck only. Family members' readings aren't added to your Apple Health.")
                    }
                }
            }
            .navigationTitle("Log Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    // MARK: Pieces

    /// One line per vital: name on the left, box(es) and unit on the right.
    private func row(for kind: VitalKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Label(kind.title, systemImage: kind.symbol)
                Spacer(minLength: 4)
                if kind == .bloodPressure {
                    numberBox("Systolic, top number", text: binding(\.first, kind))
                    Text("/").foregroundStyle(.secondary).accessibilityHidden(true)
                    numberBox("Diastolic, bottom number", text: binding(\.second, kind))
                } else {
                    numberBox(kind.title, text: binding(\.first, kind))
                }
                Text(Units.unitLabel(for: kind))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
                    .accessibilityHidden(true)
            }
            if state(of: kind) == .incomplete {
                Text(kind == .bloodPressure ? "Enter both numbers, or leave both empty." : "That doesn't look like a number.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    /// A visibly boxed field, so it's obvious where to tap.
    private func numberBox(_ accessibilityName: String, text: Binding<String>) -> some View {
        TextField("", text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .padding(.vertical, 8)
            .frame(width: 60)
            .background(.fill.tertiary, in: .rect(cornerRadius: 8))
            .accessibilityLabel(accessibilityName)
    }

    private func binding(_ store: ReferenceWritableKeyPath<Self, [VitalKind: String]>, _ kind: VitalKind) -> Binding<String> {
        Binding { self[keyPath: store][kind] ?? "" } set: { self[keyPath: store][kind] = $0 }
    }

    // MARK: What's on the form

    private var shownKinds: [VitalKind] {
        let usual = Preferences.formVitals(from: formVitals)
        return usual + extras.filter { !usual.contains($0) }
    }

    private var addableKinds: [VitalKind] {
        VitalKind.allCases.filter { !shownKinds.contains($0) }
    }

    // MARK: Checking and saving

    /// Accepts "98.6" and, for locales that use it, "98,6".
    private func parse(_ text: String?) -> Double? {
        guard let text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private func isBlank(_ text: String?) -> Bool {
        (text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func state(of kind: VitalKind) -> EntryState {
        let needsSecond = kind == .bloodPressure
        if isBlank(first[kind]) && (!needsSecond || isBlank(second[kind])) { return .empty }
        let ok = parse(first[kind]) != nil && (!needsSecond || parse(second[kind]) != nil)
        return ok ? .complete : .incomplete
    }

    /// Something to save, and nothing half-entered that would silently be dropped.
    private var canSave: Bool {
        let states = shownKinds.map(state(of:))
        return states.contains(.complete) && !states.contains(.incomplete)
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var saved: [Reading] = []
        for kind in shownKinds where state(of: kind) == .complete {
            guard let value = parse(first[kind]) else { continue }
            let reading = Reading(
                kind: kind,
                date: date,
                value: Units.toStored(value, kind: kind),
                secondValue: kind == .bloodPressure ? parse(second[kind]) : nil,
                note: trimmedNote
            )
            context.insert(reading)
            reading.person = person
            saved.append(reading)
        }
        // Apple Health holds the phone owner's data only. The readings are safe in the
        // app either way; Health is a copy, so a refusal just leaves the ID empty.
        if person.isSelf {
            Task {
                for reading in saved {
                    reading.healthSampleID = await HealthStore.shared.save(reading)
                }
            }
        }
        dismiss()
    }
}

#Preview {
    LogReadingView(person: Person(name: "Me", isSelf: true))
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

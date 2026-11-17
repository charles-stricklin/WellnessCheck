import SwiftUI
import SwiftData

/// Shown when records come back empty: either none are connected, or access was declined.
private struct NoRecordsView: View {
    let what: String

    var body: some View {
        ContentUnavailableView {
            Label("No \(what) Found", systemImage: "heart.text.clipboard")
        } description: {
            Text("If your doctor, hospital or the VA shares health records with Apple Health, connect them in the Health app under Browse › Health Records. If you already have, check that WellnessCheck is allowed to read them in Health › Sharing › Apps.")
        }
    }
}

/// A checklist of records to bring in. Nothing is checked to start, because
/// lists from providers often include things people don't take (supplies, old prescriptions).
private struct RecordChecklist<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @Binding var chosen: Set<Item.ID>
    let isAlreadyAdded: (Item) -> Bool
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ForEach(items) { item in
            let added = isAlreadyAdded(item)
            let on = chosen.contains(item.id)
            Button {
                if on { chosen.remove(item.id) } else { chosen.insert(item.id) }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: added ? "checkmark.circle" : (on ? "checkmark.circle.fill" : "circle"))
                        .font(.title2)
                        .foregroundStyle(on ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        row(item)
                        if added {
                            Text("Already in your list").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(added)
            .accessibilityAddTraits(on ? .isSelected : [])
        }
    }
}

/// "Add from Health Records" on the Meds tab.
struct ImportMedicationsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var items: [RecordMedication]?
    @State private var chosen: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if let items {
                    if items.isEmpty {
                        NoRecordsView(what: "Medicines")
                    } else {
                        List {
                            Section {
                                RecordChecklist(items: items, chosen: $chosen, isAlreadyAdded: isAdded) { med in
                                    Text("\(med.name) \(med.strength)").foregroundStyle(.primary)
                                    if !med.instructions.isEmpty {
                                        Text(med.instructions).font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                            } footer: {
                                Text("Check the ones you take. Afterward, tap each one on the Meds tab to set when you take it.")
                            }
                        }
                    }
                } else {
                    ProgressView("Reading your records…")
                }
            }
            .navigationTitle("From Health Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chosen.isEmpty ? "Add" : "Add \(chosen.count)", action: add).disabled(chosen.isEmpty)
                }
            }
            .task { items = await HealthRecords.medications() }
        }
    }

    private func isAdded(_ med: RecordMedication) -> Bool {
        (person.medications ?? []).contains { $0.name.lowercased() == med.name.lowercased() }
    }

    private func add() {
        for med in items ?? [] where chosen.contains(med.id) {
            let new = Medication(name: med.name)
            new.strength = med.strength
            new.instructions = med.instructions
            new.startDate = med.date
            context.insert(new)
            new.person = person
        }
        try? context.save()
        dismiss()
    }
}

/// "Add from Health Records" in Medical ID's allergies.
struct ImportAllergiesView: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var items: [Allergy]?
    @State private var chosen: Set<String> = []

    struct Allergy: Identifiable { let name: String; var id: String { name } }

    var body: some View {
        NavigationStack {
            Group {
                if let items {
                    if items.isEmpty {
                        NoRecordsView(what: "Allergies")
                    } else {
                        List {
                            RecordChecklist(items: items, chosen: $chosen,
                                            isAlreadyAdded: { item in person.allergies.contains { $0.lowercased() == item.name.lowercased() } }) {
                                Text($0.name).foregroundStyle(.primary)
                            }
                        }
                    }
                } else {
                    ProgressView("Reading your records…")
                }
            }
            .navigationTitle("From Health Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        person.allergies += chosen.sorted()
                        dismiss()
                    }
                    .disabled(chosen.isEmpty)
                }
            }
            .task { items = await HealthRecords.allergies().map(Allergy.init) }
        }
    }
}

/// Lab results from health records, one line per test with its latest value.
struct LabResultsView: View {
    @State private var results: [LabResult]?

    var body: some View {
        Group {
            if let results {
                if results.isEmpty {
                    NoRecordsView(what: "Lab Results")
                } else {
                    List(latest, id: \.name) { result in
                        NavigationLink {
                            LabHistoryView(name: result.name, results: history(result.name))
                        } label: {
                            LabRow(result: result, showName: true)
                        }
                    }
                }
            } else {
                ProgressView("Reading your records…")
            }
        }
        .navigationTitle("Lab Results")
        .task { results = await HealthRecords.labResults() }
    }

    /// Newest result per test, tests in alphabetical order.
    private var latest: [LabResult] {
        Dictionary(grouping: results ?? [], by: \.name)
            .compactMap { $0.value.max { $0.date < $1.date } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func history(_ name: String) -> [LabResult] {
        (results ?? []).filter { $0.name == name }.sorted { $0.date > $1.date }
    }
}

private struct LabHistoryView: View {
    let name: String
    let results: [LabResult]

    var body: some View {
        List(results) { LabRow(result: $0, showName: false) }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LabRow: View {
    let result: LabResult
    let showName: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showName { Text(result.name).font(.headline) }
            HStack(alignment: .firstTextBaseline) {
                Text("\(result.value) \(result.unit)").font(showName ? .body : .headline).monospacedDigit()
                if let flag = result.flag {
                    Text(flag).font(.footnote.bold()).foregroundStyle(.orange)
                }
                Spacer()
                Text(result.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !result.range.isEmpty {
                Text("Normal range: \(result.range)").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

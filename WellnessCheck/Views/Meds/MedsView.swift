import SwiftUI
import SwiftData

/// The Meds tab: the active person's medicines, grouped Taking / Paused / Stopped.
struct MedsView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]
    // Shared with the Vitals tab, so both show the same person.
    @AppStorage("activePersonID") private var activePersonID = ""
    @State private var editing: Medication?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(MedStatus.allCases) { status in
                    let meds = medications(status)
                    if !meds.isEmpty {
                        Section(status.label) {
                            ForEach(meds) { med in
                                Button { editing = med } label: { MedRow(med: med) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .overlay {
                if allMedications.isEmpty {
                    ContentUnavailableView(
                        "No Medicines Yet",
                        systemImage: "pills",
                        description: Text("Tap + to add a medicine.")
                    )
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Medicine", systemImage: "plus") { isAdding = true }
                        .disabled(activePerson == nil)
                }
            }
            .sheet(isPresented: $isAdding) {
                if let activePerson { MedicationEditor(person: activePerson) }
            }
            .sheet(item: $editing) { med in
                if let activePerson { MedicationEditor(person: activePerson, medication: med) }
            }
        }
    }

    private var activePerson: Person? {
        people.first { $0.id.uuidString == activePersonID } ?? people.first { $0.isSelf }
    }

    private var title: String {
        guard let activePerson, !activePerson.isSelf else { return "Medicines" }
        return "\(activePerson.name)'s Medicines"
    }

    private var allMedications: [Medication] { activePerson?.medications ?? [] }

    private func medications(_ status: MedStatus) -> [Medication] {
        allMedications.filter { $0.status == status }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private struct MedRow: View {
    let med: Medication

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(med.title).font(.headline)
            Text(med.scheduleSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !med.purpose.isEmpty {
                Text(med.purpose)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if med.status != .taking, !med.statusNote.isEmpty {
                Text(med.statusNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            if med.isRunningLow, let daysLeft = med.daysLeft {
                Label(daysLeft == 0 ? "Out, or nearly. Request a refill."
                                    : "About \(daysLeft) days left. Time to request a refill.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            if let change = med.recentChange {
                Label("Changed \(change.date.formatted(.dateTime.month().day())): \(change.summary)",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .padding(.vertical, 2)
    }
}

#Preview {
    MedsView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

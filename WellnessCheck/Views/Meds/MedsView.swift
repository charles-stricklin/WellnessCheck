import SwiftUI
import SwiftData

/// The Meds tab: the active person's medicines, grouped Taking / Paused / Stopped.
struct MedsView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]
    // Shared with the Vitals tab, so both show the same person.
    @AppStorage("activePersonID") private var activePersonID = ""
    @State private var editing: Medication?
    @State private var isAdding = false
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(MedStatus.allCases) { status in
                    let meds = medications(status)
                    if !meds.isEmpty {
                        Section(status.label) {
                            ForEach(meds) { med in
                                // A tap rather than a Button, so the row's own "Took a Dose" button works.
                                MedRow(med: med)
                                    .onTapGesture { editing = med }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction(named: "Edit") { editing = med }
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
                    // Records are the owner's only, so for family it's a plain button.
                    if activePerson?.isSelf == true && HealthRecords.isAvailable {
                        Menu("Add Medicine", systemImage: "plus") {
                            Button("Add a Medicine", systemImage: "square.and.pencil") { isAdding = true }
                            Button("Add from Health Records", systemImage: "heart.text.clipboard") { isImporting = true }
                        }
                    } else {
                        Button("Add Medicine", systemImage: "plus") { isAdding = true }
                            .disabled(activePerson == nil)
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                if let activePerson { MedicationEditor(person: activePerson) }
            }
            .sheet(isPresented: $isImporting) {
                if let activePerson { ImportMedicationsView(person: activePerson) }
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
    @Environment(\.modelContext) private var context
    let med: Medication

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let data = med.pillPhoto, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 48, height: 48).clipShape(.rect(cornerRadius: 8))
                    .accessibilityHidden(true)
            }
            details
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(med.title).font(.headline)
            if !med.genericName.isEmpty {
                Text(med.genericName).font(.subheadline).foregroundStyle(.secondary)
            }
            if !med.appearance.isEmpty {
                Text(med.appearance).font(.subheadline).foregroundStyle(.secondary)
            }
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
            if let last = med.lastTaken {
                Text("Last taken \(last.formatted(.relative(presentation: .named)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let refills = med.refillsLeft {
                Text(refills == 1 ? "1 refill left" : "\(refills) refills left")
                    .font(.subheadline)
                    .foregroundStyle(refills == 0 ? .orange : .secondary)
            }
            // As-needed medicines never come up on the checklist, so they're logged here.
            if med.frequency == .asNeeded && med.status == .taking {
                Button("Took a Dose", systemImage: "checkmark.circle", action: logDose)
                    .buttonStyle(.bordered)
                    .padding(.top, 2)
            }
            if med.needsTimes {
                Label("Tap to set when you take it", systemImage: "clock.badge.exclamationmark")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
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

    private func logDose() {
        let amount = med.asNeededAmount
        let record = DoseRecord(date: .now, scheduledFor: .now, amount: amount)
        context.insert(record)
        record.medication = med
        if let onHand = med.onHand { med.onHand = max(0, onHand - amount) }
        try? context.save()
    }
}

#Preview {
    MedsView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

import SwiftUI
import SwiftData
import EventKit
import EventKitUI

/// The Appointments tab: the active person's visits, upcoming first.
struct AppointmentsView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]
    // Shared with the other tabs, so all of them show the same person.
    @AppStorage("activePersonID") private var activePersonID = ""
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                section("Upcoming", upcoming)
                section("Past", past)
                section("Canceled", canceled)
            }
            .overlay {
                if all.isEmpty {
                    ContentUnavailableView(
                        "No Appointments Yet",
                        systemImage: "calendar",
                        description: Text("Tap + to add a doctor's visit.")
                    )
                }
            }
            .navigationTitle(title)
            .navigationDestination(for: Appointment.self) { AppointmentDetailView(appointment: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Appointment", systemImage: "plus") { isAdding = true }
                        .disabled(activePerson == nil)
                }
            }
            .sheet(isPresented: $isAdding) {
                if let activePerson { AppointmentEditor(person: activePerson) }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ visits: [Appointment]) -> some View {
        if !visits.isEmpty {
            Section(title) {
                ForEach(visits) { visit in
                    NavigationLink(value: visit) { AppointmentRow(appointment: visit) }
                }
            }
        }
    }

    private var activePerson: Person? {
        people.first { $0.id.uuidString == activePersonID } ?? people.first { $0.isSelf }
    }

    private var title: String {
        guard let activePerson, !activePerson.isSelf else { return "Appointments" }
        return "\(activePerson.name)'s Visits"
    }

    private var all: [Appointment] { activePerson?.appointments ?? [] }
    private var upcoming: [Appointment] { all.filter { !$0.isCanceled && !$0.isPast }.sorted { $0.date < $1.date } }
    private var past: [Appointment] { all.filter { !$0.isCanceled && $0.isPast }.sorted { $0.date > $1.date } }
    private var canceled: [Appointment] { all.filter(\.isCanceled).sorted { $0.date > $1.date } }
}

private struct AppointmentRow: View {
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(appointment.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Text(appointment.date.formatted(.dateTime.day()))
                    .font(.title2.bold())
            }
            .frame(width: 48)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.doctor?.name ?? (appointment.reason.isEmpty ? "Appointment" : appointment.reason))
                    .font(.headline)
                Text(appointment.date.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let detail = [appointment.doctor?.specialty ?? "", appointment.doctor == nil ? "" : appointment.reason]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One visit: when, where and with whom, one-tap actions, then the notes.
struct AppointmentDetailView: View {
    @Environment(\.openURL) private var openURL
    let appointment: Appointment
    @State private var isEditing = false
    @State private var isAddingToCalendar = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appointment.date.formatted(date: .complete, time: .omitted))
                        .font(.title2.bold())
                    Text(appointment.date.formatted(date: .omitted, time: .shortened))
                        .font(.title3)
                    if appointment.isCanceled {
                        Text("Canceled").font(.headline).foregroundStyle(.red)
                    }
                    if !appointment.reason.isEmpty {
                        Text(appointment.reason).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let doctor = appointment.doctor {
                Section("With") {
                    NavigationLink { DoctorDetailView(doctor: doctor) } label: { DoctorRow(doctor: doctor) }
                }
            }

            Section {
                if let url = Contact.directionsURL(appointment.place) {
                    Button { openURL(url) } label: {
                        LabeledContent("Directions") { Text(appointment.place).multilineTextAlignment(.trailing) }
                    }
                }
                if let phone = appointment.doctor?.phone, let url = Contact.phoneURL(phone) {
                    Button { openURL(url) } label: { LabeledContent("Call the Office", value: phone) }
                }
                if !appointment.isPast && !appointment.isCanceled {
                    Button("Add to Calendar", systemImage: "calendar.badge.plus") { isAddingToCalendar = true }
                }
            }

            if !appointment.prepNotes.isEmpty {
                Section("Before the Visit") { Text(appointment.prepNotes) }
            }
            if !appointment.afterNotes.isEmpty {
                Section("What the Doctor Said") { Text(appointment.afterNotes) }
            } else if appointment.isPast && !appointment.isCanceled {
                Section {
                    Button("Write Down What the Doctor Said", systemImage: "square.and.pencil") { isEditing = true }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            if let person = appointment.person { AppointmentEditor(person: person, appointment: appointment) }
        }
        .sheet(isPresented: $isAddingToCalendar) {
            CalendarEventSheet(appointment: appointment).ignoresSafeArea()
        }
    }
}

/// Apple's own "New Event" screen, filled in. It runs outside the app, so no
/// calendar permission is needed and the person stays in control of what's saved.
struct CalendarEventSheet: UIViewControllerRepresentable {
    let appointment: Appointment
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let doctorName = appointment.doctor?.name
        event.title = doctorName.map { "Appointment with \($0)" } ?? (appointment.reason.isEmpty ? "Doctor's appointment" : appointment.reason)
        event.startDate = appointment.date
        event.endDate = appointment.date.addingTimeInterval(3600)
        event.location = appointment.place.isEmpty ? nil : appointment.place
        event.notes = [appointment.reason, appointment.prepNotes].filter { !$0.isEmpty }.joined(separator: "\n\n")
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

/// Adding or changing a visit.
struct AppointmentEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let person: Person
    var appointment: Appointment?

    @State private var date = Self.defaultDate
    @State private var doctor: Doctor?
    @State private var reason = ""
    @State private var location = ""
    @State private var prepNotes = ""
    @State private var afterNotes = ""
    @State private var isCanceled = false
    @State private var loaded = false
    @State private var isConfirmingDelete = false

    /// Tomorrow at 9, a likelier starting point than this exact minute.
    private static var defaultDate: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    DoctorPicker(title: "With", selection: $doctor)
                }
                Section {
                    TextField("Reason, like Checkup", text: $reason)
                    TextField(doctor?.address.isEmpty == false ? "Somewhere other than the doctor's office?" : "Where (optional)",
                              text: $location, axis: .vertical)
                } footer: {
                    if let address = doctor?.address, !address.isEmpty, location.isEmpty {
                        Text("At \(address)")
                    }
                }
                Section {
                    TextField("Fasting, what to bring, questions to ask…", text: $prepNotes, axis: .vertical)
                        .lineLimit(3...)
                } header: {
                    Text("Before the Visit")
                }
                Section {
                    TextField("Results, changes, next steps…", text: $afterNotes, axis: .vertical)
                        .lineLimit(3...)
                } header: {
                    Text("What the Doctor Said")
                } footer: {
                    Text("Fill this in after the visit, while it's fresh.")
                }
                if appointment != nil {
                    Section {
                        Toggle("Canceled", isOn: $isCanceled)
                        Button("Delete Appointment", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(appointment == nil ? "Add Appointment" : "Edit Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .confirmationDialog("Delete this appointment?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let appointment { context.delete(appointment) }
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("To keep it on record, mark it Canceled instead.")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let appointment else { return }
        loaded = true
        date = appointment.date
        doctor = appointment.doctor
        reason = appointment.reason
        location = appointment.location
        prepNotes = appointment.prepNotes
        afterNotes = appointment.afterNotes
        isCanceled = appointment.isCanceled
    }

    private func save() {
        let target = appointment ?? {
            let new = Appointment(date: date)
            context.insert(new)
            new.person = person
            return new
        }()
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        target.date = date
        target.doctor = doctor
        target.reason = clean(reason)
        target.location = clean(location)
        target.prepNotes = clean(prepNotes)
        target.afterNotes = clean(afterNotes)
        target.isCanceled = isCanceled
        try? context.save()
        dismiss()
    }
}

#Preview {
    AppointmentsView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

import SwiftUI
import SwiftData
import PhotosUI

/// The Doctors tab: the household's care team.
struct DoctorsView: View {
    @Query(sort: \Doctor.name) private var doctors: [Doctor]
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List(doctors) { doctor in
                NavigationLink(value: doctor) { DoctorRow(doctor: doctor) }
            }
            .overlay {
                if doctors.isEmpty {
                    ContentUnavailableView(
                        "No Doctors Yet",
                        systemImage: "stethoscope",
                        description: Text("Tap + to add someone on your care team.")
                    )
                }
            }
            .navigationTitle("Doctors")
            .navigationDestination(for: Doctor.self) { DoctorDetailView(doctor: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Doctor", systemImage: "plus") { isAdding = true }
                }
            }
            .sheet(isPresented: $isAdding) { DoctorEditor() }
        }
    }
}

struct DoctorRow: View {
    let doctor: Doctor

    var body: some View {
        HStack(spacing: 12) {
            DoctorBadge(doctor: doctor, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(doctor.name).font(.headline)
                let detail = [doctor.specialty, doctor.practice].filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Photo if there is one, otherwise initials in a circle.
struct DoctorBadge: View {
    let doctor: Doctor
    let size: CGFloat

    var body: some View {
        Group {
            if let data = doctor.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(doctor.initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// One doctor: one-tap call, email and directions, then their visits and medicines.
struct DoctorDetailView: View {
    @Environment(\.openURL) private var openURL
    let doctor: Doctor
    @State private var isEditing = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    DoctorBadge(doctor: doctor, size: 88)
                    Text(doctor.name).font(.title2.bold()).multilineTextAlignment(.center)
                    if !doctor.specialty.isEmpty {
                        Text(doctor.specialty).foregroundStyle(.secondary)
                    }
                    if !doctor.practice.isEmpty {
                        Text(doctor.practice).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                if let url = Contact.phoneURL(doctor.phone) {
                    Button { openURL(url) } label: { LabeledContent("Call", value: doctor.phone) }
                }
                if let url = Contact.emailURL(doctor.email) {
                    Button { openURL(url) } label: { LabeledContent("Email", value: doctor.email) }
                }
                if let url = Contact.directionsURL(doctor.address) {
                    Button { openURL(url) } label: {
                        LabeledContent("Directions") { Text(doctor.address).multilineTextAlignment(.trailing) }
                    }
                }
            }

            if !doctor.notes.isEmpty {
                Section("Notes") { Text(doctor.notes) }
            }

            let visits = (doctor.appointments ?? []).filter { !$0.isPast && !$0.isCanceled }.sorted { $0.date < $1.date }
            if !visits.isEmpty {
                Section("Upcoming Visits") {
                    ForEach(visits) { visit in
                        VStack(alignment: .leading) {
                            Text(visit.date.formatted(date: .abbreviated, time: .shortened))
                            if let person = visit.person, !person.isSelf {
                                Text("For \(person.name)").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            let meds = (doctor.medications ?? []).filter { $0.status == .taking }.sorted { $0.name < $1.name }
            if !meds.isEmpty {
                Section("Prescribed") {
                    ForEach(meds) { Text($0.title) }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) { DoctorEditor(doctor: doctor) }
    }
}

/// Builds the links behind the call, email and directions buttons.
enum Contact {
    static func phoneURL(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    static func emailURL(_ email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") ? URL(string: "mailto:\(trimmed)") : nil
    }

    static func directionsURL(_ address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "maps://?daddr=\(query)")
    }
}

/// Adding or changing a doctor. `onSave` lets other screens (a medicine, a visit)
/// add a doctor and pick them in one go.
struct DoctorEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var doctor: Doctor?
    var onSave: ((Doctor) -> Void)? = nil

    @State private var name = ""
    @State private var specialty = ""
    @State private var practice = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var photo: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var loaded = false
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        // A local copy: PhotosPicker builds its label off the main actor.
                        let current = photo
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            VStack(spacing: 6) {
                                if let current, let image = UIImage(data: current) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 88, height: 88).clipShape(.circle)
                                } else {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 56))
                                }
                                Text(current == nil ? "Add Photo (optional)" : "Change Photo").font(.footnote)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Name, like Dr. Jane Smith", text: $name)
                        .textContentType(.name)
                    TextField("Specialty, like Cardiology", text: $specialty)
                    TextField("Practice or hospital", text: $practice)
                        .textContentType(.organizationName)
                }
                Section {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                }
                Section("Notes") {
                    TextField("Office hours, nurse's name, portal…", text: $notes, axis: .vertical)
                }
                if doctor != nil {
                    Section {
                        Button("Delete Doctor", role: .destructive) { isConfirmingDelete = true }
                    }
                }
            }
            .navigationTitle(doctor == nil ? "Add Doctor" : "Edit Doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \(doctor?.name ?? "this doctor")?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let doctor { context.delete(doctor) }
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("Their visits and medicines are kept; they just won't show a doctor.")
            }
            .onChange(of: photoItem) {
                Task { photo = try? await photoItem?.loadTransferable(type: Data.self) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded, let doctor else { return }
        loaded = true
        name = doctor.name
        specialty = doctor.specialty
        practice = doctor.practice
        phone = doctor.phone
        email = doctor.email
        address = doctor.address
        notes = doctor.notes
        photo = doctor.photo
    }

    private func save() {
        let target = doctor ?? {
            let new = Doctor(name: "")
            context.insert(new)
            return new
        }()
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        target.name = clean(name)
        target.specialty = clean(specialty)
        target.practice = clean(practice)
        target.phone = clean(phone)
        target.email = clean(email)
        target.address = clean(address)
        target.notes = clean(notes)
        target.photo = photo
        try? context.save()
        onSave?(target)
        dismiss()
    }
}

/// "Prescribed by" / "With": choose a doctor, or add a new one without leaving.
struct DoctorPicker: View {
    let title: String
    @Binding var selection: Doctor?
    @Query(sort: \Doctor.name) private var doctors: [Doctor]
    @State private var isAdding = false

    var body: some View {
        Picker(title, selection: $selection) {
            Text("None").tag(Doctor?.none)
            ForEach(doctors) { Text($0.name).tag(Doctor?.some($0)) }
        }
        Button("Add a New Doctor", systemImage: "person.badge.plus") { isAdding = true }
            .sheet(isPresented: $isAdding) {
                DoctorEditor { selection = $0 }
            }
    }
}

#Preview {
    DoctorsView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

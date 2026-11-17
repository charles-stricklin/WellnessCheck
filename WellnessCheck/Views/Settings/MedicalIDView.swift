import SwiftUI
import SwiftData

/// One person's Medical ID: who they are, blood type, allergies and who to call.
/// Edits save as they're made; there's nothing here worth a Cancel.
struct MedicalIDView: View {
    @Bindable var person: Person
    @AppStorage(Units.kilogramsKey) private var metric = false
    @State private var newAllergy = ""
    @State private var isImportingAllergies = false
    @FocusState private var allergyFocused: Bool

    static let bloodTypes = ["O Positive (O+)", "O Negative (O−)", "A Positive (A+)", "A Negative (A−)",
                             "B Positive (B+)", "B Negative (B−)", "AB Positive (AB+)", "AB Negative (AB−)"]

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $person.name)
                    .textContentType(.name)
                if !person.isSelf {
                    TextField("Relationship, like Spouse", text: $person.relationship)
                }
            }

            Section {
                if let birthDate = person.birthDate {
                    DatePicker("Date of birth",
                               selection: Binding { birthDate } set: { person.birthDate = $0 },
                               in: ...Date.now, displayedComponents: .date)
                    LabeledContent("Age", value: age(from: birthDate))
                } else {
                    LabeledContent("Date of birth") {
                        Button("Add") {
                            person.birthDate = Calendar.current.date(from: DateComponents(year: 1955, month: 1, day: 1))
                        }
                    }
                }
                Picker("Sex", selection: $person.sexRaw) {
                    Text("Not set").tag(String?.none)
                    ForEach(Sex.allCases) { Text($0.label).tag(String?.some($0.rawValue)) }
                }
                Picker("Height", selection: heightBinding) {
                    Text("Not set").tag(Int?.none)
                    ForEach(heightRange, id: \.self) { Text(heightLabel($0)).tag(Int?.some($0)) }
                }
                Picker("Blood type", selection: $person.bloodType) {
                    Text("Not sure").tag("")
                    ForEach(Self.bloodTypes, id: \.self) { Text($0).tag($0) }
                }
            }

            Section {
                ForEach(person.allergies, id: \.self) { Text($0) }
                    .onDelete { person.allergies.remove(atOffsets: $0) }
                HStack {
                    TextField("Add an allergy, like Penicillin", text: $newAllergy)
                        .focused($allergyFocused)
                        .submitLabel(.done)
                        .onSubmit(addAllergy)
                    if !newAllergy.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Add", action: addAllergy)
                    }
                }
                if person.isSelf && HealthRecords.isAvailable {
                    Button("Add from Health Records", systemImage: "heart.text.clipboard") { isImportingAllergies = true }
                }
            } header: {
                Text("Allergies")
            } footer: {
                if !person.allergies.isEmpty { Text("Swipe left on an allergy to remove it.") }
            }

            Section {
                TextField("Name", text: $person.emergencyName)
                    .textContentType(.name)
                TextField("Relationship, like Daughter", text: $person.emergencyRelationship)
                TextField("Phone", text: $person.emergencyPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                if let url = Contact.phoneURL(person.emergencyPhone) {
                    Link(destination: url) {
                        Label("Call \(person.emergencyName.isEmpty ? "Emergency Contact" : person.emergencyName)", systemImage: "phone.fill")
                    }
                }
            } header: {
                Text("Emergency Contact")
            }
        }
        .sheet(isPresented: $isImportingAllergies) { ImportAllergiesView(person: person) }
        .navigationTitle("Medical ID")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addAllergy() {
        let allergy = newAllergy.trimmingCharacters(in: .whitespaces)
        guard !allergy.isEmpty, !person.allergies.contains(allergy) else { return }
        person.allergies.append(allergy)
        newAllergy = ""
        allergyFocused = true
    }

    private func age(from birthDate: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
        return "\(years) years"
    }

    // Height is stored in centimeters and shown in the units chosen in Settings,
    // matching the picker in setup.
    private static let cmPerInch = 2.54
    private var heightRange: ClosedRange<Int> { metric ? 100...230 : 39...90 }

    private func heightLabel(_ value: Int) -> String {
        metric ? "\(value) cm" : "\(value / 12)′ \(value % 12)″"
    }

    private var heightBinding: Binding<Int?> {
        Binding {
            person.heightCm.map { Int((metric ? $0 : $0 / Self.cmPerInch).rounded()) }
        } set: { value in
            person.heightCm = value.map { metric ? Double($0) : Double($0) * Self.cmPerInch }
        }
    }
}

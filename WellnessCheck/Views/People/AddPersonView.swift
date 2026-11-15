import SwiftUI
import SwiftData

/// Sheet for adding a family member whose readings will be kept in the app.
struct AddPersonView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Called with the new person so the caller can switch to them.
    var onAdd: (Person) -> Void = { _ in }

    @State private var name = ""
    @State private var relationship = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Relationship (e.g., Spouse, Son)", text: $relationship)
                } footer: {
                    Text("Their readings stay in WellnessCheck and aren't added to your Apple Health.")
                }
            }
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add).disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func add() {
        let person = Person(name: trimmedName, relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(person)
        onAdd(person)
        dismiss()
    }
}

#Preview {
    AddPersonView()
        .modelContainer(for: [Person.self, Reading.self], inMemory: true)
}

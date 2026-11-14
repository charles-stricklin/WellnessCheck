import SwiftUI
import SwiftData

/// Sheet for entering one reading by hand.
struct LogReadingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: VitalKind = .bloodPressure
    @State private var first = ""
    @State private var second = ""
    @State private var date = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Vital", selection: $kind) {
                    ForEach(VitalKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }

                Section {
                    if kind == .bloodPressure {
                        numberField("Systolic (top number)", text: $first)
                        numberField("Diastolic (bottom number)", text: $second)
                    } else {
                        numberField(kind.title, text: $first)
                    }
                } footer: {
                    Text("In \(Units.unitLabel(for: kind)).")
                }

                Section {
                    DatePicker("Taken", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("Log Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!isValid)
                }
            }
            // A value typed for one vital means nothing for another.
            .onChange(of: kind) {
                first = ""
                second = ""
            }
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }

    /// Accepts "98.6" and, for locales that use it, "98,6".
    private func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool {
        guard parse(first) != nil else { return false }
        return kind != .bloodPressure || parse(second) != nil
    }

    private func save() {
        guard let firstValue = parse(first) else { return }
        let reading = Reading(
            kind: kind,
            date: date,
            value: Units.toStored(firstValue, kind: kind),
            secondValue: kind == .bloodPressure ? parse(second) : nil,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(reading)
        dismiss()
    }
}

#Preview {
    LogReadingView()
        .modelContainer(for: Reading.self, inMemory: true)
}

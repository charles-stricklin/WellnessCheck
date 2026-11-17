import SwiftUI

enum Preferences {
    /// Most people open the app to record a reading (the morning blood pressure),
    /// not to review history, so by default each launch starts on the Log Reading form.
    static let openToLogReadingKey = "prefs.openToLogReading"

    /// The vitals that get a box on the reading form, as comma-separated raw values.
    /// A string so it fits in @AppStorage.
    static let formVitalsKey = "prefs.formVitals"
    /// What most people check daily; temperature and oxygen are occasional.
    static let defaultFormVitals = [VitalKind.bloodPressure, .heartRate, .glucose, .weight]
        .map(\.rawValue).joined(separator: ",")

    /// In the app's usual order, whatever order they were checked in.
    static func formVitals(from stored: String) -> [VitalKind] {
        let chosen = Set(stored.split(separator: ",").map(String.init))
        return VitalKind.allCases.filter { chosen.contains($0.rawValue) }
    }
}

/// The Settings tab. Holds the choices made during setup so they can be changed later.
struct SettingsView: View {
    @AppStorage(Units.glucoseMmolKey) private var glucoseMmol = false
    @AppStorage(Units.celsiusKey) private var celsius = false
    @AppStorage(Units.kilogramsKey) private var kilograms = false
    @AppStorage(Preferences.openToLogReadingKey) private var openToLogReading = true
    @AppStorage(Preferences.formVitalsKey) private var formVitals = Preferences.defaultFormVitals

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    OpenToLogReadingToggle(isOn: $openToLogReading)
                } header: {
                    Text("When the App Opens")
                }
                Section {
                    FormVitalsChecklist(stored: $formVitals)
                } header: {
                    Text("On the Reading Form")
                } footer: {
                    Text("These get a box on the form each time. Others can still be added from the form when you need them.")
                }
                Section("Units") {
                    UnitPicker(label: "Blood sugar", isOn: $glucoseMmol, off: "mg/dL", on: "mmol/L")
                    UnitPicker(label: "Temperature", isOn: $celsius, off: "°F", on: "°C")
                    UnitPicker(label: "Weight and height", isOn: $kilograms, off: "lb", on: "kg")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Shared by setup and Settings so the wording is identical in both places.
struct OpenToLogReadingToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text("Start with a new reading")
            Text("Open straight to the form for recording a reading. Turn off to open to your list of readings instead.")
        }
    }
}

/// One checkable row per vital. Used in setup and Settings.
struct FormVitalsChecklist: View {
    @Binding var stored: String

    var body: some View {
        let chosen = Set(Preferences.formVitals(from: stored))
        ForEach(VitalKind.allCases) { kind in
            Button {
                var next = chosen
                if next.contains(kind) { next.remove(kind) } else { next.insert(kind) }
                stored = VitalKind.allCases.filter(next.contains).map(\.rawValue).joined(separator: ",")
            } label: {
                HStack {
                    Label(kind.title, systemImage: kind.symbol)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: chosen.contains(kind) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(chosen.contains(kind) ? Color.accentColor : .secondary)
                        .font(.title3)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            .accessibilityAddTraits(chosen.contains(kind) ? .isSelected : [])
        }
    }
}

/// A labeled two-choice segmented control, used for each unit choice.
struct UnitPicker: View {
    let label: String
    @Binding var isOn: Bool
    let off: String
    let on: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Picker(label, selection: $isOn) {
                Text(off).tag(false)
                Text(on).tag(true)
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    SettingsView()
}

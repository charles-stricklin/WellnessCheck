import SwiftUI
import SwiftData
import UserNotifications

enum Preferences {
    /// Most people open the app to record a reading (the morning blood pressure),
    /// not to review history, so by default each launch starts on the Log Reading form.
    static let openToLogReadingKey = "prefs.openToLogReading"

    /// The vitals that get a box on the reading form, as comma-separated raw values.
    /// A string so it fits in @AppStorage.
    static let formVitalsKey = "prefs.formVitals"
    static let appearanceKey = "prefs.appearance"
    static let faceIDLockKey = "prefs.faceIDLock"
    /// What most people check daily; temperature and oxygen are occasional.
    static let defaultFormVitals = [VitalKind.bloodPressure, .heartRate, .glucose, .weight]
        .map(\.rawValue).joined(separator: ",")

    /// In the app's usual order, whatever order they were checked in.
    static func formVitals(from stored: String) -> [VitalKind] {
        let chosen = Set(stored.split(separator: ",").map(String.init))
        return VitalKind.allCases.filter { chosen.contains($0.rawValue) }
    }
}

/// The Settings tab. Holds the choices made during setup so they can be changed later,
/// plus Medical ID, reminders, privacy and appearance.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \Person.createdAt) private var people: [Person]
    @AppStorage("activePersonID") private var activePersonID = ""
    @AppStorage(Units.glucoseMmolKey) private var glucoseMmol = false
    @AppStorage(Units.celsiusKey) private var celsius = false
    @AppStorage(Units.kilogramsKey) private var kilograms = false
    @AppStorage(Preferences.openToLogReadingKey) private var openToLogReading = true
    @AppStorage(Preferences.formVitalsKey) private var formVitals = Preferences.defaultFormVitals
    @AppStorage(Preferences.appearanceKey) private var appearance = Appearance.auto.rawValue
    @AppStorage(Preferences.faceIDLockKey) private var faceIDLock = false
    @AppStorage(Reminders.medicinesKey) private var medicineReminders = true
    @AppStorage(Reminders.appointmentsKey) private var appointmentReminders = true
    @AppStorage(Reminders.readingTimesKey) private var readingTimes = ""
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                if let person = activePerson {
                    Section {
                        NavigationLink {
                            MedicalIDView(person: person)
                        } label: {
                            Label(person.isSelf ? "Medical ID" : "Medical ID for \(person.name)", systemImage: "staroflife.fill")
                        }
                    } footer: {
                        Text("Blood type, allergies, emergency contact, and the details on your reports.")
                    }
                }

                Section {
                    Toggle("Medicine reminders", isOn: $medicineReminders)
                    Toggle("Appointment reminders", isOn: $appointmentReminders)
                    ReadingTimesEditor(stored: $readingTimes)
                } header: {
                    Text("Reminders")
                } footer: {
                    if notificationsDenied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are turned off for WellnessCheck, so reminders can't appear.")
                            Button("Turn On in the Settings App") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                            }
                        }
                    } else {
                        Text("Medicine reminders follow each medicine's times. Appointment reminders come the evening before and 2 hours ahead.")
                    }
                }

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

                Section {
                    Toggle("Lock with Face ID", isOn: $faceIDLock)
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                } header: {
                    Text("Privacy and Appearance")
                } footer: {
                    Text("When locked, WellnessCheck asks for Face ID, or your passcode, each time it opens.")
                }
            }
            .navigationTitle("Settings")
            .task { await checkNotifications() }
            .onChange(of: medicineReminders) { Task { await checkNotifications() } }
            .onChange(of: appointmentReminders) { Task { await checkNotifications() } }
            .onChange(of: readingTimes) { Task { await checkNotifications() } }
        }
    }

    private var activePerson: Person? {
        people.first { $0.id.uuidString == activePersonID } ?? people.first { $0.isSelf }
    }

    @Environment(\.modelContext) private var context

    /// Reschedules for the new choices, which also asks permission the first time.
    private func checkNotifications() async {
        await Reminders.reschedule(in: context, askPermission: true)
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsDenied = status == .denied
    }
}

/// Times of day to be reminded to take readings, like 7:30 AM and 9:00 PM.
private struct ReadingTimesEditor: View {
    @Binding var stored: String

    var body: some View {
        let times = Reminders.readingTimes(from: stored)
        ForEach(times.indices, id: \.self) { index in
            HStack {
                DatePicker("Reading reminder", selection: binding(times, index), displayedComponents: .hourAndMinute)
                Button("Remove", systemImage: "minus.circle.fill") {
                    var next = times
                    next.remove(at: index)
                    stored = Reminders.store(next)
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
            }
        }
        Button("Add a Reading Reminder", systemImage: "plus.circle") {
            // Mornings are when most people check blood pressure and fasting sugar.
            stored = Reminders.store(times + [DateComponents(hour: times.isEmpty ? 7 : 21, minute: 0)])
        }
    }

    private func binding(_ times: [DateComponents], _ index: Int) -> Binding<Date> {
        Binding {
            Calendar.current.date(from: times[index]) ?? .now
        } set: { date in
            var next = times
            next[index] = Calendar.current.dateComponents([.hour, .minute], from: date)
            stored = Reminders.store(next)
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

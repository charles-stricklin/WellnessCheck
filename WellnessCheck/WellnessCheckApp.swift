import SwiftUI
import SwiftData
import UserNotifications

@main
struct WellnessCheckApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    #if DEBUG
                    SampleData.seedIfRequested(into: container)
                    #endif
                    // Runs after seeding so sample readings without a person go to the owner.
                    People.ensureSelf(in: container.mainContext)
                }
        }
        .modelContainer(container)
    }

    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Person.self, Reading.self, Medication.self, DoseTime.self, DoseChange.self, DoseRecord.self, Doctor.self, Appointment.self)
        } catch {
            fatalError("Could not open the WellnessCheck data store: \(error)")
        }
    }()
}

/// Receives taps on reminders. It has to be set as the delegate before launch
/// finishes, or a tap that launched the app would be missed.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let opensForm = response.notification.request.content.userInfo[Reminders.openFormKey] as? Bool ?? false
        guard opensForm else { return }
        await MainActor.run {
            AppRouter.shared.selectedTab = .vitals
            AppRouter.shared.openLogForm = true
        }
    }

    /// Show reminders even while the app is open, since that's often when the time arrives.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

#if DEBUG
/// Launch with `-seedSampleData` (in the scheme or `simctl launch`) to fill an empty
/// store with a few days of made-up readings, so screens can be checked without typing.
@MainActor
enum SampleData {
    static func seedIfRequested(into container: ModelContainer) {
        guard CommandLine.arguments.contains("-seedSampleData") else { return }
        let context = container.mainContext
        guard (try? context.fetchCount(FetchDescriptor<Reading>())) == 0 else { return }

        let now = Date.now
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        [
            Reading(kind: .bloodPressure, date: ago(1), value: 118, secondValue: 76, note: "Morning, resting"),
            Reading(kind: .heartRate, date: ago(1), value: 68),
            Reading(kind: .glucose, date: ago(2), value: 94, note: "Fasting"),
            Reading(kind: .weight, date: ago(2), value: 86.2),
            Reading(kind: .bloodPressure, date: ago(26), value: 124, secondValue: 82, note: "After dinner"),
            Reading(kind: .oxygen, date: ago(27), value: 98),
            Reading(kind: .temperature, date: ago(28), value: 36.8),
        ].forEach(context.insert)
        let spouse = Person(name: "Pat", relationship: "Spouse")
        context.insert(spouse)
        let spouseReading = Reading(kind: .bloodPressure, date: ago(3), value: 131, secondValue: 85)
        context.insert(spouseReading)
        spouseReading.person = spouse

        // Made-up medicines so the Meds tab and the form's checklist have something to show.
        let me = People.ensureSelf(in: context)
        // A blood pressure target so the In Range / Out of Range flags show.
        me.targets = [VitalTarget(kindRaw: VitalKind.bloodPressure.rawValue, high: 120, secondHigh: 80)]
        let samples: [(String, String, String, [(Int, Double)], Double)] = [
            ("Lisinopril", "10 mg", "Blood pressure", [(8, 1)], 30),
            ("Metoprolol", "50 mg", "Blood pressure", [(8, 0.5), (20, 0.5)], 6),
            ("Vitamin B12", "1000 mcg", "Supplement", [(8, 1)], 90),
        ]
        for (name, strength, purpose, times, onHand) in samples {
            let med = Medication(name: name)
            med.strength = strength
            med.purpose = purpose
            med.onHand = onHand
            med.startDate = ago(24 * 60)
            context.insert(med)
            med.person = me
            for (hour, amount) in times {
                let time = DoseTime(hour: hour, minute: 0, amount: amount)
                context.insert(time)
                time.medication = med
            }
        }
        try? context.save()
    }
}
#endif

import SwiftUI
import SwiftData

@main
struct WellnessCheckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if DEBUG
                .task { SampleData.seedIfRequested(into: container) }
            #endif
        }
        .modelContainer(container)
    }

    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Reading.self)
        } catch {
            fatalError("Could not open the WellnessCheck data store: \(error)")
        }
    }()
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
        try? context.save()
    }
}
#endif

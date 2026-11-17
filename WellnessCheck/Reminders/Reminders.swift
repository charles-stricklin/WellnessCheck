import Foundation
import SwiftData
import UserNotifications
import Observation

/// Lets a tapped reminder reach the screen it's about, wherever the app happens to be.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    /// Set when a medicine or reading reminder is tapped; the Vitals tab opens the form and clears it.
    var openLogForm = false
    var selectedTab: AppTab = .vitals
}

enum AppTab: Hashable { case vitals, appointments, meds, doctors, settings }

/// Schedules the phone's reminders from what's in the app.
///
/// Rather than one repeating reminder per medicine, each upcoming time slot gets one
/// reminder naming everything due then, for the next several days. That stays well
/// under iOS's limit of 64 scheduled reminders, handles every-other-day and
/// certain-days medicines exactly, and leaves out doses already checked off.
/// The catch: it's refreshed whenever the app opens or something changes, so
/// reminders run out if the app goes unopened for longer than `daysAhead`.
@MainActor
enum Reminders {
    static let medicinesKey = "reminders.medicines"
    static let appointmentsKey = "reminders.appointments"
    /// Times of day for reading reminders, as "HH:mm" separated by commas.
    static let readingTimesKey = "reminders.readingTimes"
    static let afterMealsKey = "reminders.afterMeals"
    /// Breakfast, lunch and dinner, as "HH:mm" separated by commas.
    static let mealTimesKey = "reminders.mealTimes"
    static let defaultMealTimes = "08:00,12:00,18:00"
    /// Two hours after eating is the usual time for an after-meal blood sugar check.
    static let afterMealDelay: TimeInterval = 2 * 3600
    static let mealNames = [String(localized: "breakfast"), String(localized: "lunch"), String(localized: "dinner")]

    static let daysAhead = 10
    private static let maxScheduled = 60
    private static let idPrefix = "wc."
    nonisolated static let openFormKey = "openForm"

    private static var defaults: UserDefaults { .standard }
    private static var medicinesOn: Bool { defaults.object(forKey: medicinesKey) as? Bool ?? true }
    private static var appointmentsOn: Bool { defaults.object(forKey: appointmentsKey) as? Bool ?? true }

    static func readingTimes(from stored: String) -> [DateComponents] {
        stored.split(separator: ",").compactMap { part in
            let bits = part.split(separator: ":").compactMap { Int($0) }
            guard bits.count == 2 else { return nil }
            return DateComponents(hour: bits[0], minute: bits[1])
        }
        .sorted { ($0.hour ?? 0, $0.minute ?? 0) < ($1.hour ?? 0, $1.minute ?? 0) }
    }

    /// Meal times keep their order (breakfast, lunch, dinner) rather than being sorted.
    static func mealTimes(from stored: String) -> [DateComponents] {
        stored.split(separator: ",").compactMap { part in
            let bits = part.split(separator: ":").compactMap { Int($0) }
            return bits.count == 2 ? DateComponents(hour: bits[0], minute: bits[1]) : nil
        }
    }

    static func store(_ times: [DateComponents]) -> String {
        times.map { String(format: "%02d:%02d", $0.hour ?? 0, $0.minute ?? 0) }.joined(separator: ",")
    }

    /// `askPermission` is only for moments the person chose reminders (setup, Settings),
    /// so iOS's question never pops up out of nowhere.
    static func reschedule(in context: ModelContext, askPermission: Bool = false) async {
        let requests = buildRequests(in: context)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard !requests.isEmpty else { return }

        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined && askPermission {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else { return }
        for request in requests {
            try? await center.add(request)
        }
    }

    private struct Slot {
        var medicines: [String] = []
        var readings = false
        /// "breakfast" when this is the after-meal blood sugar check.
        var afterMeal: String?
    }

    private static func buildRequests(in context: ModelContext) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let days = (0..<daysAhead).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        var slots: [Date: Slot] = [:]

        if medicinesOn {
            let meds = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
            for med in meds {
                let answered = Set((med.records ?? []).map(\.scheduledFor))
                for day in days where med.isScheduled(on: day) {
                    for time in med.sortedTimes {
                        let at = time.date(on: day)
                        guard at > now, !answered.contains(at) else { continue }
                        // Family members' medicines are named, since a caregiver gets these too.
                        let name = med.person.map { $0.isSelf ? med.name : "\(med.name) (\($0.name))" } ?? med.name
                        slots[at, default: Slot()].medicines.append(name)
                    }
                }
            }
        }

        for time in readingTimes(from: defaults.string(forKey: readingTimesKey) ?? "") {
            for day in days {
                guard let at = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day),
                      at > now else { continue }
                slots[at, default: Slot()].readings = true
            }
        }

        if defaults.bool(forKey: afterMealsKey) {
            let meals = mealTimes(from: defaults.string(forKey: mealTimesKey) ?? defaultMealTimes)
            for (index, meal) in meals.enumerated() {
                for day in days {
                    guard let ate = calendar.date(bySettingHour: meal.hour ?? 0, minute: meal.minute ?? 0, second: 0, of: day) else { continue }
                    let at = ate.addingTimeInterval(afterMealDelay)
                    guard at > now else { continue }
                    slots[at, default: Slot()].afterMeal = mealNames[min(index, mealNames.count - 1)]
                }
            }
        }

        var requests: [(Date, UNNotificationRequest)] = slots.map { at, slot in
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.userInfo = [openFormKey: true]
            let meds = slot.medicines.sorted()
            switch (meds.isEmpty, slot.readings) {
            case (false, true): content.title = String(localized: "Time for your medicines and readings")
            case (false, false): content.title = String(localized: "Time for your medicines")
            default: content.title = String(localized: "Time to take your readings")
            }
            if !meds.isEmpty { content.body = list(meds) }
            if let meal = slot.afterMeal {
                let check = String(localized: "Check your blood sugar: 2 hours after \(meal).")
                if meds.isEmpty && !slot.readings { content.title = String(localized: "Time to check your blood sugar") }
                content.body = content.body.isEmpty ? check : "\(content.body)\n\(check)"
            }
            return (at, request(id: "slot.\(Int(at.timeIntervalSince1970))", at: at, content: content))
        }

        if appointmentsOn {
            let visits = (try? context.fetch(FetchDescriptor<Appointment>())) ?? []
            for visit in visits where !visit.isCanceled && visit.date > now {
                let who = visit.doctor?.name ?? (visit.reason.isEmpty ? String(localized: "your appointment") : visit.reason)
                let time = visit.date.formatted(date: .omitted, time: .shortened)
                let forWhom = visit.person.map { $0.isSelf ? "" : " (\($0.name))" } ?? ""
                // The evening before, so there's time to prepare (fasting, paperwork)…
                if let dayBefore = calendar.date(byAdding: .day, value: -1, to: visit.date),
                   let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore), evening > now {
                    let content = UNMutableNotificationContent()
                    content.title = String(localized: "Tomorrow: \(who) at \(time)\(forWhom)")
                    content.body = visit.prepNotes
                    content.sound = .default
                    requests.append((evening, request(id: "visit.eve.\(visit.id)", at: evening, content: content)))
                }
                // …and two hours ahead, enough to get there.
                let soon = visit.date.addingTimeInterval(-2 * 3600)
                if soon > now {
                    let content = UNMutableNotificationContent()
                    content.title = String(localized: "In 2 hours: \(who) at \(time)\(forWhom)")
                    content.body = visit.place
                    content.sound = .default
                    requests.append((soon, request(id: "visit.soon.\(visit.id)", at: soon, content: content)))
                }
            }
        }

        return requests.sorted { $0.0 < $1.0 }.prefix(maxScheduled).map(\.1)
    }

    /// "Carvedilol, Metformin and 10 more" — enough to recognize, short enough to read.
    private static func list(_ names: [String]) -> String {
        let shown = 3
        guard names.count > shown else { return names.formatted(.list(type: .and)) }
        return String(localized: "\(names.prefix(shown).joined(separator: ", ")) and \(names.count - shown) more")
    }

    private static func request(id: String, at date: Date, content: UNNotificationContent) -> UNNotificationRequest {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: idPrefix + id, content: content, trigger: trigger)
    }
}

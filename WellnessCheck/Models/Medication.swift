import Foundation
import SwiftData

/// A medicine someone takes. Belongs to one person, like readings do.
///
/// Every property has a default and every relationship is optional because CloudKit
/// sync requires it. Enums are stored as raw strings so a future case can't break saved data.
@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// Free text as printed on the label, such as "25 mg" or "100 units/mL".
    var strength: String = ""
    var purpose: String = ""
    /// Superseded by `doctor`; kept so data saved before doctors existed still opens.
    var prescriber: String = ""
    var doctor: Doctor?
    var unitRaw: String = DoseUnit.tablet.rawValue
    var frequencyRaw: String = MedFrequency.daily.rawValue
    /// Calendar weekday numbers (1 = Sunday) when the frequency is `.someDays`.
    var weekdays: [Int] = []
    /// When they began taking it; also anchors "every other day".
    var startDate: Date = Date.now
    var statusRaw: String = MedStatus.taking.rawValue
    /// Why it's paused or stopped, in their words.
    var statusNote: String = ""
    /// How many they have; nil when they'd rather not count.
    var onHand: Double?
    var createdAt: Date = Date.now
    var person: Person?

    @Relationship(deleteRule: .cascade, inverse: \DoseTime.medication)
    var times: [DoseTime]? = []
    @Relationship(deleteRule: .cascade, inverse: \DoseChange.medication)
    var changes: [DoseChange]? = []
    @Relationship(deleteRule: .cascade, inverse: \DoseRecord.medication)
    var records: [DoseRecord]? = []

    init(name: String) {
        self.name = name
    }

    var unit: DoseUnit {
        get { DoseUnit(rawValue: unitRaw) ?? .tablet }
        set { unitRaw = newValue.rawValue }
    }

    var frequency: MedFrequency {
        get { MedFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var status: MedStatus {
        get { MedStatus(rawValue: statusRaw) ?? .taking }
        set { statusRaw = newValue.rawValue }
    }

    /// "Carvedilol 25 mg"
    var title: String { strength.isEmpty ? name : "\(name) \(strength)" }

    var sortedTimes: [DoseTime] {
        (times ?? []).sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }
}

/// One scheduled time of day and how much to take then.
@Model
final class DoseTime {
    var hour: Int = 8
    var minute: Int = 0
    var amount: Double = 1
    var medication: Medication?

    init(hour: Int, minute: Int, amount: Double) {
        self.hour = hour
        self.minute = minute
        self.amount = amount
    }
}

/// A dated note of a change to how a medicine is taken, so "when did that dose
/// change?" has an answer.
@Model
final class DoseChange {
    var date: Date = Date.now
    var summary: String = ""
    var medication: Medication?

    init(date: Date = .now, summary: String) {
        self.date = date
        self.summary = summary
    }
}

/// A dose checked off as taken. A dose with no record simply wasn't taken.
@Model
final class DoseRecord {
    /// When it was taken.
    var date: Date = Date.now
    /// The scheduled time it answers, so the same dose isn't asked about twice.
    var scheduledFor: Date = Date.now
    var amount: Double = 1
    var medication: Medication?

    init(date: Date, scheduledFor: Date, amount: Double) {
        self.date = date
        self.scheduledFor = scheduledFor
        self.amount = amount
    }
}

enum MedStatus: String, CaseIterable, Identifiable {
    case taking, paused, stopped
    var id: String { rawValue }
    var label: String {
        switch self {
        case .taking: "Taking"
        case .paused: "Paused"
        case .stopped: "Stopped"
        }
    }
}

enum MedFrequency: String, CaseIterable, Identifiable {
    case daily, everyOtherDay, someDays, asNeeded
    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: "Every day"
        case .everyOtherDay: "Every other day"
        case .someDays: "Certain days"
        case .asNeeded: "As needed"
        }
    }
}

enum DoseUnit: String, CaseIterable, Identifiable {
    case tablet, capsule, unit, mL, puff, drop, patch, injection
    var id: String { rawValue }

    /// Pill-like units come in halves; insulin units and mL are typed as numbers.
    var isCountable: Bool { ![.unit, .mL].contains(self) }

    func label(for amount: Double) -> String {
        let plural = amount > 1
        return switch self {
        case .tablet: plural ? "tablets" : "tablet"
        case .capsule: plural ? "capsules" : "capsule"
        case .unit: plural ? "units" : "unit"
        case .mL: "mL"
        case .puff: plural ? "puffs" : "puff"
        case .drop: plural ? "drops" : "drop"
        case .patch: plural ? "patches" : "patch"
        case .injection: plural ? "injections" : "injection"
        }
    }

    var pickerLabel: String { label(for: 2).capitalized }
}

enum Dose {
    /// "½ tablet", "1½ tablets", "22 units": halves as fractions, the way labels say them.
    static func describe(_ amount: Double, _ unit: DoseUnit) -> String {
        "\(number(amount)) \(unit.label(for: amount))"
    }

    static func number(_ amount: Double) -> String {
        let whole = Int(amount)
        let rest = amount - Double(whole)
        if abs(rest - 0.5) < 0.001 { return whole == 0 ? "½" : "\(whole)½" }
        if rest == 0 { return "\(whole)" }
        return amount.formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// Scheduling arithmetic, kept off the views so the reading form and the Meds
/// tab agree on what's due and what's running low.
extension Medication {
    func isScheduled(on day: Date, calendar: Calendar = .current) -> Bool {
        guard status == .taking, calendar.startOfDay(for: day) >= calendar.startOfDay(for: startDate) else { return false }
        switch frequency {
        case .daily: return true
        case .asNeeded: return false
        case .someDays: return weekdays.contains(calendar.component(.weekday, from: day))
        case .everyOtherDay:
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate),
                                               to: calendar.startOfDay(for: day)).day ?? 0
            return days % 2 == 0
        }
    }

    /// Average amount per day, for estimating how long the supply lasts.
    var dailyAmount: Double {
        let perDay = (times ?? []).reduce(0) { $0 + $1.amount }
        return switch frequency {
        case .daily: perDay
        case .everyOtherDay: perDay / 2
        case .someDays: perDay * Double(weekdays.count) / 7
        case .asNeeded: 0
        }
    }

    var daysLeft: Int? {
        guard let onHand, dailyAmount > 0 else { return nil }
        return Int(onHand / dailyAmount)
    }

    /// About a week left is enough time to get a refill through most pharmacies.
    static let lowSupplyDays = 7
    var isRunningLow: Bool { status == .taking && (daysLeft ?? .max) <= Self.lowSupplyDays }

    /// A dose change in the last two weeks, worth pointing out at the checklist
    /// until it's become habit.
    var recentChange: DoseChange? {
        let cutoff = Date.now.addingTimeInterval(-14 * 86_400)
        return (changes ?? []).filter { $0.date >= cutoff }.max { $0.date < $1.date }
    }

    /// "½ tablet at 8:00 AM, 1 tablet at 8:00 PM · Every day"
    var scheduleSummary: String {
        if frequency == .asNeeded { return MedFrequency.asNeeded.label }
        let times = sortedTimes.map { "\(Dose.describe($0.amount, unit)) at \($0.timeLabel)" }
        var days = frequency.label
        if frequency == .someDays {
            let symbols = Calendar.current.shortWeekdaySymbols
            days = weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
        }
        return times.isEmpty ? days : "\(times.joined(separator: ", ")) · \(days)"
    }
}

extension DoseTime {
    func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    var timeLabel: String { date(on: .now).formatted(date: .omitted, time: .shortened) }
}

/// One dose waiting to be checked off.
struct DueDose: Identifiable {
    let medication: Medication
    let time: DoseTime
    let scheduledFor: Date

    var id: String { "\(medication.id.uuidString)-\(scheduledFor.timeIntervalSince1970)" }
}

enum MedSchedule {
    /// Doses from a few hours ago through a few hours ahead count as "now", so
    /// morning medicines show whether the form is opened at 6:30 or 10:00.
    static let lookBack: TimeInterval = 4 * 3600
    static let lookAhead: TimeInterval = 3 * 3600

    static func due(for medications: [Medication], at now: Date = .now) -> [DueDose] {
        let calendar = Calendar.current
        let window = now.addingTimeInterval(-lookBack)...now.addingTimeInterval(lookAhead)
        // Yesterday too, so a 10 PM dose is still due shortly after midnight.
        let days = [calendar.date(byAdding: .day, value: -1, to: now) ?? now, now]
        var due: [DueDose] = []
        for med in medications {
            let answered = Set((med.records ?? []).map(\.scheduledFor))
            for day in days where med.isScheduled(on: day) {
                for time in med.sortedTimes {
                    let at = time.date(on: day)
                    if window.contains(at), !answered.contains(at) {
                        due.append(DueDose(medication: med, time: time, scheduledFor: at))
                    }
                }
            }
        }
        return due.sorted { ($0.scheduledFor, $0.medication.name) < ($1.scheduledFor, $1.medication.name) }
    }
}

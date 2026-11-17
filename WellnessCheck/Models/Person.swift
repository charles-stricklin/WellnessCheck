import Foundation
import SwiftData

/// Someone whose readings are kept in the app: the phone's owner, or a family member.
///
/// Only the owner (`isSelf`) is connected to Apple Health. Health belongs to the
/// person who owns the phone, so a family member's readings must never be written
/// into it, and Health's readings are always the owner's.
@Model
final class Person {
    var id: UUID = UUID()
    var name: String = ""
    /// Free text such as "Spouse" or "Son"; empty for the owner.
    var relationship: String = ""
    var isSelf: Bool = false
    var createdAt: Date = Date.now
    /// Owner's details, asked for during setup. Optional because family members
    /// don't have them yet, and owners from before setup asked for them don't either.
    var birthDate: Date?
    /// Stored as `Sex.rawValue` so a future case can't break saved data.
    var sexRaw: String?
    var heightCm: Double?

    // Medical ID, for whoever needs it in a hurry. Free text: people copy it from a card.
    /// Such as "O Positive (O+)".
    var bloodType: String = ""
    var allergies: [String] = []
    var emergencyName: String = ""
    var emergencyRelationship: String = ""
    var emergencyPhone: String = ""

    /// Target ranges set by the person or their doctor; readings outside them are flagged.
    var targets: [VitalTarget] = []

    var sex: Sex? {
        get { sexRaw.flatMap(Sex.init(rawValue:)) }
        set { sexRaw = newValue?.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Reading.person)
    var readings: [Reading]? = []

    @Relationship(deleteRule: .cascade, inverse: \Medication.person)
    var medications: [Medication]? = []

    @Relationship(deleteRule: .cascade, inverse: \Appointment.person)
    var appointments: [Appointment]? = []

    init(name: String, relationship: String = "", isSelf: Bool = false) {
        self.name = name
        self.relationship = relationship
        self.isSelf = isSelf
    }
}

/// Apple Health's sex options, plus a way to decline.
enum Sex: String, CaseIterable, Identifiable {
    case female, male, other, notSaid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .other: "Other"
        case .notSaid: "Prefer not to say"
        }
    }
}

enum People {
    /// Placeholder until the owner types their name during setup.
    static let defaultOwnerName = "Me"

    /// Makes sure the owner's profile exists, and gives it any reading that has no
    /// owner yet (readings logged before profiles existed). Returns the owner.
    @MainActor
    @discardableResult
    static func ensureSelf(in context: ModelContext) -> Person {
        let owners = (try? context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.isSelf }))) ?? []
        let me = mergeOwners(owners) ?? {
            let person = Person(name: defaultOwnerName, isSelf: true)
            context.insert(person)
            return person
        }()
        let orphans = (try? context.fetch(FetchDescriptor<Reading>(predicate: #Predicate { $0.person == nil }))) ?? []
        orphans.forEach { $0.person = me }
        try? context.save()
        return me
    }

    /// With iCloud, a reinstall or a second device makes a fresh owner before the
    /// original arrives from iCloud. Keep the oldest, move everything onto it, fill
    /// in anything it's missing from the newer one, and delete the extras.
    @MainActor
    private static func mergeOwners(_ owners: [Person]) -> Person? {
        let sorted = owners.sorted { $0.createdAt < $1.createdAt }
        guard let keep = sorted.first else { return nil }
        for extra in sorted.dropFirst() {
            extra.readings?.forEach { $0.person = keep }
            extra.medications?.forEach { $0.person = keep }
            extra.appointments?.forEach { $0.person = keep }
            if keep.name == defaultOwnerName { keep.name = extra.name }
            if keep.birthDate == nil { keep.birthDate = extra.birthDate }
            if keep.sexRaw == nil { keep.sexRaw = extra.sexRaw }
            if keep.heightCm == nil { keep.heightCm = extra.heightCm }
            if keep.bloodType.isEmpty { keep.bloodType = extra.bloodType }
            keep.allergies += extra.allergies.filter { !keep.allergies.contains($0) }
            if keep.emergencyName.isEmpty {
                keep.emergencyName = extra.emergencyName
                keep.emergencyRelationship = extra.emergencyRelationship
                keep.emergencyPhone = extra.emergencyPhone
            }
            extra.modelContext?.delete(extra)
        }
        return keep
    }
}

/// A target range for one vital, in the app's stored units (mmHg, bpm, %, mg/dL, °C, kg).
/// Any limit can be left empty. For blood pressure, `low`/`high` are the top number
/// and `secondLow`/`secondHigh` the bottom.
struct VitalTarget: Codable, Hashable {
    var kindRaw: String
    var low: Double?
    var high: Double?
    var secondLow: Double?
    var secondHigh: Double?

    var isEmpty: Bool { low == nil && high == nil && secondLow == nil && secondHigh == nil }

    func contains(_ reading: any VitalValue) -> Bool {
        func within(_ value: Double?, _ low: Double?, _ high: Double?) -> Bool {
            guard let value else { return true }
            return value >= (low ?? -.infinity) && value <= (high ?? .infinity)
        }
        return within(reading.value, low, high) && within(reading.secondValue, secondLow, secondHigh)
    }
}

extension Person {
    func target(for kind: VitalKind) -> VitalTarget? {
        targets.first { $0.kindRaw == kind.rawValue && !$0.isEmpty }
    }

    /// nil when there's no target for that vital, so nothing is shown rather than a guess.
    func isInRange(_ reading: any VitalValue) -> Bool? {
        target(for: reading.kind)?.contains(reading)
    }
}

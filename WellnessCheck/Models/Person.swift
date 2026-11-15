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

    var sex: Sex? {
        get { sexRaw.flatMap(Sex.init(rawValue:)) }
        set { sexRaw = newValue?.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Reading.person)
    var readings: [Reading]? = []

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
        let me = owners.first ?? {
            let person = Person(name: defaultOwnerName, isSelf: true)
            context.insert(person)
            return person
        }()
        let orphans = (try? context.fetch(FetchDescriptor<Reading>(predicate: #Predicate { $0.person == nil }))) ?? []
        orphans.forEach { $0.person = me }
        try? context.save()
        return me
    }
}

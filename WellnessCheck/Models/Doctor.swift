import Foundation
import SwiftData

/// Someone on the care team. Shared by the whole household, since family members
/// often see the same doctor; appointments and medicines point to one.
@Model
final class Doctor {
    var id: UUID = UUID()
    var name: String = ""
    /// Such as "Cardiology" or "Primary care".
    var specialty: String = ""
    /// Practice, clinic or hospital.
    var practice: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var notes: String = ""
    @Attribute(.externalStorage) var photo: Data?
    var createdAt: Date = Date.now

    // Deleting a doctor mustn't delete visits or medicines, only the link to them.
    @Relationship(deleteRule: .nullify, inverse: \Appointment.doctor)
    var appointments: [Appointment]? = []
    @Relationship(deleteRule: .nullify, inverse: \Medication.doctor)
    var medications: [Medication]? = []

    init(name: String) {
        self.name = name
    }

    /// Two letters for the round badge when there's no photo.
    var initials: String {
        let words = name.replacingOccurrences(of: "Dr.", with: "").split(separator: " ")
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// One visit, for one person.
@Model
final class Appointment {
    var id: UUID = UUID()
    var date: Date = Date.now
    var reason: String = ""
    /// Only when it isn't the doctor's usual address.
    var location: String = ""
    /// Fasting instructions, what to bring, questions to ask.
    var prepNotes: String = ""
    /// What the doctor said, written down afterward.
    var afterNotes: String = ""
    var isCanceled: Bool = false
    var doctor: Doctor?
    var person: Person?

    init(date: Date) {
        self.date = date
    }

    /// The visit's own location if one was given, otherwise the doctor's address.
    var place: String {
        location.isEmpty ? (doctor?.address ?? "") : location
    }

    /// An hour's grace so a visit in progress still reads as upcoming.
    var isPast: Bool { date < Date.now.addingTimeInterval(-3600) }
}

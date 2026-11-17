import Foundation
import HealthKit

/// A medicine as listed in someone's health records.
struct RecordMedication: Identifiable, Sendable {
    let id: UUID
    let name: String
    let strength: String
    let instructions: String
    let date: Date
}

/// One lab result, such as an A1c of 6.4 %.
struct LabResult: Identifiable, Sendable {
    let id: UUID
    let name: String
    let value: String
    let unit: String
    let date: Date
    /// "4.0–5.6", when the lab gave one.
    let range: String
    /// "High" or "Low" when the lab flagged it.
    let flag: String?
}

/// Reads the clinical records (from doctors, hospitals, the VA) that people connect
/// in the Health app. Records arrive as FHIR, the standard most U.S. providers share,
/// so nothing here is specific to one provider.
///
/// Records are read only, never written, and only for the phone's owner.
@MainActor
enum HealthRecords {
    private static let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable() && store.supportsHealthRecords()
    }

    /// iOS shows its own sheet listing record types; asked only when the person
    /// taps something that needs records, so the question makes sense.
    static func requestAccess(_ kind: HKClinicalTypeIdentifier) async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: [HKClinicalType(kind)])
    }

    private static func records(_ kind: HKClinicalTypeIdentifier) async -> [HKClinicalRecord] {
        guard isAvailable else { return [] }
        await requestAccess(kind)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.clinicalRecord(type: HKClinicalType(kind))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    static func medications() async -> [RecordMedication] {
        var seen = Set<String>()
        return await records(.medicationRecord).compactMap { record in
            let json = fhir(record)
            // Records keep a history; only show each medicine once, newest first.
            guard seen.insert(record.displayName.lowercased()).inserted else { return nil }
            let status = (json["status"] as? String)?.lowercased() ?? "active"
            guard !["stopped", "completed", "cancelled", "entered-in-error"].contains(status) else { return nil }
            let (name, strength) = splitStrength(tidy(record.displayName))
            let dosage = (json["dosageInstruction"] as? [[String: Any]]) ?? (json["dosage"] as? [[String: Any]]) ?? []
            let instructions = (dosage.first?["text"] as? String).map(sentenceCase) ?? ""
            return RecordMedication(id: record.uuid, name: name, strength: strength, instructions: instructions, date: record.startDate)
        }
    }

    static func allergies() async -> [String] {
        var seen = Set<String>()
        return await records(.allergyRecord).compactMap { record in
            let name = tidy(record.displayName)
            return seen.insert(name.lowercased()).inserted ? name : nil
        }
    }

    static func labResults() async -> [LabResult] {
        await records(.labResultRecord).compactMap { record in
            let json = fhir(record)
            var value = ""
            var unit = ""
            if let quantity = json["valueQuantity"] as? [String: Any] {
                value = number(quantity["value"])
                unit = (quantity["unit"] as? String) ?? (quantity["code"] as? String) ?? ""
            } else if let text = json["valueString"] as? String {
                value = text
            }
            guard !value.isEmpty else { return nil }
            return LabResult(id: record.uuid, name: tidy(record.displayName), value: value, unit: unit,
                             date: record.startDate, range: range(json), flag: flag(json))
        }
    }

    // MARK: FHIR details

    private static func fhir(_ record: HKClinicalRecord) -> [String: Any] {
        guard let data = record.fhirResource?.data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    private static func number(_ any: Any?) -> String {
        guard let value = any as? Double ?? (any as? NSNumber)?.doubleValue else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    private static func range(_ json: [String: Any]) -> String {
        guard let first = (json["referenceRange"] as? [[String: Any]])?.first else { return "" }
        if let text = first["text"] as? String { return text }
        let low = number((first["low"] as? [String: Any])?["value"])
        let high = number((first["high"] as? [String: Any])?["value"])
        switch (low.isEmpty, high.isEmpty) {
        case (false, false): return "\(low)–\(high)"
        case (false, true): return "≥ \(low)"
        case (true, false): return "≤ \(high)"
        default: return ""
        }
    }

    /// FHIR's interpretation codes; R4 sends a list, the older DSTU2 a single one.
    private static func flag(_ json: [String: Any]) -> String? {
        let concepts = (json["interpretation"] as? [[String: Any]]) ?? [(json["interpretation"] as? [String: Any])].compactMap { $0 }
        let codes = concepts.flatMap { ($0["coding"] as? [[String: Any]]) ?? [] }.compactMap { $0["code"] as? String }
        if codes.contains(where: { ["H", "HH", "HU", ">"].contains($0) }) { return String(localized: "High") }
        if codes.contains(where: { ["L", "LL", "LU", "<"].contains($0) }) { return String(localized: "Low") }
        if codes.contains("A") || codes.contains("AA") { return String(localized: "Abnormal") }
        return nil
    }

    // MARK: Text

    /// Many systems (the VA included) send names in capitals. "CARVEDILOL 25MG TAB"
    /// becomes "Carvedilol 25mg Tab"; mixed-case names are left alone.
    static func tidy(_ text: String) -> String {
        guard text == text.uppercased() else { return text }
        return text.split(separator: " ").map { word in
            word.contains(where: \.isNumber) ? word.lowercased() : word.capitalized
        }.joined(separator: " ")
    }

    /// "Carvedilol 25mg Tab" → ("Carvedilol", "25mg Tab"): the strength starts at the first number.
    private static func splitStrength(_ text: String) -> (String, String) {
        let words = text.split(separator: " ")
        guard let index = words.firstIndex(where: { $0.contains(where: \.isNumber) }), index > 0 else { return (text, "") }
        return (words[..<index].joined(separator: " "), words[index...].joined(separator: " "))
    }

    private static func sentenceCase(_ text: String) -> String {
        guard text == text.uppercased() else { return text }
        let lower = text.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}

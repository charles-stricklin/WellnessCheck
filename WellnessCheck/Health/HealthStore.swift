import Foundation
import HealthKit
import Observation

/// A reading that came from Apple Health and was written by some other app or device.
/// Shown alongside the user's own readings but never stored by WellnessCheck.
struct HealthReading: Identifiable, Sendable {
    let id: UUID
    let kind: VitalKind
    let date: Date
    /// Same units as `Reading`: mmHg, bpm, %, mg/dL, °C, kg.
    let value: Double
    let secondValue: Double?
    let sourceName: String
}

/// Everything WellnessCheck does with Apple Health.
///
/// Readings logged in the app are copied to Health so they sit with the rest of the
/// user's data. Readings from other sources are read back for display. Samples this
/// app wrote are excluded on the way in — the app already has them in its own store.
@MainActor
@Observable
final class HealthStore {
    static let shared = HealthStore()

    private let store = HKHealthStore()
    private(set) var external: [HealthReading] = []

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Types and units

    private static let systolic = HKQuantityType(.bloodPressureSystolic)
    private static let diastolic = HKQuantityType(.bloodPressureDiastolic)
    private static let bloodPressure = HKCorrelationType(.bloodPressure)
    private static let mmHg = HKUnit.millimeterOfMercury()
    private static let mgdl = HKUnit(from: "mg/dL")
    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    /// The single-quantity kinds (everything but blood pressure), with their HealthKit unit.
    private static let quantityKinds: [(VitalKind, HKQuantityType, HKUnit)] = [
        (.heartRate, HKQuantityType(.heartRate), bpm),
        (.oxygen, HKQuantityType(.oxygenSaturation), .percent()),
        (.glucose, HKQuantityType(.bloodGlucose), mgdl),
        (.temperature, HKQuantityType(.bodyTemperature), .degreeCelsius()),
        (.weight, HKQuantityType(.bodyMass), .gramUnit(with: .kilo)),
    ]

    private static var allTypes: Set<HKSampleType> {
        Set(quantityKinds.map(\.1)).union([systolic, diastolic])
    }

    /// HealthKit stores oxygen as a fraction (0.98); the app stores a percentage (98).
    private static func toApp(_ value: Double, _ kind: VitalKind) -> Double {
        kind == .oxygen ? value * 100 : value
    }

    private static func toHealth(_ value: Double, _ kind: VitalKind) -> Double {
        kind == .oxygen ? value / 100 : value
    }

    // MARK: Permission

    /// Shows the system Health permission sheet. iOS only shows it once per type;
    /// later calls return immediately, so this is safe to call on every launch.
    func requestAccess() async {
        guard isAvailable else { return }
        // Reading blood pressure requires asking for the correlation's component types.
        try? await store.requestAuthorization(toShare: Self.allTypes, read: Set(Self.allTypes))
    }

    // MARK: Writing

    /// Copies a reading into Health. Returns the Health sample's ID so a later
    /// delete in the app can remove it from Health too; nil if Health refused it.
    func save(_ reading: Reading) async -> UUID? {
        guard isAvailable else { return nil }
        let date = reading.date
        let metadata: [String: Any]? = reading.note.isEmpty ? nil : ["WCNote": reading.note]

        let sample: HKSample
        if reading.kind == .bloodPressure {
            guard let dia = reading.secondValue else { return nil }
            let parts: Set<HKSample> = [
                HKQuantitySample(type: Self.systolic, quantity: HKQuantity(unit: Self.mmHg, doubleValue: reading.value), start: date, end: date),
                HKQuantitySample(type: Self.diastolic, quantity: HKQuantity(unit: Self.mmHg, doubleValue: dia), start: date, end: date),
            ]
            sample = HKCorrelation(type: Self.bloodPressure, start: date, end: date, objects: parts, metadata: metadata)
        } else {
            guard let (_, type, unit) = Self.quantityKinds.first(where: { $0.0 == reading.kind }) else { return nil }
            let quantity = HKQuantity(unit: unit, doubleValue: Self.toHealth(reading.value, reading.kind))
            sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date, metadata: metadata)
        }

        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    /// Removes a sample this app wrote. Blood-pressure correlations take their
    /// systolic and diastolic parts with them, which Health does not do on its own.
    func delete(sampleID: UUID, kind: VitalKind) async {
        guard isAvailable else { return }
        let predicate = HKQuery.predicateForObject(with: sampleID)
        if kind == .bloodPressure {
            let query = HKSampleQueryDescriptor(predicates: [.correlation(type: Self.bloodPressure, predicate: predicate)], sortDescriptors: [])
            guard let correlation = try? await query.result(for: store).first else { return }
            try? await store.delete([correlation] + Array(correlation.objects))
        } else if let type = Self.quantityKinds.first(where: { $0.0 == kind })?.1 {
            _ = try? await store.deleteObjects(of: type, predicate: predicate)
        }
    }

    // MARK: Reading

    /// Loads the last 90 days of readings written by other apps and devices.
    func refresh() async {
        guard isAvailable else { return }
        let since = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let notOurs = NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
        let window = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: since, end: nil),
            notOurs,
        ])
        var results: [HealthReading] = []

        for (kind, type, unit) in Self.quantityKinds {
            let query = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: window)], sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 200)
            let samples = (try? await query.result(for: store)) ?? []
            results += samples.map {
                HealthReading(
                    id: $0.uuid, kind: kind, date: $0.startDate,
                    value: Self.toApp($0.quantity.doubleValue(for: unit), kind),
                    secondValue: nil, sourceName: $0.sourceRevision.source.name
                )
            }
        }

        let bpQuery = HKSampleQueryDescriptor(predicates: [.correlation(type: Self.bloodPressure, predicate: window)], sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 200)
        for correlation in (try? await bpQuery.result(for: store)) ?? [] {
            let sys = correlation.objects(for: Self.systolic).first as? HKQuantitySample
            let dia = correlation.objects(for: Self.diastolic).first as? HKQuantitySample
            guard let sys, let dia else { continue }
            results.append(HealthReading(
                id: correlation.uuid, kind: .bloodPressure, date: correlation.startDate,
                value: sys.quantity.doubleValue(for: Self.mmHg),
                secondValue: dia.quantity.doubleValue(for: Self.mmHg),
                sourceName: correlation.sourceRevision.source.name
            ))
        }

        external = results
    }
}
extension HealthReading: VitalValue {}

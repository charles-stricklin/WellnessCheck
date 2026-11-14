import Foundation
import SwiftData

/// The vitals WellnessCheck tracks. Raw values are persisted, so never rename them.
enum VitalKind: String, CaseIterable, Identifiable, Codable {
    case bloodPressure, heartRate, oxygen, glucose, temperature, weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bloodPressure: "Blood Pressure"
        case .heartRate: "Heart Rate"
        case .oxygen: "Blood Oxygen"
        case .glucose: "Blood Glucose"
        case .temperature: "Temperature"
        case .weight: "Weight"
        }
    }

    var symbol: String {
        switch self {
        case .bloodPressure: "heart.fill"
        case .heartRate: "waveform.path.ecg"
        case .oxygen: "lungs.fill"
        case .glucose: "drop.fill"
        case .temperature: "thermometer.medium"
        case .weight: "scalemass.fill"
        }
    }
}

/// One vital-sign reading.
///
/// Values are stored in one fixed unit per kind (mmHg, bpm, %, mg/dL, °C, kg) and
/// converted only for display, so changing the unit setting never alters history.
/// Every property has a default because CloudKit sync requires it.
@Model
final class Reading {
    var kindRaw: String = VitalKind.heartRate.rawValue
    var date: Date = Date.now
    /// Systolic for blood pressure; the only value for every other kind.
    var value: Double = 0
    /// Diastolic for blood pressure; nil otherwise.
    var secondValue: Double?
    var note: String = ""
    /// The copy saved to Apple Health, so deleting here can delete it there too.
    var healthSampleID: UUID?

    var kind: VitalKind {
        get { VitalKind(rawValue: kindRaw) ?? .heartRate }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: VitalKind, date: Date = .now, value: Double, secondValue: Double? = nil, note: String = "") {
        self.kindRaw = kind.rawValue
        self.date = date
        self.value = value
        self.secondValue = secondValue
        self.note = note
    }
}

/// What every displayable reading has, whether it lives in the app or came from Health.
protocol VitalValue {
    var kind: VitalKind { get }
    var date: Date { get }
    var value: Double { get }
    var secondValue: Double? { get }
}

extension Reading: VitalValue {}

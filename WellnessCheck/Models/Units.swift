import Foundation

/// Display units. Defaults are US units (mg/dL, °F, lb); the switches will live in Settings.
/// Storage is always mg/dL, °C and kg — see `Reading`.
enum Units {
    static let glucoseMmolKey = "units.glucoseMmol"
    static let celsiusKey = "units.celsius"
    static let kilogramsKey = "units.kilograms"

    private static var defaults: UserDefaults { .standard }

    /// mg/dL ÷ 18.016 = mmol/L (glucose's molar mass).
    private static let mgdlPerMmol = 18.016
    private static let lbPerKg = 2.20462

    static func unitLabel(for kind: VitalKind) -> String {
        switch kind {
        case .bloodPressure: "mmHg"
        case .heartRate: "bpm"
        case .oxygen: "%"
        case .glucose: defaults.bool(forKey: glucoseMmolKey) ? "mmol/L" : "mg/dL"
        case .temperature: defaults.bool(forKey: celsiusKey) ? "°C" : "°F"
        case .weight: defaults.bool(forKey: kilogramsKey) ? "kg" : "lb"
        }
    }

    /// Stored unit → the unit the user sees.
    static func toDisplay(_ stored: Double, kind: VitalKind) -> Double {
        switch kind {
        case .glucose: defaults.bool(forKey: glucoseMmolKey) ? stored / mgdlPerMmol : stored
        case .temperature: defaults.bool(forKey: celsiusKey) ? stored : stored * 9 / 5 + 32
        case .weight: defaults.bool(forKey: kilogramsKey) ? stored : stored * lbPerKg
        default: stored
        }
    }

    /// The unit the user typed → stored unit.
    static func toStored(_ entered: Double, kind: VitalKind) -> Double {
        switch kind {
        case .glucose: defaults.bool(forKey: glucoseMmolKey) ? entered * mgdlPerMmol : entered
        case .temperature: defaults.bool(forKey: celsiusKey) ? entered : (entered - 32) * 5 / 9
        case .weight: defaults.bool(forKey: kilogramsKey) ? entered : entered / lbPerKg
        default: entered
        }
    }

    /// The reading as the user should see it, e.g. "120/80", "98.6", "6.1".
    static func formatted(_ reading: any VitalValue) -> String {
        let kind = reading.kind
        if kind == .bloodPressure {
            let dia = reading.secondValue.map { String(Int($0.rounded())) } ?? "–"
            return "\(Int(reading.value.rounded()))/\(dia)"
        }
        let shown = toDisplay(reading.value, kind: kind)
        let decimals: Int = switch kind {
        case .heartRate, .oxygen: 0
        case .glucose: defaults.bool(forKey: glucoseMmolKey) ? 1 : 0
        case .temperature, .weight: 1
        case .bloodPressure: 0
        }
        return shown.formatted(.number.precision(.fractionLength(decimals)))
    }
}

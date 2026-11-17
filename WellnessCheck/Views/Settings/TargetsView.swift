import SwiftUI

/// Target ranges for one person, typed in the units they see. Saved when they leave
/// the screen, converting to stored units so a later unit switch doesn't change them.
struct TargetsView: View {
    @Bindable var person: Person
    /// Text as typed, by vital: [low, high, second low, second high].
    @State private var text: [VitalKind: [String]] = [:]

    var body: some View {
        Form {
            Section {
                EmptyView()
            } footer: {
                Text("Ask your doctor what your targets should be. Leave a box empty for no limit. Readings outside a target are marked Out of Range.")
            }
            ForEach(VitalKind.allCases) { kind in
                Section {
                    if kind == .bloodPressure {
                        rangeRow("Top number", kind, 0, 1)
                        rangeRow("Bottom number", kind, 2, 3)
                    } else {
                        rangeRow(Units.unitLabel(for: kind), kind, 0, 1)
                    }
                } header: {
                    Label(kind.title, systemImage: kind.symbol)
                }
            }
        }
        .navigationTitle("Target Ranges")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    private func rangeRow(_ title: String, _ kind: VitalKind, _ lowIndex: Int, _ highIndex: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            box("From", kind, lowIndex)
            Text("to").foregroundStyle(.secondary)
            box("To", kind, highIndex)
        }
    }

    @ScaledMetric private var boxWidth = 64.0

    private func box(_ name: String, _ kind: VitalKind, _ index: Int) -> some View {
        TextField("", text: Binding {
            text[kind]?[index] ?? ""
        } set: {
            var values = text[kind] ?? ["", "", "", ""]
            values[index] = $0
            text[kind] = values
        })
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.center)
        .monospacedDigit()
        .padding(.vertical, 6)
        .frame(width: boxWidth)
        .background(.fill.tertiary, in: .rect(cornerRadius: 8))
        .accessibilityLabel("\(kind.title) \(name.lowercased())")
    }

    private func load() {
        for kind in VitalKind.allCases {
            let target = person.targets.first { $0.kindRaw == kind.rawValue }
            text[kind] = [target?.low, target?.high, target?.secondLow, target?.secondHigh].map { value in
                guard let value else { return "" }
                // Blood pressure's second pair is mmHg too, so the same conversion applies.
                let shown = Units.toDisplay(value, kind: kind)
                return shown.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
            }
        }
    }

    private func save() {
        person.targets = VitalKind.allCases.compactMap { kind in
            let values = (text[kind] ?? []).map { raw -> Double? in
                let cleaned = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                return Double(cleaned).map { Units.toStored($0, kind: kind) }
            } + [nil, nil, nil, nil]
            let target = VitalTarget(kindRaw: kind.rawValue, low: values[0], high: values[1],
                                     secondLow: values[2], secondHigh: values[3])
            return target.isEmpty ? nil : target
        }
    }
}

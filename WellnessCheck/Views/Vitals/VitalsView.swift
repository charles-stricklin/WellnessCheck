import SwiftUI
import SwiftData

/// The Vitals tab: the latest reading of each kind, then the full history by day.
struct VitalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var isLogging = false

    var body: some View {
        NavigationStack {
            List {
                Section("Latest") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(VitalKind.allCases) { kind in
                            VitalTile(kind: kind, latest: readings.first { $0.kind == kind })
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(days, id: \.self) { day in
                    Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                        ForEach(readings(on: day)) { reading in
                            ReadingRow(reading: reading)
                        }
                        .onDelete { offsets in
                            let dayReadings = readings(on: day)
                            offsets.forEach { context.delete(dayReadings[$0]) }
                        }
                    }
                }
            }
            .overlay {
                if readings.isEmpty {
                    ContentUnavailableView(
                        "No Readings Yet",
                        systemImage: "heart.text.square",
                        description: Text("Tap + to log your first reading.")
                    )
                    .padding(.top, 200)
                }
            }
            .navigationTitle("Vitals")
            .toolbar {
                Button("Log Reading", systemImage: "plus") { isLogging = true }
            }
            .sheet(isPresented: $isLogging) {
                LogReadingView()
            }
        }
    }

    private var days: [Date] {
        let calendar = Calendar.current
        var seen = Set<Date>()
        return readings.compactMap {
            let day = calendar.startOfDay(for: $0.date)
            return seen.insert(day).inserted ? day : nil
        }
    }

    private func readings(on day: Date) -> [Reading] {
        readings.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }
}

private struct VitalTile: View {
    let kind: VitalKind
    let latest: Reading?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(kind.title, systemImage: kind.symbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(latest.map(Units.formatted) ?? "—")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                if latest != nil {
                    Text(Units.unitLabel(for: kind))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text(latest?.date.formatted(.relative(presentation: .named)) ?? "No readings")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ReadingRow: View {
    let reading: Reading

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reading.kind.symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Units.formatted(reading))
                        .font(.headline)
                        .monospacedDigit()
                    Text(Units.unitLabel(for: reading.kind))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(reading.note.isEmpty ? reading.kind.title : "\(reading.kind.title) · \(reading.note)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(reading.date.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VitalsView()
        .modelContainer(for: Reading.self, inMemory: true)
}

import SwiftUI
import PDFKit
import UIKit

/// "Share with your doctor": a PDF covering a chosen stretch of time, previewed
/// here and shared through the usual share sheet (Mail, Messages, AirDrop, Print…).
struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var days = 30
    @State private var pdf: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Covering", selection: $days) {
                    Text("2 Weeks").tag(14)
                    Text("30 Days").tag(30)
                    Text("90 Days").tag(90)
                }
                .pickerStyle(.segmented)
                .padding()
                if let pdf {
                    PDFPreview(url: pdf)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("Report for Your Doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if let pdf {
                        ShareLink(item: pdf) { Label("Share", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            .task(id: days) {
                pdf = HealthReport(person: person, days: days).writePDF()
            }
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(url: url)
    }
}

/// Builds the report. Written as HTML and printed to PDF, because the print system
/// already knows how to break tables across pages.
@MainActor
struct HealthReport {
    let person: Person
    let days: Int

    private var start: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    /// The person's own readings, plus Apple Health's for the phone's owner, as on the Vitals tab.
    private var readings: [any VitalValue] {
        let own: [any VitalValue] = (person.readings ?? []).filter { $0.date >= start }
        let health: [any VitalValue] = person.isSelf ? HealthStore.shared.external.filter { $0.date >= start } : []
        return (own + health).sorted { $0.date > $1.date }
    }

    func writePDF() -> URL? {
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: html), startingAtPageAt: 0)
        // US Letter with half-inch margins.
        let paper = CGRect(x: 0, y: 0, width: 612, height: 792)
        renderer.setValue(paper, forKey: "paperRect")
        renderer.setValue(paper.insetBy(dx: 36, dy: 36), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, paper, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        let name = person.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Health Report - \(name).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Sections

    private var html: String {
        """
        <html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system, Helvetica; font-size: 11pt; color: #1a1a1a; }
        h1 { font-size: 20pt; margin: 0 0 2pt 0; }
        h2 { font-size: 13pt; margin: 18pt 0 6pt 0; border-bottom: 1px solid #ccc; padding-bottom: 2pt; }
        .muted { color: #666; }
        table { width: 100%; border-collapse: collapse; }
        th { text-align: left; font-size: 9pt; color: #666; border-bottom: 1px solid #ccc; padding: 3pt 4pt; }
        td { padding: 3pt 4pt; border-bottom: 1px solid #eee; vertical-align: top; }
        .num { text-align: right; }
        </style></head><body>
        <h1>Health Report: \(esc(person.name))</h1>
        <div class="muted">\(esc(start.formatted(date: .long, time: .omitted))) to \(esc(Date.now.formatted(date: .long, time: .omitted))) · Prepared with WellnessCheck</div>
        \(aboutSection)
        \(summarySection)
        \(medicinesSection)
        \(readingsSection)
        </body></html>
        """
    }

    private var aboutSection: String {
        var rows: [(String, String)] = []
        if let birth = person.birthDate {
            let age = Calendar.current.dateComponents([.year], from: birth, to: .now).year ?? 0
            rows.append(("Date of birth", "\(birth.formatted(date: .long, time: .omitted)) (\(age) years)"))
        }
        if let sex = person.sex { rows.append(("Sex", sex.label)) }
        if let cm = person.heightCm {
            let inches = Int((cm / 2.54).rounded())
            rows.append(("Height", "\(inches / 12)′ \(inches % 12)″ (\(Int(cm.rounded())) cm)"))
        }
        if !person.bloodType.isEmpty { rows.append(("Blood type", person.bloodType)) }
        rows.append(("Allergies", person.allergies.isEmpty ? "None listed" : person.allergies.joined(separator: ", ")))
        if !person.emergencyName.isEmpty {
            let who = [person.emergencyName, person.emergencyRelationship, person.emergencyPhone].filter { !$0.isEmpty }
            rows.append(("Emergency contact", who.joined(separator: " · ")))
        }
        return "<h2>About</h2><table>" + rows.map { "<tr><td class=\"muted\" width=\"28%\">\(esc($0.0))</td><td>\(esc($0.1))</td></tr>" }.joined() + "</table>"
    }

    private var summarySection: String {
        let byKind = Dictionary(grouping: readings, by: \.kind)
        let rows = VitalKind.allCases.compactMap { kind -> String? in
            guard let list = byKind[kind], !list.isEmpty else { return nil }
            func avg(_ values: [Double]) -> Double { values.reduce(0, +) / Double(values.count) }
            let firsts = list.map(\.value)
            let seconds = list.compactMap(\.secondValue)
            let average = Value(kind: kind, value: avg(firsts), secondValue: seconds.isEmpty ? nil : avg(seconds))
            // For blood pressure, low and high go by the top number.
            let low = list.min { $0.value < $1.value }!
            let high = list.max { $0.value < $1.value }!
            let outside = person.target(for: kind) == nil ? "—" : "\(list.filter { person.isInRange($0) == false }.count)"
            return "<tr><td>\(esc(kind.title)) <span class=\"muted\">(\(esc(Units.unitLabel(for: kind))))</span></td>"
                + "<td class=\"num\">\(list.count)</td><td class=\"num\">\(esc(Units.formatted(average)))</td>"
                + "<td class=\"num\">\(esc(Units.formatted(low)))</td><td class=\"num\">\(esc(Units.formatted(high)))</td><td class=\"num\">\(outside)</td></tr>"
        }
        guard !rows.isEmpty else { return "<h2>Vital Signs</h2><p class=\"muted\">No readings in this period.</p>" }
        return "<h2>Vital Signs</h2><table><tr><th>Vital</th><th class=\"num\">Readings</th><th class=\"num\">Average</th>"
            + "<th class=\"num\">Lowest</th><th class=\"num\">Highest</th><th class=\"num\">Out of range</th></tr>" + rows.joined() + "</table>"
    }

    private var medicinesSection: String {
        let meds = (person.medications ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !meds.isEmpty else { return "" }
        var out = "<h2>Medicines</h2><table><tr><th>Medicine</th><th>How taken</th><th>For / prescribed by</th><th class=\"num\">Checked off</th></tr>"
        for med in meds where med.status == .taking {
            let forBy = [med.purpose, med.doctor?.name ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
            out += "<tr><td>\(esc(med.title))</td><td>\(esc(med.scheduleSummary))</td><td>\(esc(forBy))</td><td class=\"num\">\(esc(adherence(med)))</td></tr>"
        }
        out += "</table>"
        let notTaking = meds.filter { $0.status != .taking }
        if !notTaking.isEmpty {
            out += "<p><b>Paused or stopped:</b> " + notTaking.map {
                esc("\($0.title), \($0.status.label.lowercased())" + ($0.statusNote.isEmpty ? "" : " (\($0.statusNote))"))
            }.joined(separator: "; ") + "</p>"
        }
        let changes = meds.flatMap { med in (med.changes ?? []).filter { $0.date >= start }.map { (med, $0) } }
            .sorted { $0.1.date > $1.1.date }
        if !changes.isEmpty {
            out += "<p><b>Changes in this period:</b></p><table>" + changes.map { med, change in
                "<tr><td width=\"18%\">\(esc(change.date.formatted(date: .abbreviated, time: .omitted)))</td><td>\(esc(med.title)): \(esc(change.summary))</td></tr>"
            }.joined() + "</table>"
        }
        return out
    }

    /// "27 of 30": doses checked off against doses scheduled in the period, so far.
    private func adherence(_ med: Medication) -> String {
        guard med.frequency != .asNeeded else {
            let count = (med.records ?? []).filter { $0.date >= start }.count
            return count == 1 ? "1 time" : "\(count) times"
        }
        let calendar = Calendar.current
        var scheduled = 0
        var day = max(start, calendar.startOfDay(for: med.startDate))
        while day <= .now {
            if med.isScheduled(on: day) {
                scheduled += med.sortedTimes.filter { $0.date(on: day) <= .now }.count
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? .distantFuture
        }
        let taken = (med.records ?? []).filter { $0.scheduledFor >= start }.count
        return scheduled == 0 ? "—" : "\(min(taken, scheduled)) of \(scheduled)"
    }

    private var readingsSection: String {
        guard !readings.isEmpty else { return "" }
        let rows = readings.map { reading in
            let source = (reading as? HealthReading)?.sourceName ?? ""
            var note = (reading as? Reading)?.note ?? source
            if person.isInRange(reading) == false { note = "Out of range" + (note.isEmpty ? "" : " · \(note)") }
            return "<tr><td width=\"26%\">\(esc(reading.date.formatted(date: .abbreviated, time: .shortened)))</td>"
                + "<td>\(esc(reading.kind.title))</td><td class=\"num\">\(esc(Units.formatted(reading))) \(esc(Units.unitLabel(for: reading.kind)))</td>"
                + "<td class=\"muted\">\(esc(note))</td></tr>"
        }
        return "<h2>All Readings</h2><table><tr><th>When</th><th>Vital</th><th class=\"num\">Reading</th><th>Note or source</th></tr>"
            + rows.joined() + "</table>"
    }

    private func esc(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// An average, shaped like a reading so it formats the same way.
    private struct Value: VitalValue {
        let kind: VitalKind
        var date: Date = .now
        let value: Double
        let secondValue: Double?
    }
}

import SwiftUI

/// A pet's printable summary — the web app's summary view
/// (renderSummary): face, name, the species/breed/age line,
/// basics, vet, and every record, ready to hand to a vet or a
/// pet sitter. The button shares the same words as text, which
/// is how a phone prints.
struct SummaryView: View {
    let pet: Pet
    let records: [Record]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 6) {
                    Text(pet.speciesEmoji).font(.system(size: 52))
                    Text(pet.name)
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(Theme.greenDark)
                    Text(metaLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                basicsCard
                vetCard
                recordsCard

                ShareLink(item: plainText) {
                    Text("🖨 Print / share this summary")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(Theme.page)
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metaLine: String {
        [pet.speciesLabel, pet.breed, Self.ageText(pet.birthday)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            kv("Birthday", pet.birthday.map { Record.formatDay($0) })
            kv("Weight", pet.weight)
            kv("Food", pet.food)
            kv("Allergies", pet.allergies)
            kv("Notes & quirks", pet.notes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }

    private var vetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🏥 Vet").font(.headline)
            if [pet.vetClinic, pet.vetName, pet.vetPhone].allSatisfy({ ($0 ?? "").isEmpty }) {
                Text("No vet on file.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                kv("Clinic", pet.vetClinic)
                kv("Vet", pet.vetName)
                kv("Phone", pet.vetPhone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📋 Records").font(.headline)
            if records.isEmpty {
                Text("No records on file.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    HStack(alignment: .top) {
                        Text(record.kindLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 92, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.title).font(.subheadline)
                            let dates = [
                                record.dateGiven.map { "Given \(Record.formatDay($0))" },
                                record.nextDue.map { "Next due \(Record.formatDay($0))" },
                            ].compactMap { $0 }
                            if !dates.isEmpty {
                                Text(dates.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }

    @ViewBuilder
    private func kv(_ key: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(key)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .leading)
                Text(value).font(.subheadline)
            }
        }
    }

    /// The same summary as plain text, for the share/print sheet.
    private var plainText: String {
        var lines: [String] = []
        lines.append("\(pet.speciesEmoji) \(pet.name)")
        lines.append(metaLine)
        lines.append("")
        func add(_ key: String, _ value: String?) {
            if let value, !value.isEmpty { lines.append("\(key): \(value)") }
        }
        add("Birthday", pet.birthday.map { Record.formatDay($0) })
        add("Weight", pet.weight)
        add("Food", pet.food)
        add("Allergies", pet.allergies)
        add("Notes & quirks", pet.notes)
        lines.append("")
        lines.append("Vet")
        if [pet.vetClinic, pet.vetName, pet.vetPhone].allSatisfy({ ($0 ?? "").isEmpty }) {
            lines.append("No vet on file.")
        } else {
            add("Clinic", pet.vetClinic)
            add("Vet", pet.vetName)
            add("Phone", pet.vetPhone)
        }
        lines.append("")
        lines.append("Records")
        if records.isEmpty {
            lines.append("No records on file.")
        } else {
            for record in records {
                let dates = [
                    record.dateGiven.map { "Given \(Record.formatDay($0))" },
                    record.nextDue.map { "Next due \(Record.formatDay($0))" },
                ].compactMap { $0 }
                lines.append("\(record.kindLabel): \(record.title)" + (dates.isEmpty ? "" : " — " + dates.joined(separator: " · ")))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The web app's ageText(), simplified to whole years and
    /// months: "3 yrs 3 mo", "6 mo", "2 yrs".
    static func ageText(_ birthday: String?) -> String? {
        guard let day = Record.parseDay(birthday) else { return nil }
        let comps = Calendar.current.dateComponents([.year, .month], from: day, to: Date())
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        if years > 0 && months > 0 { return "\(years) yrs \(months) mo" }
        if years > 0 { return "\(years) yrs" }
        if months > 0 { return "\(months) mo" }
        return "Under a month"
    }
}

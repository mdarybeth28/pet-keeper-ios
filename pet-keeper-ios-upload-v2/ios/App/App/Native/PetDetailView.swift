import SwiftUI

/// The native pet screen: one pet's fields and its records, read
/// from the real `pets` / `records` tables. Read-only in this slice —
/// adding and editing pets and records stays in the web app for now
/// (build plan §3 keeps the forms web-scoped).
///
/// The shape mirrors the web app's pet page (`renderPet()`): basics,
/// vet, then records grouped Vaccinations / Medicines / Other, with
/// the same "Given … · Next due …" line and the same due pill words.
struct PetDetailView: View {
    @EnvironmentObject private var session: SessionStore
    let pet: Pet

    @State private var records: [Record] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private static let groupOrder: [(kind: String, heading: String)] = [
        ("vaccination", "💉 Vaccinations"),
        ("medicine", "💊 Medicines"),
        ("other", "📝 Other records"),
    ]

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(pet.speciesEmoji).font(.largeTitle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.name).font(.title3).fontWeight(.semibold)
                        Text(pet.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text("Basics")) {
                fieldRow("Birthday", pet.birthday.map { Record.formatDay($0) })
                fieldRow("Weight", pet.weight)
                fieldRow("Food", pet.food)
                fieldRow("Allergies", pet.allergies)
                fieldRow("Notes & quirks", pet.notes)
                if [pet.birthday, pet.weight, pet.food, pet.allergies, pet.notes]
                    .allSatisfy({ ($0 ?? "").isEmpty }) {
                    Text("No basics added yet — you can add them in the web app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Vet")) {
                fieldRow("Clinic", pet.vetClinic)
                fieldRow("Vet", pet.vetName)
                fieldRow("Phone", pet.vetPhone)
                if [pet.vetClinic, pet.vetName, pet.vetPhone]
                    .allSatisfy({ ($0 ?? "").isEmpty }) {
                    Text("No vet added yet — you can add one in the web app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            recordsContent
        }
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.state) {
            if session.state == .signedIn { await load() }
        }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var recordsContent: some View {
        if isLoading {
            Section(header: Text("Records")) {
                ProgressView("Loading records…")
            }
        } else if let loadError {
            Section(header: Text("Records")) {
                Text(loadError)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Try again") { Task { await load() } }
            }
        } else if records.isEmpty {
            Section(header: Text("Records")) {
                Text("No records yet. A rabies shot, a monthly medicine, anything with a date — records are added in the web app for now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(Self.groupOrder, id: \.kind) { group in
                let groupRecords = records.filter { ($0.kind ?? "other") == group.kind }
                if !groupRecords.isEmpty {
                    Section(header: Text(group.heading)) {
                        ForEach(groupRecords) { record in
                            recordRow(record)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
    }

    private func recordRow(_ record: Record) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.title).font(.headline)
                Spacer()
                if let label = record.dueLabel,
                   record.dueBucket == .overdue || record.dueBucket == .dueToday || record.dueBucket == .soon {
                    Text(label)
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(record.dueBucket == .soon ? Color.orange.opacity(0.2) : Color.red.opacity(0.18),
                                    in: Capsule())
                }
            }
            let dates = [
                record.dateGiven.map { "Given \(Record.formatDay($0))" },
                record.nextDue.map { "Next due \(Record.formatDay($0))" },
            ].compactMap { $0 }
            if !dates.isEmpty {
                Text(dates.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let notes = record.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        guard let token = await session.validAccessToken() else {
            loadError = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        do {
            records = try await RecordsService.fetchRecords(accessToken: token, petId: pet.id)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

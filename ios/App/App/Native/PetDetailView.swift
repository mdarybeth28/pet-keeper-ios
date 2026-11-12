import SwiftUI

/// The native pet screen: one pet's fields and its records, read
/// from the real `pets` / `records` tables — and, since the
/// parity round, fully workable here: edit the pet, add / edit /
/// remove records, read a vet receipt, open the printable
/// summary, or remove the pet. The shape mirrors the web app's
/// pet page (`renderPet()`): basics, vet, then records grouped
/// Vaccinations / Medicines / Other, with the same due pill words.
struct PetDetailView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var petState: Pet
    @State private var records: [Record] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showEditPet = false
    @State private var showAddRecord = false
    @State private var editingRecord: Record?
    @State private var showReceipt = false
    @State private var confirmDeletePet = false
    @State private var actionError: String?

    private static let groupOrder: [(kind: String, heading: String)] = [
        ("vaccination", "💉 Vaccinations"),
        ("medicine", "💊 Medicines"),
        ("other", "📝 Other records"),
    ]

    init(pet: Pet) {
        _petState = State(initialValue: pet)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(petState.speciesEmoji).font(.largeTitle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(petState.name).font(.title3).fontWeight(.semibold)
                        Text(petState.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.white)
            }

            Section {
                Button {
                    showReceipt = true
                } label: {
                    Label("Read a vet receipt", systemImage: "camera.fill")
                        .fontWeight(.semibold)
                }
                NavigationLink {
                    SummaryView(pet: petState, records: records)
                } label: {
                    Label("Pet summary (for the vet or a sitter)", systemImage: "doc.text.fill")
                }
                Button {
                    showAddRecord = true
                } label: {
                    Label("Add a record", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .listRowBackground(Color.white)

            Section(header: Text("Basics")) {
                fieldRow("Birthday", petState.birthday.map { Record.formatDay($0) })
                fieldRow("Weight", petState.weight)
                fieldRow("Food", petState.food)
                fieldRow("Allergies", petState.allergies)
                fieldRow("Notes & quirks", petState.notes)
                if [petState.birthday, petState.weight, petState.food, petState.allergies, petState.notes]
                    .allSatisfy({ ($0 ?? "").isEmpty }) {
                    Text("No basics added yet — tap Edit up top to add them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.white)

            Section(header: Text("Vet")) {
                fieldRow("Clinic", petState.vetClinic)
                fieldRow("Vet", petState.vetName)
                fieldRow("Phone", petState.vetPhone)
                if [petState.vetClinic, petState.vetName, petState.vetPhone]
                    .allSatisfy({ ($0 ?? "").isEmpty }) {
                    Text("No vet added yet — tap Edit up top to add one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color.white)

            recordsContent

            if let actionError {
                Section {
                    Text(actionError).font(.subheadline).foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmDeletePet = true
                } label: {
                    HStack { Spacer(); Text("Remove \(petState.name)"); Spacer() }
                }
            }
            .listRowBackground(Color.white)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.page)
        .navigationTitle(petState.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEditPet = true }
            }
        }
        .sheet(isPresented: $showEditPet) {
            PetFormView(existing: petState) { _ in
                Task { await reloadPet() }
            }
            .environmentObject(session)
        }
        .sheet(isPresented: $showAddRecord) {
            RecordFormView(pet: petState, existing: nil) {
                Task { await load() }
            }
            .environmentObject(session)
        }
        .sheet(item: $editingRecord) { record in
            RecordFormView(pet: petState, existing: record) {
                Task { await load() }
            }
            .environmentObject(session)
        }
        .sheet(isPresented: $showReceipt) {
            ReceiptView(pet: petState) {
                Task { await load(); await reloadPet() }
            }
            .environmentObject(session)
        }
        .confirmationDialog("Remove \(petState.name) and all of \(petState.name)'s records? This can't be undone.",
                            isPresented: $confirmDeletePet, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await deletePet() } }
            Button("Keep", role: .cancel) {}
        }
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
                Text("No records yet. A rabies shot, a monthly medicine, anything with a date — tap Add a record up top.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(Self.groupOrder, id: \.kind) { group in
                let groupRecords = records.filter { ($0.kind ?? "other") == group.kind }
                if !groupRecords.isEmpty {
                    Section(header: Text(group.heading)) {
                        ForEach(groupRecords) { record in
                            Button {
                                editingRecord = record
                            } label: {
                                recordRow(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.white)
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
                Text(record.title).font(.headline).foregroundStyle(.primary)
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
        .contentShape(Rectangle())
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
            records = try await RecordsService.fetchRecords(accessToken: token, petId: petState.id)
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Re-read this pet's own row (after an edit, or after the
    /// receipt reader filled in vet fields).
    private func reloadPet() async {
        guard let token = await session.validAccessToken() else { return }
        if let all = try? await PetsService.fetchPets(accessToken: token),
           let fresh = all.first(where: { $0.id == petState.id }) {
            petState = fresh
        }
    }

    private func deletePet() async {
        guard let token = await session.validAccessToken() else { return }
        do {
            try await PetsService.deletePet(accessToken: token, petId: petState.id)
            dismiss()
        } catch {
            actionError = error.localizedDescription
        }
    }
}

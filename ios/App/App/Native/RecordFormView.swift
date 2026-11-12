import SwiftUI

/// The add-a-record / edit-a-record form — the web app's record
/// form (view-record-form) in native dress: kind segment, title,
/// date given, next due, notes, and (when editing) the remove
/// button with the web's own confirmation words.
struct RecordFormView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    /// The record being edited, or nil for a new one.
    let existing: Record?
    var onSaved: () -> Void = {}

    @State private var kind = "vaccination"
    @State private var title = ""
    @State private var hasGiven = false
    @State private var dateGiven = Date()
    @State private var hasDue = false
    @State private var nextDue = Date()
    @State private var notes = ""
    @State private var message: String?
    @State private var isSaving = false
    @State private var confirmDelete = false

    init(pet: Pet, existing: Record?, onSaved: @escaping () -> Void = {}) {
        self.pet = pet
        self.existing = existing
        self.onSaved = onSaved
        if let record = existing {
            _kind = State(initialValue: record.kind ?? "other")
            _title = State(initialValue: record.title)
            if let day = Record.parseDay(record.dateGiven) {
                _hasGiven = State(initialValue: true)
                _dateGiven = State(initialValue: day)
            }
            if let day = Record.parseDay(record.nextDue) {
                _hasDue = State(initialValue: true)
                _nextDue = State(initialValue: day)
            }
            _notes = State(initialValue: record.notes ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("What kind?", selection: $kind) {
                        Text("💉 Vaccination").tag("vaccination")
                        Text("💊 Medicine").tag("medicine")
                        Text("📝 Other").tag("other")
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("The record")) {
                    TextField("Name — like Rabies shot", text: $title)
                    Toggle("Date given", isOn: $hasGiven)
                    if hasGiven {
                        DatePicker("Date given", selection: $dateGiven, displayedComponents: .date)
                    }
                    Toggle("Next due", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Next due", selection: $nextDue, displayedComponents: .date)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let message {
                    Section {
                        Text(message).foregroundStyle(.red).font(.subheadline)
                    }
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving { ProgressView() }
                            Text("Save record").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            HStack { Spacer(); Text("Remove this record"); Spacer() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle(existing == nil ? "Add a record" : "Edit record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Remove this record? This can't be undone.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { Task { await delete() } }
                Button("Keep it", role: .cancel) {}
            }
        }
    }

    private func save() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            message = "Give the record a name first — like \u{201C}Rabies shot\u{201D}."
            return
        }
        guard let ownerId = session.currentUserID,
              let token = await session.validAccessToken() else {
            message = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        isSaving = true
        defer { isSaving = false }
        let row = RecordsService.recordRow(
            ownerId: ownerId, petId: pet.id, kind: kind, title: cleanTitle,
            dateGiven: hasGiven ? Record.isoString(dateGiven) : nil,
            nextDue: hasDue ? Record.isoString(nextDue) : nil,
            notes: notes)
        do {
            if let existing {
                try await RecordsService.updateRecord(accessToken: token, recordId: existing.id, row: row)
            } else {
                try await RecordsService.createRecord(accessToken: token, row: row)
            }
            onSaved()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete() async {
        guard let existing, let token = await session.validAccessToken() else { return }
        do {
            try await RecordsService.deleteRecord(accessToken: token, recordId: existing.id)
            onSaved()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

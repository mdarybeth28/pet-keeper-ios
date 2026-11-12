import SwiftUI

/// The add-a-pet / edit-a-pet form — the web app's pet form
/// (view-pet-form) in native dress: the same fields in the same
/// order, the same save row, the same first rule ("Give your pet
/// a name first."). Empty fields save as null, exactly like the
/// web's `value.trim() || null`.
struct PetFormView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    /// The pet being edited, or nil when this is a new pet.
    let existing: Pet?
    /// Called after a successful save (with the saved pet when the
    /// server returned one) so the caller can refresh itself.
    var onSaved: (Pet?) -> Void = { _ in }

    @State private var name = ""
    @State private var species = "dog"
    @State private var breed = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var weight = ""
    @State private var food = ""
    @State private var allergies = ""
    @State private var notes = ""
    @State private var vetClinic = ""
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var message: String?
    @State private var isSaving = false

    init(existing: Pet?, onSaved: @escaping (Pet?) -> Void = { _ in }) {
        self.existing = existing
        self.onSaved = onSaved
        if let pet = existing {
            _name = State(initialValue: pet.name)
            _species = State(initialValue: pet.species)
            _breed = State(initialValue: pet.breed ?? "")
            if let day = Record.parseDay(pet.birthday) {
                _hasBirthday = State(initialValue: true)
                _birthday = State(initialValue: day)
            }
            _weight = State(initialValue: pet.weight ?? "")
            _food = State(initialValue: pet.food ?? "")
            _allergies = State(initialValue: pet.allergies ?? "")
            _notes = State(initialValue: pet.notes ?? "")
            _vetClinic = State(initialValue: pet.vetClinic ?? "")
            _vetName = State(initialValue: pet.vetName ?? "")
            _vetPhone = State(initialValue: pet.vetPhone ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("The basics")) {
                    TextField("Name", text: $name)
                    Picker("Kind", selection: $species) {
                        Text("🐶 Dog").tag("dog")
                        Text("🐱 Cat").tag("cat")
                    }
                    .pickerStyle(.segmented)
                    TextField("Breed", text: $breed)
                    Toggle("Birthday", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                    }
                    TextField("Weight (like 12 lbs)", text: $weight)
                    TextField("Food", text: $food)
                    TextField("Allergies", text: $allergies)
                }
                Section(header: Text("Notes & quirks")) {
                    TextField("Anything worth remembering", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section(header: Text("Vet")) {
                    TextField("Clinic", text: $vetClinic)
                    TextField("Vet's name", text: $vetName)
                    TextField("Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
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
                            Text("Save pet").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle(existing == nil ? "Add a pet" : "Edit \(existing!.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            message = "Give your pet a name first."
            return
        }
        guard let ownerId = session.currentUserID,
              let token = await session.validAccessToken() else {
            message = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        isSaving = true
        defer { isSaving = false }
        let row = PetsService.petRow(
            ownerId: ownerId, name: cleanName, species: species,
            breed: breed, birthday: hasBirthday ? Record.isoString(birthday) : nil,
            weight: weight, vetClinic: vetClinic, vetName: vetName,
            vetPhone: vetPhone, food: food, allergies: allergies, notes: notes)
        do {
            if let existing {
                try await PetsService.updatePet(accessToken: token, petId: existing.id, row: row)
                onSaved(nil)
            } else {
                let created = try await PetsService.createPet(accessToken: token, row: row)
                onSaved(created)
            }
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

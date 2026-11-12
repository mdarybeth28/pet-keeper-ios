import SwiftUI
import PhotosUI
import UIKit

/// The 📸 receipt door on a pet's page — the web app's receipt
/// flow step for step: pick a photo, the reader reads it, the
/// person checks the read over on an editable card (fix anything,
/// take a row off, choose whether the vet gets saved too), and
/// saving files the records. A read that comes back empty — or
/// a photo the person says still doesn't look right — offers
/// the fallback: send the photo to Mary, who reads it herself.
struct ReceiptView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    var onSaved: () -> Void = {}

    private struct DraftRow: Identifiable {
        let id = UUID()
        var kind = "other"
        var title = ""
        var hasGiven = false
        var dateGiven = Date()
        var hasDue = false
        var nextDue = Date()
        var notes = ""
        var isTotalRow = false
    }

    private enum Stage {
        case pick, reading, review, fallback, sent, saved
    }

    @State private var stage: Stage = .pick
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var read: ReceiptRead?
    @State private var rows: [DraftRow] = []
    @State private var saveVet = true
    @State private var note = ""
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch stage {
                    case .pick: pickCard
                    case .reading: readingCard
                    case .review: reviewCard
                    case .fallback: fallbackCard
                    case .sent: doneCard("Sent to Mary 💚 She'll take a look.")
                    case .saved: doneCard("Saved to your account ✓")
                    }
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(Theme.page)
            .navigationTitle("Read a receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(stage == .saved || stage == .sent ? "Done" : "Never mind") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { newItem in
                guard let newItem else { return }
                Task { await loadAndRead(newItem) }
            }
        }
    }

    // MARK: - Cards

    private var pickCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📸 Snap a vet receipt")
                .font(.headline)
            Text("Take a photo of \(pet.name)'s vet receipt or pick one from your photos. I'll read the shots, medicines and dates off it — then you check it over before anything is saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Text("Pick the receipt photo")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.green, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .card()
    }

    private var readingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading your receipt…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("📸 Here's what I read — check it over")
                .font(.headline)
            if let rd = read {
                if let readName = rd.petName, !readName.isEmpty,
                   Self.nameKey(readName) != Self.nameKey(pet.name) {
                    Text("This receipt looks like it's for \(readName) — you're filing it under \(pet.name).")
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amberSoft, in: RoundedRectangle(cornerRadius: 12))
                }
                if rd.unsureHas(["pet_name"]) {
                    Text("⚠ check this one — the pet's name on the paper wasn't clear.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !vetFill.isEmpty {
                    Toggle(isOn: $saveVet) {
                        Text("Also save the vet on \(pet.name)'s page: \(vetBits)")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    if rd.unsureHas(["vet_clinic", "vet_name", "vet_phone"]) {
                        Text("⚠ check this one — the vet part of the paper wasn't clear.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach($rows) { $row in
                draftRowCard($row)
            }
            Button {
                Task { await saveReview() }
            } label: {
                HStack {
                    if isWorking { ProgressView() }
                    Text("Save these records")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isWorking)
            Button("Photo still doesn't look right? Send it to Mary") {
                stage = .fallback
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .card()
    }

    private func draftRowCard(_ row: Binding<DraftRow>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("What kind?", selection: row.kind) {
                Text("💉 Vaccination").tag("vaccination")
                Text("💊 Medicine").tag("medicine")
                Text("📝 Other").tag("other")
            }
            .pickerStyle(.segmented)
            TextField("Name", text: row.title)
                .textFieldStyle(.roundedBorder)
            Toggle("Date given", isOn: row.hasGiven)
                .font(.subheadline)
            if row.hasGiven.wrappedValue {
                DatePicker("Date given", selection: row.dateGiven, displayedComponents: .date)
                    .font(.subheadline)
            }
            Toggle("Next due", isOn: row.hasDue)
                .font(.subheadline)
            if row.hasDue.wrappedValue {
                DatePicker("Next due", selection: row.nextDue, displayedComponents: .date)
                    .font(.subheadline)
            }
            if !row.notes.wrappedValue.isEmpty {
                Text(row.notes.wrappedValue)
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let rd = read, rd.unsureHas(["items", "title", "date_given", "next_due"]) {
                Text("⚠ check this one")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Take this one off", role: .destructive) {
                rows.removeAll { $0.id == row.wrappedValue.id }
            }
            .font(.subheadline)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I couldn't read that one clearly.")
                .font(.headline)
            Text("That happens with crumpled or faded receipts — it's not you. Send the photo to Mary and she'll read it with her own eyes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("A note for Mary (only if you want)", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
            if photoData == nil {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Text("Pick the photo first")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Theme.greenDark)
                }
            }
            Button {
                Task { await sendToMary() }
            } label: {
                HStack {
                    if isWorking { ProgressView() }
                    Text("📩 Send this photo to Mary")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isWorking || photoData == nil)
        }
        .card()
    }

    private func doneCard(_ words: String) -> some View {
        VStack(spacing: 10) {
            Text("🐾").font(.largeTitle)
            Text(words).font(.headline).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: - The vet fill (the web's receiptVetFill)

    /// The vet fields from the read that this pet is still
    /// missing. A filled field is never overwritten.
    private var vetFill: [String: Any] {
        guard let rd = read else { return [:] }
        var fill: [String: Any] = [:]
        if let v = rd.vetClinic, !v.isEmpty, (pet.vetClinic ?? "").isEmpty { fill["vet_clinic"] = v }
        if let v = rd.vetName, !v.isEmpty, (pet.vetName ?? "").isEmpty { fill["vet_name"] = v }
        if let v = rd.vetPhone, !v.isEmpty, (pet.vetPhone ?? "").isEmpty { fill["vet_phone"] = v }
        return fill
    }

    private var vetBits: String {
        guard let rd = read else { return "" }
        return [vetFill["vet_clinic"] as? String ?? rd.vetClinic,
                vetFill["vet_phone"] as? String ?? rd.vetPhone]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// The web's receiptNameKey(): lowercase, punctuation to
    /// spaces, runs of spaces collapsed, trimmed.
    private static func nameKey(_ s: String) -> String {
        let lowered = s.lowercased()
        let spaced = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    // MARK: - Work

    private func loadAndRead(_ item: PhotosPickerItem) async {
        stage = .reading
        message = nil
        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let prepared = Self.preparedJPEG(from: raw) else {
                stage = .fallback
                return
            }
            photoData = prepared
            guard let token = await session.validAccessToken() else {
                message = "Your sign-in expired. Please sign out and sign in again."
                stage = .pick
                return
            }
            let rd = try await ReceiptService.readReceipt(accessToken: token, imageData: prepared, mimeType: "image/jpeg")
            if rd.isEmpty {
                stage = .fallback
                return
            }
            read = rd
            rows = Self.draftRows(from: rd)
            saveVet = true
            stage = .review
        } catch {
            // The web treats a failed read the same as an empty
            // one: the fallback card, never a dead end.
            stage = .fallback
        }
    }

    private static func draftRows(from rd: ReceiptRead) -> [DraftRow] {
        var out: [DraftRow] = (rd.items ?? []).map { item in
            var row = DraftRow()
            row.kind = item.kind ?? "other"
            row.title = item.title ?? ""
            if let day = Record.parseDay(item.dateGiven) {
                row.hasGiven = true
                row.dateGiven = day
            }
            if let day = Record.parseDay(item.nextDue) {
                row.hasDue = true
                row.nextDue = day
            }
            return row
        }
        if let total = rd.total, !total.isEmpty {
            var row = DraftRow()
            row.kind = "other"
            row.title = "Vet visit total"
            row.notes = "$" + total
            row.isTotalRow = true
            out.append(row)
        }
        return out
    }

    private func saveReview() async {
        guard let ownerId = session.currentUserID,
              let token = await session.validAccessToken() else {
            message = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        let recordRows: [[String: Any]] = rows.compactMap { row in
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return RecordsService.recordRow(
                ownerId: ownerId, petId: pet.id, kind: row.kind, title: title,
                dateGiven: row.hasGiven ? Record.isoString(row.dateGiven) : nil,
                nextDue: row.hasDue ? Record.isoString(row.nextDue) : nil,
                notes: row.notes)
        }
        isWorking = true
        defer { isWorking = false }
        do {
            if saveVet && !vetFill.isEmpty {
                try await PetsService.patchPetFields(accessToken: token, petId: pet.id, fields: vetFill)
            }
            try await RecordsService.insertRecords(accessToken: token, rows: recordRows)
            onSaved()
            stage = .saved
        } catch {
            message = "Those records didn't save. They're still written above — try again in a moment."
        }
    }

    private func sendToMary() async {
        guard let photoData,
              let userId = session.currentUserID,
              let token = await session.validAccessToken() else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await ReceiptService.sendPhotoToMary(
                accessToken: token, userId: userId, userEmail: session.currentEmail,
                petName: pet.name, note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                imageData: photoData)
            stage = .sent
        } catch {
            message = "That didn't send. Your photo is still right here — try again in a moment."
        }
    }

    /// Downscale to a receipt-sized JPEG, the native twin of the
    /// web's receiptPrepPhoto(): long edge capped, quality 0.8.
    private static func preparedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxEdge: CGFloat = 1600
        let longEdge = max(image.size.width, image.size.height)
        var drawImage = image
        if longEdge > maxEdge {
            let scale = maxEdge / longEdge
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            drawImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        return drawImage.jpegData(compressionQuality: 0.8)
    }
}

/// The web app's card: white, rounded, a hairline border.
private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

private extension View {
    func card() -> some View { modifier(CardModifier()) }
}

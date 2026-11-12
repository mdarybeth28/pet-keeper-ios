import Foundation

/// One receipt read, exactly as the read-receipt function answers
/// (its contract is written at the top of its index.ts):
/// { pet_name, species, vet_clinic, vet_name, vet_phone,
///   items: [{kind, title, date_given, next_due}],
///   total, unsure[], cached }.
struct ReceiptRead: Decodable {
    struct Item: Decodable {
        let kind: String?
        let title: String?
        let dateGiven: String?
        let nextDue: String?

        enum CodingKeys: String, CodingKey {
            case kind, title
            case dateGiven = "date_given"
            case nextDue = "next_due"
        }
    }

    let petName: String?
    let species: String?
    let vetClinic: String?
    let vetName: String?
    let vetPhone: String?
    let items: [Item]?
    let total: String?
    let unsure: [String]?
    let cached: Bool?

    enum CodingKeys: String, CodingKey {
        case petName = "pet_name"
        case species
        case vetClinic = "vet_clinic"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
        case items, total, unsure, cached
    }

    /// The web app's receiptReadIsEmpty(): nothing read at all —
    /// no items, no vet, no total — means the fallback card.
    var isEmpty: Bool {
        (items ?? []).isEmpty
            && (vetClinic ?? "").isEmpty
            && (vetName ?? "").isEmpty
            && (vetPhone ?? "").isEmpty
            && (total ?? "").isEmpty
    }

    func unsureHas(_ names: [String]) -> Bool {
        let u = unsure ?? []
        return names.contains { u.contains($0) }
    }
}

/// The doors behind the 📸 button and the settings screen: the
/// receipt reader itself, the send-this-photo-to-Mary fallback,
/// and the plain function invokes (send-feedback, delete-account).
/// All of them are the web app's own Edge Functions, called the
/// same way the web calls them.
enum ReceiptService {
    /// POST one function and hand back its JSON. Throws with the
    /// function's own plain-words error when it sends one.
    static func invoke(accessToken: String, function: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: SupabaseConfig.functionURL(function))
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw PetsService.serviceError(data: data, status: status, fallback: "That didn't go through (HTTP \(status)).")
        }
        return data
    }

    /// Read one receipt photo. The photo goes as base64 JSON —
    /// the function's exact contract — and is never stored.
    static func readReceipt(accessToken: String, imageData: Data, mimeType: String) async throws -> ReceiptRead {
        let data = try await invoke(accessToken: accessToken, function: "read-receipt", body: [
            "image_base64": imageData.base64EncodedString(),
            "mime_type": mimeType,
        ])
        return try JSONDecoder().decode(ReceiptRead.self, from: data)
    }

    /// The send-it-to-Mary chain, step for step the web's
    /// sendReceiptToMary(): upload the photo to the private
    /// help-photos bucket under the sender's own folder, leave the
    /// help_photos row, then ring send-help-photo to email Mary.
    static func sendPhotoToMary(accessToken: String, userId: String, userEmail: String?,
                                petName: String, note: String, imageData: Data) async throws {
        let path = "\(userId)/\(Int(Date().timeIntervalSince1970 * 1000)).jpg"

        var upload = URLRequest(url: SupabaseConfig.storageObjectURL(bucket: "help-photos", path: path))
        upload.httpMethod = "POST"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            upload.setValue(value, forHTTPHeaderField: key)
        }
        upload.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        upload.httpBody = imageData
        let (upData, upResponse) = try await URLSession.shared.data(for: upload)
        let upStatus = (upResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard upStatus == 200 else {
            throw PetsService.serviceError(data: upData, status: upStatus, fallback: "That photo didn't send (HTTP \(upStatus)).")
        }

        var insert = URLRequest(url: SupabaseConfig.restURL("help_photos"))
        insert.httpMethod = "POST"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            insert.setValue(value, forHTTPHeaderField: key)
        }
        insert.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        insert.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": userId,
            "user_email": userEmail ?? NSNull(),
            "pet_name": petName,
            "note": note.isEmpty ? NSNull() : note,
            "photo_path": path,
        ])
        let (inData, inResponse) = try await URLSession.shared.data(for: insert)
        let inStatus = (inResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard inStatus == 201 else {
            throw PetsService.serviceError(data: inData, status: inStatus, fallback: "That photo didn't send (HTTP \(inStatus)).")
        }

        _ = try await invoke(accessToken: accessToken, function: "send-help-photo", body: [
            "photo_path": path,
            "pet_name": petName,
            "note": note,
            "user_email": userEmail ?? "",
        ])
    }
}

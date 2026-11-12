import Foundation

/// Reads from the live `pets` table through Supabase's REST door,
/// with the signed-in user's access token. Row-level security does
/// the rest: this request can only ever return the caller's own pets.
enum PetsService {
    static func fetchPets(accessToken: String) async throws -> [Pet] {
        var components = URLComponents(url: SupabaseConfig.restURL("pets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "name.asc"),
        ]
        var request = URLRequest(url: components.url!)
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(SessionStore.ErrorResponse.self, from: data))?.bestMessage
            throw NSError(domain: "PetKeeperPets", code: status, userInfo: [
                NSLocalizedDescriptionKey: message ?? "Could not load pets (HTTP \(status)).",
            ])
        }
        return try JSONDecoder().decode([Pet].self, from: data)
    }
}

/// The write half of the pets door — the same rows the web app's
/// savePet() builds: every field, trimmed, empty strings as null,
/// updated_at stamped on both insert and update. Deletes mirror
/// the web's deletePet() (the database cascades the pet's records).
extension PetsService {
    /// The row both the insert and the update send — one shape,
    /// so the two can never drift apart.
    static func petRow(ownerId: String, name: String, species: String,
                       breed: String, birthday: String?, weight: String,
                       vetClinic: String, vetName: String, vetPhone: String,
                       food: String, allergies: String, notes: String) -> [String: Any] {
        func orNull(_ s: String) -> Any {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? NSNull() : t
        }
        return [
            "owner_id": ownerId,
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "species": species,
            "breed": orNull(breed),
            "birthday": birthday ?? NSNull(),
            "weight": orNull(weight),
            "vet_clinic": orNull(vetClinic),
            "vet_name": orNull(vetName),
            "vet_phone": orNull(vetPhone),
            "food": orNull(food),
            "allergies": orNull(allergies),
            "notes": orNull(notes),
            "updated_at": ISO8601DateFormatter().string(from: Date()),
        ]
    }

    static func createPet(accessToken: String, row: [String: Any]) async throws -> Pet {
        var request = URLRequest(url: SupabaseConfig.restURL("pets"))
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: row)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 201, let created = try? JSONDecoder().decode([Pet].self, from: data), let pet = created.first else {
            throw serviceError(data: data, status: status, fallback: "That pet didn't save (HTTP \(status)).")
        }
        return pet
    }

    static func updatePet(accessToken: String, petId: String, row: [String: Any]) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL("pets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(petId)")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PATCH"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: row)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 204 else {
            throw serviceError(data: data, status: status, fallback: "Those changes didn't save (HTTP \(status)).")
        }
    }

    static func deletePet(accessToken: String, petId: String) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL("pets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(petId)")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 204 else {
            throw serviceError(data: data, status: status, fallback: "That pet couldn't be removed (HTTP \(status)).")
        }
    }

    /// A small patch of only the given fields — the receipt
    /// reader's vet-fill uses it (it fills fields that are empty
    /// and never overwrites one that has words).
    static func patchPetFields(accessToken: String, petId: String, fields: [String: Any]) async throws {
        var patch = fields
        patch["updated_at"] = ISO8601DateFormatter().string(from: Date())
        try await updatePet(accessToken: accessToken, petId: petId, row: patch)
    }

    static func serviceError(data: Data, status: Int, fallback: String) -> NSError {
        let message = (try? JSONDecoder().decode(SessionStore.ErrorResponse.self, from: data))?.bestMessage
        return NSError(domain: "PetKeeperPets", code: status, userInfo: [
            NSLocalizedDescriptionKey: message ?? fallback,
        ])
    }
}

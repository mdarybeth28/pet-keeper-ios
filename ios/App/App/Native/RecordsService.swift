import Foundation

/// Reads from the live `records` table through Supabase's REST door,
/// with the signed-in user's access token — the same pattern as
/// PetsService, and row-level security does the protecting.
///
/// The ordering mirrors the web app's `loadAll()` exactly:
/// `sb.from("records").select("*").order("next_due", {ascending:true,
/// nullsFirst:false})` — PostgREST spells that `next_due.asc.nullslast`.
enum RecordsService {
    /// Every record on the signed-in account, soonest due first,
    /// records with no due date last.
    static func fetchRecords(accessToken: String) async throws -> [Record] {
        try await fetch(accessToken: accessToken, petId: nil)
    }

    /// One pet's records, same ordering.
    static func fetchRecords(accessToken: String, petId: String) async throws -> [Record] {
        try await fetch(accessToken: accessToken, petId: petId)
    }

    private static func fetch(accessToken: String, petId: String?) async throws -> [Record] {
        var components = URLComponents(url: SupabaseConfig.restURL("records"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "next_due.asc.nullslast"),
        ]
        if let petId {
            queryItems.append(URLQueryItem(name: "pet_id", value: "eq.\(petId)"))
        }
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(SessionStore.ErrorResponse.self, from: data))?.bestMessage
            throw NSError(domain: "PetKeeperRecords", code: status, userInfo: [
                NSLocalizedDescriptionKey: message ?? "Could not load records (HTTP \(status)).",
            ])
        }
        return try JSONDecoder().decode([Record].self, from: data)
    }
}

/// The write half of the records door — the same rows the web
/// app's saveRecord() builds, the receipt review's bulk insert,
/// and deleteRecord(). Records carry no timestamps (the web app
/// never sets one), so none are sent.
extension RecordsService {
    /// The row both the insert and the update send.
    static func recordRow(ownerId: String, petId: String, kind: String,
                          title: String, dateGiven: String?, nextDue: String?,
                          notes: String) -> [String: Any] {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "owner_id": ownerId,
            "pet_id": petId,
            "kind": kind,
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "date_given": dateGiven ?? NSNull(),
            "next_due": nextDue ?? NSNull(),
            "notes": trimmedNotes.isEmpty ? NSNull() : trimmedNotes,
        ]
    }

    static func createRecord(accessToken: String, row: [String: Any]) async throws {
        try await insertRecords(accessToken: accessToken, rows: [row])
    }

    /// Insert several rows at once — the receipt review saves all
    /// its kept rows in one call, like the web app does.
    static func insertRecords(accessToken: String, rows: [[String: Any]]) async throws {
        guard !rows.isEmpty else { return }
        var request = URLRequest(url: SupabaseConfig.restURL("records"))
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: rows)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 201 else {
            throw PetsService.serviceError(data: data, status: status, fallback: "Those records didn't save (HTTP \(status)).")
        }
    }

    static func updateRecord(accessToken: String, recordId: String, row: [String: Any]) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL("records"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(recordId)")]
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
            throw PetsService.serviceError(data: data, status: status, fallback: "Those changes didn't save (HTTP \(status)).")
        }
    }

    static func deleteRecord(accessToken: String, recordId: String) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL("records"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(recordId)")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 204 else {
            throw PetsService.serviceError(data: data, status: status, fallback: "That record couldn't be removed (HTTP \(status)).")
        }
    }
}

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

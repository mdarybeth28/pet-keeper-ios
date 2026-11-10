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

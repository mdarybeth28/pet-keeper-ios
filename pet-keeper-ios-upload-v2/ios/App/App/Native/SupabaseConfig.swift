import Foundation

/// Connection facts for Pet Keeper's own Supabase project — the same
/// project the web app at yourpetkeeper.com talks to. The publishable
/// key is a PUBLIC client key (it ships in the web page source today);
/// it is not a secret. Row-level security on the database is what
/// actually protects each person's rows: a signed-out request can
/// read nothing, and a signed-in request can only read its own rows.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://iuaibtdrcoxcrgihzfmi.supabase.co")!
    static let publishableKey = "sb_publishable_O8GS4YTIuK3tEkkmdGoF_Q_EASb1cJh"

    static var authTokenURL: URL {
        projectURL.appendingPathComponent("auth/v1/token")
    }

    static var logoutURL: URL {
        projectURL.appendingPathComponent("auth/v1/logout")
    }

    static func restURL(_ path: String) -> URL {
        projectURL.appendingPathComponent("rest/v1/\(path)")
    }

    /// Headers every Supabase REST/Auth call needs.
    static func baseHeaders(accessToken: String? = nil) -> [String: String] {
        var headers = [
            "apikey": publishableKey,
            "Content-Type": "application/json",
        ]
        if let accessToken {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        return headers
    }
}

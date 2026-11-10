import Foundation

/// The approval gate, natively — the SAME one question the web app
/// asks after sign-in (v4.3 web app, resolveGate()):
///
///   RPC current_email_is_approved -> is this email approved?
///
/// Owners are always in. Everyone else is in only when their email
/// sits in approved_emails — the row the Stripe webhook writes when
/// a web payment lands, and the row the Apple IAP bridge
/// (phase3-prep/apple-iap-bridge) will write when an Apple payment
/// lands. This service NEVER grants access from anything that
/// happened on the device: not a tapped button, not a StoreKit
/// entitlement. It only ever reports what the backend says, which
/// is the web app's rule carried over unchanged.
///
/// Failure shape mirrors the web app too: if the RPC itself errors
/// (the one-paste gate setup has not been run), the gate fails OPEN
/// to the old behaviour and flags it, so a half-finished setup can
/// never lock anybody out. The flag is surfaced on the paywall/More
/// surfaces via `setupMissing`, exactly as the web Office shows it.
enum ApprovalService {
    enum GateResult {
        case approved
        case waiting
        /// RPC missing/errored — web behaviour: fail open.
        case openSetupMissing
    }

    static func checkGate(accessToken: String, email: String?) async -> GateResult {
        if StoreConfig.isOwner(email: email) { return .approved }

        var request = URLRequest(url: SupabaseConfig.restURL("rpc/current_email_is_approved"))
        request.httpMethod = "POST"
        for (key, value) in SupabaseConfig.baseHeaders(accessToken: accessToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = Data("{}".utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return .openSetupMissing }
            // PostgREST returns a bare JSON boolean for this RPC.
            let text = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text == "true" { return .approved }
            if text == "false" { return .waiting }
            return .openSetupMissing
        } catch {
            return .openSetupMissing
        }
    }
}

/// Observable holder for the gate result, owned by RootTabView.
/// Rechecked: on sign-in, after a purchase finishes, after a
/// restore, and whenever the paywall's "Check again" is tapped.
/// Between checks the last known result stands — the app never
/// upgrades a `waiting` to `approved` on its own word.
@MainActor
final class ApprovalStore: ObservableObject {
    enum State: Equatable {
        case unknown
        case checking
        case approved
        case waiting
        /// Fail-open (gate setup missing), like the web app.
        case openSetupMissing
    }

    @Published private(set) var state: State = .unknown

    var isWaiting: Bool { state == .waiting }
    var mayEnter: Bool { state == .approved || state == .openSetupMissing }

    func reset() { state = .unknown }

    /// One backend question. Returns the resulting state so callers
    /// (the paywall's post-purchase poll) can loop on it.
    @discardableResult
    func check(session: SessionStore) async -> State {
        guard session.isSignedIn, let token = await session.validAccessToken() else {
            state = .unknown
            return state
        }
        state = .checking
        switch await ApprovalService.checkGate(accessToken: token, email: session.currentEmail) {
        case .approved: state = .approved
        case .waiting: state = .waiting
        case .openSetupMissing: state = .openSetupMissing
        }
        return state
    }

    /// Post-purchase / post-restore polling. Apple's server
    /// notification reaches the bridge asynchronously — a purchase
    /// can be fully paid seconds before the approved_emails row
    /// lands. Poll the BACKEND (never the local entitlement) a few
    /// times, then stop and let the paywall say honestly that the
    /// confirmation is still on its way.
    @discardableResult
    func checkUntilApproved(session: SessionStore, attempts: Int = 6, delaySeconds: UInt64 = 5) async -> State {
        for attempt in 0..<attempts {
            let result = await check(session: session)
            if result != .waiting { return result }
            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
        return state
    }
}

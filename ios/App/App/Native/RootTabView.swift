import SwiftUI
import UIKit

/// The app's front door: a native tab bar, behind the approval
/// gate.
/// - Signed out / restoring: the tabs themselves show the sign-in
///   form (Pets/Due soon handle it), exactly as Phases 1–2 built.
/// - Signed in: the gate asks the backend ONE question first (the
///   web app's resolveGate(), via ApprovalStore). Approved (or the
///   web's fail-open setup-missing case) -> the tabs. Waiting ->
///   the native paywall (PaywallView) instead of the tabs, so no
///   pets/records queries fire for an unapproved account — the
///   web app's rule, carried over.
/// - Pets: native, reads the real account data (Phase 1 proof,
///   pet detail + records added in Phase 2).
/// - Due soon: native, real due list since Phase 2.
/// - More: native settings rows (the app lock) above the scoped web
///   tab (bundled local screens live there).
///
/// Phase 2 also wires the optional app lock here: a lock overlay
/// sits over the tabs whenever AppLockManager says so, and app
/// background/foreground transitions feed its grace-period rule.
/// The lifecycle is observed through UIApplication notifications
/// (not SwiftUI's scenePhase) because this app's window is built by
/// the AppDelegate, not by a SwiftUI scene.
///
/// Native is the primary experience on purpose — that is the whole
/// shape of Option A in the build plan, and what keeps this an app
/// rather than a website in a wrapper (Guideline 4.2).
struct RootTabView: View {
    @StateObject private var session = SessionStore()
    @StateObject private var appLock = AppLockManager()
    @StateObject private var approval = ApprovalStore()
    @StateObject private var subscriptions = SubscriptionStore()

    var body: some View {
        ZStack {
            gateContent
            if appLock.isLocked {
                LockView()
            }
        }
        .environmentObject(session)
        .environmentObject(appLock)
        .environmentObject(approval)
        .environmentObject(subscriptions)
        .task {
            await session.restore()
        }
        .task(id: session.state) {
            // The gate is asked on sign-in, and stood down on
            // sign-out. Purchases/restores re-ask it themselves
            // (see PaywallView).
            if session.state == .signedIn {
                subscriptions.start()
                await approval.check(session: session)
            } else if session.state == .signedOut {
                approval.reset()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            appLock.appDidEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            appLock.appBecameActive()
            if appLock.isLocked {
                Task { await appLock.authenticate() }
            }
        }
    }

    @ViewBuilder
    private var gateContent: some View {
        if session.state == .signedIn && approval.state == .waiting {
            PaywallView()
        } else if session.state == .signedIn
                    && (approval.state == .unknown || approval.state == .checking) {
            // One moment while the backend answers the gate
            // question; the tabs appear as soon as it does.
            ProgressView("Checking your account…")
        } else {
            TabView {
                PetsView()
                    .tabItem { Label("Pets", systemImage: "pawprint.fill") }
                DueSoonView()
                    .tabItem { Label("Due soon", systemImage: "calendar.badge.clock") }
                MoreView()
                    .tabItem { Label("More", systemImage: "square.grid.2x2") }
            }
        }
    }
}

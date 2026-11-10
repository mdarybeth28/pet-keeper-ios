import SwiftUI
import UIKit

/// The app's front door: a native tab bar.
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

    var body: some View {
        ZStack {
            TabView {
                PetsView()
                    .tabItem { Label("Pets", systemImage: "pawprint.fill") }
                DueSoonView()
                    .tabItem { Label("Due soon", systemImage: "calendar.badge.clock") }
                MoreView()
                    .tabItem { Label("More", systemImage: "square.grid.2x2") }
            }
            if appLock.isLocked {
                LockView()
            }
        }
        .environmentObject(session)
        .environmentObject(appLock)
        .task {
            await session.restore()
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
}

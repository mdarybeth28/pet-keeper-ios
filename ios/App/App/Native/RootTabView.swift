import SwiftUI

/// The app's front door: a native tab bar.
/// - Pets: native, reads the real account data (the Phase 1 proof).
/// - Due soon: native, honest empty state until Phase 2.
/// - More: the scoped web tab (bundled local screens live here).
///
/// Native is the primary experience on purpose — that is the whole
/// shape of Option A in the build plan, and what keeps this an app
/// rather than a website in a wrapper (Guideline 4.2).
struct RootTabView: View {
    @StateObject private var session = SessionStore()

    var body: some View {
        TabView {
            PetsView()
                .tabItem { Label("Pets", systemImage: "pawprint.fill") }
            DueSoonView()
                .tabItem { Label("Due soon", systemImage: "calendar.badge.clock") }
            WebTabView()
                .tabItem { Label("More", systemImage: "square.grid.2x2") }
        }
        .environmentObject(session)
        .task {
            await session.restore()
        }
    }
}

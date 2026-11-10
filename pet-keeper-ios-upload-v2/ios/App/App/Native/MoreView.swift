import SwiftUI

/// The More tab: a native settings section on top, the scoped web
/// home below. The web view keeps its role exactly as Phase 1 built
/// it (bundled local screens, no remote loading — see WebTabView);
/// Phase 2 adds the app-lock row the plan calls for, natively,
/// because Face ID is a native feature and its switch belongs here.
struct MoreView: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("App lock")
                    .font(.headline)
                Toggle(isOn: Binding(
                    get: { appLock.isEnabled },
                    set: { appLock.setEnabled($0) }
                )) {
                    Text("Lock with Face ID / passcode")
                        .font(.subheadline)
                }
                .disabled(!appLock.canUseDeviceAuth)
                Text(appLock.canUseDeviceAuth
                     ? "When this is on, Pet Keeper asks for Face ID (or this phone's passcode) when you open it, and again if you've been away a few minutes. It's off unless you turn it on."
                     : "This phone has no Face ID or passcode set up, so the app lock can't be turned on here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))

            Divider()

            WebTabView()
        }
    }
}

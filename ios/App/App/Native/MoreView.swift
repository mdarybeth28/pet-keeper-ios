import SwiftUI

/// The More tab: native account + settings rows on top, the
/// scoped web home below. The web view keeps its role exactly as
/// Phase 1 built it (bundled local screens, no remote loading —
/// see WebTabView); the app-lock row lives here because Face ID
/// is a native feature. The parity round added the web app's
/// settings doors natively: Tell Mary (feedback) and delete
/// account, so nobody has to leave the app for either.
struct MoreView: View {
    @EnvironmentObject private var appLock: AppLockManager
    @EnvironmentObject private var session: SessionStore
    @State private var showFeedback = false
    @State private var showDeleteAccount = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                if let email = session.currentEmail {
                    Text("Signed in as \(email)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                Divider()

                Button {
                    showFeedback = true
                } label: {
                    Label("Tell Mary something", systemImage: "envelope.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Theme.greenDark)
                }

                Button(role: .destructive) {
                    showDeleteAccount = true
                } label: {
                    Label("Delete my account", systemImage: "trash")
                        .font(.subheadline)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.page)

            Divider()

            WebTabView()
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView()
                .environmentObject(session)
        }
    }
}

/// Delete account — the web app's careful flow: read the
/// warning, type your own email to prove it's really you, then
/// the delete-account function does the rest and the app signs
/// out to the front door.
struct DeleteAccountView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var typedEmail = ""
    @State private var error: String?
    @State private var isWorking = false

    private var emailMatches: Bool {
        guard let mine = session.currentEmail else { return false }
        return typedEmail.trimmingCharacters(in: .whitespaces).lowercased() == mine.lowercased()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This removes your account and every pet and record in it, for good. It can't be undone.")
                        .font(.subheadline)
                    Text("If you have a subscription, cancel it too in the App Store — deleting the account doesn't stop a subscription by itself.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section(header: Text("Type your email to confirm")) {
                    TextField("Email", text: $typedEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.subheadline)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await deleteAccount() }
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking { ProgressView() }
                            Text("Delete my account for good")
                            Spacer()
                        }
                    }
                    .disabled(!emailMatches || isWorking)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep my account") { dismiss() }
                }
            }
        }
    }

    private func deleteAccount() async {
        guard let token = await session.validAccessToken() else {
            error = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await ReceiptService.invoke(accessToken: token, function: "delete-account", body: [:])
            await session.signOut()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

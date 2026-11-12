import SwiftUI

/// The tell-Mary door from the settings screen — the web app's
/// feedback card: one message box, sent through the same
/// send-feedback function the web uses.
struct FeedbackView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var error: String?
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Questions, ideas, something not working? Write it here — it goes straight to Mary.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    TextField("Your message", text: $message, axis: .vertical)
                        .lineLimit(4...8)
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.subheadline)
                    }
                }
                if sent {
                    Section {
                        Text("Sent ✓ Thank you!")
                            .foregroundStyle(Theme.greenDark)
                            .font(.subheadline)
                    }
                }
                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSending { ProgressView() }
                            Text("Send").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.page)
            .navigationTitle("Tell Mary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    private func send() async {
        guard let token = await session.validAccessToken() else {
            error = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await ReceiptService.invoke(accessToken: token, function: "send-feedback", body: [
                "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
                "user_email": session.currentEmail ?? "",
            ])
            sent = true
            message = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}

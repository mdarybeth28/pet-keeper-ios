import SwiftUI

/// The front door — the same two doors the web app opens with:
/// sign in, or create an account, plus the forgot-password email.
/// Shows the server's own error words when something fails; never
/// invents a reason.
struct SignInView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var note: String?

    enum Mode { case signIn, create }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Text("🐾")
                        .font(.system(size: 44))
                    Text("Pet Keeper")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(Theme.greenDark)
                    Text(mode == .signIn
                         ? "Sign in with the same email and password you use on yourpetkeeper.com."
                         : "Make your account — then every pet's shots, visits and records live in one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("I want to", selection: $mode) {
                    Text("Sign in").tag(Mode.signIn)
                    Text("Create account").tag(Mode.create)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section(header: Text(mode == .signIn ? "Your account" : "Your new account")) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
            }

            if let error = session.lastError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
            if let note {
                Section {
                    Text(note)
                        .foregroundStyle(Theme.greenDark)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    isWorking = true
                    note = nil
                    Task {
                        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
                        let pw = password
                        if mode == .signIn {
                            await session.signIn(email: cleanEmail, password: pw)
                        } else {
                            await session.signUp(email: cleanEmail, password: pw)
                        }
                        isWorking = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isWorking { ProgressView() }
                        Text(mode == .signIn ? "Sign in" : "Create my account")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(isWorking || email.isEmpty || password.isEmpty)
            }

            if mode == .signIn {
                Section {
                    Button("Forgot your password?") {
                        note = nil
                        Task {
                            let cleanEmail = email.trimmingCharacters(in: .whitespaces)
                            if await session.sendPasswordReset(email: cleanEmail) {
                                note = "Check your email — a reset link is on its way. It opens on the website, where you pick the new password."
                            }
                        }
                    }
                    .disabled(email.isEmpty)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.page)
    }
}

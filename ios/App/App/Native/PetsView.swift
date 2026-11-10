import SwiftUI

/// The Pets tab — the Phase 1 proof screen. Reads the REAL `pets`
/// table for the signed-in account and shows every state honestly:
/// restoring, signed out (the sign-in form), loading, error with the
/// server's words, genuinely empty, and the list itself. There is no
/// sample data anywhere in this screen.
struct PetsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var pets: [Pet] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Your pets")
                .toolbar {
                    if session.isSignedIn {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Sign out") {
                                Task { await session.signOut() }
                            }
                        }
                    }
                }
        }
        .task(id: session.state) {
            if session.state == .signedIn { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .restoring:
            ProgressView("One moment…")
        case .signedOut:
            SignInView()
        case .signedIn:
            if isLoading {
                ProgressView("Loading your pets…")
            } else if let loadError {
                VStack(spacing: 12) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text(loadError)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }
                }
                .padding()
            } else if pets.isEmpty {
                VStack(spacing: 10) {
                    Text("🐾").font(.largeTitle)
                    Text("No pets yet")
                        .font(.headline)
                    Text("Pets on your account will show up here. You can add pets in the web app today; adding them here arrives in a later phase.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(pets) { pet in
                    NavigationLink {
                        PetDetailView(pet: pet)
                    } label: {
                        HStack(spacing: 12) {
                            Text(pet.speciesEmoji).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.name).font(.headline)
                                Text(pet.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        guard let token = await session.validAccessToken() else {
            loadError = "Your sign-in expired. Please sign out and sign in again."
            return
        }
        do {
            pets = try await PetsService.fetchPets(accessToken: token)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

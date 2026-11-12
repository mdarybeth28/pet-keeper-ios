import SwiftUI

/// The Pets tab. Reads the REAL `pets` table for the signed-in
/// account and shows every state honestly: restoring, signed out
/// (the sign-in form), loading, error with the server's words,
/// genuinely empty — with the add-a-pet door right there — and
/// the list itself. There is no sample data anywhere in this
/// screen.
struct PetsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var pets: [Pet] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var showAddPet = false
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Your pets")
                .toolbar {
                    if session.isSignedIn {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showAddPet = true
                            } label: {
                                Label("Add a pet", systemImage: "plus.circle.fill")
                            }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Sign out") {
                                Task { await session.signOut() }
                            }
                        }
                    }
                }
        }
        .sheet(isPresented: $showAddPet) {
            PetFormView(existing: nil) { _ in
                Task { await load() }
            }
            .environmentObject(session)
        }
        .task(id: session.state) {
            if session.state == .signedIn { await load() }
        }
        .onAppear {
            // Coming back from a pet's page (where pets can be
            // added, edited, or removed) re-reads the list.
            if hasLoadedOnce && session.state == .signedIn {
                Task { await load() }
            }
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
            if isLoading && pets.isEmpty {
                ProgressView("Loading your pets…")
            } else if let loadError, pets.isEmpty {
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
                VStack(spacing: 12) {
                    Text("🐾").font(.system(size: 52))
                    Text("No pets yet")
                        .font(.headline)
                    Text("Add your first pet and every shot, visit and due date has a home.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Add a pet") { showAddPet = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 40)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.page)
            } else {
                List(pets) { pet in
                    NavigationLink {
                        PetDetailView(pet: pet)
                    } label: {
                        HStack(spacing: 12) {
                            Text(pet.speciesEmoji).font(.title)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.name).font(.headline)
                                Text(pet.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.page)
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
            hasLoadedOnce = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}

import SwiftUI

/// The Due Soon tab — the app's home due-list, native since Phase 2.
///
/// It mirrors the web app's home "coming due" strip exactly
/// (`renderHome()` + `dueInfo()` in the v4.3 web app):
/// - Records with a next_due that is overdue, due today, or due
///   within 30 days appear here; records due later than 30 days and
///   records with no due date do not (the web classes those "later"
///   and leaves them off the strip, on the pet's own page instead).
/// - Rows carry the web app's own pill words ("3 days overdue",
///   "Due today", "Due in 5 days"), soonest first.
/// - A genuinely empty list says so honestly — no sample dates,
///   ever.
///
/// Loading the full record list here is also what feeds the local
/// due-date reminders (DueNotificationScheduler): after every
/// successful load, this view hands the scheduler the account's
/// full records.
struct DueSoonView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var dueRecords: [Record] = []
    @State private var petNames: [String: String] = [:]
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Due soon")
        }
        .task(id: session.state) {
            if session.state == .signedIn {
                await load()
            } else if session.state == .signedOut {
                await DueNotificationScheduler.clearAll()
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
            if isLoading && !hasLoaded {
                ProgressView("Loading what's due…")
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
            } else if dueRecords.isEmpty {
                VStack(spacing: 10) {
                    Text("⏰").font(.largeTitle)
                    Text("Nothing due right now")
                        .font(.headline)
                    Text("Nothing is overdue, and nothing is due in the next 30 days. When a shot or medicine gets close, it will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    let overdue = dueRecords.filter { $0.dueBucket == .overdue || $0.dueBucket == .dueToday }
                    let comingUp = dueRecords.filter { $0.dueBucket == .soon }
                    if !overdue.isEmpty {
                        Section(header: Text("Overdue")) {
                            ForEach(overdue) { record in row(record) }
                        }
                    }
                    if !comingUp.isEmpty {
                        Section(header: Text("Due in the next 30 days")) {
                            ForEach(comingUp) { record in row(record) }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
    }

    private func row(_ record: Record) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.kindEmoji)
                Text(petNames[record.petId] ?? "Pet").fontWeight(.semibold)
                Text("— \(record.title)").font(.headline)
            }
            HStack(spacing: 8) {
                if let label = record.dueLabel {
                    Text(label)
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(record.dueBucket == .soon ? Color.orange.opacity(0.2) : Color.red.opacity(0.18),
                                    in: Capsule())
                }
                Text(Record.formatDay(record.nextDue))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
            async let petsTask = PetsService.fetchPets(accessToken: token)
            async let recordsTask = RecordsService.fetchRecords(accessToken: token)
            let pets = try await petsTask
            let allRecords = try await recordsTask
            petNames = Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0.name) })
            // The web app's strip rule: a dueInfo exists and its
            // class is not "later"; sorted by days-until-due.
            dueRecords = allRecords
                .filter { $0.dueBucket == .overdue || $0.dueBucket == .dueToday || $0.dueBucket == .soon }
                .sorted { ($0.daysUntilDue ?? Int.max) < ($1.daysUntilDue ?? Int.max) }
            hasLoaded = true
            // Full-list load: (re)schedule the local due reminders.
            // This is also the moment notification permission is
            // asked, the first time only — never at cold launch.
            await DueNotificationScheduler.reschedule(records: allRecords)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

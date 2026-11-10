import SwiftUI

/// The Due Soon tab. In the finished app this is the home due-list —
/// shots and medicines coming due, read from the `records` table's
/// `next_due` dates (that data already exists on the backend).
///
/// Phase 1 shows an honest empty state instead: this tab does not
/// read records yet, and it will not pretend otherwise with sample
/// dates. The real due list is Phase 2 work (build plan §3).
struct DueSoonView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("⏰").font(.largeTitle)
                Text("Nothing to show yet")
                    .font(.headline)
                Text("Your pets' upcoming shots and medicines will appear here in the next phase of the app. For now, your due dates live in the web app at yourpetkeeper.com.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Due soon")
        }
    }
}

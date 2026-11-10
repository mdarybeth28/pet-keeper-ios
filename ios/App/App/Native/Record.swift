import Foundation

/// One row of the live `records` table. Field names and types mirror
/// exactly what the web app writes today, verified 2026-11-10 against
/// the v4.3 web app's own row construction in TWO places that must
/// agree — and do:
///
///   - `saveRecord()` (record form): row = { owner_id, pet_id, kind,
///     title, date_given, next_due, notes }
///   - `saveReceiptReview()` (receipt reader): rows.push({ owner_id,
///     pet_id, kind, title, date_given, next_due, notes })
///
/// `id` is the row's primary key (the web app deletes/updates by
/// `.eq("id", …)` and renders rows with `data-rec = r.id`). Records
/// have NO `updated_at`/`created_at` in the web app's row
/// construction — unlike `pets`, record inserts never set one — so
/// none is modelled here. Nothing is invented beyond this evidence.
///
/// `kind` is "vaccination" / "medicine" / "other" in the web app
/// (the record form's segment; reads fall back to "other" when it is
/// missing), so it is optional here. `date_given` and `next_due` are
/// date strings ("yyyy-MM-dd") or null.
struct Record: Codable, Identifiable, Equatable {
    let id: String
    let ownerId: String?
    let petId: String
    let kind: String?
    let title: String
    let dateGiven: String?
    let nextDue: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case petId = "pet_id"
        case kind
        case title
        case dateGiven = "date_given"
        case nextDue = "next_due"
        case notes
    }

    var kindLabel: String {
        switch kind {
        case "vaccination": return "Vaccination"
        case "medicine": return "Medicine"
        default: return "Other"
        }
    }

    var kindEmoji: String {
        switch kind {
        case "vaccination": return "💉"
        case "medicine": return "💊"
        default: return "📝"
        }
    }

    // MARK: - Due semantics (a mirror of the web app's `dueInfo()`)

    /// Parses a "yyyy-MM-dd" date string the way the web app's
    /// `parseD()` does: first 10 characters, local calendar day.
    static func parseDay(_ string: String?) -> Date? {
        guard let string, string.count >= 10 else { return nil }
        let prefix = String(string.prefix(10))
        let parts = prefix.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }

    /// The parsed next-due day, or nil when the record has none.
    var dueDate: Date? { Self.parseDay(nextDue) }

    /// Whole days from today (local start of day) to the due day —
    /// the web app's `diffDays(todayStart(), d)`. Nil when the
    /// record has no next_due.
    var daysUntilDue: Int? {
        guard let dueDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        return Calendar.current.dateComponents([.day], from: today, to: due).day
    }

    /// The due bucket, mirroring the web app's `dueInfo()` classes:
    /// n < 0 → overdue; n == 0 → overdue ("Due today");
    /// 1...30 → soon; n > 30 → later; no next_due → none.
    enum DueBucket: Equatable {
        case none
        case overdue
        case dueToday
        case soon
        case later
    }

    var dueBucket: DueBucket {
        guard let n = daysUntilDue else { return .none }
        if n < 0 { return .overdue }
        if n == 0 { return .dueToday }
        if n <= 30 { return .soon }
        return .later
    }

    /// The pill words, character-for-character the web app's
    /// `dueInfo()` labels.
    var dueLabel: String? {
        guard let n = daysUntilDue else { return nil }
        if n < 0 { return n == -1 ? "1 day overdue" : "\(abs(n)) days overdue" }
        if n == 0 { return "Due today" }
        if n <= 30 { return n == 1 ? "Due tomorrow" : "Due in \(n) days" }
        return "Due \(Self.formatDay(nextDue))"
    }

    /// The web app's `fmtD()`: "Jan 5, 2027" style, or "" when the
    /// string does not parse.
    static func formatDay(_ string: String?) -> String {
        guard let date = parseDay(string) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

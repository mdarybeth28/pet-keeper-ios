import Foundation
import UserNotifications

/// Local due-date reminders — the plan's local-first cut (build plan
/// §3: "Local notifications (scheduled on-device from synced due
/// dates) are the cheaper first cut; remote push is the full
/// version"). No server, no device tokens, no APNs: the reminders are
/// scheduled on the phone from the records the app already read.
///
/// THE RULE (named constants, one place):
/// - One reminder per record that has a next_due today or later.
/// - It fires at 9:00 AM local on the due date
///   (`reminderHour` / `reminderMinute` below).
/// - Overdue records get no reminder — their date has passed; the
///   Due Soon tab is where overdue lives.
/// - Only REAL records schedule anything. Nothing is ever scheduled
///   from sample or placeholder data (there is none in this app).
///
/// Permission: asked once, after the first successful records load
/// (never at cold launch) — see `reschedule(records:)`, which the
/// Due Soon tab calls after loading. If permission is denied or
/// never granted, scheduling quietly does nothing; the app never
/// nags about it again.
enum DueNotificationScheduler {
    /// Every identifier this app schedules starts with this prefix,
    /// keyed by record id: "due-reminder-<record id>". Re-scheduling
    /// cancels pending requests with this prefix before re-adding,
    /// so it is idempotent — call it after every full records load.
    static let identifierPrefix = "due-reminder-"
    static let reminderHour = 9
    static let reminderMinute = 0

    private static let permissionAskedKey = "dueNotificationPermissionAskedV1"

    /// Cancel this app's pending due reminders and schedule fresh
    /// ones from the given records (the account's FULL record list —
    /// never a partial per-pet list, or other pets' reminders would
    /// be cancelled away).
    static func reschedule(records: [Record]) async {
        let center = UNUserNotificationCenter.current()

        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined,
           !UserDefaults.standard.bool(forKey: permissionAskedKey) {
            UserDefaults.standard.set(true, forKey: permissionAskedKey)
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            settings = await center.notificationSettings()
        }

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }

        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        for record in records {
            guard let dueDate = record.dueDate,
                  let days = record.daysUntilDue, days >= 0 else { continue }
            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            components.hour = reminderHour
            components.minute = reminderMinute
            guard let fireDate = Calendar.current.date(from: components),
                  fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Pet Keeper"
            content.body = days == 0
                ? "\(record.title) is due today."
                : "\(record.title) is coming due."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + record.id,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Remove every pending due reminder (used on sign-out, so one
    /// person's reminders never linger into the next account).
    static func clearAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }
}

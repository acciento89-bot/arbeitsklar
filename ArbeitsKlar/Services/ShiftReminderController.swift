import Foundation
import UserNotifications

@MainActor
final class ShiftReminderController {
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "arbeitsklar-shift-"
    private let plannedIdentifierPrefix = "arbeitsklar-planned-"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func schedule(for session: WorkSession, remainingWorkTime: TimeInterval) async {
        cancel(for: session.id)
        guard remainingWorkTime >= 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.notification.title")
        content.body = String(localized: "reminder.notification.body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: remainingWorkTime,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier(for: session.id),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancel(for sessionID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: sessionID)])
    }

    func schedule(for plannedShift: ScheduledShift) async -> Bool {
        cancelPlannedShift(id: plannedShift.id)
        guard let minutesBefore = plannedShift.reminderMinutesBefore else { return true }

        let fireDate = plannedShift.startsAt.addingTimeInterval(-TimeInterval(minutesBefore * 60))
        guard fireDate > .now else { return true }
        guard await requestAuthorization() else { return false }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "planner.reminder.title")
        content.body = String(localized: "planner.reminder.body")
        content.sound = .default

        let components = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let request = UNNotificationRequest(
            identifier: plannedIdentifier(for: plannedShift.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancelPlannedShift(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [plannedIdentifier(for: id)])
    }

    func cancelAll() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func identifier(for sessionID: UUID) -> String {
        identifierPrefix + sessionID.uuidString
    }

    private func plannedIdentifier(for shiftID: UUID) -> String {
        plannedIdentifierPrefix + shiftID.uuidString
    }
}

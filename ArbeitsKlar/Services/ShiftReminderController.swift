import Foundation
import UserNotifications

@MainActor
final class ShiftReminderController {
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "arbeitsklar-shift-"

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

    func cancelAll() async {
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func identifier(for sessionID: UUID) -> String {
        identifierPrefix + sessionID.uuidString
    }
}

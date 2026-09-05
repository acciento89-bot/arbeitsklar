import ActivityKit
import Foundation

@MainActor
final class LiveActivityController {
    private let isEnabled: Bool
    private var currentActivity: Activity<WorkActivityAttributes>?

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func start(for session: WorkSession) {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let existing = activity(for: session.id) {
            currentActivity = existing
            return
        }

        let attributes = WorkActivityAttributes(sessionID: session.id)
        let content = ActivityContent(
            state: contentState(for: session, asOf: session.startedAt, isRunning: true),
            staleDate: nil
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            currentActivity = nil
        }
    }

    func update(for session: WorkSession, asOf date: Date = .now) async {
        guard isEnabled else { return }
        guard let activity = activity(for: session.id) else { return }

        currentActivity = activity
        await activity.update(
            ActivityContent(
                state: contentState(for: session, asOf: date, isRunning: true),
                staleDate: date.addingTimeInterval(90)
            )
        )
    }

    func end(for session: WorkSession, at date: Date = .now) async {
        guard isEnabled else { return }
        guard let activity = activity(for: session.id) else { return }

        let finalContent = ActivityContent(
            state: contentState(for: session, asOf: date, isRunning: false),
            staleDate: nil
        )

        await activity.end(
            finalContent,
            dismissalPolicy: .after(date.addingTimeInterval(10 * 60))
        )
        currentActivity = nil
    }

    private func activity(for sessionID: UUID) -> Activity<WorkActivityAttributes>? {
        if currentActivity?.attributes.sessionID == sessionID {
            return currentActivity
        }

        return Activity<WorkActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
    }

    private func contentState(
        for session: WorkSession,
        asOf date: Date,
        isRunning: Bool
    ) -> WorkActivityAttributes.ContentState {
        WorkActivityAttributes.ContentState(
            startedAt: session.startedAt,
            timerReferenceDate: session.timerReferenceDate(asOf: date),
            updatedAt: date,
            elapsedSeconds: session.duration(asOf: date),
            earnedAmount: session.earnings(asOf: date),
            projectedEarnings: session.projectedEarningsForPlannedDuration(asOf: date),
            hourlyRate: session.hourlyRate,
            currencyCode: session.currencyCode,
            plannedWorkEndDate: session.timerReferenceDate(asOf: date)
                .addingTimeInterval(session.plannedHours * 3_600),
            isRunning: isRunning,
            isPaused: session.isPaused
        )
    }
}

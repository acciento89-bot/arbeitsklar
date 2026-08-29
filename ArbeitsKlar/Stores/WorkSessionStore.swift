import Foundation
import Observation

struct WorkPeriodSummary: Equatable {
    let sessionCount: Int
    let workDuration: TimeInterval
    let breakDuration: TimeInterval
    let overtimeDuration: TimeInterval
    let earnings: Double
    let currencyCode: String

    var isEmpty: Bool { sessionCount == 0 }
    var averageWorkDuration: TimeInterval {
        isEmpty ? 0 : workDuration / Double(sessionCount)
    }
    var averageEarnings: Double {
        isEmpty ? 0 : earnings / Double(sessionCount)
    }
}

@MainActor
@Observable
final class WorkSessionStore {
    private struct Snapshot: Codable {
        var profile: PayProfile
        var sessions: [WorkSession]
    }

    var profile: PayProfile {
        didSet { persist() }
    }

    private(set) var sessions: [WorkSession] {
        didSet { persist() }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let liveActivityController: LiveActivityController

    @ObservationIgnored
    private let reminderController: ShiftReminderController

    private static let snapshotKey = "work_session_snapshot_v1"

    init(
        defaults: UserDefaults = .standard,
        liveActivitiesEnabled: Bool = true
    ) {
        self.defaults = defaults
        self.liveActivityController = LiveActivityController(isEnabled: liveActivitiesEnabled)
        self.reminderController = ShiftReminderController()

        if
            let data = defaults.data(forKey: Self.snapshotKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        {
            self.profile = snapshot.profile
            self.sessions = snapshot.sessions.sorted { $0.startedAt > $1.startedAt }
        } else {
            self.profile = .defaultValue
            self.sessions = []
        }
    }

    var activeSession: WorkSession? {
        sessions.first(where: \.isActive)
    }

    var completedSessions: [WorkSession] {
        sessions
            .filter { !$0.isActive }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func startShift(at date: Date = .now) async {
        guard activeSession == nil else { return }

        let session = WorkSession(
            startedAt: date,
            hourlyRate: profile.hourlyRate,
            currencyCode: profile.currencyCode,
            plannedHours: profile.plannedHours
        )
        sessions.insert(session, at: 0)
        liveActivityController.start(for: session)
        await scheduleReminderIfNeeded(for: session, asOf: date)
    }

    func pauseShift(at date: Date = .now) async {
        guard let index = sessions.firstIndex(where: \.isActive) else { return }
        guard !sessions[index].isPaused else { return }

        var session = sessions[index]
        session.breaks.append(
            WorkBreak(startedAt: max(date, session.startedAt))
        )
        sessions[index] = session
        reminderController.cancel(for: session.id)
        await liveActivityController.update(for: session, asOf: date)
    }

    func resumeShift(at date: Date = .now) async {
        guard let index = sessions.firstIndex(where: \.isActive) else { return }
        guard let breakIndex = sessions[index].breaks.firstIndex(where: \.isActive) else { return }

        var session = sessions[index]
        let breakStart = session.breaks[breakIndex].startedAt
        session.breaks[breakIndex].endedAt = max(date, breakStart)
        sessions[index] = session
        await liveActivityController.update(for: session, asOf: date)
        await scheduleReminderIfNeeded(for: session, asOf: date)
    }

    func stopShift(at date: Date = .now) async {
        guard let index = sessions.firstIndex(where: \.isActive) else { return }

        var completed = sessions[index]
        let endedAt = max(date, completed.startedAt)
        if let breakIndex = completed.breaks.firstIndex(where: \.isActive) {
            let breakStart = completed.breaks[breakIndex].startedAt
            completed.breaks[breakIndex].endedAt = max(endedAt, breakStart)
        }
        completed.endedAt = endedAt
        sessions[index] = completed
        reminderController.cancel(for: completed.id)
        await liveActivityController.end(for: completed, at: date)
    }

    @discardableResult
    func setShiftRemindersEnabled(_ isEnabled: Bool) async -> Bool {
        if isEnabled {
            guard await reminderController.requestAuthorization() else {
                profile.shiftRemindersEnabled = false
                return false
            }
            profile.shiftRemindersEnabled = true
            if let activeSession, !activeSession.isPaused {
                await scheduleReminderIfNeeded(for: activeSession)
            }
        } else {
            profile.shiftRemindersEnabled = false
            await reminderController.cancelAll()
        }
        return true
    }

    func refreshLiveActivity(asOf date: Date = .now) async {
        guard let activeSession else { return }
        await liveActivityController.update(for: activeSession, asOf: date)
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id && !$0.isActive }
    }

    @discardableResult
    func updateCompletedSession(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        breakDuration: TimeInterval,
        hourlyRate: Double,
        currencyCode: String,
        plannedHours: Double
    ) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == id && !$0.isActive }) else {
            return false
        }
        guard endedAt > startedAt, hourlyRate > 0, plannedHours > 0 else {
            return false
        }

        let totalDuration = endedAt.timeIntervalSince(startedAt)
        let normalizedBreakDuration = min(max(0, breakDuration), max(0, totalDuration - 60))
        var updatedSession = sessions[index]
        updatedSession.startedAt = startedAt
        updatedSession.endedAt = endedAt
        updatedSession.hourlyRate = hourlyRate
        updatedSession.currencyCode = currencyCode
        updatedSession.plannedHours = plannedHours

        if normalizedBreakDuration > 0 {
            let workedBeforeBreak = (totalDuration - normalizedBreakDuration) / 2
            let breakStart = startedAt.addingTimeInterval(workedBeforeBreak)
            updatedSession.breaks = [
                WorkBreak(
                    startedAt: breakStart,
                    endedAt: breakStart.addingTimeInterval(normalizedBreakDuration)
                )
            ]
        } else {
            updatedSession.breaks = []
        }

        var updatedSessions = sessions
        updatedSessions[index] = updatedSession
        sessions = updatedSessions.sorted { $0.startedAt > $1.startedAt }
        return true
    }

    func clearCompletedSessions() {
        sessions.removeAll { !$0.isActive }
    }

    func earningsToday(asOf date: Date = .now) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: date)

        return sessions
            .filter { $0.startedAt >= startOfDay && $0.startedAt <= date }
            .reduce(0) { $0 + $1.earnings(asOf: date) }
    }

    func durationToday(asOf date: Date = .now) -> TimeInterval {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: date)

        return sessions
            .filter { $0.startedAt >= startOfDay && $0.startedAt <= date }
            .reduce(0) { $0 + $1.duration(asOf: date) }
    }

    func breakDurationToday(asOf date: Date = .now) -> TimeInterval {
        sessionsToday(asOf: date)
            .reduce(0) { $0 + $1.breakDuration(asOf: date) }
    }

    func overtimeToday(asOf date: Date = .now) -> TimeInterval {
        let sessions = sessionsToday(asOf: date)
        let plannedHours = sessions.first?.plannedHours ?? profile.plannedHours
        let duration = sessions.reduce(0) { $0 + $1.duration(asOf: date) }
        return max(0, duration - plannedHours * 3_600)
    }

    func currentWeekSummary(asOf date: Date = .now) -> WorkPeriodSummary {
        let calendar = Calendar.autoupdatingCurrent
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let weekSessions = completedSessions.filter { session in
            guard let interval else { return false }
            return session.startedAt >= interval.start && session.startedAt < interval.end
        }
        let currencyCode = weekSessions.first?.currencyCode ?? profile.currencyCode

        return WorkPeriodSummary(
            sessionCount: weekSessions.count,
            workDuration: weekSessions.reduce(0) { $0 + $1.duration(asOf: date) },
            breakDuration: weekSessions.reduce(0) { $0 + $1.breakDuration(asOf: date) },
            overtimeDuration: weekSessions.reduce(0) { $0 + $1.overtime(asOf: date) },
            earnings: weekSessions
                .filter { $0.currencyCode == currencyCode }
                .reduce(0) { $0 + $1.earnings(asOf: date) },
            currencyCode: currencyCode
        )
    }

    private func sessionsToday(asOf date: Date) -> [WorkSession] {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: date)
        return sessions.filter { $0.startedAt >= startOfDay && $0.startedAt <= date }
    }

    private func scheduleReminderIfNeeded(for session: WorkSession, asOf date: Date = .now) async {
        guard profile.shiftRemindersEnabled, !session.isPaused else { return }
        let remaining = max(0, session.plannedHours * 3_600 - session.duration(asOf: date))
        await reminderController.schedule(for: session, remainingWorkTime: remaining)
    }

    private func persist() {
        let snapshot = Snapshot(profile: profile, sessions: sessions)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.snapshotKey)
    }
}

extension WorkSessionStore {
    static var preview: WorkSessionStore {
        let suiteName = "ArbeitsKlar.Preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let store = WorkSessionStore(defaults: defaults, liveActivitiesEnabled: false)

        store.profile = PayProfile(hourlyRate: 24.5, currencyCode: "EUR", plannedHours: 8)
        store.sessions = [
            WorkSession(
                startedAt: .now.addingTimeInterval(-2_700),
                hourlyRate: 24.5,
                currencyCode: "EUR",
                plannedHours: 8,
                breaks: [
                    WorkBreak(
                        startedAt: .now.addingTimeInterval(-1_800),
                        endedAt: .now.addingTimeInterval(-1_500)
                    )
                ]
            ),
            WorkSession(
                startedAt: .now.addingTimeInterval(-86_400),
                endedAt: .now.addingTimeInterval(-58_800),
                hourlyRate: 24.5,
                currencyCode: "EUR",
                plannedHours: 8
            )
        ]
        return store
    }

    static var pausedPreview: WorkSessionStore {
        let suiteName = "ArbeitsKlar.PausedPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let store = WorkSessionStore(defaults: defaults, liveActivitiesEnabled: false)

        store.profile = PayProfile(hourlyRate: 24.5, currencyCode: "EUR", plannedHours: 8)
        store.sessions = [
            WorkSession(
                startedAt: .now.addingTimeInterval(-3_600),
                hourlyRate: 24.5,
                currencyCode: "EUR",
                plannedHours: 8,
                breaks: [WorkBreak(startedAt: .now.addingTimeInterval(-600))]
            )
        ]
        return store
    }

    #if DEBUG
    static var demo: WorkSessionStore {
        let suiteName = "ArbeitsKlar.Demo.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let store = WorkSessionStore(defaults: defaults, liveActivitiesEnabled: false)
        let calendar = Calendar.autoupdatingCurrent

        store.profile = PayProfile(hourlyRate: 24.5, currencyCode: "EUR", plannedHours: 8)
        store.sessions = (0..<70).compactMap { dayOffset in
            guard
                let day = calendar.date(byAdding: .day, value: -dayOffset, to: .now),
                !calendar.isDateInWeekend(day),
                let startedAt = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: day)
            else {
                return nil
            }

            let workHours = [7.5, 8.0, 8.5, 9.0][dayOffset % 4]
            let breakDuration: TimeInterval = dayOffset % 3 == 0 ? 2_700 : 1_800
            let breakStart = startedAt.addingTimeInterval(4 * 3_600)
            let endedAt = startedAt.addingTimeInterval(workHours * 3_600 + breakDuration)

            return WorkSession(
                startedAt: startedAt,
                endedAt: endedAt,
                hourlyRate: 24.5,
                currencyCode: "EUR",
                plannedHours: 8,
                breaks: [
                    WorkBreak(
                        startedAt: breakStart,
                        endedAt: breakStart.addingTimeInterval(breakDuration)
                    )
                ]
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
        return store
    }
    #endif
}

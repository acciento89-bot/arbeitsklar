import Foundation
import Observation

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

    private static let snapshotKey = "work_session_snapshot_v1"

    init(
        defaults: UserDefaults = .standard,
        liveActivitiesEnabled: Bool = true
    ) {
        self.defaults = defaults
        self.liveActivityController = LiveActivityController(isEnabled: liveActivitiesEnabled)

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

    func startShift(at date: Date = .now) {
        guard activeSession == nil else { return }

        let session = WorkSession(
            startedAt: date,
            hourlyRate: profile.hourlyRate,
            currencyCode: profile.currencyCode,
            plannedHours: profile.plannedHours
        )
        sessions.insert(session, at: 0)
        liveActivityController.start(for: session)
    }

    func pauseShift(at date: Date = .now) async {
        guard let index = sessions.firstIndex(where: \.isActive) else { return }
        guard !sessions[index].isPaused else { return }

        var session = sessions[index]
        session.breaks.append(
            WorkBreak(startedAt: max(date, session.startedAt))
        )
        sessions[index] = session
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
        await liveActivityController.end(for: completed, at: date)
    }

    func refreshLiveActivity(asOf date: Date = .now) async {
        guard let activeSession else { return }
        await liveActivityController.update(for: activeSession, asOf: date)
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id && !$0.isActive }
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

    private func sessionsToday(asOf date: Date) -> [WorkSession] {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: date)
        return sessions.filter { $0.startedAt >= startOfDay && $0.startedAt <= date }
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
}

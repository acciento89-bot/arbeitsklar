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
            currencyCode: profile.currencyCode
        )
        sessions.insert(session, at: 0)
        liveActivityController.start(for: session)
    }

    func stopShift(at date: Date = .now) async {
        guard let index = sessions.firstIndex(where: \.isActive) else { return }

        sessions[index].endedAt = max(date, sessions[index].startedAt)
        let completed = sessions[index]
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
                currencyCode: "EUR"
            ),
            WorkSession(
                startedAt: .now.addingTimeInterval(-86_400),
                endedAt: .now.addingTimeInterval(-58_800),
                hourlyRate: 24.5,
                currencyCode: "EUR"
            )
        ]
        return store
    }
}

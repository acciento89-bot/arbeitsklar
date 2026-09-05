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
    static let shared = WorkSessionStore()

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

    private(set) var paycheckAudits: [PaycheckAudit] {
        didSet { persistPaycheckAudits() }
    }

    private(set) var shiftTemplates: [ShiftTemplate] {
        didSet { persistShiftTemplates() }
    }

    private(set) var scheduledShifts: [ScheduledShift] {
        didSet { persistScheduledShifts() }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    @ObservationIgnored
    private let liveActivityController: LiveActivityController

    @ObservationIgnored
    private let reminderController: ShiftReminderController

    private static let snapshotKey = "work_session_snapshot_v1"
    private static let paycheckAuditsKey = "paycheck_audits_v1"
    private static let shiftTemplatesKey = "shift_templates_v1"
    private static let scheduledShiftsKey = "scheduled_shifts_v1"

    init(
        defaults: UserDefaults = .standard,
        liveActivitiesEnabled: Bool = true
    ) {
        self.defaults = defaults
        self.liveActivityController = LiveActivityController(isEnabled: liveActivitiesEnabled)
        self.reminderController = ShiftReminderController()
        if
            let scheduledData = defaults.data(forKey: Self.scheduledShiftsKey),
            let scheduled = try? JSONDecoder().decode([ScheduledShift].self, from: scheduledData)
        {
            self.scheduledShifts = scheduled.sorted { $0.startsAt < $1.startsAt }
        } else {
            self.scheduledShifts = []
        }
        if
            let templateData = defaults.data(forKey: Self.shiftTemplatesKey),
            let templates = try? JSONDecoder().decode([ShiftTemplate].self, from: templateData)
        {
            self.shiftTemplates = templates
        } else {
            self.shiftTemplates = []
        }
        if
            let auditData = defaults.data(forKey: Self.paycheckAuditsKey),
            let audits = try? JSONDecoder().decode([PaycheckAudit].self, from: auditData)
        {
            self.paycheckAudits = audits.sorted { $0.month > $1.month }
        } else {
            self.paycheckAudits = []
        }

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

    var nextScheduledShift: ScheduledShift? {
        scheduledShifts.first { !$0.isPast() }
    }

    func startShift(at date: Date = .now) async {
        guard activeSession == nil else { return }

        let session = WorkSession(
            startedAt: date,
            hourlyRate: profile.hourlyRate,
            currencyCode: profile.currencyCode,
            plannedHours: profile.plannedHours,
            payRules: profile.payRules
        )
        sessions.insert(session, at: 0)
        liveActivityController.start(for: session)
        await scheduleReminderIfNeeded(for: session, asOf: date)
    }

    func startShift(using template: ShiftTemplate, at date: Date = .now) async {
        guard activeSession == nil else { return }

        let session = WorkSession(
            startedAt: date,
            hourlyRate: profile.hourlyRate,
            currencyCode: profile.currencyCode,
            plannedHours: template.plannedHours,
            payRules: profile.payRules,
            title: template.name,
            note: template.note,
            tags: template.tags
        )
        sessions.insert(session, at: 0)
        liveActivityController.start(for: session)
        await scheduleReminderIfNeeded(for: session, asOf: date)
    }

    @discardableResult
    func startShift(from plannedShift: ScheduledShift, at date: Date = .now) async -> Bool {
        guard activeSession == nil else { return false }
        guard scheduledShifts.contains(where: { $0.id == plannedShift.id }) else { return false }

        let session = WorkSession(
            startedAt: date,
            hourlyRate: profile.hourlyRate,
            currencyCode: profile.currencyCode,
            plannedHours: plannedShift.plannedHours,
            payRules: profile.payRules,
            title: plannedShift.title,
            note: plannedShift.note,
            tags: plannedShift.tags
        )
        scheduledShifts.removeAll { $0.id == plannedShift.id }
        reminderController.cancelPlannedShift(id: plannedShift.id)
        sessions.insert(session, at: 0)
        liveActivityController.start(for: session)
        await scheduleReminderIfNeeded(for: session, asOf: date)
        return true
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

    func addTip(_ amount: Double) {
        guard amount > 0, let index = sessions.firstIndex(where: \.isActive) else { return }
        sessions[index].tips += amount
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id && !$0.isActive }
    }

    @discardableResult
    func addCompletedSession(
        startedAt: Date,
        endedAt: Date,
        breakDuration: TimeInterval,
        hourlyRate: Double,
        currencyCode: String,
        plannedHours: Double,
        payRules: PayRules,
        title: String = "",
        note: String = "",
        tags: [String] = [],
        tips: Double = 0
    ) -> Bool {
        guard endedAt > startedAt, hourlyRate > 0, plannedHours > 0 else {
            return false
        }

        let totalDuration = endedAt.timeIntervalSince(startedAt)
        let normalizedBreakDuration = min(max(0, breakDuration), max(0, totalDuration - 60))
        let breaks: [WorkBreak]
        if normalizedBreakDuration > 0 {
            let workedBeforeBreak = (totalDuration - normalizedBreakDuration) / 2
            let breakStart = startedAt.addingTimeInterval(workedBeforeBreak)
            breaks = [
                WorkBreak(
                    startedAt: breakStart,
                    endedAt: breakStart.addingTimeInterval(normalizedBreakDuration)
                )
            ]
        } else {
            breaks = []
        }

        sessions.append(
            WorkSession(
                startedAt: startedAt,
                endedAt: endedAt,
                hourlyRate: hourlyRate,
                currencyCode: currencyCode,
                plannedHours: plannedHours,
                breaks: breaks,
                payRules: payRules,
                title: title,
                note: note,
                tags: tags,
                tips: tips
            )
        )
        sessions.sort { $0.startedAt > $1.startedAt }
        return true
    }

    @discardableResult
    func updateCompletedSession(
        id: UUID,
        startedAt: Date,
        endedAt: Date,
        breakDuration: TimeInterval,
        hourlyRate: Double,
        currencyCode: String,
        plannedHours: Double,
        title: String,
        note: String,
        tags: [String],
        tips: Double
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
        updatedSession.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedSession.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedSession.tags = ShiftTemplate.normalizedTags(tags)
        updatedSession.tips = max(0, tips)

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

    func saveShiftTemplate(_ template: ShiftTemplate) {
        guard !template.name.isEmpty else { return }
        if let index = shiftTemplates.firstIndex(where: { $0.id == template.id }) {
            shiftTemplates[index] = template
        } else {
            shiftTemplates.append(template)
        }
    }

    func deleteShiftTemplate(id: UUID) {
        shiftTemplates.removeAll { $0.id == id }
    }

    @discardableResult
    func saveScheduledShift(_ plannedShift: ScheduledShift) async -> Bool {
        var normalized = plannedShift
        var reminderSucceeded = true
        if plannedShift.reminderMinutesBefore != nil {
            reminderSucceeded = await reminderController.schedule(for: plannedShift)
            if !reminderSucceeded {
                normalized.reminderMinutesBefore = nil
            }
        } else {
            reminderController.cancelPlannedShift(id: plannedShift.id)
        }

        if let index = scheduledShifts.firstIndex(where: { $0.id == normalized.id }) {
            scheduledShifts[index] = normalized
        } else {
            scheduledShifts.append(normalized)
        }
        scheduledShifts.sort { $0.startsAt < $1.startsAt }
        return reminderSucceeded
    }

    func deleteScheduledShift(id: UUID) {
        reminderController.cancelPlannedShift(id: id)
        scheduledShifts.removeAll { $0.id == id }
    }

    func scheduledShifts(on date: Date) -> [ScheduledShift] {
        let calendar = Calendar.autoupdatingCurrent
        return scheduledShifts.filter { calendar.isDate($0.startsAt, inSameDayAs: date) }
    }

    func earningsToday(asOf date: Date = .now) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        let startOfDay = calendar.startOfDay(for: date)

        return sessions
            .filter { $0.startedAt >= startOfDay && $0.startedAt <= date }
            .reduce(0) { $0 + $1.earnings(asOf: date) }
    }

    func tipsToday(asOf date: Date = .now) -> Double {
        sessionsToday(asOf: date).reduce(0) { $0 + $1.tips }
    }

    func earningsThisMonth(asOf date: Date = .now) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }

        return sessions
            .filter {
                $0.startedAt >= interval.start
                    && $0.startedAt < interval.end
                    && $0.startedAt <= date
                    && $0.currencyCode == profile.currencyCode
            }
            .reduce(0) { $0 + $1.earnings(asOf: date) }
    }

    func reloadFromDisk() {
        guard
            let data = defaults.data(forKey: Self.snapshotKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        profile = snapshot.profile
        sessions = snapshot.sessions.sorted { $0.startedAt > $1.startedAt }
        if
            let auditData = defaults.data(forKey: Self.paycheckAuditsKey),
            let audits = try? JSONDecoder().decode([PaycheckAudit].self, from: auditData)
        {
            paycheckAudits = audits.sorted { $0.month > $1.month }
        }
        if
            let templateData = defaults.data(forKey: Self.shiftTemplatesKey),
            let templates = try? JSONDecoder().decode([ShiftTemplate].self, from: templateData)
        {
            shiftTemplates = templates
        }
        if
            let scheduledData = defaults.data(forKey: Self.scheduledShiftsKey),
            let scheduled = try? JSONDecoder().decode([ScheduledShift].self, from: scheduledData)
        {
            scheduledShifts = scheduled.sorted { $0.startsAt < $1.startsAt }
        }
    }

    func expectedEarnings(forMonthContaining date: Date, currencyCode: String) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        return completedSessions
            .filter {
                $0.startedAt >= interval.start
                    && $0.startedAt < interval.end
                    && $0.currencyCode == currencyCode
            }
            .reduce(0) { $0 + $1.earnings() }
    }

    func paycheckAudit(forMonthContaining date: Date, currencyCode: String) -> PaycheckAudit? {
        let calendar = Calendar.autoupdatingCurrent
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
        return paycheckAudits.first {
            calendar.isDate($0.month, equalTo: monthStart, toGranularity: .month)
                && $0.currencyCode == currencyCode
        }
    }

    func savePaycheckAudit(
        forMonthContaining date: Date,
        actualGross: Double,
        currencyCode: String,
        note: String
    ) {
        let calendar = Calendar.autoupdatingCurrent
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else { return }
        if let index = paycheckAudits.firstIndex(where: {
            calendar.isDate($0.month, equalTo: monthStart, toGranularity: .month)
                && $0.currencyCode == currencyCode
        }) {
            paycheckAudits[index].actualGross = max(0, actualGross)
            paycheckAudits[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            paycheckAudits[index].updatedAt = .now
        } else {
            paycheckAudits.append(
                PaycheckAudit(
                    month: monthStart,
                    actualGross: max(0, actualGross),
                    currencyCode: currencyCode,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        paycheckAudits.sort { $0.month > $1.month }
    }

    func deletePaycheckAudit(forMonthContaining date: Date, currencyCode: String) {
        let calendar = Calendar.autoupdatingCurrent
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start else { return }
        paycheckAudits.removeAll {
            calendar.isDate($0.month, equalTo: monthStart, toGranularity: .month)
                && $0.currencyCode == currencyCode
        }
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

    private func persistPaycheckAudits() {
        guard let data = try? JSONEncoder().encode(paycheckAudits) else { return }
        defaults.set(data, forKey: Self.paycheckAuditsKey)
    }

    private func persistShiftTemplates() {
        guard let data = try? JSONEncoder().encode(shiftTemplates) else { return }
        defaults.set(data, forKey: Self.shiftTemplatesKey)
    }

    private func persistScheduledShifts() {
        guard let data = try? JSONEncoder().encode(scheduledShifts) else { return }
        defaults.set(data, forKey: Self.scheduledShiftsKey)
    }
}

extension WorkSessionStore {
    static var preview: WorkSessionStore {
        let suiteName = "ArbeitsKlar.Preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let store = WorkSessionStore(defaults: defaults, liveActivitiesEnabled: false)

        store.profile = PayProfile(
            hourlyRate: 24.5,
            currencyCode: "EUR",
            plannedHours: 8,
            monthlyEarningsGoal: 3_500,
            shiftEarningsGoal: 120,
            shiftGoalTitle: "Weekend trip",
            payRules: PayRules(overtimeMultiplier: 1.25, nightBonusPercent: 20, weekendBonusPercent: 30)
        )
        store.shiftTemplates = [
            ShiftTemplate(
                name: "Early shift",
                startHour: 7,
                startMinute: 30,
                plannedHours: 8,
                breakMinutes: 30,
                tags: ["Service"]
            )
        ]
        store.scheduledShifts = [
            ScheduledShift(
                startsAt: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: .now) ?? .now,
                plannedHours: 8,
                breakMinutes: 30,
                title: "Early shift",
                tags: ["Service"]
            )
        ]
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
                ],
                payRules: store.profile.payRules
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

        store.profile = PayProfile(
            hourlyRate: 24.5,
            currencyCode: "EUR",
            plannedHours: 8,
            shiftEarningsGoal: 120,
            shiftGoalTitle: "Weekend trip",
            payRules: PayRules(overtimeMultiplier: 1.25, nightBonusPercent: 20, weekendBonusPercent: 30)
        )
        store.shiftTemplates = [
            ShiftTemplate(name: "Early shift", plannedHours: 8, breakMinutes: 30, tags: ["Service"])
        ]
        store.scheduledShifts = []
        store.sessions = [
            WorkSession(
                startedAt: .now.addingTimeInterval(-3_600),
                hourlyRate: 24.5,
                currencyCode: "EUR",
                plannedHours: 8,
                breaks: [WorkBreak(startedAt: .now.addingTimeInterval(-600))],
                payRules: store.profile.payRules
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

        store.profile = PayProfile(
            hourlyRate: 24.5,
            currencyCode: "EUR",
            plannedHours: 8,
            monthlyEarningsGoal: 3_500,
            shiftEarningsGoal: 150,
            shiftGoalTitle: "Holiday fund",
            payRules: PayRules(overtimeMultiplier: 1.25, nightBonusPercent: 20, weekendBonusPercent: 30)
        )
        store.shiftTemplates = [
            ShiftTemplate(name: "Service", startHour: 7, startMinute: 30, plannedHours: 8, breakMinutes: 30, tags: ["Service"]),
            ShiftTemplate(name: "Emergency duty", startHour: 16, plannedHours: 6, breakMinutes: 0, tags: ["On-call"])
        ]
        store.scheduledShifts = (1...8).compactMap { dayOffset in
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: .now),
                !calendar.isDateInWeekend(day),
                let start = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: day)
            else { return nil }
            return ScheduledShift(
                startsAt: start,
                plannedHours: dayOffset % 4 == 0 ? 6 : 8,
                breakMinutes: dayOffset % 4 == 0 ? 0 : 30,
                title: dayOffset % 4 == 0 ? "Emergency duty" : "Service",
                tags: dayOffset % 4 == 0 ? ["On-call"] : ["Service"],
                reminderMinutesBefore: nil
            )
        }
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
                ],
                payRules: store.profile.payRules,
                title: dayOffset % 5 == 0 ? "Emergency duty" : "Service",
                note: dayOffset % 7 == 0 ? "Customer visit documented" : "",
                tags: dayOffset % 5 == 0 ? ["On-call"] : ["Service"],
                tips: dayOffset % 6 == 0 ? 5 : 0
            )
        }
        .sorted { $0.startedAt > $1.startedAt }
        let expectedGross = store.expectedEarnings(forMonthContaining: .now, currencyCode: "EUR")
        store.savePaycheckAudit(
            forMonthContaining: .now,
            actualGross: max(1, expectedGross - 23.5),
            currencyCode: "EUR",
            note: "Example discrepancy for UI testing"
        )
        return store
    }
    #endif
}

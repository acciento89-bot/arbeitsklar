import AppIntents

struct StartShiftIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.start.title"
    static let description = IntentDescription("intent.start.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = WorkSessionStore.shared
        guard store.activeSession == nil else {
            return .result(dialog: "intent.start.already_running")
        }
        await store.startShift()
        return .result(dialog: "intent.start.success")
    }
}

struct PauseShiftIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.pause.title"
    static let description = IntentDescription("intent.pause.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = WorkSessionStore.shared
        guard let session = store.activeSession else {
            return .result(dialog: "intent.no_active_shift")
        }
        guard !session.isPaused else {
            return .result(dialog: "intent.pause.already_paused")
        }
        await store.pauseShift()
        return .result(dialog: "intent.pause.success")
    }
}

struct ResumeShiftIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.resume.title"
    static let description = IntentDescription("intent.resume.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = WorkSessionStore.shared
        guard let session = store.activeSession else {
            return .result(dialog: "intent.no_active_shift")
        }
        guard session.isPaused else {
            return .result(dialog: "intent.resume.not_paused")
        }
        await store.resumeShift()
        return .result(dialog: "intent.resume.success")
    }
}

struct EndShiftIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.end.title"
    static let description = IntentDescription("intent.end.description")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = WorkSessionStore.shared
        guard store.activeSession != nil else {
            return .result(dialog: "intent.no_active_shift")
        }
        await store.stopShift()
        return .result(dialog: "intent.end.success")
    }
}

struct ArbeitsKlarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartShiftIntent(),
            phrases: [
                "Start my shift with \(.applicationName)",
                "Starte meine Schicht mit \(.applicationName)"
            ],
            shortTitle: "intent.start.title",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PauseShiftIntent(),
            phrases: [
                "Pause my shift with \(.applicationName)",
                "Pausiere meine Schicht mit \(.applicationName)"
            ],
            shortTitle: "intent.pause.title",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ResumeShiftIntent(),
            phrases: [
                "Resume my shift with \(.applicationName)",
                "Setze meine Schicht mit \(.applicationName) fort"
            ],
            shortTitle: "intent.resume.title",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: EndShiftIntent(),
            phrases: [
                "End my shift with \(.applicationName)",
                "Beende meine Schicht mit \(.applicationName)"
            ],
            shortTitle: "intent.end.title",
            systemImageName: "stop.fill"
        )
    }
}

import Foundation

struct ScheduledShift: Codable, Hashable, Identifiable {
    let id: UUID
    var startsAt: Date
    var plannedHours: Double
    var breakMinutes: Int
    var title: String
    var note: String
    var tags: [String]
    var reminderMinutesBefore: Int?
    var templateID: UUID?

    init(
        id: UUID = UUID(),
        startsAt: Date,
        plannedHours: Double,
        breakMinutes: Int = 0,
        title: String = "",
        note: String = "",
        tags: [String] = [],
        reminderMinutesBefore: Int? = nil,
        templateID: UUID? = nil
    ) {
        self.id = id
        self.startsAt = startsAt
        self.plannedHours = min(max(plannedHours, 1), 16)
        self.breakMinutes = min(max(breakMinutes, 0), 240)
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = ShiftTemplate.normalizedTags(tags)
        self.reminderMinutesBefore = reminderMinutesBefore.map { min(max($0, 0), 1_440) }
        self.templateID = templateID
    }

    var endsAt: Date {
        startsAt.addingTimeInterval(
            plannedHours * 3_600 + TimeInterval(breakMinutes * 60)
        )
    }

    func isPast(asOf date: Date = .now) -> Bool {
        endsAt < date
    }
}

import Foundation

struct ShiftTemplate: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var startHour: Int
    var startMinute: Int
    var plannedHours: Double
    var breakMinutes: Int
    var note: String
    var tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        startHour: Int = 7,
        startMinute: Int = 30,
        plannedHours: Double = 8,
        breakMinutes: Int = 30,
        note: String = "",
        tags: [String] = []
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startHour = min(max(startHour, 0), 23)
        self.startMinute = min(max(startMinute, 0), 59)
        self.plannedHours = min(max(plannedHours, 1), 16)
        self.breakMinutes = min(max(breakMinutes, 0), 240)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = Self.normalizedTags(tags)
    }

    func startDate(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date) ?? date
    }

    static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        let normalized: [String] = tags.compactMap { rawTag -> String? in
            let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else { return nil }
            let key = tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .autoupdatingCurrent)
            guard seen.insert(key).inserted else { return nil }
            return tag
        }
        return Array(normalized.prefix(8))
    }
}

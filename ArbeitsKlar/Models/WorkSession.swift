import Foundation

struct WorkBreak: Codable, Hashable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var isActive: Bool { endedAt == nil }

    func duration(asOf date: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }
}

struct WorkSession: Codable, Hashable, Identifiable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var hourlyRate: Double
    var currencyCode: String
    var plannedHours: Double
    var breaks: [WorkBreak]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        hourlyRate: Double,
        currencyCode: String,
        plannedHours: Double = 8,
        breaks: [WorkBreak] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.hourlyRate = hourlyRate
        self.currencyCode = currencyCode
        self.plannedHours = plannedHours
        self.breaks = breaks
    }

    var isActive: Bool { endedAt == nil }
    var activeBreak: WorkBreak? { breaks.first(where: \.isActive) }
    var isPaused: Bool { activeBreak != nil }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case hourlyRate
        case currencyCode
        case plannedHours
        case breaks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        hourlyRate = try container.decode(Double.self, forKey: .hourlyRate)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        plannedHours = try container.decodeIfPresent(Double.self, forKey: .plannedHours) ?? 8
        breaks = try container.decodeIfPresent([WorkBreak].self, forKey: .breaks) ?? []
    }

    func duration(asOf date: Date = .now) -> TimeInterval {
        let effectiveEnd = endedAt ?? date
        let totalDuration = max(0, effectiveEnd.timeIntervalSince(startedAt))
        return max(0, totalDuration - breakDuration(asOf: effectiveEnd))
    }

    func breakDuration(asOf date: Date = .now) -> TimeInterval {
        breaks.reduce(0) { total, workBreak in
            total + workBreak.duration(asOf: date)
        }
    }

    func overtime(asOf date: Date = .now) -> TimeInterval {
        max(0, duration(asOf: date) - plannedHours * 3_600)
    }

    func timerReferenceDate(asOf date: Date = .now) -> Date {
        date.addingTimeInterval(-duration(asOf: date))
    }

    func earnings(asOf date: Date = .now) -> Double {
        EarningsCalculator.earnings(
            hourlyRate: hourlyRate,
            elapsedTime: duration(asOf: date)
        )
    }
}

import Foundation

struct WorkSession: Codable, Hashable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    let hourlyRate: Double
    let currencyCode: String

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        hourlyRate: Double,
        currencyCode: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.hourlyRate = hourlyRate
        self.currencyCode = currencyCode
    }

    var isActive: Bool { endedAt == nil }

    func duration(asOf date: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }

    func earnings(asOf date: Date = .now) -> Double {
        EarningsCalculator.earnings(
            hourlyRate: hourlyRate,
            elapsedTime: duration(asOf: date)
        )
    }
}


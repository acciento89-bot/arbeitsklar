import Foundation

enum EarningsCalculator {
    static func earnings(hourlyRate: Double, elapsedTime: TimeInterval) -> Double {
        guard hourlyRate > 0, elapsedTime > 0 else { return 0 }
        return hourlyRate * elapsedTime / 3_600
    }

    static func projectedEarnings(hourlyRate: Double, plannedHours: Double) -> Double {
        max(0, hourlyRate) * max(0, plannedHours)
    }

    static func breakdown(
        for session: WorkSession,
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> EarningsBreakdown {
        let intervals = session.workIntervals(asOf: date)
        let totalDuration = intervals.reduce(0) { $0 + $1.duration }
        let hourlyRate = max(0, session.hourlyRate)
        let base = earnings(hourlyRate: hourlyRate, elapsedTime: totalDuration)

        let overtimeDuration = overtimeDuration(
            in: intervals,
            threshold: max(0, session.plannedHours) * 3_600
        )
        let overtimePremium = earnings(
            hourlyRate: hourlyRate * max(0, session.payRules.overtimeMultiplier - 1),
            elapsedTime: overtimeDuration
        )

        let nightDuration = premiumDuration(
            in: intervals,
            windows: nightWindows(
                covering: intervals,
                startHour: session.payRules.nightStartHour,
                endHour: session.payRules.nightEndHour,
                calendar: calendar
            )
        )
        let nightPremium = earnings(
            hourlyRate: hourlyRate * max(0, session.payRules.nightBonusPercent) / 100,
            elapsedTime: nightDuration
        )

        let weekendDuration = intervals.reduce(0) { total, interval in
            total + durationOnWeekend(in: interval, calendar: calendar)
        }
        let weekendPremium = earnings(
            hourlyRate: hourlyRate * max(0, session.payRules.weekendBonusPercent) / 100,
            elapsedTime: weekendDuration
        )

        return EarningsBreakdown(
            baseEarnings: base,
            overtimePremium: overtimePremium,
            nightPremium: nightPremium,
            weekendPremium: weekendPremium
        )
    }

    static func projectedDate(
        forEarnings target: Double,
        session: WorkSession,
        asOf date: Date = .now
    ) -> Date? {
        if target <= session.earnings(asOf: date) { return date }
        guard session.hourlyRate > 0 else { return nil }

        var projected = session
        if let activeBreakIndex = projected.breaks.firstIndex(where: \.isActive) {
            projected.breaks[activeBreakIndex].endedAt = date
        }

        var lowerBound = date
        var upperBound = date.addingTimeInterval(48 * 3_600)
        guard projected.earnings(asOf: upperBound) >= target else { return nil }

        for _ in 0..<24 {
            let midpoint = lowerBound.addingTimeInterval(upperBound.timeIntervalSince(lowerBound) / 2)
            if projected.earnings(asOf: midpoint) >= target {
                upperBound = midpoint
            } else {
                lowerBound = midpoint
            }
        }
        return upperBound
    }

    static func projectedEarningsForPlannedDuration(
        session: WorkSession,
        asOf date: Date = .now
    ) -> Double {
        var projected = session
        if let activeBreakIndex = projected.breaks.firstIndex(where: \.isActive) {
            projected.breaks[activeBreakIndex].endedAt = date
        }

        let targetDuration = max(0, projected.plannedHours) * 3_600
        if projected.duration(asOf: date) >= targetDuration {
            return projected.earnings(asOf: date)
        }
        var lowerBound = max(date, projected.startedAt)
        var upperBound = projected.startedAt.addingTimeInterval(48 * 3_600)
        guard projected.duration(asOf: upperBound) >= targetDuration else {
            return projected.earnings(asOf: upperBound)
        }

        for _ in 0..<24 {
            let midpoint = lowerBound.addingTimeInterval(upperBound.timeIntervalSince(lowerBound) / 2)
            if projected.duration(asOf: midpoint) >= targetDuration {
                upperBound = midpoint
            } else {
                lowerBound = midpoint
            }
        }
        return projected.earnings(asOf: upperBound)
    }

    private static func overtimeDuration(in intervals: [DateInterval], threshold: TimeInterval) -> TimeInterval {
        var regularRemaining = threshold
        var overtime: TimeInterval = 0
        for interval in intervals {
            let regular = min(regularRemaining, interval.duration)
            regularRemaining -= regular
            overtime += max(0, interval.duration - regular)
        }
        return overtime
    }

    private static func premiumDuration(in intervals: [DateInterval], windows: [DateInterval]) -> TimeInterval {
        intervals.reduce(0) { total, interval in
            total + windows.reduce(0) { subtotal, window in
                subtotal + overlapDuration(interval, window)
            }
        }
    }

    private static func nightWindows(
        covering intervals: [DateInterval],
        startHour: Int,
        endHour: Int,
        calendar: Calendar
    ) -> [DateInterval] {
        guard startHour != endHour, let first = intervals.first, let last = intervals.last else { return [] }
        let safeStart = min(max(startHour, 0), 23)
        let safeEnd = min(max(endHour, 0), 23)
        guard
            let firstDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: first.start)),
            let finalDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last.end))
        else { return [] }

        var windows: [DateInterval] = []
        var day = firstDay
        while day <= finalDay {
            guard
                let start = calendar.date(bySettingHour: safeStart, minute: 0, second: 0, of: day),
                let endDay = safeStart < safeEnd ? day : calendar.date(byAdding: .day, value: 1, to: day),
                let end = calendar.date(bySettingHour: safeEnd, minute: 0, second: 0, of: endDay)
            else { break }
            if end > start {
                windows.append(DateInterval(start: start, end: end))
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return windows
    }

    private static func durationOnWeekend(in interval: DateInterval, calendar: Calendar) -> TimeInterval {
        var total: TimeInterval = 0
        var cursor = interval.start
        while cursor < interval.end {
            guard let dayInterval = calendar.dateInterval(of: .day, for: cursor) else { break }
            let segmentEnd = min(dayInterval.end, interval.end)
            if calendar.isDateInWeekend(cursor) {
                total += max(0, segmentEnd.timeIntervalSince(cursor))
            }
            cursor = segmentEnd
        }
        return total
    }

    private static func overlapDuration(_ lhs: DateInterval, _ rhs: DateInterval) -> TimeInterval {
        max(0, min(lhs.end, rhs.end).timeIntervalSince(max(lhs.start, rhs.start)))
    }
}

import Foundation

enum HistoryPeriod: String, CaseIterable, Equatable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .week: "history.period.week"
        case .month: "history.period.month"
        case .all: "history.period.all"
        }
    }

    func contains(_ date: Date, asOf referenceDate: Date, calendar: Calendar) -> Bool {
        switch self {
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.contains(date) == true
        case .month:
            calendar.dateInterval(of: .month, for: referenceDate)?.contains(date) == true
        case .all:
            true
        }
    }

    func moving(_ date: Date, by value: Int, calendar: Calendar = .autoupdatingCurrent) -> Date {
        switch self {
        case .week:
            calendar.date(byAdding: .weekOfYear, value: value, to: date) ?? date
        case .month:
            calendar.date(byAdding: .month, value: value, to: date) ?? date
        case .all:
            date
        }
    }

    func canMoveForward(
        from referenceDate: Date,
        to currentDate: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        guard self != .all else { return false }
        let component: Calendar.Component = self == .week ? .weekOfYear : .month
        guard
            let referenceStart = calendar.dateInterval(of: component, for: referenceDate)?.start,
            let currentStart = calendar.dateInterval(of: component, for: currentDate)?.start
        else {
            return false
        }
        return referenceStart < currentStart
    }

    func interval(
        containing date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval? {
        switch self {
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)
        case .month: calendar.dateInterval(of: .month, for: date)
        case .all: nil
        }
    }
}

struct HistoryEarningsPoint: Equatable, Identifiable {
    let periodStart: Date
    let earnings: Double

    var id: Date { periodStart }
}

enum HistoryAnalytics {
    static func sessions(
        from sessions: [WorkSession],
        period: HistoryPeriod,
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [WorkSession] {
        sessions.filter { period.contains($0.startedAt, asOf: date, calendar: calendar) }
    }

    static func summary(
        for sessions: [WorkSession],
        fallbackCurrencyCode: String,
        asOf date: Date = .now
    ) -> WorkPeriodSummary {
        let currencyCode = sessions.first?.currencyCode ?? fallbackCurrencyCode

        return WorkPeriodSummary(
            sessionCount: sessions.count,
            workDuration: sessions.reduce(0) { $0 + $1.duration(asOf: date) },
            breakDuration: sessions.reduce(0) { $0 + $1.breakDuration(asOf: date) },
            overtimeDuration: sessions.reduce(0) { $0 + $1.overtime(asOf: date) },
            earnings: sessions
                .filter { $0.currencyCode == currencyCode }
                .reduce(0) { $0 + $1.earnings(asOf: date) },
            currencyCode: currencyCode
        )
    }

    static func earningsPoints(
        for sessions: [WorkSession],
        period: HistoryPeriod,
        currencyCode: String,
        asOf date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [HistoryEarningsPoint] {
        let component: Calendar.Component = period == .all ? .month : .day
        let matchingSessions = sessions.filter { $0.currencyCode == currencyCode }
        let grouped = Dictionary(grouping: matchingSessions) { session in
            calendar.dateInterval(of: component, for: session.startedAt)?.start
                ?? calendar.startOfDay(for: session.startedAt)
        }

        return grouped.map { periodStart, sessions in
            HistoryEarningsPoint(
                periodStart: periodStart,
                earnings: sessions.reduce(0) { $0 + $1.earnings(asOf: date) }
            )
        }
        .sorted { $0.periodStart < $1.periodStart }
    }
}

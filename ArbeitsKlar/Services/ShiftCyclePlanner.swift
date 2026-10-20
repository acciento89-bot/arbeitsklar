import Foundation

enum ShiftCycleError: Error, Equatable {
    case emptyName, invalidTimeZone, invalidPattern, noWorkDays
    case invalidDateRange, rangeTooLong, invalidTemplate, conflicts
}

struct ShiftCyclePreview {
    let shifts: [ScheduledShift]
    /// IDs of generated candidates that cannot be applied safely.
    let conflictingShiftIDs: Set<UUID>
    var nonconflictingShifts: [ScheduledShift] {
        shifts.filter { !conflictingShiftIDs.contains($0.id) }
    }
}

enum ShiftCyclePlanner {
    /// Calendar arithmetic intentionally avoids adding 86,400 seconds across DST.
    static func preview(
        _ cycle: ShiftCycle, existing: [ScheduledShift], asOf now: Date = .now
    ) throws -> ShiftCyclePreview {
        guard !cycle.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShiftCycleError.emptyName
        }
        guard let zone = TimeZone(identifier: cycle.timeZoneIdentifier) else {
            throw ShiftCycleError.invalidTimeZone
        }
        guard (7...28).contains(cycle.dayTemplates.count), cycle.dayTemplates.count % 7 == 0 else {
            throw ShiftCycleError.invalidPattern
        }
        let templates = cycle.dayTemplates.compactMap { $0 }
        guard !templates.isEmpty else { throw ShiftCycleError.noWorkDays }
        guard templates.allSatisfy({
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (0...23).contains($0.startHour) && (0...59).contains($0.startMinute) &&
            $0.plannedHours.isFinite && (1...16).contains($0.plannedHours) &&
            (0...240).contains($0.breakMinutes)
        }) else { throw ShiftCycleError.invalidTemplate }
        guard cycle.anchorDate.timeIntervalSince1970.isFinite,
              cycle.endDate.timeIntervalSince1970.isFinite,
              now.timeIntervalSince1970.isFinite else { throw ShiftCycleError.invalidDateRange }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let firstDay = calendar.startOfDay(for: cycle.anchorDate)
        let lastDay = calendar.startOfDay(for: cycle.endDate)
        guard let days = calendar.dateComponents([.day], from: firstDay, to: lastDay).day,
              days >= 0 else { throw ShiftCycleError.invalidDateRange }
        guard days <= 182 else { throw ShiftCycleError.rangeTooLong }
        // An edit replaces only future members of the same series. A shift that
        // has already started still participates in collision detection.
        let protected = existing.filter { !($0.cycleID == cycle.id && $0.startsAt >= now) }
        var candidates: [ScheduledShift] = []
        var accepted: [ScheduledShift] = []
        var conflicts = Set<UUID>()
        for offset in 0...days {
            guard let template = cycle.dayTemplates[offset % cycle.dayTemplates.count],
                  let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let start = calendar.date(
                    bySettingHour: template.startHour, minute: template.startMinute, second: 0,
                    of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first,
                    direction: .forward
                  ), calendar.isDate(start, inSameDayAs: day), start >= now else { continue }
            let shift = ScheduledShift(
                startsAt: start, plannedHours: template.plannedHours,
                breakMinutes: template.breakMinutes, title: template.name,
                note: template.note, tags: template.tags,
                templateID: template.id, cycleID: cycle.id
            )
            candidates.append(shift)
            // Accepted candidates also protect against self-overlapping cycles.
            if (protected + accepted).contains(where: { overlaps(shift, $0) }) {
                conflicts.insert(shift.id)
            } else {
                accepted.append(shift)
            }
        }
        return ShiftCyclePreview(shifts: candidates, conflictingShiftIDs: conflicts)
    }

    private static func overlaps(_ lhs: ScheduledShift, _ rhs: ScheduledShift) -> Bool {
        lhs.startsAt < rhs.endsAt && rhs.startsAt < lhs.endsAt
    }
}

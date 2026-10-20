import Foundation

/// One persisted value keeps cycle definitions and their dated members consistent.
struct ShiftRoster: Codable {
    var shifts: [ScheduledShift]
    var cycles: [ShiftCycle]

    func applying(_ cycle: ShiftCycle, skipConflicts: Bool, asOf now: Date) throws -> ShiftRoster {
        let preview = try ShiftCyclePlanner.preview(cycle, existing: shifts, asOf: now)
        guard skipConflicts || preview.conflictingShiftIDs.isEmpty else { throw ShiftCycleError.conflicts }
        let additions = skipConflicts ? preview.nonconflictingShifts : preview.shifts
        guard !additions.isEmpty else { throw ShiftCycleError.noFutureShifts }
        var result = self
        result.shifts.removeAll { $0.cycleID == cycle.id && $0.startsAt >= now }
        result.shifts.append(contentsOf: additions)
        result.shifts.sort { $0.startsAt < $1.startsAt }
        result.cycles.removeAll { $0.id == cycle.id }
        result.cycles.append(cycle)
        return result
    }

    func endingCycle(id: UUID, asOf now: Date) -> ShiftRoster {
        ShiftRoster(
            shifts: shifts.filter { !($0.cycleID == id && $0.startsAt >= now) },
            cycles: cycles.filter { $0.id != id }
        )
    }
}

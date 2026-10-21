import Foundation

struct ConsumedShiftOccurrence: Codable, Hashable {
    let cycleID: UUID
    let startsAt: Date
}

/// One persisted value keeps cycle definitions and their dated members consistent.
struct ShiftRoster: Codable {
    var shifts: [ScheduledShift]
    var cycles: [ShiftCycle]
    var consumed: [ConsumedShiftOccurrence]

    init(shifts: [ScheduledShift], cycles: [ShiftCycle], consumed: [ConsumedShiftOccurrence] = []) {
        self.shifts = shifts; self.cycles = cycles; self.consumed = consumed
    }
    private enum CodingKeys: String, CodingKey { case shifts, cycles, consumed }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        shifts = try values.decode([ScheduledShift].self, forKey: .shifts)
        cycles = try values.decode([ShiftCycle].self, forKey: .cycles)
        consumed = try values.decodeIfPresent([ConsumedShiftOccurrence].self, forKey: .consumed) ?? []
    }

    func consuming(shiftID: UUID) -> ShiftRoster {
        guard let shift = shifts.first(where: { $0.id == shiftID }) else { return self }
        var result = self
        result.shifts.removeAll { $0.id == shiftID }
        if let cycleID = shift.cycleID {
            let occurrence = ConsumedShiftOccurrence(cycleID: cycleID, startsAt: shift.cycleOccurrenceDate ?? shift.startsAt)
            if !result.consumed.contains(occurrence) { result.consumed.append(occurrence) }
        }
        return result
    }

    func applying(_ cycle: ShiftCycle, skipConflicts: Bool, asOf now: Date) throws -> ShiftRoster {
        let preview = try ShiftCyclePlanner.preview(cycle, existing: shifts, consumed: consumed, asOf: now)
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
            cycles: cycles.filter { $0.id != id }, consumed: consumed
        )
    }
}

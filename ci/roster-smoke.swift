import Foundation

var checked = 0
func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError("FAIL: \(message)") }
    checked += 1
}
func berlin(_ text: String) -> Date {
    let f = ISO8601DateFormatter()
    return f.date(from: text)!
}
func cycle(_ slots: [ShiftTemplate?], start: String = "2026-10-26T00:00:00+01:00", end: String = "2026-11-08T00:00:00+01:00") -> ShiftCycle {
    ShiftCycle(name: "Früh / frei", anchorDate: berlin(start), endDate: berlin(end), timeZoneIdentifier: "Europe/Berlin", dayTemplates: slots)
}
let early = ShiftTemplate(name: "Früh", startHour: 7, startMinute: 30, plannedHours: 8, breakMinutes: 30, tags: ["A"])
let late = ShiftTemplate(name: "Spät", startHour: 15, startMinute: 0, plannedHours: 7)
let week: [ShiftTemplate?] = [early, early, early, early, early, nil, nil]
let now = berlin("2026-10-25T00:00:00+02:00")
let regular = cycle(week)
let p = try ShiftCyclePlanner.preview(regular, existing: [], asOf: now)
expect(p.shifts.count == 10, "two inclusive weeks contain ten work days")
expect(p.conflictingShiftIDs.isEmpty, "empty diary has no conflicts")
expect(p.shifts.first?.startsAt == berlin("2026-10-26T07:30:00+01:00"), "first local start")
expect(p.shifts.last?.startsAt == berlin("2026-11-06T07:30:00+01:00"), "inclusive end avoids weekend")
expect(p.shifts.allSatisfy { $0.cycleID == regular.id && $0.templateID == early.id }, "snapshots link series and template")
expect(p.shifts.first?.endsAt == berlin("2026-10-26T16:00:00+01:00"), "elapsed duration includes break")
expect(p.shifts.first?.tags == ["A"], "template values copied")
expect(p.shifts.allSatisfy { $0.reminderMinutesBefore == nil }, "bulk plans do not opt into notifications")
let fortnight = cycle(week + [late, late, late, late, late, nil, nil], end: "2026-11-22T00:00:00+01:00")
let f = try ShiftCyclePlanner.preview(fortnight, existing: [], asOf: now)
expect(f.shifts.count == 20, "four weeks alternate two-week pattern")
expect(f.shifts[5].title == "Spät" && f.shifts[10].title == "Früh", "second week and wrap use correct templates")
let touching = ScheduledShift(startsAt: berlin("2026-10-26T16:00:00+01:00"), plannedHours: 1)
let touchingPreview = try ShiftCyclePlanner.preview(regular, existing: [touching], asOf: now)
expect(touchingPreview.conflictingShiftIDs.isEmpty, "touching endpoints do not overlap")
let overnight = ScheduledShift(startsAt: berlin("2026-10-25T23:00:00+01:00"), plannedHours: 10)
let conflict = try ShiftCyclePlanner.preview(regular, existing: [overnight], asOf: now)
expect(conflict.conflictingShiftIDs.count == 1, "previous-day overnight shift conflicts")
expect(conflict.nonconflictingShifts.count == 9, "explicit skip preview excludes conflict")
let reapply = try ShiftCyclePlanner.preview(regular, existing: p.shifts, asOf: now)
expect(reapply.conflictingShiftIDs.isEmpty, "future same-series shifts are replaceable")
let afterStart = try ShiftCyclePlanner.preview(regular, existing: [], asOf: berlin("2026-10-26T08:00:00+01:00"))
expect(afterStart.shifts.count == 9, "do not generate starts in the past")
let gapTemplate = ShiftTemplate(name: "Nacht", startHour: 2, startMinute: 30, plannedHours: 3)
let gap = cycle(Array(repeating: gapTemplate, count: 7), start: "2027-03-28T00:00:00+01:00", end: "2027-03-28T00:00:00+01:00")
let gapPlan = try ShiftCyclePlanner.preview(gap, existing: [], asOf: now)
expect(gapPlan.shifts.first?.startsAt == berlin("2027-03-28T03:00:00+02:00"), "missing DST time advances to next valid time")
let fold = cycle(Array(repeating: gapTemplate, count: 7), start: "2027-10-31T00:00:00+02:00", end: "2027-10-31T00:00:00+02:00")
let foldPreview = try ShiftCyclePlanner.preview(fold, existing: [], asOf: now)
expect(foldPreview.shifts.first?.startsAt == berlin("2027-10-31T02:30:00+02:00"), "repeated local time chooses first occurrence")
var bad = regular
bad.dayTemplates = []
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("empty cycle accepted") } catch { checked += 1 }
bad = regular; bad.dayTemplates = Array(repeating: nil, count: 7)
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("all-rest cycle accepted") } catch { checked += 1 }
bad = regular; bad.timeZoneIdentifier = "Invalid/Zone"
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("invalid zone accepted") } catch { checked += 1 }
bad = regular; bad.endDate = berlin("2026-10-25T00:00:00+02:00")
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("reverse range accepted") } catch { checked += 1 }
bad = regular; bad.endDate = berlin("2027-10-26T00:00:00+02:00")
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("overlong range accepted") } catch { checked += 1 }
bad = regular; bad.name = "   "
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("empty name accepted") } catch { checked += 1 }
bad = regular; bad.dayTemplates = Array(repeating: early, count: 8)
do { _ = try ShiftCyclePlanner.preview(bad, existing: [], asOf: now); fatalError("partial week accepted") } catch { checked += 1 }
var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(touching)) as! [String: Any]
json.removeValue(forKey: "cycleID")
let legacy = try JSONDecoder().decode(ScheduledShift.self, from: JSONSerialization.data(withJSONObject: json))
expect(legacy.cycleID == nil && legacy.startsAt == touching.startsAt, "old saved shifts decode without cycle identity")
let restored = try JSONDecoder().decode(ShiftCycle.self, from: JSONEncoder().encode(regular))
expect(restored == regular && restored.dayTemplates[5] == nil, "saved rest-day slots round trip")


let blankRoster = ShiftRoster(shifts: [overnight], cycles: [])
do { _ = try blankRoster.applying(regular, skipConflicts: false, asOf: now); fatalError("conflicting apply accepted") }
catch ShiftCycleError.conflicts { checked += 1 }
let applied = try blankRoster.applying(regular, skipConflicts: true, asOf: now)
expect(applied.shifts.count == 10 && applied.cycles.count == 1, "apply retains unrelated shift and skips collision")
let appliedAgain = try applied.applying(regular, skipConflicts: true, asOf: now)
expect(appliedAgain.shifts.count == applied.shifts.count, "reapply does not duplicate generated dates")
let midday = berlin("2026-10-27T12:00:00+01:00")
let historical = applied.shifts.filter { $0.startsAt < midday }
var revised = regular
revised.dayTemplates = Array(repeating: late, count: 7)
let edited = try applied.applying(revised, skipConflicts: true, asOf: midday)
expect(historical.allSatisfy { old in edited.shifts.contains { $0.id == old.id } }, "edit preserves past and already started entries by identity")
expect(edited.cycles.first?.dayTemplates.compactMap { $0 }.first?.id == late.id, "edit persists updated template snapshots")
let ended = edited.endingCycle(id: regular.id, asOf: midday)
expect(ended.cycles.isEmpty && ended.shifts.count == historical.count, "end removes only future members and definition")
expect(ended.shifts.contains { $0.id == overnight.id }, "unrelated historical shift survives cancellation")
let roundTripRoster = try JSONDecoder().decode(ShiftRoster.self, from: JSONEncoder().encode(edited))
expect(roundTripRoster.shifts.map(\.id) == edited.shifts.map(\.id) && roundTripRoster.cycles == edited.cycles, "atomic snapshot reopens with definitions and member identities")
let exhaustedDate = berlin("2027-01-01T00:00:00+01:00")
do { _ = try applied.applying(regular, skipConflicts: true, asOf: exhaustedDate); fatalError("empty future plan accepted") }
catch ShiftCycleError.noFutureShifts { checked += 1 }
let suiteName = "roster-smoke-\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
defer { defaults.removePersistentDomain(forName: suiteName) }
defaults.set(try JSONEncoder().encode([overnight]), forKey: "scheduled_shifts_v1")
let storage = ShiftRosterStorage(defaults: defaults)
expect(storage.load().shifts.first?.id == overnight.id && storage.load().cycles.isEmpty, "legacy storage migrates without losing individual shift")
try storage.save(edited)
expect(storage.load().cycles == edited.cycles && storage.load().shifts.count == edited.shifts.count, "single-key persistence reopens complete roster")
let longTemplate = ShiftTemplate(name: "Lang", startHour: 23, startMinute: 0, plannedHours: 16, breakMinutes: 240)
let shortTemplate = ShiftTemplate(name: "Früh", startHour: 7, startMinute: 0, plannedHours: 8)
let crossing = cycle([longTemplate, shortTemplate, nil, nil, nil, nil, nil])
let crossingPreview = try ShiftCyclePlanner.preview(crossing, existing: [], asOf: now)
expect(crossingPreview.conflictingShiftIDs.count == 2, "intra-pattern overnight collisions detected across weeks")
let foreignBlockers = p.shifts.map { shift -> ScheduledShift in
    var value = shift; value.cycleID = UUID(); return value
}
do { _ = try ShiftRoster(shifts: foreignBlockers, cycles: []).applying(regular, skipConflicts: true, asOf: now); fatalError("fully blocked cycle applied") }
catch ShiftCycleError.noFutureShifts { checked += 1 }
let corrupt = Data("not-json".utf8)
defaults.set(corrupt, forKey: ShiftRosterStorage.key)
_ = storage.load()
expect(defaults.data(forKey: ShiftRosterStorage.key + "_recovery") == corrupt, "invalid saved snapshot is retained byte-for-byte for recovery")
print("PASS: \(checked) roster rule and persistence checks")

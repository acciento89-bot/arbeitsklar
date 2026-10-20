package de.kamilunavo.arbeitsklar

import org.junit.Assert.*
import org.junit.Test
import java.time.*

class RosterRulesTest {
    private val start = LocalDate.of(2026, 10, 26)
    private val now = Instant.parse("2026-10-25T00:00:00Z").toEpochMilli()
    private val early = RosterTemplate(name = "Early", hour = 7, minute = 30, hours = 8.0, breakMinutes = 30)
    private fun cycle() = RosterCycle(name = "Week", start = start, end = start.plusDays(13), zone = "Europe/Berlin",
        slots = listOf(early, early, early, early, early, null, null))
    @Test fun calendarAndReapply() {
        val cycle = cycle()
        val first = RosterState(emptyList(), emptyList()).applying(cycle, false, now)
        assertEquals(10, first.shifts.size)
        assertEquals(Instant.parse("2026-10-26T06:30:00Z").toEpochMilli(), first.shifts.first().startsAt)
        assertEquals(8.5 * 3600000, (first.shifts.first().endsAt - first.shifts.first().startsAt).toDouble(), 0.0)
        assertEquals(10, first.applying(cycle, false, now).shifts.size)
    }
    @Test fun conflictsRequireExplicitSkip() {
        val existing = PlannedShift(startsAt = Instant.parse("2026-10-26T06:00:00Z").toEpochMilli(), hours = 2.0, title = "Other")
        val state = RosterState(listOf(existing), emptyList())
        assertThrows(IllegalArgumentException::class.java) { state.applying(cycle(), false, now) }
        assertEquals(10, state.applying(cycle(), true, now).shifts.size)
    }
    @Test fun endPreservesStartedAndUnrelated() {
        val cycle = cycle()
        val applied = RosterState(emptyList(), emptyList()).applying(cycle, false, now)
        val cutoff = Instant.parse("2026-10-27T12:00:00Z").toEpochMilli()
        val ended = applied.ending(cycle.id, cutoff)
        assertEquals(2, ended.shifts.size)
        assertTrue(ended.cycles.isEmpty())
        assertTrue(ended.shifts.all { it.startsAt < cutoff })
    }
    @Test fun gapAndRepeatedHour() {
        val template = early.copy(hour = 2, minute = 30)
        val gap = cycle().copy(start = LocalDate.of(2027,3,28), end = LocalDate.of(2027,3,28), slots = List(7) { template })
        assertEquals(Instant.parse("2027-03-28T01:00:00Z").toEpochMilli(), RosterRules.preview(gap, emptyList(), now).shifts.first().startsAt)
        val repeated = gap.copy(start = LocalDate.of(2026,10,25), end = LocalDate.of(2026,10,25))
        assertEquals(Instant.parse("2026-10-25T00:30:00Z").toEpochMilli(), RosterRules.preview(repeated, emptyList(), now).shifts.first().startsAt)
    }
    @Test fun invalidRangesAndAllRestRejected() {
        val c = cycle()
        listOf(c.copy(end=start.minusDays(1)), c.copy(end=start.plusDays(183)), c.copy(slots=List(7){null}), c.copy(name=" "), c.copy(slots=List(8){early})).forEach {
            assertThrows(IllegalArgumentException::class.java) { RosterRules.preview(it, emptyList(), now) }
        }
    }
    @Test fun expiredApplyDoesNotClearPlan() {
        val c = cycle()
        val state = RosterState(emptyList(), emptyList()).applying(c, false, now)
        assertThrows(IllegalArgumentException::class.java) { state.applying(c, true, Instant.parse("2027-01-01T00:00:00Z").toEpochMilli()) }
        assertEquals(10, state.shifts.size)
    }
}

package de.kamilunavo.arbeitsklar

import java.time.*
import java.time.temporal.ChronoUnit
import java.util.UUID

data class PlannedShift(
    val id: String = UUID.randomUUID().toString(),
    val startsAt: Long,
    val hours: Double,
    val title: String,
    val breakMinutes: Int = 0,
    val cycleId: String? = null,
) {
    val endsAt: Long get() = startsAt + (hours * 3_600_000).toLong() + breakMinutes * 60_000L
}

data class RosterTemplate(
    val id: String = UUID.randomUUID().toString(),
    val name: String, val hour: Int, val minute: Int,
    val hours: Double, val breakMinutes: Int = 0,
)
data class RosterCycle(
    val id: String = UUID.randomUUID().toString(),
    val name: String, val start: LocalDate, val end: LocalDate,
    val zone: String, val slots: List<RosterTemplate?>,
)
data class RosterPreview(val shifts: List<PlannedShift>, val conflictingIds: Set<String>) {
    val applicable get() = shifts.filterNot { it.id in conflictingIds }
}
data class RosterState(val shifts: List<PlannedShift>, val cycles: List<RosterCycle>) {
    fun applying(cycle: RosterCycle, skipConflicts: Boolean, now: Long): RosterState {
        val preview = RosterRules.preview(cycle, shifts, now)
        require(skipConflicts || preview.conflictingIds.isEmpty()) { "conflicts" }
        val additions = if (skipConflicts) preview.applicable else preview.shifts
        require(additions.isNotEmpty()) { "no_future" }
        return RosterState(
            (shifts.filterNot { it.cycleId == cycle.id && it.startsAt >= now } + additions).sortedBy { it.startsAt },
            cycles.filterNot { it.id == cycle.id } + cycle,
        )
    }
    fun ending(id: String, now: Long) = RosterState(
        shifts.filterNot { it.cycleId == id && it.startsAt >= now }, cycles.filterNot { it.id == id },
    )
}

object RosterRules {
    fun preview(cycle: RosterCycle, existing: List<PlannedShift>, now: Long): RosterPreview {
        require(cycle.name.isNotBlank()) { "name" }
        require(cycle.slots.size in 7..28 && cycle.slots.size % 7 == 0) { "pattern" }
        require(cycle.slots.any { it != null }) { "no_work" }
        val zone = runCatching { ZoneId.of(cycle.zone) }.getOrElse { throw IllegalArgumentException("zone") }
        val days = ChronoUnit.DAYS.between(cycle.start, cycle.end)
        require(days in 0..182) { "range" }
        cycle.slots.filterNotNull().forEach {
            require(it.name.isNotBlank() && it.hour in 0..23 && it.minute in 0..59 &&
                it.hours.isFinite() && it.hours in 1.0..16.0 && it.breakMinutes in 0..240) { "template" }
        }
        val protected = existing.filterNot { it.cycleId == cycle.id && it.startsAt >= now }
        val all = mutableListOf<PlannedShift>()
        val accepted = mutableListOf<PlannedShift>()
        val conflicts = mutableSetOf<String>()
        for (offset in 0..days.toInt()) {
            val template = cycle.slots[offset % cycle.slots.size] ?: continue
            val local = cycle.start.plusDays(offset.toLong()).atTime(template.hour, template.minute)
            val offsets = zone.rules.getValidOffsets(local)
            // Match iOS: first valid time after a DST gap; first occurrence in an overlap.
            val time = if (offsets.isEmpty()) {
                zone.rules.getTransition(local).dateTimeAfter.atZone(zone)
            } else ZonedDateTime.ofLocal(local, zone, offsets.first())
            val millis = time.toInstant().toEpochMilli()
            if (millis < now) continue
            val shift = PlannedShift(startsAt=millis, hours=template.hours, title=template.name,
                breakMinutes=template.breakMinutes, cycleId=cycle.id)
            all += shift
            if ((protected + accepted).any { shift.startsAt < it.endsAt && it.startsAt < shift.endsAt }) {
                conflicts += shift.id
            } else accepted += shift
        }
        return RosterPreview(all, conflicts)
    }
}

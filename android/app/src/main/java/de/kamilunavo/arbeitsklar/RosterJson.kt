package de.kamilunavo.arbeitsklar

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/** A single JSON value commits definitions and their dated shifts together. */
object RosterJson {
    fun encode(state: RosterState): String = JSONObject()
        .put("shifts", JSONArray().apply { state.shifts.forEach { put(shiftJson(it)) } })
        .put("cycles", JSONArray().apply { state.cycles.forEach { cycle -> put(
            JSONObject().put("id",cycle.id).put("name",cycle.name).put("start",cycle.start.toString())
                .put("end",cycle.end.toString()).put("zone",cycle.zone)
                .put("slots",JSONArray().apply { cycle.slots.forEach { template ->
                    put(template?.let { JSONObject().put("id",it.id).put("name",it.name)
                        .put("hour",it.hour).put("minute",it.minute).put("hours",it.hours).put("break",it.breakMinutes) } ?: JSONObject.NULL)
                } })
        ) } }).toString()

    fun decode(text: String): RosterState {
        val root = JSONObject(text)
        val shifts = root.getJSONArray("shifts")
        val cycles = root.getJSONArray("cycles")
        return RosterState(readShifts(shifts), List(cycles.length()) { i ->
            val c = cycles.getJSONObject(i)
            val slots = c.getJSONArray("slots")
            RosterCycle(c.getString("id"),c.getString("name"),LocalDate.parse(c.getString("start")),
                LocalDate.parse(c.getString("end")),c.getString("zone"),List(slots.length()) { j ->
                    if (slots.isNull(j)) null else slots.getJSONObject(j).let { t ->
                        RosterTemplate(t.getString("id"),t.getString("name"),t.getInt("hour"),t.getInt("minute"),t.getDouble("hours"),t.optInt("break"))
                    }
                })
        })
    }
    fun legacy(text: String) = RosterState(readShifts(JSONArray(text)), emptyList())
    private fun readShifts(a: JSONArray) = List(a.length()) { i ->
        val o = a.getJSONObject(i)
        PlannedShift(o.getString("id"),o.getLong("starts"),o.getDouble("hours"),o.optString("title"),
            o.optInt("break"),if(o.isNull("cycle")) null else o.optString("cycle").takeIf { it.isNotBlank() })
    }
    private fun shiftJson(s: PlannedShift) = JSONObject().put("id",s.id).put("starts",s.startsAt)
        .put("hours",s.hours).put("title",s.title).put("break",s.breakMinutes).put("cycle",s.cycleId ?: JSONObject.NULL)
}

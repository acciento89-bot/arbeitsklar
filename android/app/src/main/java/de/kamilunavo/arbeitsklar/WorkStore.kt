package de.kamilunavo.arbeitsklar

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import kotlin.math.max

data class Profile(
    val hourlyRate: Double = 20.0,
    val currency: String = "EUR",
    val plannedHours: Double = 8.0,
    val monthlyGoal: Double = 0.0,
    val shiftGoal: Double = 0.0,
    val overtimeMultiplier: Double = 1.0,
    val nightBonus: Double = 0.0,
    val weekendBonus: Double = 0.0,
    val reminders: Boolean = false,
)

data class WorkBreak(val startedAt: Long, val endedAt: Long? = null)

data class WorkSession(
    val id: String = UUID.randomUUID().toString(),
    val startedAt: Long = System.currentTimeMillis(),
    val endedAt: Long? = null,
    val hourlyRate: Double,
    val currency: String,
    val plannedHours: Double,
    val breaks: List<WorkBreak> = emptyList(),
    val title: String = "",
    val note: String = "",
    val tips: Double = 0.0,
) {
    val active get() = endedAt == null
    val paused get() = breaks.any { it.endedAt == null }
    fun breakMillis(now: Long = System.currentTimeMillis()) = breaks.sumOf { max(0, (it.endedAt ?: now) - it.startedAt) }
    fun workMillis(now: Long = System.currentTimeMillis()) = max(0, (endedAt ?: now) - startedAt - breakMillis(now))
    fun earnings(now: Long = System.currentTimeMillis()) = workMillis(now) / 3_600_000.0 * hourlyRate
}

data class PlannedShift(
    val id: String = UUID.randomUUID().toString(),
    val startsAt: Long,
    val hours: Double,
    val title: String,
)

class WorkStore(context: Context) {
    private val prefs = context.getSharedPreferences("arbeitsklar_v1", Context.MODE_PRIVATE)
    var profile: Profile = readProfile(); private set
    var sessions: List<WorkSession> = readSessions(); private set
    var planned: List<PlannedShift> = readPlanned(); private set
    var theme: String
        get() = prefs.getString("theme", "classic") ?: "classic"
        set(value) = prefs.edit().putString("theme", value).apply()
    var onboarded: Boolean
        get() = prefs.getBoolean("onboarded", false)
        set(value) = prefs.edit().putBoolean("onboarded", value).apply()

    val active get() = sessions.firstOrNull { it.active }
    val completed get() = sessions.filterNot { it.active }.sortedByDescending { it.startedAt }

    fun start(title: String = "", hours: Double = profile.plannedHours) {
        if (active != null) return
        sessions = listOf(WorkSession(hourlyRate = profile.hourlyRate, currency = profile.currency, plannedHours = hours, title = title)) + sessions
        saveSessions()
    }
    fun start(shift: PlannedShift) { start(shift.title, shift.hours); planned = planned.filterNot { it.id == shift.id }; savePlanned() }
    fun pause() = mutateActive { it.copy(breaks = it.breaks + WorkBreak(System.currentTimeMillis())) }
    fun resume() = mutateActive { session ->
        session.copy(breaks = session.breaks.map { if (it.endedAt == null) it.copy(endedAt = System.currentTimeMillis()) else it })
    }
    fun stop() = mutateActive { session ->
        session.copy(
            endedAt = System.currentTimeMillis(),
            breaks = session.breaks.map { if (it.endedAt == null) it.copy(endedAt = System.currentTimeMillis()) else it }
        )
    }
    fun addTip(amount: Double) { if (amount > 0) mutateActive { it.copy(tips = it.tips + amount) } }
    fun delete(id: String) { sessions = sessions.filterNot { it.id == id }; saveSessions() }
    fun addPlanned(startsAt: Long, hours: Double, title: String) {
        planned = (planned + PlannedShift(startsAt = startsAt, hours = hours.coerceIn(1.0, 16.0), title = title.trim())).sortedBy { it.startsAt }
        savePlanned()
    }
    fun deletePlanned(id: String) { planned = planned.filterNot { it.id == id }; savePlanned() }
    fun updateProfile(value: Profile) { profile = value; prefs.edit().putString("profile", profileJson(value).toString()).apply() }
    fun clearHistory() { sessions = sessions.filter { it.active }; saveSessions() }

    private fun mutateActive(block: (WorkSession) -> WorkSession) {
        val current = active ?: return
        sessions = sessions.map { if (it.id == current.id) block(it) else it }
        saveSessions()
    }
    private fun saveSessions() = prefs.edit().putString("sessions", JSONArray().apply { sessions.forEach { put(sessionJson(it)) } }.toString()).apply()
    private fun savePlanned() = prefs.edit().putString("planned", JSONArray().apply { planned.forEach { put(JSONObject().put("id", it.id).put("starts", it.startsAt).put("hours", it.hours).put("title", it.title)) } }.toString()).apply()
    private fun readProfile(): Profile = runCatching {
        val o = JSONObject(prefs.getString("profile", "{}")!!)
        Profile(o.optDouble("rate", 20.0), o.optString("currency", "EUR"), o.optDouble("hours", 8.0), o.optDouble("monthly"), o.optDouble("shift"), o.optDouble("overtime", 1.0), o.optDouble("night"), o.optDouble("weekend"), o.optBoolean("reminders"))
    }.getOrDefault(Profile())
    private fun readSessions(): List<WorkSession> = runCatching {
        val a = JSONArray(prefs.getString("sessions", "[]")); List(a.length()) { i ->
            val o=a.getJSONObject(i); val b=o.optJSONArray("breaks") ?: JSONArray()
            WorkSession(o.getString("id"),o.getLong("starts"),if(o.has("ends"))o.getLong("ends")else null,o.getDouble("rate"),o.getString("currency"),o.getDouble("hours"),List(b.length()){j->val x=b.getJSONObject(j);WorkBreak(x.getLong("starts"),if(x.has("ends"))x.getLong("ends")else null)},o.optString("title"),o.optString("note"),o.optDouble("tips"))
        }
    }.getOrDefault(emptyList())
    private fun readPlanned(): List<PlannedShift> = runCatching {
        val a=JSONArray(prefs.getString("planned","[]"));List(a.length()){i->val o=a.getJSONObject(i);PlannedShift(o.getString("id"),o.getLong("starts"),o.getDouble("hours"),o.optString("title"))}
    }.getOrDefault(emptyList())
    private fun profileJson(p: Profile)=JSONObject().put("rate",p.hourlyRate).put("currency",p.currency).put("hours",p.plannedHours).put("monthly",p.monthlyGoal).put("shift",p.shiftGoal).put("overtime",p.overtimeMultiplier).put("night",p.nightBonus).put("weekend",p.weekendBonus).put("reminders",p.reminders)
    private fun sessionJson(s:WorkSession)=JSONObject().put("id",s.id).put("starts",s.startedAt).apply{if(s.endedAt!=null)put("ends",s.endedAt)}.put("rate",s.hourlyRate).put("currency",s.currency).put("hours",s.plannedHours).put("title",s.title).put("note",s.note).put("tips",s.tips).put("breaks",JSONArray().apply{s.breaks.forEach{b->put(JSONObject().put("starts",b.startedAt).apply{if(b.endedAt!=null)put("ends",b.endedAt)})}})
}

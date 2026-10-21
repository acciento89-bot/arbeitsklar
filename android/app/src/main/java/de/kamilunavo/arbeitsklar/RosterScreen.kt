package de.kamilunavo.arbeitsklar

import android.app.DatePickerDialog
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import java.time.*
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun RosterScreen(store: WorkStore, close: () -> Unit, reload: () -> Unit, modifier: Modifier) {
    var editing by rememberSaveable { mutableStateOf<String?>(null) }
    var ending by rememberSaveable { mutableStateOf<String?>(null) }
    var failure by rememberSaveable { mutableStateOf(false) }
    if (editing != null) {
        RosterEditor(store, editing!!, { editing = null }, reload, modifier)
        return
    }
    LazyColumn(modifier.fillMaxSize(), contentPadding=PaddingValues(20.dp), verticalArrangement=Arrangement.spacedBy(16.dp)) {
        item { TextButton(close) { Text(tr("Zurück zum Planer","Back to planner")) } }
        item { Text(tr("Schichtfolgen","Shift cycles"), style=MaterialTheme.typography.headlineLarge) }
        item { Text(tr("Wiederkehrende Arbeits- und freie Tage. Bereits erfasste Arbeitszeiten bleiben erhalten.","Repeating work and rest days. Recorded work sessions are retained.")) }
        item { Button({
            val today = LocalDate.now()
            val shift = RosterTemplate(name=if(Locale.getDefault().language=="de") "Tagschicht" else "Day shift",hour=8,minute=0,hours=store.profile.plannedHours,breakMinutes=30)
            val cycle = RosterCycle(name=if(Locale.getDefault().language=="de") "Meine Schichtfolge" else "My shift cycle",start=today,end=today.plusDays(27),zone=ZoneId.systemDefault().id,slots=listOf(shift,shift,shift,shift,shift,null,null))
            editing = encodeCycle(cycle)
        },Modifier.fillMaxWidth()) { Text(tr("Schichtfolge anlegen","Create shift cycle")) } }
        if(store.cycles.isEmpty()) item { Text(tr("Noch keine Schichtfolge angelegt.","No shift cycles yet.")) }
        items(store.cycles,key={it.id}) { cycle ->
            Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(18.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
                Text(cycle.name,style=MaterialTheme.typography.titleLarge)
                Text("${cycle.start} – ${cycle.end}\n${cycle.zone}")
                OutlinedButton({editing=encodeCycle(cycle)},Modifier.fillMaxWidth()) { Text(tr("Bearbeiten","Edit")) }
                TextButton({ending=cycle.id},Modifier.fillMaxWidth()) { Text(tr("Schichtfolge beenden","End shift cycle")) }
            } }
        }
    }
    if(ending!=null) AlertDialog(onDismissRequest={ending=null},title={Text(tr("Schichtfolge beenden?","End shift cycle?"))},text={Text(tr("Nur zukünftige Termine dieser Folge werden entfernt. Begonnene und vergangene Termine bleiben erhalten.","Only future members of this cycle are removed. Started and historical shifts are retained."))},confirmButton={TextButton({
        runCatching { store.endCycle(ending!!); reload() }.onFailure { failure=true };ending=null
    }){Text(tr("Beenden","End cycle"))}},dismissButton={TextButton({ending=null}){Text(tr("Abbrechen","Cancel"))}})
    if(failure) AlertDialog(onDismissRequest={failure=false},text={Text(tr("Der Plan konnte nicht gespeichert werden.","The plan could not be saved."))},confirmButton={TextButton({failure=false}){Text("OK")}})
}

private fun encodeCycle(cycle: RosterCycle) = RosterJson.encode(RosterState(emptyList(),listOf(cycle)))

@Composable
private fun RosterEditor(store: WorkStore, initial: String, close: () -> Unit, reload: () -> Unit, modifier: Modifier) {
    var json by rememberSaveable(initial) { mutableStateOf(initial) }
    val draft = remember(json) { RosterJson.decode(json).cycles.single() }
    var preview by remember { mutableStateOf<RosterPreview?>(null) }
    var skip by rememberSaveable { mutableStateOf(false) }
    var error by rememberSaveable { mutableStateOf<String?>(null) }
    var customSlot by rememberSaveable { mutableStateOf<Int?>(null) }
    fun update(cycle: RosterCycle) { json=encodeCycle(cycle);preview=null;skip=false }
    val presets = listOf(
        RosterTemplate(id="early",name=tr("Frühschicht","Early shift"),hour=6,minute=0,hours=8.0,breakMinutes=30),
        RosterTemplate(id="late",name=tr("Spätschicht","Late shift"),hour=14,minute=0,hours=8.0,breakMinutes=30),
        RosterTemplate(id="night",name=tr("Nachtschicht","Night shift"),hour=22,minute=0,hours=8.0,breakMinutes=30),
    )
    val choices = (draft.slots.filterNotNull()+store.cycles.flatMap { it.slots.filterNotNull() }+presets).distinctBy { it.id }
    val context = LocalContext.current
    val dateFormat = DateTimeFormatter.ofPattern("EEE, d MMM HH:mm",Locale.getDefault()).withZone(ZoneId.of(draft.zone))
    LazyColumn(modifier.fillMaxSize().imePadding().testTag("cycle-scroll"),contentPadding=PaddingValues(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        item { TextButton(close) { Text(tr("Abbrechen","Cancel")) };Text(tr("Schichtfolge planen","Plan shift cycle"),style=MaterialTheme.typography.headlineMedium) }
        item { OutlinedTextField(draft.name,{update(draft.copy(name=it))},Modifier.fillMaxWidth().testTag("cycle-name"),label={Text(tr("Name","Name"))}) }
        item { Text(tr("Maximal 183 Kalendertage. Die Uhrzeiten bleiben in der gespeicherten Zeitzone, auch auf Reisen.","Up to 183 calendar days. Times stay in the saved time zone, including when travelling."));Text(draft.zone,style=MaterialTheme.typography.labelLarge) }
        item { OutlinedButton({DatePickerDialog(context,{_,y,m,d->update(draft.copy(start=LocalDate.of(y,m+1,d)))},draft.start.year,draft.start.monthValue-1,draft.start.dayOfMonth).show()},Modifier.fillMaxWidth()){Text(tr("Beginn: ","Start: ")+draft.start)} }
        item { OutlinedButton({DatePickerDialog(context,{_,y,m,d->update(draft.copy(end=LocalDate.of(y,m+1,d)))},draft.end.year,draft.end.monthValue-1,draft.end.dayOfMonth).show()},Modifier.fillMaxWidth()){Text(tr("Letzter Tag: ","Last day: ")+draft.end)} }
        item { Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {
            TextButton({if(draft.slots.size>7)update(draft.copy(slots=draft.slots.dropLast(7)))},enabled=draft.slots.size>7){Text("−")}
            Text(tr("Wochen im Muster: ","Weeks in pattern: ")+(draft.slots.size/7))
            TextButton({if(draft.slots.size<28)update(draft.copy(slots=draft.slots+List(7){null}))},enabled=draft.slots.size<28){Text("+")}
        } }
        item { Text(tr("Das Muster beginnt am Beginn-Datum und wiederholt sich bis zum letzten Tag.","The pattern starts on your start date and repeats through the last day.")) }
        items(draft.slots.indices.toList(),key={it}) { index ->
            var expanded by remember { mutableStateOf(false) }
            val label=draft.start.plusDays(index.toLong()).format(DateTimeFormatter.ofPattern("EEE",Locale.getDefault()))
            Column {
                OutlinedButton({expanded=true},Modifier.fillMaxWidth()) { Text("${index/7+1} · $label: "+(draft.slots[index]?.name ?: tr("Frei","Rest"))) }
                DropdownMenu(expanded,{expanded=false}) {
                    DropdownMenuItem(text={Text(tr("Frei","Rest"))},onClick={update(draft.copy(slots=draft.slots.mapIndexed{i,t->if(i==index)null else t}));expanded=false})
                    choices.forEach { template -> DropdownMenuItem(text={Text(template.name)},onClick={update(draft.copy(slots=draft.slots.mapIndexed{i,t->if(i==index)template else t}));expanded=false}) }
                    DropdownMenuItem(text={Text(tr("Eigene Vorlage…","Custom template…"))},onClick={customSlot=index;expanded=false})
                }
            }
        }
        item { Button({runCatching { store.previewCycle(draft) }.onSuccess{preview=it}.onFailure{error=it.message}},Modifier.fillMaxWidth().testTag("cycle-preview")){Text(tr("Datierte Vorschau","Dated preview"))} }
        item { Text(tr("Anwenden ersetzt zukünftige Termine derselben Folge, auch einzeln bearbeitete. Erinnerungen werden nicht automatisch aktiviert.","Applying replaces future members of this cycle, including individually edited shifts. Reminders are not enabled automatically."),style=MaterialTheme.typography.bodySmall) }
        preview?.let { value ->
            item { Text(tr("Termine: ","Shifts: ")+value.shifts.size+tr(" · Überschneidungen: "," · Conflicts: ")+value.conflictingIds.size) }
            if(value.conflictingIds.isNotEmpty()) item { Row(Modifier.fillMaxWidth()) { Text(tr("Überschneidungen überspringen","Skip conflicting shifts"),Modifier.weight(1f));Switch(skip,{skip=it}) } }
            items(value.shifts,key={it.id}) { shift -> Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(12.dp)) {
                Text(dateFormat.format(Instant.ofEpochMilli(shift.startsAt)));Text(shift.title)
                if(shift.id in value.conflictingIds) Text(tr("Überschneidung","Conflicting shift"),color=MaterialTheme.colorScheme.error)
            } } }
            item { Button({runCatching { store.applyCycle(draft,skip) }.onSuccess{reload();close()}.onFailure{error=it.message;preview=null}},Modifier.fillMaxWidth().testTag("cycle-apply"),enabled=value.shifts.isNotEmpty()&&(skip||value.conflictingIds.isEmpty())&&(!skip||value.applicable.isNotEmpty())){Text(tr("Anwenden","Apply"))} }
        }
    }
    if(customSlot!=null) CustomRosterTemplate({customSlot=null}) { template ->
        val index=customSlot!!;update(draft.copy(slots=draft.slots.mapIndexed{i,t->if(i==index)template else t}));customSlot=null
    }
    if(error!=null) AlertDialog(onDismissRequest={error=null},title={Text(tr("Bitte prüfen","Please check"))},text={Text(when(error){
        "conflicts"->tr("Überschneidungen anpassen oder ausdrücklich überspringen.","Adjust conflicts or explicitly choose to skip them.")
        "no_future"->tr("Keine anwendbaren zukünftigen Termine. Der bisherige Plan bleibt erhalten.","No applicable future shifts. Your existing plan is retained.")
        else->tr("Name, Muster und Zeitraum prüfen. Mindestens ein Arbeitstag und maximal 183 Kalendertage.","Check name, pattern and range. At least one work day and at most 183 calendar days.")
    })},confirmButton={TextButton({error=null}){Text("OK")}})
}

@Composable private fun CustomRosterTemplate(close:()->Unit,save:(RosterTemplate)->Unit) {
    var name by rememberSaveable {mutableStateOf("")};var hour by rememberSaveable{mutableStateOf("8")};var minute by rememberSaveable{mutableStateOf("0")}
    var hours by rememberSaveable{mutableStateOf("8")};var pause by rememberSaveable{mutableStateOf("30")}
    val h=hour.toIntOrNull();val m=minute.toIntOrNull();val length=hours.replace(',','.').toDoubleOrNull();val rest=pause.toIntOrNull()
    val valid=name.isNotBlank()&&h!=null&&h in 0..23&&m!=null&&m in 0..59&&length!=null&&length.isFinite()&&length in 1.0..16.0&&rest!=null&&rest in 0..240
    AlertDialog(close,title={Text(tr("Eigene Schichtvorlage","Custom shift template"))},text={Column(verticalArrangement=Arrangement.spacedBy(8.dp)){
        OutlinedTextField(name,{name=it},label={Text(tr("Name","Name"))})
        Row {OutlinedTextField(hour,{hour=it},Modifier.weight(1f),label={Text(tr("Stunde","Hour"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number));OutlinedTextField(minute,{minute=it},Modifier.weight(1f),label={Text(tr("Minute","Minute"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number))}
        OutlinedTextField(hours,{hours=it},label={Text(tr("Arbeitsstunden","Work hours"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal))
        OutlinedTextField(pause,{pause=it},label={Text(tr("Pause in Minuten","Break minutes"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Number))
    }},confirmButton={TextButton({save(RosterTemplate(name=name.trim(),hour=h!!,minute=m!!,hours=length!!,breakMinutes=rest!!))},enabled=valid){Text(tr("Übernehmen","Use template"))}},dismissButton={TextButton(close){Text(tr("Abbrechen","Cancel"))}})
}

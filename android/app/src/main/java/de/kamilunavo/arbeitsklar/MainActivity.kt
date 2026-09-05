package de.kamilunavo.arbeitsklar

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.DateFormat
import java.text.NumberFormat
import java.util.*
import kotlin.math.max

private val Bg=Color(0xFF090E17)
private val Surface=Color(0xFF131B29)
private val Subtle=Color(0xFF202A3A)
private val Blue=Color(0xFF4A9CFF)
private val Mint=Color(0xFF3AD9A1)
private val Amber=Color(0xFFFFB845)
private val Secondary=Color.White.copy(alpha=.64f)
private val Border=Color.White.copy(alpha=.08f)
private val german get()=Locale.getDefault().language=="de"
private fun tr(de:String,en:String)=if(german)de else en

class MainActivity:ComponentActivity(){
    override fun onCreate(savedInstanceState:Bundle?){super.onCreate(savedInstanceState);setContent{ArbeitsKlarApp()}}
}

private enum class Tab(val icon:ImageVector){Today(Icons.Default.Bolt),Planner(Icons.Default.CalendarMonth),History(Icons.Default.History),Settings(Icons.Default.Tune)}

@Composable private fun ArbeitsKlarApp(){
    val context=LocalContext.current
    val store=remember{WorkStore(context)}
    val billing=remember{BillingManager(context)}
    var refresh by remember{mutableIntStateOf(0)}
    val reload: () -> Unit = { refresh += 1 }
    val colors=darkColorScheme(primary=Blue,secondary=Mint,background=Bg,surface=Surface,onBackground=Color.White,onSurface=Color.White)
    MaterialTheme(colorScheme=colors){
        if(!store.onboarded)Onboarding(store,reload)
        else MainShell(store,billing,refresh,reload)
    }
}

@Composable private fun Onboarding(store:WorkStore,reload:()->Unit){
    var page by remember{mutableIntStateOf(0)}
    val pages=listOf(
        Triple(tr("DEIN VERDIENST","YOUR EARNINGS"),tr("Sieh deinen Lohn wachsen.","Watch your pay grow."),Icons.Default.TrendingUp),
        Triple(tr("PAUSEN IM GRIFF","BREAKS UNDER CONTROL"),tr("Start, Pause und Feierabend mit einem Tippen.","Start, pause and clock out with one tap."),Icons.Default.PauseCircle),
        Triple(tr("BESSER PLANEN","PLAN AHEAD"),tr("Schichten planen und deinen Monat im Blick behalten.","Plan shifts and keep your month in view."),Icons.Default.CalendarMonth)
    )
    Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(Blue.copy(alpha=.22f),Bg),radius=900f))){
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(24.dp)){
            Row(verticalAlignment=Alignment.CenterVertically){Icon(Icons.Default.Bolt,null,tint=Mint);Text("ArbeitsKlar",fontWeight=FontWeight.Bold,fontSize=19.sp);Spacer(Modifier.weight(1f));if(page<2)TextButton({store.onboarded=true;reload()}){Text(tr("Überspringen","Skip"))}}
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(96.dp).background(Blue.copy(alpha=.14f),RoundedCornerShape(30.dp)),contentAlignment=Alignment.Center){Icon(pages[page].third,null,tint=if(page==1)Mint else Blue,modifier=Modifier.size(48.dp))}
            Text(pages[page].first,color=Mint,fontWeight=FontWeight.Bold,fontSize=12.sp,letterSpacing=1.5.sp,modifier=Modifier.padding(top=28.dp))
            Text(pages[page].second,fontSize=38.sp,lineHeight=43.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=10.dp))
            Text(tr("Privat, lokal gespeichert und ohne Konto.","Private, stored on your device, and no account required."),color=Secondary,fontSize=16.sp,modifier=Modifier.padding(top=14.dp))
            Spacer(Modifier.weight(1f))
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.Center){pages.indices.forEach{Box(Modifier.padding(4.dp).size(if(it==page)28.dp else 8.dp,8.dp).background(if(it==page)Blue else Color.White.copy(alpha=.16f),CircleShape))}}
            Button({if(page<2)page++ else{store.onboarded=true;reload()}},Modifier.fillMaxWidth().padding(top=20.dp).height(56.dp),shape=RoundedCornerShape(18.dp)){Text(if(page==2)tr("ArbeitsKlar starten","Start ArbeitsKlar")else tr("Weiter","Continue"),fontWeight=FontWeight.Bold)}
        }
    }
}

@Composable private fun MainShell(store:WorkStore,billing:BillingManager,refresh:Int,reload:()->Unit){
    var tab by remember{mutableStateOf(Tab.Today)}
    Scaffold(containerColor=Bg,bottomBar={NavigationBar(containerColor=Surface){Tab.entries.forEach{item->NavigationBarItem(tab==item,{tab=item},{Icon(item.icon,null)},label={Text(when(item){Tab.Today->tr("Heute","Today");Tab.Planner->tr("Planer","Planner");Tab.History->tr("Verlauf","History");Tab.Settings->tr("Einstellungen","Settings")} )},colors=NavigationBarItemDefaults.colors(selectedIconColor=Blue,selectedTextColor=Blue,indicatorColor=Blue.copy(alpha=.14f)))}}}){padding->
        when(tab){
            Tab.Today->TodayScreen(store,refresh,reload,Modifier.padding(padding))
            Tab.Planner->PlannerScreen(store,refresh,reload,Modifier.padding(padding))
            Tab.History->HistoryScreen(store,refresh,reload,Modifier.padding(padding))
            Tab.Settings->SettingsScreen(store,billing,refresh,reload,Modifier.padding(padding))
        }
    }
}

@Composable private fun TodayScreen(store:WorkStore,refresh:Int,reload:()->Unit,modifier:Modifier){
    var tick by remember{mutableLongStateOf(System.currentTimeMillis())}
    LaunchedEffect(store.active?.id,store.active?.paused,refresh){while(store.active!=null){tick=System.currentTimeMillis();kotlinx.coroutines.delay(1000)}}
    var tip by remember{mutableStateOf("")}
    val active=store.active
    val today=store.completed.filter{sameDay(it.startedAt,System.currentTimeMillis())}+(listOfNotNull(active))
    val worked=today.sumOf{it.workMillis(tick)}
    val earnings=today.sumOf{it.earnings(tick)+it.tips}
    LazyColumn(modifier.fillMaxSize(),contentPadding=PaddingValues(20.dp,18.dp,20.dp,32.dp),verticalArrangement=Arrangement.spacedBy(18.dp)){
        item{Header(tr("HEUTE IM BLICK","TODAY AT A GLANCE"),tr("Dein Arbeitstag, glasklar.","Your workday, crystal clear."),tr("Zeit, Verdienst und Pausen – live und nur auf deinem Gerät.","Time, earnings and breaks — live and only on your device."))}
        item{HeroCard(store,tick,reload)}
        if(active!=null)item{GlassCard{Row(verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(tr("Trinkgeld","Tips"),fontWeight=FontWeight.Bold);Text(money(active.tips,active.currency),fontSize=22.sp,fontWeight=FontWeight.Bold,color=Mint)};listOf(2,5,10).forEach{amount->AssistChip({store.addTip(amount.toDouble());reload()},{Text("+$amount")},modifier=Modifier.padding(start=5.dp))}};Row(Modifier.padding(top=10.dp),verticalAlignment=Alignment.CenterVertically){OutlinedTextField(tip,{tip=it},Modifier.weight(1f),placeholder={Text(tr("Betrag","Amount"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal),singleLine=true);Button({tip.replace(',','.').toDoubleOrNull()?.let{store.addTip(it)};tip="";reload()},Modifier.padding(start=8.dp)){Text(tr("Hinzufügen","Add"))}}}}
        if(active==null&&store.planned.isNotEmpty())item{val next=store.planned.first();GlassCard{Text(tr("NÄCHSTE SCHICHT","NEXT SHIFT"),color=Mint,fontSize=11.sp,fontWeight=FontWeight.Bold);Text(next.title.ifBlank{tr("Geplante Schicht","Planned shift")},fontSize=21.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=5.dp));Text(dateTime(next.startsAt)+" · "+hours(next.hours),color=Secondary,modifier=Modifier.padding(top=5.dp));Button({store.start(next);reload()},Modifier.fillMaxWidth().padding(top=12.dp)){Icon(Icons.Default.PlayArrow,null);Text(tr(" Jetzt starten"," Start now"))}}}
        item{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(12.dp)){Metric(Modifier.weight(1f),Icons.Default.Timer,tr("Arbeitszeit","Work time"),duration(worked));Metric(Modifier.weight(1f),Icons.Default.Euro,tr("Verdienst","Earnings"),money(earnings,store.profile.currency))}}
        item{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(12.dp)){Metric(Modifier.weight(1f),Icons.Default.Coffee,tr("Pausen","Breaks"),duration(today.sumOf{it.breakMillis(tick)}));Metric(Modifier.weight(1f),Icons.Default.MoreTime,tr("Überstunden","Overtime"),duration(max(0,worked-(store.profile.plannedHours*3_600_000).toLong())))}}
        if(store.profile.monthlyGoal>0)item{GoalCard(tr("Monatsziel","Monthly goal"),store.completed.filter{sameMonth(it.startedAt)}.sumOf{it.earnings()+it.tips},store.profile.monthlyGoal,store.profile.currency)}
        item{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.Center,verticalAlignment=Alignment.CenterVertically){Icon(Icons.Default.Lock,null,tint=Mint,modifier=Modifier.size(15.dp));Text(tr(" Deine Daten bleiben lokal auf diesem Gerät."," Your data stays on this device."),color=Secondary,fontSize=12.sp)}}
    }
}

@Composable private fun HeroCard(store:WorkStore,now:Long,reload:()->Unit){
    val s=store.active
    Card(colors=CardDefaults.cardColors(containerColor=Color.Transparent),shape=RoundedCornerShape(28.dp),modifier=Modifier.fillMaxWidth()){
        Column(Modifier.background(Brush.linearGradient(listOf(Blue.copy(alpha=.95f),Mint.copy(alpha=.88f)))).padding(22.dp)){
            Text(if(s==null)tr("BEREIT FÜR DEINE SCHICHT","READY FOR YOUR SHIFT")else if(s.paused)tr("PAUSE LÄUFT","BREAK IN PROGRESS")else tr("SCHICHT LÄUFT","SHIFT IN PROGRESS"),fontSize=11.sp,fontWeight=FontWeight.Bold,letterSpacing=1.2.sp)
            Text(if(s==null)money(0.0,store.profile.currency)else money(s.earnings(now)+s.tips,s.currency),fontSize=42.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=8.dp))
            Text(if(s==null)tr("Starte, wenn du bereit bist.","Start when you're ready.")else duration(s.workMillis(now))+" · "+hours(s.plannedHours),color=Color.White.copy(alpha=.82f))
            if(s==null)Button({store.start();reload()},Modifier.fillMaxWidth().padding(top=22.dp).height(52.dp),colors=ButtonDefaults.buttonColors(containerColor=Color.White,contentColor=Bg)){Icon(Icons.Default.PlayArrow,null);Text(tr(" Schicht starten"," Start shift"),fontWeight=FontWeight.Bold)}
            else Row(Modifier.fillMaxWidth().padding(top=22.dp),horizontalArrangement=Arrangement.spacedBy(10.dp)){Button({if(s.paused)store.resume()else store.pause();reload()},Modifier.weight(1f),colors=ButtonDefaults.buttonColors(containerColor=Color.White.copy(alpha=.18f))){Icon(if(s.paused)Icons.Default.PlayArrow else Icons.Default.Pause,null);Text(if(s.paused)tr(" Weiter"," Resume")else tr(" Pause"," Break"))};Button({store.stop();reload()},Modifier.weight(1f),colors=ButtonDefaults.buttonColors(containerColor=Bg.copy(alpha=.75f))){Icon(Icons.Default.Stop,null);Text(tr(" Feierabend"," Clock out"))}}
        }
    }
}

@Composable private fun PlannerScreen(store:WorkStore,refresh:Int,reload:()->Unit,modifier:Modifier){
    var editor by remember{mutableStateOf(false)}
    LazyColumn(modifier.fillMaxSize(),contentPadding=PaddingValues(20.dp,18.dp,20.dp,32.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
        item{Row(verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Header(tr("SCHICHTPLAN","SHIFT PLAN"),tr("Vorausdenken. Entspannt starten.","Plan ahead. Start relaxed."),tr("Plane deine nächsten Einsätze und starte sie direkt.","Schedule upcoming shifts and start them directly."))};IconButton({editor=true}){Icon(Icons.Default.Add,null,tint=Blue)}}}
        if(store.planned.isEmpty())item{EmptyCard(Icons.Default.CalendarMonth,tr("Noch keine Schichten geplant","No shifts planned yet"),tr("Lege deine nächste Schicht mit Startzeit und Dauer an.","Add your next shift with its start time and duration."))}
        else items(store.planned,key={it.id}){s->GlassCard{Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(48.dp).background(Blue.copy(alpha=.14f),RoundedCornerShape(15.dp)),contentAlignment=Alignment.Center){Icon(Icons.Default.CalendarMonth,null,tint=Blue)};Column(Modifier.weight(1f).padding(start=13.dp)){Text(s.title.ifBlank{tr("Geplante Schicht","Planned shift")},fontWeight=FontWeight.Bold,fontSize=18.sp);Text(dateTime(s.startsAt)+" · "+hours(s.hours),color=Secondary,fontSize=13.sp)};IconButton({store.deletePlanned(s.id);reload()}){Icon(Icons.Default.Delete,null,tint=Secondary)}};OutlinedButton({store.start(s);reload()},Modifier.fillMaxWidth()){Text(tr("Jetzt starten","Start now"))}}}
    }
    if(editor)ShiftEditor({editor=false}){time,hours,title->store.addPlanned(time,hours,title);editor=false;reload()}
}

@Composable private fun ShiftEditor(close:()->Unit,save:(Long,Double,String)->Unit){
    var title by remember{mutableStateOf("")};var hours by remember{mutableStateOf("8")}
    AlertDialog(close,title={Text(tr("Schicht planen","Plan shift"),fontWeight=FontWeight.Bold)},text={Column{OutlinedTextField(title,{title=it},Modifier.fillMaxWidth(),label={Text(tr("Bezeichnung","Title"))});OutlinedTextField(hours,{hours=it},Modifier.fillMaxWidth().padding(top=10.dp),label={Text(tr("Dauer in Stunden","Duration in hours"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal));Text(tr("Start: morgen um 08:00 Uhr","Starts tomorrow at 8:00 AM"),color=Secondary,modifier=Modifier.padding(top=12.dp))}},confirmButton={Button({save(tomorrowAtEight(),hours.replace(',','.').toDoubleOrNull()?:8.0,title)}){Text(tr("Planen","Schedule"))}},dismissButton={TextButton(close){Text(tr("Abbrechen","Cancel"))}})
}

@Composable private fun HistoryScreen(store:WorkStore,refresh:Int,reload:()->Unit,modifier:Modifier){
    var query by remember{mutableStateOf("")};val sessions=remember(refresh,query){store.completed.filter{query.isBlank()||it.title.contains(query,true)||it.note.contains(query,true)}}
    val total=sessions.sumOf{it.earnings()+it.tips};val work=sessions.sumOf{it.workMillis()}
    LazyColumn(modifier.fillMaxSize(),contentPadding=PaddingValues(20.dp,18.dp,20.dp,32.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
        item{Header(tr("VERLAUF","HISTORY"),tr("Was du geleistet hast.","What you've accomplished."),tr("Schichten, Zeiten und Brutto-Schätzungen auf einen Blick.","Shifts, hours, and gross estimates at a glance."))}
        item{OutlinedTextField(query,{query=it},Modifier.fillMaxWidth(),placeholder={Text(tr("Schichten durchsuchen","Search shifts"))},leadingIcon={Icon(Icons.Default.Search,null)})}
        item{GlassCard{Row{Column(Modifier.weight(1f)){Text(tr("Schichten","Shifts"),color=Secondary);Text(sessions.size.toString(),fontSize=26.sp,fontWeight=FontWeight.Bold)};Column(Modifier.weight(1f)){Text(tr("Arbeitszeit","Work time"),color=Secondary);Text(duration(work),fontSize=26.sp,fontWeight=FontWeight.Bold)};Column(Modifier.weight(1f)){Text(tr("Verdienst","Earnings"),color=Secondary);Text(money(total,store.profile.currency),fontSize=21.sp,fontWeight=FontWeight.Bold,color=Mint)}}}}
        if(sessions.isEmpty())item{EmptyCard(Icons.Default.History,tr("Noch kein Verlauf","No history yet"),tr("Beendete Schichten erscheinen automatisch hier.","Completed shifts appear here automatically."))}
        else items(sessions,key={it.id}){s->GlassCard{Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(46.dp).background(Mint.copy(alpha=.14f),RoundedCornerShape(14.dp)),contentAlignment=Alignment.Center){Icon(Icons.Default.Check,null,tint=Mint)};Column(Modifier.weight(1f).padding(start=12.dp)){Text(s.title.ifBlank{tr("Arbeitsschicht","Work shift")},fontWeight=FontWeight.Bold);Text(dateTime(s.startedAt)+" · "+duration(s.workMillis()),color=Secondary,fontSize=13.sp)};Column(horizontalAlignment=Alignment.End){Text(money(s.earnings()+s.tips,s.currency),fontWeight=FontWeight.Bold,color=Mint);IconButton({store.delete(s.id);reload()}){Icon(Icons.Default.Delete,null,tint=Secondary,modifier=Modifier.size(18.dp))}}}}}
    }
}

@Composable private fun SettingsScreen(store:WorkStore,billing:BillingManager,refresh:Int,reload:()->Unit,modifier:Modifier){
    val context=LocalContext.current;val state by billing.state.collectAsStateWithLifecycle();var paywall by remember{mutableStateOf(false)};var clear by remember{mutableStateOf(false)}
    var rate by remember(refresh){mutableStateOf(store.profile.hourlyRate.toString())};var hours by remember(refresh){mutableStateOf(store.profile.plannedHours.toString())};var currency by remember(refresh){mutableStateOf(store.profile.currency)}
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){granted->store.updateProfile(store.profile.copy(reminders=granted));reload()}
    LazyColumn(modifier.fillMaxSize(),contentPadding=PaddingValues(20.dp,18.dp,20.dp,32.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
        item{Header(tr("EINSTELLUNGEN","SETTINGS"),tr("ArbeitsKlar für dich.","ArbeitsKlar, your way."),tr("Lohn, Ziele, Design und Datenschutz.","Pay, goals, design, and privacy."))}
        item{SettingsCard(tr("ArbeitsKlar Pro","ArbeitsKlar Pro"),Icons.Default.AutoAwesome){Row(verticalAlignment=Alignment.CenterVertically){Text(if(state.pro)tr("Dauerhaft freigeschaltet","Unlocked forever")else tr("Alle Premium-Funktionen entdecken","Discover all premium features"),Modifier.weight(1f),color=if(state.pro)Mint else Secondary);if(!state.pro)Button({paywall=true}){Text("Pro")}}}}
        item{SettingsCard(tr("Lohn & Schicht","Pay & shift"),Icons.Default.Payments){OutlinedTextField(rate,{rate=it},Modifier.fillMaxWidth(),label={Text(tr("Stundenlohn","Hourly rate"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal));Row(Modifier.padding(top=8.dp)){OutlinedTextField(hours,{hours=it},Modifier.weight(1f),label={Text(tr("Planstunden","Planned hours"))},keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal));OutlinedTextField(currency,{currency=it.uppercase().take(3)},Modifier.width(105.dp).padding(start=8.dp),label={Text(tr("Währung","Currency"))})};Button({store.updateProfile(store.profile.copy(hourlyRate=rate.replace(',','.').toDoubleOrNull()?:20.0,plannedHours=hours.replace(',','.').toDoubleOrNull()?:8.0,currency=currency.ifBlank{"EUR"}));reload()},Modifier.fillMaxWidth().padding(top=10.dp)){Text(tr("Speichern","Save"))}}}
        item{SettingsCard(tr("Design","Design"),Icons.Default.Palette){listOf("classic" to tr("Klassisch","Classic"),"aurora" to "Aurora","sunset" to "Sunset").forEach{(key,label)->Row(Modifier.fillMaxWidth().clickable{if(key=="classic"||state.pro){store.theme=key;reload()}else paywall=true}.padding(vertical=8.dp),verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(34.dp).background(themeBrush(key),CircleShape));Text(label,Modifier.weight(1f).padding(start=12.dp));if(key!="classic"&&!state.pro)Icon(Icons.Default.Lock,null,tint=Amber)else if(store.theme==key)Icon(Icons.Default.CheckCircle,null,tint=Mint)}}}}
        item{SettingsCard(tr("Automatisierung","Automation"),Icons.Default.Notifications){Row(verticalAlignment=Alignment.CenterVertically){Text(tr("Schicht-Erinnerungen","Shift reminders"),Modifier.weight(1f));Switch(checked=store.profile.reminders,onCheckedChange={enabled->if(!state.pro)paywall=true else if(enabled)permission.launch(Manifest.permission.POST_NOTIFICATIONS)else{store.updateProfile(store.profile.copy(reminders=false));reload()}})}}}
        item{SettingsCard(tr("Daten & Datenschutz","Data & privacy"),Icons.Default.Lock){Text(tr("Alle Daten werden ausschließlich lokal gespeichert.","All data is stored only on this device."),color=Secondary);OutlinedButton({clear=true},Modifier.fillMaxWidth().padding(top=10.dp)){Text(tr("Verlauf löschen","Clear history"))};LinkRow(tr("Datenschutz","Privacy policy")){open(context,"https://kamilunavo.com/arbeitsklar/privacy")};LinkRow(tr("Support","Support")){open(context,"https://kamilunavo.com/arbeitsklar/support")}}}
        item{Text("ArbeitsKlar 1.0.1 (4)",color=Secondary,fontSize=12.sp,textAlign=TextAlign.Center,modifier=Modifier.fillMaxWidth())}
    }
    if(paywall)Paywall(state,{billing.purchase(context as Activity)},{billing.restore()}){paywall=false}
    if(clear)AlertDialog({clear=false},title={Text(tr("Verlauf wirklich löschen?","Clear your history?"))},text={Text(tr("Beendete Schichten werden dauerhaft entfernt.","Completed shifts will be permanently removed."))},confirmButton={TextButton({store.clearHistory();clear=false;reload()}){Text(tr("Löschen","Clear"),color=MaterialTheme.colorScheme.error)}},dismissButton={TextButton({clear=false}){Text(tr("Abbrechen","Cancel"))}})
}

@Composable private fun Paywall(state:BillingState,buy:()->Unit,restore:()->Unit,close:()->Unit)=AlertDialog(close,title={Text("ArbeitsKlar Pro",fontWeight=FontWeight.Bold)},text={Column{Box(Modifier.size(58.dp).background(Brush.linearGradient(listOf(Blue,Mint)),RoundedCornerShape(18.dp)),contentAlignment=Alignment.Center){Icon(Icons.Default.AutoAwesome,null,modifier=Modifier.size(30.dp))};Text(tr("Mehr aus jeder Schicht holen.","Get more from every shift."),fontSize=23.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=16.dp));listOf(tr("Unbegrenzter Verlauf und Export","Unlimited history and export"),tr("Schicht-Erinnerungen","Shift reminders"),tr("Aurora- und Sunset-Design","Aurora and Sunset themes"),tr("Einmal kaufen, dauerhaft nutzen","One purchase, yours forever")).forEach{Row(Modifier.padding(top=10.dp)){Icon(Icons.Default.CheckCircle,null,tint=Mint);Text(it,Modifier.padding(start=9.dp))}};Button(buy,Modifier.fillMaxWidth().padding(top=18.dp),enabled=state.product!=null){Text(state.product?.oneTimePurchaseOfferDetails?.formattedPrice?:tr("In Google Play freischalten","Unlock in Google Play"))};TextButton(restore,Modifier.fillMaxWidth()){Text(tr("Käufe wiederherstellen","Restore purchases"))}}},confirmButton={TextButton(close){Text(tr("Fertig","Done"))}})

@Composable private fun Header(kicker:String,title:String,subtitle:String){Text(kicker,color=Mint,fontWeight=FontWeight.Bold,fontSize=11.sp,letterSpacing=1.4.sp);Text(title,fontSize=30.sp,lineHeight=35.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=5.dp));Text(subtitle,color=Secondary,modifier=Modifier.padding(top=7.dp))}
@Composable private fun GlassCard(content:@Composable ColumnScope.()->Unit)=Card(Modifier.fillMaxWidth(),colors=CardDefaults.cardColors(containerColor=Surface),shape=RoundedCornerShape(24.dp),border=androidx.compose.foundation.BorderStroke(1.dp,Border)){Column(Modifier.padding(18.dp),content=content)}
@Composable private fun Metric(modifier:Modifier,icon:ImageVector,label:String,value:String)=Card(modifier,colors=CardDefaults.cardColors(containerColor=Surface),shape=RoundedCornerShape(22.dp),border=androidx.compose.foundation.BorderStroke(1.dp,Border)){Column(Modifier.padding(16.dp)){Box(Modifier.size(38.dp).background(Blue.copy(alpha=.14f),RoundedCornerShape(12.dp)),contentAlignment=Alignment.Center){Icon(icon,null,tint=Blue,modifier=Modifier.size(20.dp))};Text(label,color=Secondary,fontSize=12.sp,modifier=Modifier.padding(top=13.dp));Text(value,fontWeight=FontWeight.Bold,fontSize=19.sp,modifier=Modifier.padding(top=3.dp))}}
@Composable private fun GoalCard(label:String,current:Double,target:Double,currency:String)=GlassCard{val progress=(current/target).toFloat().coerceIn(0f,1f);Row{Text(label,fontWeight=FontWeight.Bold,modifier=Modifier.weight(1f));Text(money(current,currency)+" / "+money(target,currency),color=Mint,fontWeight=FontWeight.Bold)};LinearProgressIndicator({progress},Modifier.fillMaxWidth().padding(top=13.dp).height(8.dp),color=Mint,trackColor=Subtle,strokeCap=androidx.compose.ui.graphics.StrokeCap.Round)}
@Composable private fun EmptyCard(icon:ImageVector,title:String,message:String)=GlassCard{Column(Modifier.fillMaxWidth().padding(vertical=16.dp),horizontalAlignment=Alignment.CenterHorizontally){Icon(icon,null,tint=Blue,modifier=Modifier.size(40.dp));Text(title,fontWeight=FontWeight.Bold,fontSize=18.sp,modifier=Modifier.padding(top=10.dp));Text(message,color=Secondary,textAlign=TextAlign.Center,modifier=Modifier.padding(top=6.dp))}}
@Composable private fun SettingsCard(title:String,icon:ImageVector,content:@Composable ColumnScope.()->Unit)=GlassCard{Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(42.dp).background(Blue.copy(alpha=.14f),RoundedCornerShape(13.dp)),contentAlignment=Alignment.Center){Icon(icon,null,tint=Blue)};Text(title,fontSize=19.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(start=12.dp))};Column(Modifier.padding(top=14.dp),content=content)}
@Composable private fun LinkRow(title:String,click:()->Unit)=Row(Modifier.fillMaxWidth().clickable(onClick=click).padding(vertical=10.dp),verticalAlignment=Alignment.CenterVertically){Text(title,Modifier.weight(1f),fontWeight=FontWeight.SemiBold);Icon(Icons.Default.OpenInNew,null,tint=Secondary)}

private fun money(value:Double,currency:String):String=runCatching{NumberFormat.getCurrencyInstance().apply{this.currency=Currency.getInstance(currency)}.format(value)}.getOrElse{"%.2f %s".format(value,currency)}
private fun duration(ms:Long):String{val minutes=ms/60_000;return "%02d:%02d".format(minutes/60,minutes%60)}
private fun hours(value:Double)=tr("%.1f Std.".format(value),"%.1f hrs".format(value))
private fun dateTime(ms:Long)=DateFormat.getDateTimeInstance(DateFormat.MEDIUM,DateFormat.SHORT).format(Date(ms))
private fun sameDay(a:Long,b:Long):Boolean{val x=Calendar.getInstance().apply{timeInMillis=a};val y=Calendar.getInstance().apply{timeInMillis=b};return x.get(Calendar.YEAR)==y.get(Calendar.YEAR)&&x.get(Calendar.DAY_OF_YEAR)==y.get(Calendar.DAY_OF_YEAR)}
private fun sameMonth(a:Long):Boolean{val x=Calendar.getInstance().apply{timeInMillis=a};val y=Calendar.getInstance();return x.get(Calendar.YEAR)==y.get(Calendar.YEAR)&&x.get(Calendar.MONTH)==y.get(Calendar.MONTH)}
private fun tomorrowAtEight():Long=Calendar.getInstance().apply{add(Calendar.DAY_OF_YEAR,1);set(Calendar.HOUR_OF_DAY,8);set(Calendar.MINUTE,0);set(Calendar.SECOND,0);set(Calendar.MILLISECOND,0)}.timeInMillis
private fun themeBrush(key:String)=Brush.linearGradient(when(key){"aurora"->listOf(Color(0xFF24BFAA),Color(0xFF4C6BF5));"sunset"->listOf(Color(0xFFFF576B),Color(0xFFB837E6));else->listOf(Blue,Mint)})
private fun open(context:android.content.Context,url:String)=context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))

package de.kamilunavo.arbeitsklar

import android.content.Intent
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.*

@RunWith(AndroidJUnit4::class)
class RosterNativeTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val device = UiDevice.getInstance(instrumentation)
    private fun waitText(text:String) = compose.waitUntil(15000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    private fun screenshot(name:String) {
        val dir=File(context.filesDir,"roster-native-qa").apply{mkdirs()}
        device.takeScreenshot(File(dir,"$name.png"))
    }
    @Test fun legacyStorageApplyReopenAndEndPreserveIndividualShifts() {
        check(BuildConfig.DEBUG)
        val prefs=context.getSharedPreferences("arbeitsklar_v1",0)
        prefs.edit().clear().putBoolean("onboarded",true).putString("planned",JSONArray().put(
            JSONObject().put("id","legacy").put("starts",System.currentTimeMillis()-86400000L).put("hours",8.0).put("title","Legacy")
        ).toString()).commit()
        val store=WorkStore(context)
        assertEquals("legacy",store.planned.single().id)
        val tomorrow=LocalDate.now().plusDays(1)
        val template=RosterTemplate(name="QA Shift",hour=8,minute=0,hours=8.0,breakMinutes=30)
        val cycle=RosterCycle(name="QA Cycle",start=tomorrow,end=tomorrow.plusDays(13),zone=ZoneId.systemDefault().id,slots=listOf(template,template,template,template,template,null,null))
        store.applyCycle(cycle,false)
        assertEquals(11,store.planned.size)
        val reopened=WorkStore(context)
        assertEquals(cycle, reopened.cycles.single())
        assertEquals(store.planned,reopened.planned)
        reopened.applyCycle(cycle,false)
        assertEquals(11,reopened.planned.size)
        reopened.endCycle(cycle.id)
        assertEquals(listOf("legacy"),WorkStore(context).planned.map{it.id})
        assertTrue(WorkStore(context).cycles.isEmpty())
        // Starting an unrelated plan while a session is active must not remove it.
        reopened.start()
        reopened.start(reopened.planned.single())
        assertEquals("legacy",WorkStore(context).planned.single().id)
    }
    @Test fun nativeCycleEditorPreviewApplyAndReopen() {
        check(BuildConfig.DEBUG)
        context.getSharedPreferences("arbeitsklar_v1",0).edit().clear().putBoolean("onboarded",true).commit()
        context.getSystemService(android.app.LocaleManager::class.java).applicationLocales = android.os.LocaleList.forLanguageTags("de-DE")
        val scenario=ActivityScenario.launch<MainActivity>(Intent(context,MainActivity::class.java))
        try {
            waitText("Planer")
            compose.onNodeWithText("Planer").performClick()
            compose.onNodeWithText(" Schichtfolgen").performScrollTo().performClick()
            waitText("Schichtfolge anlegen")
            compose.onNodeWithText("Schichtfolge anlegen").performClick()
            waitText("Schichtfolge planen")
            compose.onNodeWithText("Meine Schichtfolge").performTextClearance()
            compose.onNodeWithText("Name").performTextInput("Native Folge")
            device.pressBack()
            screenshot("01-editor")
            compose.onNodeWithText("Datierte Vorschau").performScrollTo().performClick()
            compose.waitForIdle()
            screenshot("02-preview")
            compose.onNodeWithText("Anwenden").performScrollTo().performClick()
            waitText("Native Folge")
            screenshot("03-saved")
            scenario.recreate()
            assertEquals("Native Folge",WorkStore(context).cycles.single().name)
            assertTrue(WorkStore(context).planned.isNotEmpty())
        } finally { scenario.close() }
    }
}

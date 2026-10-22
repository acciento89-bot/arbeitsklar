package de.kamilunavo.arbeitsklar

import android.content.Intent
import android.os.LocaleList
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Regression for the rejected v8 first-run screen; never seed onboarding as complete. */
@RunWith(AndroidJUnit4::class)
class OnboardingNativeTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    private fun launchFreshIntroduction(): ActivityScenario<MainActivity> {
        check(BuildConfig.DEBUG)
        context.getSharedPreferences("arbeitsklar_v1", 0).edit().clear().commit()
        // Completing the introduction must not reset previously saved work settings.
        WorkStore(context).updateProfile(Profile(hourlyRate = 31.25))
        context.getSystemService(android.app.LocaleManager::class.java).applicationLocales = LocaleList.forLanguageTags("en-US")
        return ActivityScenario.launch(Intent(context, MainActivity::class.java))
    }

    private fun expectMain() {
        compose.waitUntil(5000) { compose.onAllNodesWithText("Today").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithTag("main-navigation").assertIsDisplayed()
        assertTrue(WorkStore(context).onboarded)
        assertEquals(31.25, WorkStore(context).profile.hourlyRate, 0.0)
    }

    private fun screenshot(name: String) {
        val dir = File(context.filesDir, "roster-native-qa").apply { mkdirs() }
        assertTrue(UiDevice.getInstance(instrumentation).takeScreenshot(File(dir, "$name.png")))
    }

    @Test fun startIntroductionEntersMainImmediatelyAndPersists() {
        val scenario = launchFreshIntroduction()
        try {
            compose.onNodeWithText("Continue").performClick()
            compose.onNodeWithText("Continue").performClick()
            compose.onNodeWithText("Start ArbeitsKlar").performClick()
            expectMain()
            screenshot("00-onboarding-start")
            scenario.recreate()
            expectMain()
        } finally { scenario.close() }
    }

    @Test fun skipIntroductionEntersMainImmediatelyAndPersists() {
        val scenario = launchFreshIntroduction()
        try {
            compose.onNodeWithText("Skip").performClick()
            expectMain()
            screenshot("00-onboarding-skip")
            scenario.recreate()
            expectMain()
        } finally { scenario.close() }
    }
}

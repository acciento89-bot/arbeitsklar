package de.kamilunavo.arbeitsklarqa;
import android.content.Intent;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.*;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.*;
import org.junit.runner.RunWith;
import java.io.File;
@RunWith(AndroidJUnit4.class)
public class OnboardingAcceptanceTest {
 static final String APP="de.kamilunavo.arbeitsklar";
 UiDevice device; File proof;
 @Before public void freshSyntheticInstall() throws Exception {
  device=UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
  Assert.assertEquals("1",device.executeShellCommand("getprop ro.kernel.qemu").trim());
  Assert.assertEquals("35",device.executeShellCommand("getprop ro.build.version.sdk").trim());
  proof=new File(InstrumentationRegistry.getInstrumentation().getTargetContext().getExternalFilesDir(null),"proof");proof.mkdirs();
  Assert.assertEquals("Success",device.executeShellCommand("pm clear "+APP).trim());
  device.executeShellCommand("cmd locale set-app-locales "+APP+" --user 0 --locales en-US");
  launch();
 }
 void launch(){Intent i=InstrumentationRegistry.getInstrumentation().getContext().getPackageManager().getLaunchIntentForPackage(APP);Assert.assertNotNull(i);i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK);InstrumentationRegistry.getInstrumentation().getContext().startActivity(i);}
 UiObject2 button(String text){UiObject2 n=device.wait(Until.findObject(By.text(text)),15000);Assert.assertNotNull("Missing button: "+text,n);return n;}
 void snap(String name){Assert.assertTrue(device.takeScreenshot(new File(proof,name+".png")));}
 @Test public void lastIntroductionButtonEntersMainWithoutRestart() throws Exception {
  button("Continue").click();button("Continue").click();
  button("Start ArbeitsKlar");snap("01-last-introduction");
  button("Start ArbeitsKlar").click();
  boolean entered=device.wait(Until.hasObject(By.text("Today")),5000);
  snap("02-after-start-tap");
  if(!entered){device.executeShellCommand("am force-stop "+APP);launch();Assert.assertTrue("Completion must persist across restart",device.wait(Until.hasObject(By.text("Today")),15000));snap("03-only-after-cold-restart");}
  Assert.assertTrue("Start must enter Today immediately, without restarting the app",entered);
 }
 @Test public void skipIntroductionEntersMainWithoutRestart() throws Exception {
  button("Skip").click();
  boolean entered=device.wait(Until.hasObject(By.text("Today")),5000);snap("04-after-skip-tap");
  Assert.assertTrue("Skip must enter Today immediately",entered);
 }
}

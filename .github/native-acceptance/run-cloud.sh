#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'Cloud disposable runner required'; exit 2; }
cd "$GITHUB_WORKSPACE"
proof="$GITHUB_WORKSPACE/.github/native-acceptance/proof"
mkdir -p "$proof"
serial=emulator-5554
avd=ArbeitsKlarNativeAcceptanceApi35
cleanup() {
  rc=$?; trap - EXIT; set +e
  timeout 10s adb -s "$serial" exec-out screencap -p > "$proof/final-screen.png" 2> "$proof/screen-error.txt"
  timeout 10s adb -s "$serial" shell dumpsys window windows > "$proof/final-window.txt" 2>&1
  timeout 10s adb -s "$serial" logcat -d -b crash > "$proof/crash-log.txt" 2>&1
  timeout 10s adb -s "$serial" emu kill > "$proof/emulator-stop.txt" 2>&1
  for attempt in {1..15}; do
    if ! timeout 3s adb devices | grep -Fq "$serial"; then break; fi
    sleep 1
  done
  timeout 15s "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" delete avd -n "$avd" > "$proof/avd-delete.txt" 2>&1
  timeout 10s "$ANDROID_HOME/emulator/emulator" -list-avds > "$proof/remaining-avds.txt" 2>&1
  avd_rc=$?
  timeout 5s adb devices > "$proof/remaining-devices.txt" 2>&1
  device_rc=$?
  python3 .github/native-acceptance/verify_cleanup.py --proof "$proof" --avd "$avd" --serial "$serial" --avd-rc "$avd_rc" --device-rc "$device_rc"
  if [[ $? != 0 ]]; then echo 'Owned cloud device cleanup not verified' > "$proof/cleanup-failed.txt"; rc=1; fi
  exit "$rc"
}
trap cleanup EXIT
# Reject nonowned or wrong-platform targets before the existing tests write synthetic data.
[[ "$(timeout 5s adb -s "$serial" shell getprop ro.build.version.sdk | tr -d '\r')" == 35 ]]
[[ "$(timeout 5s adb -s "$serial" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]]
timeout 5s adb devices > "$proof/before-devices.txt"
[[ "$(awk 'NR>1 && NF {print $1}' "$proof/before-devices.txt")" == "$serial" ]]
# Stop only the known cloud image launcher before Compose starts the app directly.
# This avoids first-boot Pixel Launcher ANRs obscuring the captured app evidence.
timeout 10s adb -s "$serial" shell am force-stop com.google.android.apps.nexuslauncher
sleep 20
timeout 10s adb -s "$serial" shell dumpsys activity lastanr > "$proof/preflight-anr.txt"
if grep -Eqi "ANR in|Application Not Responding|com.android.systemui|com.google.android.apps.nexuslauncher" "$proof/preflight-anr.txt"; then
  echo 'Cloud system/launcher ANR observed; native tests not started' >&2
  exit 1
else
  grep_rc=$?
  [[ "$grep_rc" == 1 ]] || { echo 'Cannot read ANR evidence' >&2; exit 1; }
fi
gradle -p android --no-daemon --max-workers=1 connectedDebugAndroidTest -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true --stacktrace 2>&1 | tee "$proof/native-tests.log"
python3 .github/native-acceptance/verify-native-results.py

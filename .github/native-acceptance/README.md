# Native onboarding and roster acceptance

Manual dispatch: Android CI with `native_acceptance=true`. The cloud job runs all four Android native tests on one disposable official API35 Google APIs emulator. It never starts a second local emulator. Normal PR/main CI builds an unsigned release only; it does not publish to Play.

The two `OnboardingNativeTest` scenarios start with onboarding incomplete, tap Start or Skip, require the actual main navigation immediately, preserve an existing hourly rate, and recreate the activity to verify persistence. They cover the first-run failure Google reported for version8. The two `RosterNativeTest` scenarios exercise legacy migration, recurring roster persistence and consumed occurrences, real editor/preview/apply/recreate, and individual edits.

The verifier rejects reports missing either first-run test, either roster test, or any of the seven actual screenshots. It also rejects failures/errors/skips, unexpected installed identity, missing saved synthetic data, or system dialogs obscuring the evidence. Unit fixtures do not establish native success.

All writes belong to the fresh disposable debug app. No purchase, redemption, restoration, personal data, or external communication is exercised. The existing billing initialization can query product availability normally.

The command retains the debug APK until saved-data and screenshot evidence has been copied. AGP otherwise uninstalls it; see https://issuetracker.google.com/issues/295039976. The exit trap then stops and deletes only the owned cloud emulator and verifies cleanup.

For investigations against the actual signed release, `.github/onboarding-native/host` is a separate UI Automator harness. It must run only against a disposable API35 emulator: its setup verifies QEMU and clears the target app's synthetic data. Its two independent Start/Skip tests demonstrated both failures against the unchanged payload derived from submitted8, then passed against the corrected candidate. Keep release identity and artifact digests alongside its results; a debug pass alone is not proof of a signed store artifact.

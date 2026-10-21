# ArbeitsKlar Android8 native acceptance

Manual dispatch only: Android CI with native_acceptance=true. Normal PR/main CI still builds the unsigned release; the separate manual job runs the two existing RosterNativeTest methods on one fresh official API35 Google APIs cloud emulator. No local emulator is created. The existing Kotlin test bytes are unchanged.

The tests exercise legacy migration, recurring roster persistence and consumed occurrences, real cycle editor/preview/apply/recreate, and individual edits. They modify synthetic data in their own fresh debug app only. No purchase, redemption, restore, personal device or external messaging test runs.

Before those tests the shell requires the exact emulator serial, QEMU, API35, no extra connected device, and no observed SystemUI ANR. The final verifier requires both named original tests, no failures/errors/skips, actual installed1.1.0(8), the saved synthetic cycle and edit, plus all five actual PNGs. These are native proof, not marketing pictures. Source-unit fixtures do not establish native success.

The EXIT trap captures final diagnostics, stops and deletes only the owned cloud AVD, and fails if nonzero inventory commands prevent confirming absence. The SDK emulator executable is addressed by its full official path. All evidence stays in proof/ and is uploaded only as a private repository workflow artifact. Signing and Google delivery remain separate, explicitly authorized steps.

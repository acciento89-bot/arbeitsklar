# External first-run regression harness

Build `host` with the existing official Android SDK and Gradle toolchain. Install its debug host and test APKs together with the candidate on a single disposable API35 emulator, then run `de.kamilunavo.arbeitsklarqa.test/androidx.test.runner.AndroidJUnitRunner`.

The harness clears **only** the owned emulator's `de.kamilunavo.arbeitsklar` data before each case; never run it on a personal or production device. It requires QEMU and deliberately does not seed `onboarded=true`. It touches only Start/Continue/Skip and checks Today navigation. No purchases, restorations, or external messages occur.

Keep the candidate AAB/APK identity, derived payload verification, original failing log, corrected passing log, and actual screenshots with the incident evidence. The release-vs-debug distinction must remain explicit.

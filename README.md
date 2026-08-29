# ArbeitsKlar

ArbeitsKlar turns a work shift into immediate, motivating feedback: start a shift, watch gross earnings grow, and keep a clear local history.

ArbeitsKlar macht Arbeitszeit unmittelbar sichtbar: Schicht starten, Brutto-Verdienst live verfolgen und abgeschlossene Schichten lokal speichern.

## Current MVP

- Second-by-second in-app earnings ticker
- First-launch setup for pay, currency, and planned shift length
- Start, pause, resume, and finish shifts
- Break-aware work time, earnings, and overtime calculations
- Editable completed shifts with recalculated breaks and earnings
- Manual completed-shift entry for forgotten or imported workdays (Pro)
- Configurable monthly gross-earnings goal with live progress
- Siri and Shortcuts actions to start, pause, resume, and end a shift
- Pro week, month, and all-time insights with an earnings chart
- Pro CSV export for completed shifts
- Two premium color themes (Aurora and Sunset)
- Break-aware local shift-end reminders
- Local shift history and gross-pay estimates
- Configurable hourly rate, currency, and planned shift length
- Lock Screen and Dynamic Island Live Activity
- English and German String Catalog
- Locale-aware currencies, dates, times, and numbers
- Custom production-ready app icon
- No account, tracking, ads, or backend dependency

## ArbeitsKlar Pro

StoreKit 2 support is implemented for the non-consumable product `de.kamilunavo.arbeitsklar.pro.lifetime`. The app verifies current entitlements, listens for transaction updates, supports pending purchases, and provides an explicit restore action.

No product has been created in App Store Connect by this repository change. Until that non-consumable product is configured there, the paywall remains visible but purchasing stays disabled. Pro unlocks week/month/all-time insights with an earnings chart, manual entry and editing of completed shifts, filtered CSV export, premium color themes, and local shift-end reminders.

For local UI testing without an App Store Connect product, select the shared `ArbeitsKlar Pro Preview` scheme in Xcode. It is a Debug-only mode that unlocks Pro and loads a realistic multi-week demo history. Release and Archive builds cannot activate this override.

## Project structure

- ArbeitsKlar — main SwiftUI application
- ArbeitsKlarLiveActivity — ActivityKit and Dynamic Island extension
- ArbeitsKlar.xcodeproj — ready-to-open Xcode project
- project.yml — optional XcodeGen source of truth

## Requirements

- Xcode 16 or newer
- iOS 17 or newer
- Apple Developer team TKG684N5GL for device signing

Open ArbeitsKlar.xcodeproj, choose the ArbeitsKlar scheme, and run on an iPhone simulator or device.

## Bundle identifiers

- Main app: de.kamilunavo.arbeitsklar
- Live Activity extension: de.kamilunavo.arbeitsklar.liveactivity

The main App ID already exists. Automatic signing can create the extension identifier, or it can be registered explicitly in Certificates, Identifiers & Profiles.

## Localization

All user-facing copy lives in ArbeitsKlar/Resources/Localizable.xcstrings. English is the source language and German is fully translated. Add another locale in Xcode’s String Catalog editor; feature code does not need to change.

Currency, date, time, decimal, and duration formatting use the user’s current locale. Do not build localized sentences by concatenating translated fragments.

## Live Activity behavior

The elapsed timer is system-driven and continues on the Lock Screen. Apple controls Live Activity refresh budgets, so arbitrary currency calculations cannot reliably redraw every second while the app is suspended. The app refreshes the displayed earnings while foregrounded; a later server-push layer can provide budget-aware background updates.

## Privacy

The MVP stores its profile and shift history in UserDefaults on the device. PrivacyInfo.xcprivacy declares this required-reason API use. No personal data leaves the device.

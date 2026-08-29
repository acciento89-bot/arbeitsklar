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
- Reusable shift templates with one-tap quick start
- Calendar planner for upcoming shifts with day agenda and reminders
- Start a planned shift directly into the live earnings timer
- Searchable shift titles, notes, and tags
- Live tip tracker with quick amounts, custom entry, history totals, and CSV fields
- Configurable monthly gross-earnings goal with live progress
- Motivational per-shift goal with a live, premium-aware time-to-goal forecast
- Transparent base-pay, overtime, night, and weekend premium breakdowns
- Configurable overtime multiplier and local night-work window
- Pro monthly payslip audit comparing tracked expected gross pay with the actual statement
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

No product has been created in App Store Connect by this repository change. Until that non-consumable product is configured there, the paywall remains visible but purchasing stays disabled. Pro unlocks week/month/all-time insights with an earnings chart, the monthly payslip audit, manual entry and editing of completed shifts, filtered CSV export, premium color themes, and local shift-end reminders.

Shift templates and planned shifts are stored separately from shift history. Starting either one snapshots its name, note, tags, planned duration, current pay profile, and current premium rules into the new live shift. Existing saved shifts decode with empty metadata, so this change remains backward compatible.

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

## Pay intelligence

Each shift snapshots the active pay rules when it starts, so changing settings later does not rewrite historical earnings. Base pay, overtime premiums after the planned shift duration, night premiums inside the configured local-time window, and weekend premiums are calculated separately and may stack. The history, analytics, monthly goal, Live Activity, manual-entry preview, edit preview, and CSV export all use the same calculation engine.

All wage amounts are gross estimates. Tips are tracked separately and are only added to the displayed total income and CSV total; they are intentionally excluded from wage-premium calculations and the monthly payslip audit. Tax, collective-agreement, holiday, and country-specific legal rules are not inferred automatically.

## Live Activity behavior

The elapsed timer is system-driven and continues on the Lock Screen. Apple controls Live Activity refresh budgets, so arbitrary currency calculations cannot reliably redraw every second while the app is suspended. The app refreshes the displayed earnings while foregrounded; a later server-push layer can provide budget-aware background updates.

## Privacy

The MVP stores its profile, shift templates, planned shifts, payslip checks, and shift history in UserDefaults on the device. PrivacyInfo.xcprivacy declares this required-reason API use. Optional planner and shift-end reminders use local notifications. No personal data leaves the device.

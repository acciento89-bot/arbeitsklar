# ArbeitsKlar – Google Play release

## Build identity

- Package: de.kamilunavo.arbeitsklar
- Version: 1.0.1 (versionCode 4)
- Minimum Android: 8.0 (API 26)
- Target Android: API 36
- Product: de.kamilunavo.arbeitsklar.pro.lifetime

## Store positioning

**Short description (DE)**  
Arbeitszeit, Pausen, Trinkgeld und Verdienst klar und lokal erfassen.

**Short description (EN)**  
Track work time, breaks, tips and earnings clearly and privately.

**Full description (DE)**  
ArbeitsKlar macht deinen Arbeitstag sichtbar: Starte und pausiere deine Schicht mit einem Tippen, verfolge deinen geschätzten Verdienst live und plane kommende Einsätze. Verlauf, Trinkgeld, Schichtziele und flexible Lohnangaben bleiben lokal auf deinem Gerät. Mit ArbeitsKlar Pro stehen zusätzlicher Verlauf, Erinnerungen und weitere Designs dauerhaft zur Verfügung.

**Full description (EN)**  
ArbeitsKlar makes your workday visible. Start and pause a shift with one tap, follow estimated earnings live, and plan upcoming shifts. History, tips, shift goals, and flexible pay settings stay locally on your device. ArbeitsKlar Pro permanently unlocks extended history, reminders, and additional themes.

## Data safety

- No account and no analytics SDK.
- Work sessions, profile, planned shifts, and preferences are stored locally.
- Notification permission is optional and only used for shift reminders.
- Google Play Billing handles the optional lifetime Pro purchase.
- The app displays estimates and does not replace payroll records.

## Release checklist

1. Create the app with package de.kamilunavo.arbeitsklar.
2. Add managed product de.kamilunavo.arbeitsklar.pro.lifetime.
3. Upload the signed AAB from android/app/build/outputs/bundle/release/.
4. Publish German and English listings, screenshots, privacy URL, and support URL.
5. Complete Data safety, Content rating, Ads, Target audience, and App access.
6. Run internal testing, verify purchase and restore, then promote to production.

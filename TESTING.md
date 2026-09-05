# ArbeitsKlar internal test run

Use the shared **ArbeitsKlar Pro Preview** scheme. It starts with `-pro-preview` and `-demo-data`, so Pro features, templates, planned shifts, historical sessions, goals, pay premiums, and a payslip discrepancy are available without an App Store Connect product.

## 1. Launch and navigation

1. Build and run on an iPhone simulator running iOS 17 or newer.
2. Complete or skip onboarding.
3. Verify the four tabs: Today, Planner, History, and Settings.
4. Verify that every screen remains usable with German and English as the app language.

## 2. Planner and templates

1. Open Planner and move one month backward and forward.
2. Select a day containing a green shift marker and open its agenda card.
3. Edit the planned shift, apply another template, and save it.
4. Add a new shift on an empty day with a local reminder.
5. Deny notifications once and verify that the shift is still saved without a bell.
6. Delete a planned shift and confirm that it disappears from the day and calendar marker.
7. Open Settings → Shift templates; add, edit, and delete a template.

## 3. Live shift and tip tracker

1. On Today, start the next planned shift. It must disappear from Planner and become the active live shift.
2. Verify that title and tags were transferred.
3. Add tips with all three quick buttons and one custom amount.
4. Pause the shift and verify that worked time and earnings stop increasing.
5. Resume, then finish the shift.
6. Repeat once using a template quick-start instead of Planner.

## 4. Earnings and goals

1. In Settings, configure overtime, night, and weekend premiums.
2. Set a monthly earnings goal and a per-shift goal with a custom title.
3. Start a shift and verify live gross earnings, premium indication, goal progress, and time-to-goal.
4. Verify the Lock Screen/Dynamic Island Live Activity on a supported simulator or device.

## 5. History and payslip check

1. Search History by a shift title and by a tag.
2. Open a completed shift and edit time, break, tips, title, tags, and note.
3. Confirm that the row total includes tips while the wage calculation remains separate.
4. Switch between week, month, and all-time analytics.
5. Open the monthly payslip check, enter actual gross pay, save it, reopen it, and delete it.
6. Export CSV and verify the wage, premium, tips, total-income, title, tags, and note columns.

## 6. Persistence and recovery

1. Close the app completely and launch it again.
2. Verify that active/completed sessions, tips, templates, planned shifts, goals, and payslip checks persist.
3. Start a shift, close and reopen the app, and verify that the active timer resumes from the correct time.
4. In Settings, clear completed history and confirm that templates and planned shifts remain intact.

Record the device, iOS version, app language, failed step, and a screenshot for every issue.

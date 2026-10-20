# ArbeitsKlar: rotating roster and Duo update

Human authority: meaningful larger updates and store optimization for published apps, plus iPhone Duo support; 20 October continuation explicitly says continue. Implementation proceeds inline. The Apple app is published; Google initial production status must be verified before any new release; no recurring release monitor is authorized.

## Product
Extend the existing planner with reusable one-to-four-week work/rest cycles based on the existing shift templates. The user names a cycle, sets its first day and an end date up to 182 calendar days later, and chooses a template or rest for each cycle day. Show a dated preview with conflicts before applying. Default refuses overlaps; an explicit “skip conflicts” option saves only nonconflicting future shifts. Existing individual shifts remain editable.

Cycles are persistent. Editing a cycle replaces only its unstarted future planned shifts. Ending a cycle removes only future planned shifts and related reminders; completed work sessions and past planned shifts remain untouched. Reapplying the same cycle never duplicates its shifts. Each generated shift snapshots its template values so later template deletion does not invalidate plans. Bulk-generated shifts have no reminder by default; the existing per-shift editor remains the opt-in reminder flow.

## Rules
Use calendar-day arithmetic and a saved time-zone identifier. The first cycle date defines day zero; no midnight/86400-second stepping. Missing DST times move to the next valid time; repeated times use the first occurrence. Planned duration retains existing elapsed-hour semantics. Ranges are inclusive, at most 183 dates (182-day difference), with one-to-four complete weeks and at least one work day. Invalid dates/time zones/empty names/invalid lengths must be rejected without persistence changes. Starts before “now” are omitted. Touching shift boundaries are valid; intersecting intervals are conflicts, including overnight shifts.

## Compatibility and Duo
Add optional cycleID to ScheduledShift so old JSON still decodes. Save cycle definitions under a separate versioned key; do not replace session/profile storage. Retain free/Pro entitlements. Native adaptive SwiftUI screens must use available width, safe areas, readable touch targets, scrolling and Dynamic Type. Verify both actual Duo integrated display states and resizing; geometry-only checks must not be described as a native Duo pass. Also retain ordinary iPhone regression QA.

## Acceptance
Pure date-rule tests cover range limits, alternating weeks, rest days, DST gap/fold, overlap boundaries/overnight, past omission, legacy decoding, template snapshots and invalid inputs. Store tests cover apply/reapply/edit/cancel, persistence reopen, preservation of historical sessions and reminder cancellation. Native DE/EN tests exercise cycle creation, dated preview, conflict handling, reopening and future cancellation without purchase/restore actions. Native builds and fresh screenshots must precede store feature claims. Signed uploads and review follow existing authorization for published-app updates only. All local native QA uses one temporary device with verified finally cleanup.

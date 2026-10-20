# Rotating roster implementation plan

Goal: meaningful planner expansion plus native Duo validation for the published ArbeitsKlar iOS app, with Android parity before any related Android update.
Architecture: pure Foundation calendar planner, optional per-shift cycle identity, separate persisted cycle definitions, existing planner/editor entry point. Extend the current Android WorkStore/Compose planner equivalently after its current data model is inspected.
Spec: 2026-10-20-roster-design.md.
Constraints: no transaction QA, no publication automations, one disposable local device at a time, preserve prior records and existing entitlements.

- [x] Task 1 — Add failing date-rule/legacy JSON checks in ci/roster-smoke.swift and its shell runner; implement ShiftCycle and ShiftCyclePlanner plus optional ScheduledShift.cycleID. Verify alternating cycles, exact boundaries, DST and validation. Commit tested core.
- [x] Task 2 — Integrate separate cycle persistence and atomic future-only replacement/removal in WorkSessionStore. Test apply/reapply/edit/cancel/reopen and historical preservation. No new bulk notification opt-in.
- [ ] Task 3 — Add CyclePlannerView/CycleEditorView and planner entry point, DE/EN localization, dated preview and explicit conflict skipping. Responsive safe-area/Dynamic Type layouts; native iPhone/Duo checks.
- [ ] Task 4 — Inspect and implement Android parity with genuine model/UI tests, native serial QA, existing-data migration and no repeated billing transactions.
- [ ] Task 5 — Whole-change review, meaningful versioning, genuine native store galleries, accurate Google/Apple metadata and guarded signed delivery. No initial publication inferred from a draft Google record.

Review focus: DST/travel timezone consistency; long overnight overlap; stale preview between edit/apply; empty/all-rest or malformed persisted cycle; partial cancellation versus already started/completed records. Each belongs in the respective core/store test task. No final support or release claim without corresponding evidence.

Task 2: 37 pure Foundation rule/storage checks PASS. Cycle+member snapshot is one UserDefaults value; legacy individual shifts imported, invalid current bytes retained for recovery. Individual editor retains cycle identity. Native store/UI compile and behaviour still pending Task 3.

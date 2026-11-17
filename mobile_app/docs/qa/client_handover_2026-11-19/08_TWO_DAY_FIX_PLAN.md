# 08 — Two-Day Fix Plan (DRAFT: not approved, nothing implemented)

Window: Tue 17 Nov (afternoon) → Thu 19 Nov 2026 (handover).
Status: **proposal only.** Phase B ends here. No code has been changed in this audit. Each batch needs explicit approval.

## Assumptions
- Flutter fixes stay inside `mobile_app/`. Backend items need the backend owner; they aren't done here.
- Every retest on the device hits production unless a non-production backend is provided.
- Estimates are engineering time for one developer, including focused tests. They exclude approval wait time.

## Day 1: Tue 17 Nov (remaining) / Wed 18 Nov morning

| Order | Item | Owner | Est. | Depends on | Retest |
|---|---|---|---|---|---|
| 1 | **HO-01 face bypass**: backend fix, or written client risk acceptance | Backend / client | 0.5–1 d (backend) | Backend owner availability | Backend tests; device clock-in only with mutation approval |
| 2 | **HO-18 Branch Admin scope decision** | Product / client | decision | — | Re-run the Settings access check with the agreed role |
| 3 | **HO-02 + HO-03 voice robot**: keep it below dialogs and sheets (or hide it while a route is covered); move it clear of FABs, Save bars and values; add a hide/collapse option | Flutter | 0.5 d | — | Widget tests + device: Apply Leave date picker, payslip, preview, FAB screens |
| 4 | **HO-04 build provenance**: bump the version (e.g. 1.0.2+8) and build a debug APK for the device; record its SHA-256 | Flutter / release | 0.25 d | Install approval | Device: version shows 1.0.2; fractional balances after a cold start without `flutter run` |

## Day 2: Wed 18 Nov

| Order | Item | Owner | Est. | Retest |
|---|---|---|---|---|
| 5 | HO-05 / HO-06 employee profile: single header; Save bar only in edit mode (after web source check) | Flutter | 0.5 d | Device: View and Edit flows (no save) |
| 6 | HO-07 / HO-08 truncation: stat-card label wrapping or scaling, app-bar titles, tab-scroll affordance | Flutter | 0.5 d | Device at font 1.0 + large-text pass (needs approval) |
| 7 | HO-10 accessibility labels on icon-only controls | Flutter | 0.25 d | uiautomator dump shows labels |
| 8 | HO-14 audit date format; HO-09 card spacing; HO-15 bottom inset | Flutter | 0.25 d | Device |
| 9 | Phase C parity audit of the highest-traffic screens (Dashboard, Leave, Attendance, Approvals, Employees) | QA | 1 d (in parallel) | — |

## Thursday 19 Nov (morning)
- Release build with the upload key; record its SHA-256; install-path decision (Play internal track vs direct). A release build can't be installed over the current debug build without uninstalling first, so plan it.
- Final regression: full `flutter test`, `flutter analyze`, and the device smoke run of 09.

## Explicit deferrals (not before handover unless re-prioritized)
- HO-11, HO-12, HO-13, HO-17 backend scoping and definition items (backend owner).
- HO-16 demo data clean-up (production writes on the client tenant: client decision).
- Role-specific screens for Employee / HR / Manager: need test accounts.
- Large-scale field-by-field parity for every settings page.

## Approvals needed before any of this starts
1. Approve this plan (or reorder it).
2. Approve installing a new debug build on the phone (procedure in 01 §10).
3. Decisions on HO-01 (backend fix vs risk acceptance) and HO-18.
4. Optional: Employee / HR / Manager test accounts; permission to change the device font scale temporarily.

## Status after C1 (17 Nov 2026, afternoon)
- **Done and device-retested:** items 3 (HO-02 / HO-03), 4 (HO-04, debug build 1.0.2+8) and 5 (HO-05 / HO-06), plus HO-23 found and fixed.
- **Still open from this plan:** 1 (HO-01 backend), 2 (HO-18 decision), 6 (truncation, now including large-text HO-19 / HO-20 / HO-21), 7 (HO-10 accessibility labels), 8 (HO-14, HO-09; HO-15 partial), 9 (Phase C parity: field audit now at 48 rows).
- **New:** HO-24 (Plan Details tab missing on mobile; decision), and HO-22 (overflow detection must be visual on this device).

## Revised critical path after C3 (17 Nov evening → 19 Nov)

| When | Item | Owner | Blocks handover? |
|---|---|---|---|
| 17 Nov evening | Decide HO-01 (backend fix vs written risk acceptance) and HO-18 (Branch Admin scope) | Client / product / backend | **Yes** |
| 17 Nov evening | Record the release AAB built at 16:06 (SHA-256, source manifest) or rebuild it from a recorded source state; it was built while C3 edits were in progress (HO-32) | Release | **Yes** (provenance) |
| 18 Nov AM | Refresh the reference web/backend clone to the deployed revision (HO-31) so source comparisons are current | Backend owner | No (audit quality) |
| 18 Nov AM | Product scope: Training (HO-25) for this handover, or explicitly deferred; Plan Details (HO-24); branch-scoped counts (HO-11 / HO-26) | Product | Yes, if Training is in scope (6–9 days: can't fit) |
| 18 Nov | Flutter P3 polish if time: HO-07 titles, HO-27 labels, HO-30 card line, HO-10 a11y labels, HO-14 dates | Flutter | No |
| 18 Nov PM | Role coverage: Employee, HR and Manager accounts; repeat the smoke run (09) per role | QA + client | Yes (untested roles) |
| 18 Nov PM | If authorized: one end-to-end write test on disposable demo records (apply + cancel leave) | QA | Recommended |
| 19 Nov AM | Release build from the recorded source; install-path decision (Play internal track, or uninstall the debug build on test phones with approval); final regression (tests, analyzer, device smoke at 1.0 / 1.3) | Release + QA | Yes |

**Explicitly deferred unless re-scoped:** Training module (HO-25); admin payroll on mobile (HO-33, web-only by decision); backend scoping fixes (HO-11, HO-12, HO-17, HO-26).

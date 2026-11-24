# Task 111 — Organization Chart & Attendance module: parity, cards, responsive redesign

Evidence is render/mocked-API only (no device or emulator pass, no production calls). Screenshots: `evidence/t111/` (146 files; `before_t111_*` / `t111_*`; areas: `org`, `unpunch`, `month`, `ot`, `ip`, `latejust`, `weeklyoff`, `shift`). Five areas were built by background agents (each reported, I re-verified integration: full suite + analyzer + spot-inspected shots) and the Organization Chart by me. To allow independent work, four tab classes were first moved out of `attendance_screen.dart` into `part` files (a mechanical move; behaviour unchanged, 546 tests green).

## 1. Audit matrix (web → mobile)
| Area | Web | Mobile before | Finding |
|---|---|---|---|
| Org Chart | "Not assigned" (dept with no head), "Not set" (branch root) | "—" | wording parity |
| Un-Punches | read-only list; Date/Branch/Department filters; 20/page; no actions | extra "OUT missing" badge, Approve/Reject, Correction Requests section; no own filters; page_size=100, no paging | **functional parity gap** |
| Month View | `GET /attendance/employee-calendar/?employee_id&month=YYYY-MM` (employee search, month nav, 7 summary figures, day cells, legend, day drawer) | reused the Employee Profile attendance tab (different endpoints/data) | **wrong data source** |
| OT Entry | create-only; fields: name, id, date, hours, type, amount, approved by, status; branch filter | cramped single-line rows | layout; API has no remarks |
| Invalid Punches | Assign / Convert / Discard (`attendance.edit`); API: device id, raw time, issue, issue type, suggested match, branch | overflowing pills, tiny buttons, "future" purple (web red) | layout + colour parity |
| Late Justification | list + review (approve / reject / resubmit); statuses pending, l2_pending, approved, rejected, resubmit | one-line reasons, L1/L2 collapsed into one badge | layout |
| Weekly Off | assign / bulk assign / filters | cluttered; Bulk Assign under the system navigation bar | layout + inset bug |
| Shift Mgmt | shift master CRUD + assignment (filters, assign, bulk) | one box, icon-only actions, no length/overnight cue | layout/clarity |

## 2. Root causes
- **Org chart:** `dept.head?.name ?? '—'` and `person.name.isEmpty ? '—'`.
- **Un-Punches:** fields/actions grew on mobile that the web tab does not have; its own date/branch/department controls were missing (it silently used hidden Attendance-tab filters).
- **Month View:** it was not the web month view at all (profile tab reused).
- **Weekly Off overlap:** Bulk Assign is a **modal bottom sheet** drawn by the Navigator, outside any Scaffold, so nothing added `MediaQuery.padding.bottom`; the shared `AssignmentSheet` only added the keyboard inset and the action row scrolled with the fields. The tab's list also used `EdgeInsets.all(12)`, which replaces the automatic safe-area padding. (Shell/Scaffold/FAB checked: not the cause.)
- **OT / Invalid / Late / Shift:** single-line ellipsised rows, collapsed approval levels, fixed-width pills, no overnight cue.

## 3. Un-Punches field-by-field parity (web `UnpunchesTab.tsx` ↔ `HRUnpunchesView`)
Info banner → exact web text · Date (`date`, YYYY-MM-DD, default today, always sent) · Branch (`branch`; locked own branch for scoped users, dropdown from `/branch/branches/` otherwise) · Department (`department`; `/departments/` for unrestricted, own-branch employees' departments for scoped) · paging (`page`, `page_size=20`, "Page X of Y", only when >1 page; any filter change → page 1) · card fields Employee ID / Name / Branch / Date (raw YYYY-MM-DD, as web) / Clock In / Expected Out · Correction Status = `correction_pending` → "Correction Submitted" / "No Correction Filed" · states: web messages kept + no-match ("Clear filters") + denied (no Retry). **Removed (not on web):** "OUT missing" badge, Approve/Reject, "Correction Requests" section and status filter (review remains in Approvals → Team Approvals). Permission `attendance.view`; no mismatch between web and backend found.

## 4. UI changes per screen
Org Chart: web wording (+ "Name not set" for a head/member record with no name; "Top of chart · Not set" with the existing explanation); real values untouched. Un-Punches: filter card + labelled record cards, 1/2 columns, pull-to-refresh. Month View: sections (selection → overview with 7 backend figures → day-by-day cards with status pill, clock in–out, hours, "Flagged" → legend), per-month provider (no stale replies), read-only day sheet, states incl. denied. OT: premium cards (name+ID, status badge, large duration, amount, type chip, date, Approved By wraps), no invented actions. Invalid Punches: cards with issue rail/label, full reason, formatted time, facts grid, three 44dp actions (stack when narrow), nothing implies a fix was applied. Late Justification: cards with identity, date, clock-in, full reason, separate Manager (L1) / HR (L2) rows with remarks, proof state, Review/View; separate empty vs no-match. Weekly Off: overview / select-employees / existing-assignments sections, full-width Bulk Assign, labelled card fields, grouped bulk sheet with pinned, inset-aware action row. Shift: "Shift configuration" vs "Employee shift assignment" sections; shift cards with Default/Active/Overnight chips, shift length, working time, break, grace, labelled Edit/Deactivate; four-group form with live length/overnight chips and the backend's validation messages.

## 5. Weekly Off bottom-overlap fix
Footer wrapped in `SafeArea(top:false)` (a real `MediaQuery` inset) plus the keyboard `viewInsets`; title and fields scroll while Cancel/Assign are **pinned outside the scroll**; sheet height capped to the screen minus the status bar; list padding = 12 + `MediaQuery.padding.bottom` (+ clearance for the voice bubble). No fixed device-specific spacer — tests prove it by simulating 24 (gesture) and 48 (three-button) insets and asserting the action's bottom ≤ viewport − inset and that it is tappable, through the real `AttendanceScreen` nesting, plus an inset-sensitivity test (gap = inset one-for-one).

## 6. Files
New: `org_chart/.../org_labels.dart`; attendance `screens/{attendance_month_view,attendance_ot_tab,attendance_invalid_punches_tab,attendance_unpunches_tab}.dart` (parts), `widgets/{unpunch_widgets,month_view_widgets,ot_record_card,invalid_punch_card,late_justification_card,weekly_off_sections,shift_card,shift_format}.dart`, `providers/{unpunch_providers,month_view_providers}.dart`; tests and harnesses for every area. Modified: `org_dept_card`, `org_root_card`, `attendance_screen.dart` (imports, removed dead helpers, header Wrap fix), `shift_master_card`, `shift_assignment_tab`, `weekly_off_assignment_tab`, `assignment_form_widgets`, `late_justification_review`, `attendance_entity/datasource/repository(+impl)` (additive: un-punch page). Existing tests adjusted for deliberately changed UI only (shift/weekly-off/un-punch interactions, a loading pump) — no assertion weakened. One fix of mine after integration: the OT card's own month table spelled September "Sep" (an audit test requires en-IN "Sept") → shared formatter + regression test.

## 7–8. Responsive verification
320×568, 360×800, 393×852, 430×932, 600, 800, 1000 widths × 1×/1.5×/2× text × light/dark, long names/reasons/remarks, empty, error, denied, keyboard-open and simulated bottom insets: no overflow in the tests/inspected shots. At 2× text the Attendance screen header title+date overflowed; fixed (Wrap). Note: at 568-high/2× the pinned tab bar is below the first screen (users scroll), so tests scroll to it.

## 9–11. Tests and analyzer
New tests (agent-reported + mine): Org 22, Un-Punches 13, Month View 11, OT+Invalid 23, Late Justification 33, Weekly Off 75, Shift 24 = **201**. `flutter test`: **4061 passed, 0 failed**. `dart analyze`: **7 infos** (pre-existing `curly_braces`, baseline unchanged). Mutation checks per area (restored byte-identical) all failed tests as intended.

## 12. Remaining / decisions for the product owner
- **Un-Punches actions removed** (web has none): confirm that review only in Approvals is acceptable.
- **Month View** now uses the web endpoint; **not ported**: the "Mark Attendance" form for no-record days and the full detail drawer (needed edits inside `attendance_screen.dart` private widgets); search is server-side (web preloads 500).
- **Gaps left against web:** OT Records branch filter; Invalid Punches pagination (mobile fetches 100).
- **Shift card** shows "Present from X h · Overtime after Y h" — a paraphrase of backend help text for min/max working hours (not on web); remove if undesired. New client-side blocking only mirrors backend limits (start≠end, net hours > 0, break ≤ 480, grace ≤ 120).
- **Weekly Off agent did not re-read the web source**; its "no functional mismatch" rests on existing mobile code/tests — worth a quick web re-check on staging.
- Late Justification: the API has no late minutes (only clock-in is shown; lateness is not computed); `resubmit_by` is not in the entity.
- No before-screenshots for Month View; 320dp OT before shots failed; Un-Punches 2× before shot missing.
- Not verified on device/emulator or staging. A tap on "Add Shift" at 320×568 with 2× text missed once in a test (agent moved the test to 320×800 without root-causing it).

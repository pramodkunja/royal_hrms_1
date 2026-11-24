# Task 106 — Leave Policy: Carry Forward web parity + Monthly Leave Management responsive repair

Evidence is render/mocked-API only (no device or emulator pass, no production calls). Screenshots: `evidence/t106/before_t106_*` and `t106_*`.

## 1. Carry Forward web feature inventory (web `CarryForwardTab.tsx` and children)
Permission gate `leave.edit`; From/To year selects from the years endpoint; Preview (POST `{from_year,to_year}`); preview table (employee, code, leave type, unused days, carry forward, expiry, status) with total/pending/already-done counts; Run with confirmation; 409 duplicate and 400 invalid handling; success message with processed/skipped counts; history table (Period, Executed By, Processed, Skipped, Failed, Status, Date) paged 20; empty/error states.

## 2. Parity matrix (summary)
| Web control | Mobile before | Correction |
|---|---|---|
| History Date column | missing | added (en-IN date + time) |
| Failed count | hidden when 0 | always shown |
| 409 / 400 on run | one generic error | status-based: dismissible duplicate warning / server message / generic |
| Run confirm | no scope | dialog states scope, employee-leave count, "cannot be undone"; non-dismissible while running |
| Duplicate submit | possible | `_running` guard, buttons disabled, one POST |
| After success | history only | history, years, leave balance and stats providers refreshed; stale preview cleared |
| To Year vs From Year | could be invalid | auto-corrected to a valid year |
| States | ad hoc | shared empty / error (Retry) / denied states |
| Layout | rows overflowed at 320dp@2x | record cards, stacking, 1/2 columns |

Documented deviation (kept): mobile enables Run only after a matching Preview (HO-37); web allows Run without Preview.

## 3. Monthly Leave overlap — root cause
Fixed-width Rows with no Flexible/Wrap: select-all row (154px at 320dp@2x), action Rows (primary button off-screen at 360dp), fixed 150dp stats, month/year Row with floating labels, bare file-name Text, record cards cramming Credit/Current/Change on one line, nested scroll in the employee checklist, lazy ListView disposing card state. Parent bar now uses the shell `AppTopBar` via `PushedAppTopBar`; tab strip scrolls with a 48dp import action. No API/payload/business-rule change; no functional mismatch with web found.

## 4. Files
Lib: `leave_carry_forward_tab.dart` (rewritten), `leave_policy_screen.dart`, `monthly_leave/{monthly_leave_widgets,monthly_leave_tab,monthly_manual_entry_section,monthly_import_section,monthly_assignments_section}.dart`.
Tests: `carry_forward_parity_test.dart` (new, 31), `monthly_leave_responsive_test.dart` (new, 24), `test/visual/leave_policy_tabs_visual_test.dart` (new harness). Existing `carry_forward_ho37_test.dart` and `monthly_leave_management_test.dart` untouched.

## 5. Results
Full `flutter test`: 3595 passed, 0 failed. `dart analyze`: 7 infos (same pre-existing `curly_braces` count as baseline). Subagent mutation checks (action bar never stacks; nested ListView restored) failed the tests as expected.

## 6. Remaining
- Run/Preview POSTs not exercised against a real backend (stand-in only); no live balance changes were made.
- No device/emulator pass; keyboard behaviour is widget-test only.
- Not every Monthly shot was inspected end to end by the subagent; parent viewed 07, 08b, 08c.

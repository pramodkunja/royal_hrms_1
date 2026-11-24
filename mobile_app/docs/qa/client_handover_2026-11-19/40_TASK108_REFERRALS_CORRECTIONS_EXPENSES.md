# Task 108 — My Referrals, Attendance Corrections, Expense Statistics

Evidence is render/mocked-API only (no device or emulator pass, no live financial or attendance writes). After-screenshots: `evidence/t108/t108_*`. **Before-screenshots were not captured**: the code was changed before the harness existed and Git (the only way back) is off-limits; the "before" behaviour is documented below from the source.

## 1. Web / backend findings
**Referrals.** Web `referrals/page.tsx` calls only the referral list, the all-referrals list (admins), branches and referral rules; it has **no** bonus-breakdown section and no bonus calculation. Mobile's `ReferralBonusBreakdownPanel` was a hardcoded three-stage panel with a fixed "₹10,000" and "—" placeholders, tied to no record. The backend has `ReferralBonus` endpoints, but the web page does not use them, so there is no supported data source for that panel.
**Attendance.** Web `AttendanceCorrectionsTab.tsx`: card "Recent Correction Requests" (latest 5, newest first, `GET /attendance/corrections/my/?kind=punch&page_size=100`) with a header link **View All Corrections** → `/dashboard/my-requests?tab=attendance_correction`. No permission condition; the backend scopes the list to the signed-in employee. My Requests (`page.tsx`) accepts `?tab=leave|expense|wfh|attendance_correction`.
**Expenses.** Web `ExpenseClaims.tsx` shows five cards from `GET /expenses/stats/` (no parameters): Total Claims `total`; Pending `pending` + `pending_amount` (when > 0); Approved `approved` + `approved_amount` (when > 0); Rejected `rejected`; Total Claimed Amount `total_amount`. Backend `ExpenseStatsView` aggregates server-side; users with `expenses.approve` get company-wide figures, everyone else only their own claims. The list endpoint is paginated (default 20) and scoped differently (branch/team/HR for approvers).

## 2. Files modified
Lib: `referrals/presentation/widgets/referral_rule_card.dart`, `referrals/presentation/screens/referrals_screen.dart`, `attendance/presentation/screens/my_attendance_screen.dart`, `my_requests/presentation/screens/my_requests_screen.dart`, `core/router/app_router.dart`, `expenses/data/models/expense_model.dart`, `expenses/data/datasources/expense_remote_datasource.dart`, `expenses/presentation/screens/expense_screen.dart`.
Tests: `test/features/task108_parity_test.dart` (new, 49), harness `test/visual/task108_visual_test.dart` (new, 13 shots).

## 3. Referrals
Removed the whole panel (class, stage data, `₹10,000`, usage and the spacer above it); added closing space under the last rule card. Rules, referrals, stats and Refer Someone are unchanged. A source-level test fails if the panel returns.

## 4. Attendance corrections
Card renamed "Recent Correction Requests", shows the latest 5 (sorted by `created_at`, as web), counts still cover all punch corrections. **View All Corrections** (key `corrections-view-all`, ≥44dp, always visible on the corrections tab, wraps at large text) does `context.push('/dashboard/my-requests?tab=attendance_correction')` — the existing My Requests screen, no duplicate module. `MyRequestsScreen` now takes `initialTab` from `?tab=`; the selected chip scrolls into view. Back (system back / pop) returns to My Attendance. Data: one `GET /attendance/corrections/my/?page_size=100`, no employee parameter (server scoping). Pending/Approved/Rejected tiles stack at large text.

## 5. Expense statistics mapping
| Card | API field | Formatting |
|---|---|---|
| Total Claims | `total` | integer |
| Pending | `pending` (+ `pending_amount` when > 0) | integer; sub-amount en-IN, up to 2 decimals |
| Approved | `approved` (+ `approved_amount` when > 0) | integer; sub-amount en-IN |
| Rejected | `rejected` | integer |
| Total Claimed Amount | `total_amount` | ≥1 lakh "₹1.5L", ≥1 thousand "₹12.5K", else en-IN (web `formatAmount`) |

## 6. Root cause of incorrect statistics
The endpoint and field names were already right. The faults were in handling: (1) a 404 or non-object response became `ExpenseStats.empty()` — an error showed as "0 claims"; (2) missing/odd fields were coerced to 0; (3) `valueOrNull` hid errors entirely and showed the previous numbers during a refresh; (4) the Rejected card and the pending/approved amounts web shows were missing (4 cards instead of 5); (5) amounts under ₹1,000 were rounded to whole rupees (₹999.50 → ₹1000); (6) the category filter changed the list but not the cards, with no indication. Now: failures propagate, fields are nullable ("—" when unknown, real 0 stays 0), cards show "—" while loading/refreshing and an error strip with Retry (or Access denied for 403) after a failure; a note appears when a category filter is on ("totals cover all claims in every category").
Refresh: initial load, pull-to-refresh, and after a successful submit (verified by the screen's reaction to the form's success result; the receipt picker itself is not driven in tests). The summary is not re-requested on category change (web has no filtered stats). The detail dialog performs no mutations, and approvals happen elsewhere (the screen reloads on re-entry), so nothing extra is fetched on return.

## 7. Verification
`flutter test`: 3702 passed, 0 failed. `dart analyze`: 7 infos (pre-existing `curly_braces`, unchanged baseline). Mutation checks (restored byte-identical): reverting the loading/stale rule, swallowing 404 as zeros, and dropping the tab parameter each fail tests. A "physics" change I tried for pull-to-refresh was unnecessary (primary scroll views are already always-scrollable) and was reverted.
Layouts checked at 320/360/393/430/600/1000dp and 1.5×/2× text, light and dark.

## 8. Remaining / not verified
- Not on a device; real backend responses and the approver-vs-employee scope of `/expenses/stats/` should be checked on staging.
- For approvers the summary is company-wide while the list is scope-limited (backend behaviour, same as web).
- The expense list shows only the first 20 claims (no paging) — unchanged, out of scope.
- Pre-existing at 320dp @ 2×, untouched: My Attendance's Attendance tab (calendar header, clock button, summary cells), the Late Arrival Justifications card, the expense form header and expense list rows.

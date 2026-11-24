# Task 109 — Leave → Analytics: backend statistics integration and UI

Evidence is render/mocked-API only (no device or emulator pass, no live data). Screenshots: `evidence/t109/t109_l_*`. **No before-screenshots**: the code was changed before the harness existed and Git is off-limits; the earlier behaviour is documented from the source.

## 1. Web Analytics statistics inventory (`LeaveAnalytics.tsx`)
One request: `GET /leave/stats/?year=<calendar year>` (`&scope=own` for an "employee"). No user-selectable filters — no year picker, branch, leave-type or employee selector. Year = `getLeaveYear()` = `new Date().getFullYear()`. Employee = no `leave.approve`, no `can_manage_team`, no `can_manage_branch` (a permission rule, not a role name). Shows: five cards (Total Requests, Approved, Pending Approval, Rejected, Loss of Pay (LOP) with "N request(s) in YEAR"), a Leave Balance Breakdown (employees' own balances only), an employee empty-state ("No leave balance data for YEAR. Contact HR…"), and a Request Status Distribution (Approved / Pending / Rejected / Cancelled with % of total, shown only when total > 0).

## 2. Card → backend field mapping (`LeaveStatsView`)
| Card | Field | Backend rule | Shown as |
|---|---|---|---|
| Total Requests | `total` | all requests with `start_date` in the year | integer |
| Approved | `approved` | status approved | integer |
| Pending Approval | `pending` | pending **plus** L2-pending | integer |
| Rejected | `rejected` | status rejected | integer |
| Loss of Pay (LOP) | `lop_days` (+ `lop_requests`) | sum of `lop_days` over **approved** requests; count of approved requests with LOP > 0 | days (1 decimal when fractional); sub "N request(s) in YEAR" |
| Status distribution | `approved/pending/rejected/cancelled` ÷ `total` | — | "n (p%)", rounded |
| Balance breakdown | `balances[]` (`total_days`, `used_days`, `available`) | own-scope views only | "x used / y total", "z remaining" |
Scope: server-side — `scope=own`, no `leave.approve`, or `employee_id` → the user's own requests (+ balances); otherwise team/branch/org by approval scope. Permission: any authenticated user; `employee_id` needs `employees.view`/approve (403/404 otherwise).

## 3. Root cause
The endpoint, `year` parameter and the four count fields were already right. The faults were in what the screen did with the response: (1) the **Loss of Pay card was missing** although `lop_days`/`lop_requests` were parsed; (2) absent, null or non-numeric fields were read as 0 and shown as real zeros; (3) after a failed refresh the previous numbers stayed on screen (error shown only when nothing had ever loaded); (4) a body that is not an object crashed with a cast error; (5) "employee" for the empty-balance card was decided by the role name `employee`, not by permissions; (6) the section header row overflowed at large text; (7) status labels were clipped (`maxLines: 1`). Race ordering was already correct (Riverpod discards a superseded build) — now covered by tests.
Not a cause / not changed: the request itself (`year` only), because the backend scopes identically with or without `scope=own` (`own_scope = scope == 'own' or not has_approve`) and an existing test pins the request shape.

## 4. Files modified (Flutter only)
`leave/domain/entities/leave_entity.dart` (+`unavailable`), `leave/data/models/leave_models.dart` (strict, tolerant parsing), `leave/data/datasources/leave_remote_datasource.dart` (non-object body → error), `leave/presentation/widgets/leave_analytics_tab.dart` (five cards, states, permission-based scope), existing `test/features/leave/leave_stats_year_test.dart` (two assertions updated, see below). New: `test/features/leave/leave_analytics_stats_test.dart` (38), harness `test/visual/task109_visual_test.dart` (10 shots).
Two existing assertions changed because Task 109 changes the behaviour they encoded: the loading state now has **5** placeholders (was 4), and a 403 now reads "Access denied" (was the generic failure title). No assertion was relaxed.

## 5. Filter and refresh behaviour
Web has no filters, so none are offered. Verified: initial load (one GET `?year=`); pull-to-refresh refetches and shows placeholders meanwhile (not stale numbers); refresh re-reads the calendar year (tab left open over New Year asks for the new one); leave actions that already invalidate `leaveStatsProvider` (apply, approve, cancel, carry-forward) refetch once; a failed refresh shows the error, not old data; rapid requests — the older response answering last never overwrites the newer, and three quick refreshes end on the last response; the subtitle shows the year the server answered for.

## 6. States
Loading "…" + spinner; valid zero "0" (and "0 requests in 2026"); unavailable "—" with "Unavailable"; unknown total hides the distribution; error with Retry (404/500/malformed); 403 "Access denied" with the server's message and no Retry; empty (zeros) and employee no-balance hint.

## 7. Verification
`flutter test`: 3740 passed, 0 failed. `dart analyze`: 7 infos (pre-existing `curly_braces`, unchanged baseline). Mutation checks (restored byte-identical): showing stale data after failure, treating unavailable as 0, accepting a non-object body — each fails tests. Layout checked at 320/360/393/430/600/1000dp and 1.5×/2×, light and dark; 320dp @ 2× stacks the cards in one column.

## 8. Remaining
- Not on a device; confirm on staging with a real approver (team scope) and an employee with and without balances.
- The backend gives no per-leave-type LOP or month breakdown, so none is shown. LOP is shown as days without a unit, as on web.
- `employee_id` (another employee's stats) is a backend capability the Analytics tab does not use (nor does web's).
- Home's Leave Balance card shares `leaveStatsProvider` and still reads missing values as 0 (unchanged, out of scope).

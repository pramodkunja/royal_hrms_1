# Dashboard and WFH Defect Fixes (D1, D2): QA

**Date:** 2026-11-03
**Source:** defects D1 and D2 in `docs/qa/CROSS_FEATURE_REGRESSION_AUDIT.md`, both approved for fixing.

## D1: permission-filter all dashboard shortcuts

### Root cause

Task 2 applied the route permissions (`canAccessPath`, `lib/core/router/access_control.dart`) to the side menu and the Quick Access tiles only. Other dashboard shortcuts still pushed permission-gated routes. For a user without the permission, the router guard then silently returned them to the Dashboard.

While inspecting the files the audit named, two more shortcuts with the same root cause turned up, both pointing at `/dashboard/leave`:
- the "Apply leave" link in the employee dashboard's Recent Requests empty state;
- the "Apply Leave" button on the attendance card, which is shown on every dashboard.

Both are covered here because D1 is "all dashboard shortcuts".

### Permissions used (from `kRoutePermissions`, unchanged)

| Path | Required permission(s) |
|---|---|
| `/dashboard/leave` | `leave.view` |
| `/dashboard/expenses` | `expenses.view` |
| `/dashboard/documents` | `documents.view` |
| `/dashboard/candidate-review` | `recruitment.view` |
| `/dashboard/approvals` | any of `leave.approve`, `expenses.approve`, `wfh.approve` |
| `/dashboard/employees` | `employees.view` |
| `/dashboard/my-attendance`, `/dashboard/profile`, `/dashboard/separation` | none (self-service) |

### Changes

| File | Change |
|---|---|
| `lib/features/dashboard/presentation/screens/employee_dashboard_view.dart` | **Quick Links:** now a `ConsumerWidget` that shows only links the user can open, and hides the whole card if none remain. "My Attendance" is open to everyone, so in practice the card always has at least one link. **Action Items:** an item whose screen the user can't open is still listed (it is information from the server) but is no longer tappable. **Recent Requests empty state:** the "Apply leave" link and its tap are shown only with access to Leave; the "No requests yet." text stays. |
| `lib/features/dashboard/presentation/screens/hr_dashboard_view.dart` | **Action Queue:** each row is shown only if its destination is accessible, with dividers only between visible rows. **Total Pending** is now the sum of the visible rows that the backend counts. The backend's `HRActionQueueView` sums candidate reviews, leave approvals, attendance corrections, expense claims and onboarding reviews, and leaves out separation. Users who see every row therefore get exactly the server's figure. Separation is open to everyone, so the card is never empty. |
| `lib/features/dashboard/presentation/widgets/attendance_ring_card.dart` | The "Apply Leave" button (and its spacing) is shown only with access to `/dashboard/leave`. |

**Unchanged:**
- destination routes, `kRoutePermissions`, backend APIs, and the seeded role permissions;
- the admin dashboard: only users with `settings.edit` or superusers reach it, and they pass every permission check, so every shortcut there stays valid.

## D2: WFH "Reports to Review" visibility

### Root cause

The review block was shown when `review.hasError || reviewable reports exist`. A failed review-list request therefore made a reviewer-only section appear for everyone. When the WFH module is disabled, both lists fail with the same message, so the error was shown twice.

### Change

| File | Change |
|---|---|
| `lib/features/wfh/presentation/widgets/wfh_daily_reports_tab.dart` | The block is shown only when reviewable reports exist, which is exactly web's rule. My Reports keeps its own error and Retry. The review controls still follow the server's `can_review`. |

If a reviewer's refresh fails after their reports were shown, Riverpod keeps the previous rows, so the block stays and shows the error with Retry. A test confirms this.

## Tests added

### `test/features/dashboard/dashboard_shortcuts_test.dart` (14 tests)

These pump the real `HomeScreen` against a fake backend, with stub destination routes so taps can be checked.

- **Employee role without `leave.view`:** no Leave History link and no "Apply Leave" button. The empty state keeps its text but drops the link. The leave action item is listed but tapping it goes nowhere.
- **Without `expenses.view`:** no Claim Expense link; the other links remain.
- **Without `documents.view`:** no My Documents link; the document action item is inert.
- **With the permissions:** all shortcuts are shown and work (an action item opens Documents, a Quick Link opens Expenses).
- **No permissions at all:** the Quick Links card still holds one link (My Attendance) and is never empty.
- **Custom HR role** (`employees.view`, `leave.view`, `expenses.view`; no `recruitment.view` and no approve permissions): the queue shows Leave Approvals, Expense Claims, Onboarding Reviews and Separation Requests, and the total is 11 (2 + 4 + 5).
- **HR role without approve permissions:** only Attendance Corrections is hidden; the total is 12.
- **Visible queue row:** still opens its screen (Candidate Reviews).
- **Standard roles:**
  - Employee: all 4 Quick Links and Apply Leave.
  - Manager: generic dashboard with Apply Leave.
  - HR Admin and Branch Admin: all 6 queue rows, server total 15, Apply Leave.
  - System Admin: admin dashboard with Apply Leave.

**Proof the tests catch the defect:** with the three dashboard files reverted to their pre-fix code, the 6 restriction tests fail. The tests for permitted users and standard roles pass on both versions, as they should, since that behavior is unchanged. The files were then restored byte for byte.

### `test/features/wfh/wfh_daily_reports_tab_test.dart` (8 new tests in a "D2" group)

- Employee with an empty review list: no block.
- Employee whose review request returns 403: no block, no reviewer error, no Retry.
- Reviewer with reviewable reports: block shown, with controls only on reports marked `can_review`.
- Reviewer with an empty review list: no block.
- Review list fails while My Reports succeeds: own reports shown, no reviewer error.
- Module disabled (both lists fail): the message appears once, with a single Retry.
- My Reports failure stays visible, and Retry reloads it.
- A reviewer's refresh fails: the block stays, with the error and Retry.

**Proof:** with the old condition restored, 3 of these fail (the 403, partial-failure and module-disabled cases). The file was restored byte for byte.

## Results

- **Focused suites** (dashboard, WFH, router): 89/89 pass.
- **Full suite:** `flutter test` gives **152/152 pass** (130 before plus 22 new).
- **`flutter analyze`:** 13 issues, all pre-existing info-level `curly_braces_in_flow_control_structures` messages. None in the changed files.
- **Build:** `flutter build apk --debug --target-platform android-arm64` succeeded. The APK's Dart code was checked to contain both fixes.

## Emulator

- **Device:** `emulator-5554`, Android 14 (API 34).
- **First attempt:** on AVD `Android_Emulator_34`, the install failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE` (624 MB free; the 246 MB APK needs about twice that). The previous Royal HRMS build had already been uninstalled from that AVD as part of the reinstall, so it currently has no Royal HRMS installed. No other apps or data were touched.
- **Switch:** that emulator was shut down normally and AVD `flutter_emulator` (also Android 14, 5.1 GB free) was booted. It took the same serial, `emulator-5554`.
- **Install:** Success (`com.royalhrms.app`, versionName 1.0.0, versionCode 5).
- **Launch:** `com.royalhrms.app/.MainActivity` is in the foreground on the Sign In screen.
- **Errors:** no Flutter or runtime exceptions in logcat.
- **Evidence:** a screenshot of the login screen, stored in the session scratchpad outside the repository.
- **Authenticated checks:** not performed. `~/royal_demo_accounts.txt` has not changed since 2026-11-02 16:10 (rejected credentials), so no login was attempted. No production writes and no reviewer actions.

## Remaining limitations

- D1 and D2 are verified by automated tests only. Live, authenticated checks of the dashboards and the WFH tab wait for working credentials.
- The limitations listed in the audit are unchanged (L1–L4): login-time permission snapshot, WFH default date across midnight, no deep links, and the existing duplicate provider name.
- The `Android_Emulator_34` AVD is short on storage (about 624 MB free). Future installs there need space freed first, or use `flutter_emulator`.

## Repository state

- Changed files, all in `mobile_app/`:
  - `lib/features/dashboard/presentation/screens/employee_dashboard_view.dart`
  - `lib/features/dashboard/presentation/screens/hr_dashboard_view.dart`
  - `lib/features/dashboard/presentation/widgets/attendance_ring_card.dart`
  - `lib/features/wfh/presentation/widgets/wfh_daily_reports_tab.dart`
  - `test/features/wfh/wfh_daily_reports_tab_test.dart`
  - new: `test/features/dashboard/dashboard_shortcuts_test.dart`
  - new: this report
- No files outside `mobile_app/` changed. The web repository status is unchanged (the same 9 earlier P0-04A entries).
- Nothing was staged, committed, pushed or stashed.

# Cross-Feature Regression Audit (Tasks 1–4)

**Date:** 2026-11-03
**Branch:** `mobile/p0-auth-fixes` (uncommitted work preserved)

**Scope:**
1. Forced password change and the voice assistant restriction
2. Permission-based navigation and quick access
3. Reports placeholder restriction
4. WFH Daily Reports

**Changes required by this audit:** none were made. Two new defects are reported below and wait for approval.

## Newly discovered defects (awaiting approval; not fixed)

| ID | Severity | Defect | Where | Who is affected |
|---|---|---|---|---|
| D1 | Low–Medium | **Dashboard shortcuts outside Quick Access are not permission-filtered.** Task 2 filtered the side menu and the Quick Access tiles only. Other dashboard links still navigate to permission-gated routes, and the route guard then silently returns the user to the Dashboard (the same symptom fixed in Org Chart). | `employee_dashboard_view.dart`: "Quick Links" card (`/dashboard/leave`, `/dashboard/expenses`, `/dashboard/documents`, lines ~1343–1360) and action-item routes (`documents`, `leave`, lines 653–656). `hr_dashboard_view.dart`: Action Queue tiles (`candidate-review`, `leave`, `approvals`, `expenses`, lines ~360–390). | Only users of custom roles that lack the matching permission (`leave.view`, `expenses.view`, `documents.view`, `recruitment.view`, the approve permissions). The five seeded roles hold every permission their dashboard links need, so none of them hits it. |
| D2 | Low | **The WFH tab shows a "Reports to Review" error block to every user when the review list fails to load.** For a plain employee, or when the WFH module is disabled (both lists fail with the same 403 message), a reviewer-only section appears holding a duplicate error. Web hides the section unless it has rows. | `lib/features/wfh/presentation/widgets/wfh_daily_reports_tab.dart`: the `review.hasError \|\| …` condition | Every user when that request fails. A cosmetic deviation from web; no wrong data. |

**Suggested fixes (not applied):**
- **D1:** filter those links with the existing `canAccessPath(user, path)`, the same pattern already used for the menu, the tiles and Org Chart.
- **D2:** show the review block only when it has rows (exactly web's rule), or show its error only when the "My Reports" list loaded successfully.

## Task-by-task findings

### A. Forced password change and the voice assistant (Task 1)

| Check | Result | Basis |
|---|---|---|
| Login flag parsing | OK | `UserModel.fromJson` reads a boolean `must_change_password`; absent or null means false. The flag survives the cached-session round trip. Covered by tests. |
| Router redirects | OK | A flagged user is sent to `/change-password` from every one of the 50 registered routes. Verified exhaustively (below) with no chains or loops. |
| Session clearing | OK | Success leads to `AuthNotifier.logout()`, then `clearSession()`: secure storage is wiped and the API host's cookies are deleted. A server logout failure still clears the local session. |
| Fresh login | OK | Only a login response with the flag false opens the app. If the flag is still true, the user is sent back. Covered by tests. |
| Voice assistant restriction | OK | The mic is hidden through `voiceAssistantAllowedProvider`. `_ensureAllowed()` guards `startListening`, `openTypedCommand`, `_performSubmit` and `_attemptSilentFallback`. Covered by tests. |
| No password retained | OK | The form fields are cleared on success. The login pre-fill carries only the company code, the email and a notice. |
| Live | NOT VERIFIED | No account with `must_change_password` is available (see `FORCED_PASSWORD_CHANGE_LIVE_QA.md`). |

### B. Permission-based navigation (Task 2)

Exhaustive check: every registered route, for each of the seeded role permission sets plus a no-permission role.

| Role | Routes refused | Menu items that redirect | Quick Access tiles that redirect | Reports reachable | WFH reachable |
|---|---|---|---|---|---|
| Employee | 30 / 50 | none | none | no | yes |
| Manager | 25 / 50 | none | none | no | yes |
| HR Admin | 3 / 50 | none | none | no | yes |
| Branch Admin | 1 / 50 | none | none | no | yes |
| System Admin | 1 / 50 | none | none | no | yes |
| No permissions | 34 / 50 | none | none | no | yes |

- **Refused routes:** Employee is refused Approvals, Assessments, Attendance (team), Branches, Recruitment screens, Employees (including profiles), Face ID Registrations, Reports, Settings and all `/settings/*` screens. Manager is refused the same minus Approvals, Attendance and Employees. In both cases the remaining routes are the self-service and team screens their roles hold. Branch Admin and System Admin are refused only Reports.
- **In-app links into refused routes:**
  - Org Chart → profile was already fixed.
  - Separation detail links target `/dashboard/separation/…`, which is open to everyone.
  - Settings, Interview List and Employees sub-links sit inside screens whose own permission already covers them.
  - The remaining unfiltered links are D1.
- **Live check on 2026-11-02:** all five roles on the emulator before Task 3 (`REPORTS_PLACEHOLDER_NAVIGATION_QA.md` and the earlier session).

### C. Reports placeholder (Task 3)

| Check | Result |
|---|---|
| Hidden for every role | OK. `buildNav` skips `kUnavailablePaths` (unit-tested for all five roles and a `reports.view`-only user). |
| Direct navigation | OK. `canAccessPath` refuses `/dashboard/reports` and its sub-paths for everyone, which sends the user to the Dashboard (no loop: Dashboard itself is never refused). |
| Other System items | OK. Audit Log and Settings stay; the empty System header is dropped. |
| Report-independent features | OK. The prefix match is exact (`/dashboard/reports` or `/dashboard/reports/…`), so `/dashboard/reports-archive` would not match. Nothing else uses `kUnavailablePaths`. WFH "Daily Work Report" is a WFH route (`/dashboard/wfh`) and is unaffected. |
| Live | NOT VERIFIED (credentials). |

### D. WFH Daily Reports (Task 4)

| Check | Result |
|---|---|
| API paths and payloads | OK. Own list: `GET /wfh/reports/?mine=1`. Review list: `GET /wfh/reports/`. Submit: `POST /wfh/reports/` `{date, completed_work, pending_work, updates}`. Review: `POST /wfh/reports/<id>/review/` `{outcome, remarks}`. Tested against a fake HTTP adapter. |
| Response parsing | OK. Every serializer field is mapped; unknown statuses default to pending. |
| Employee vs reviewer lists | OK. Two separate providers. The review block shows only when it has rows (but see D2 for the error case). |
| Server-controlled review | OK. Review controls appear only where the server sends `can_review: true`. No client-side role rules. |
| Loading, empty, error, retry | OK. Tested, including showing the server's message. |
| Date validation | OK. The picker's maximum is today and the date is sent as `yyyy-MM-dd`. The backend remains authoritative (company timezone). |
| Duplicate-action protection | OK. The in-flight guard plus a disabled button on both submit and review. The test fails if the guard is removed. |
| Navigation | OK. The third tab on the WFH screen, which is reachable by every role. |
| Live | NOT VERIFIED (credentials; writes are not allowed). |

### E. Cross-feature integration

| Check | Result |
|---|---|
| Redirect loops | **None.** 50 routes × 6 permission sets × {flag off, flag on}, plus signed-out: every redirect target resolves without a further redirect. |
| Redirect order | OK. Signed-out, then forced password change, then onboarding, then permission guard. The forced password change wins over the permission guard. |
| Auth interceptor | OK. Only a 401 triggers refresh or logout. 403 responses (for example WFH "You cannot review this report", or module-disabled responses) surface as messages and never end the session. The new WFH calls use the shared `dioProvider` (same cookies and refresh). |
| Session expiry | OK. A failed refresh sets `sessionExpiredProvider`, which logs out; the router then sends the user to Login. |
| Provider conflicts | No new conflicts. The WFH report providers are uniquely named and auto-disposing, so no data carries across sign-out or account switches. One existing duplicate name (`employeeAttendanceSummaryProvider` in the attendance and dashboard provider files, from commit `2a1ceff7`) predates Tasks 1–4. |
| Loading deadlocks | None found. The submit and review guards reset in all paths (success, server error, network error), as the tests show. The earlier token-refresh deadlock (P0-02) is covered by interceptor tests. |
| Stale cached permissions | **Existing limitation (L1).** |
| UI overflow and navigation | No overflow errors in the widget tests (the WFH tab is rendered at full size). The app launches to Login with no Flutter or runtime errors in logcat. Authenticated screens were not re-inspected live. |

## Existing limitations (not regressions)

1. **L1: permissions and flags come from the login-time snapshot.** Session restore uses the cached user from secure storage, with no profile refresh. Permission changes, and a `must_change_password` set by an admin, reach the app only at the next login. The backend does not enforce `must_change_password` on API calls (it is only in the token and the login response), so an already signed-in mobile session continues until it is signed out or expires. Server-side permission checks still protect data.
2. **L2:** the WFH form's default date is set when the form opens. If the app stays open past midnight, it keeps the previous day; the backend accepts this and flags the report as late.
3. **L3:** the app has no deep links, so route guards are reachable only through in-app navigation.
4. **L4:** the duplicate provider name noted above (existing).
5. **L5: live verification.** The credentials in `~/royal_demo_accounts.txt` have not changed since 2026-11-02 16:10 and were rejected then. Per the rules, no login was attempted. No forced-password-change account exists.

## Files inspected

- `lib/core/router/app_router.dart`, `lib/core/router/access_control.dart`, `lib/core/network/auth_interceptor.dart`
- `lib/features/auth/**`: notifier, repository, user model, force-change screen, login form
- `lib/features/voice_commands/**`: access provider, controller, mic overlay
- `lib/features/dashboard/**`: nav config, sidebar, quick access, employee, HR and admin dashboard views, home screen
- `lib/features/org_chart/presentation/screens/org_chart_screen.dart`, the separation screens, the settings hub, and the employees and interview list screens (navigation calls)
- `lib/features/wfh/**`: all new report files and `wfh_screen.dart`
- **Backend (read-only):** `apps/accounts/tokens.py`, plus every use of `must_change_password` and the WFH report views and model

## Automated test results

- **Focused suites:** router, auth, voice, dashboard, Org Chart, WFH and attendance. 118/118 pass.
- **Full suite:** `flutter test` gives **130/130 pass**.
- **Exhaustive route audit:** a temporary test run for this audit and deleted afterwards. 0 redirect chains; no visible menu item or Quick Access tile redirects for any role.

## Build and analyzer

- **`flutter analyze`:** 13 issues, all pre-existing info-level `curly_braces_in_flow_control_structures` messages. No new issues.
- **`flutter build apk --debug --target-platform android-arm64`:** succeeded. The APK's Dart code was checked to contain the Task 3 (`isUnavailablePath`), Task 4 ("Daily Work Report") and Org Chart changes.

## Emulator results

- **Device:** `emulator-5554` (AVD `Android_Emulator_34`, Android 14 / API 34).
- **Install and launch:** the APK installed successfully. `com.royalhrms.app/.MainActivity` launched to the Sign In screen.
- **Errors:** no Flutter or runtime exceptions in logcat.
- **Evidence:** screenshot `01_launch_login.png` (login screen only, no data). Stored outside the repository in the session scratchpad.
- **Authenticated checks:** not performed (L5).

## Changes made

None to app or test code. The only file added is this report.

## Status

The audit is complete. **D1 and D2 await approval before any fix.** Live, authenticated verification of Tasks 1–4 remains open, pending working credentials.

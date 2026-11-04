# Reports Placeholder Navigation: QA

**Date:** 2026-11-02
**Scope:** removing access to the unfinished mobile Reports placeholder until the real module is built.

## Audit: files inspected

| Location | Finding |
|---|---|
| `lib/features/dashboard/presentation/navigation/nav_config.dart` | The `reports` menu item (System section, `reports.view`) and the `/dashboard/reports` page title. This is the only menu entry for Reports. |
| `lib/core/router/app_router.dart` | `AppRoutes.reports = '/dashboard/reports'`. Its route renders `PlaceholderScreen(title: 'Reports')`; there is no real screen. |
| `lib/core/router/access_control.dart` | Route permission `'/dashboard/reports': ['reports.view']`. |
| `lib/features/dashboard/presentation/widgets/quick_access.dart` | No Reports tile for any role. |
| `lib/features/dashboard/presentation/widgets/app_sidebar.dart` | Renders `buildNav(user)`, so it follows the menu change. |
| Dashboard views, voice commands, notifications | No links to `/dashboard/reports`. |
| Report APIs (`lib/`) | None. Mobile has no report data sources or providers. |
| `web_frontend_backend/frontend/app/dashboard/reports/page.tsx` (read-only) | Web has a real Reports module, which mobile has not ported yet. |

The placeholder was reachable from one place: the **Reports** item in the side menu. Users with `reports.view` saw it, which in practice is HR Admin, Branch Admin and System Admin. The app has no deep links, so the menu was the only way in.

## Changes

| File | Change |
|---|---|
| `lib/core/router/access_control.dart` | Added `kUnavailablePaths = {'/dashboard/reports'}` and `isUnavailablePath()`. `canAccessPath()` refuses those paths for every user, so the router redirect sends them to `/dashboard`. |
| `lib/features/dashboard/presentation/navigation/nav_config.dart` | `buildNav()` skips items whose path is unavailable. Sections left empty are already dropped. |
| `test/core/router/access_control_test.dart` | Menu expectations now use an explicit `_availableNavIds` (all items except `reports`). Added a "Reports placeholder" group with 5 tests. |

Not changed:
- the Reports `NavItem`;
- the `/dashboard/reports` route and `PlaceholderScreen`;
- the `reports.view` route permission;
- every other module's permissions.

When the real screen ships, remove the path from `kUnavailablePaths` and replace the placeholder route.

## Automated test results

- `test/core/router/access_control_test.dart`: 25/25 pass. The new tests cover:
  - Reports hidden for employee, manager, HR, Branch Admin, System Admin, and a user holding only `reports.view`;
  - the System section keeps Audit Log and Settings, and disappears when Reports was its only item;
  - direct navigation to `/dashboard/reports` and its sub-paths returns to the dashboard for every role;
  - the nav entry, route permission and prefix matching are kept;
  - no quick tile points at Reports.

  The exact menu for each of the five roles is still asserted. The existing consistency test confirms that every visible menu item and quick tile opens without being redirected.
- **Proof the tests catch the change:** with the gate removed from both files, 7 tests fail. With it restored (files byte-identical), all pass.
- **Full suite:** `flutter test` gives 109/109 pass.

## Flutter analysis

`flutter analyze`: 13 issues, all pre-existing info-level `curly_braces_in_flow_control_structures` messages. No new issues.

## Android emulator verification

- **Device:** `emulator-5554`, sdk_gphone64_arm64, Android 14 (API 34).
- **Build:** debug APK (arm64) with this change built and installed successfully. The app uses the production API.

| Role | Reports hidden | Other items present | Dashboard navigation | Result |
|---|---|---|---|---|
| Employee | Not verified | Not verified | Not verified | BLOCKED |
| Manager | Not verified | Not verified | Not verified | BLOCKED |
| HR Admin | Not verified | Not verified | Not verified | BLOCKED |
| Branch Admin | Not verified | Not verified | Not verified | BLOCKED |
| System Admin | Not verified | Not verified | Not verified | BLOCKED |

### Why live verification did not complete

The local demo-credential file `~/royal_demo_accounts.txt` was rewritten at 16:10, after the last successful demo logins (15:10–15:33). Sign-in with the current file is rejected ("Invalid company code, email, or password.") for the employee and manager accounts. A check before submitting confirmed that each field's length matched the stored value, so the cause is not a typing problem. Login attempts were stopped to avoid locking the accounts. The other three roles were not tried.

### Earlier live evidence (before this change)

Earlier on 2026-11-02, a live run on the same emulator confirmed that HR Admin, Branch Admin and System Admin saw **Reports** in the System section, and that Employee and Manager did not. That run shows where the placeholder appeared. It does not verify this change.

## Screenshots and evidence

None for this change: no login succeeded. Screenshots from an aborted attempt were deleted because they showed the emulator's launcher search screen (see the incident below).

## Remaining issues

1. **Live verification for all five roles is pending.** It needs the credentials in `~/royal_demo_accounts.txt` to match the accounts' current passwords.
2. **Test-harness incident.** In the first attempt the app was not in the foreground, and the automated login typed into the emulator launcher's Google search box. Fragments of the employee account's credentials may have been sent to Google's search-suggestion service while they were typed. Nothing was submitted as a search. The login script now refuses to type unless Royal HRMS is in the foreground with its login form showing, and it checks field lengths before submitting. **Recommendation: change the employee demo account's password again.**

## Final status

**PARTIAL**: implementation and automated verification are complete. Live emulator verification is pending for all five roles.

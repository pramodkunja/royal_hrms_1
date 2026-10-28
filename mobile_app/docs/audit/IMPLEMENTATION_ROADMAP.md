# Implementation Roadmap — Royal HRMS Mobile

*Prepared 2026-10-28 from the audit in this folder. **Nothing here has been implemented yet; each task needs approval before code changes.***

How to read this:
- Mobile paths are relative to `mobile_app/`, backend paths to `web_frontend_backend/backend/`, web paths to `web_frontend_backend/frontend/`.
- Complexity: **S** is under half a day, **M** is 1–3 days, **L** is over 3 days.
- "Order" is the suggested sequence across all priorities.

## Recommended sequence (overview)

| Order | ID | Task | Size |
|---|---|---|---|
| 1 | P0-00 | Preserve the uncommitted mobile work (branch + mobile-only commit) | S |
| 2 | **P0-02** | **Fix the auth-interceptor refresh deadlock and add the first unit tests (recommended first code task)** | S–M |
| 3 | P0-01 | Forgot password: send `company_code` | S |
| 4 | P0-05 | Enforce `must_change_password` | S |
| 5 | P0-03 | iOS bundle id and camera permission; fail release builds without a signing key | S |
| 6 | P0-04 | Face-verification decision (mobile bypass and cross-platform embeddings) | Blocked → M/L |
| 7 | P1-01 | Dashboard selection by flags (Branch Admin 403s) | S |
| 8 | P1-03 | Attendance `day_completed` | S |
| 9 | P1-04 | My Payslips pagination | S |
| 10 | P1-07 | Per-company module gating (403 "not enabled") | M |
| 11 | P1-08 | Credential storage hygiene and dead token code | M |
| 12 | P1-11 | Delete the face capture JPEG after embedding | S |
| 13 | P1-09 | Roles: `can_manage_branch` | S |
| 14 | P1-02 | Device smoke-test pass of the uncommitted features | M |
| 15 | P1-06 | Pre-joining assessment gate and portal | M |
| 16 | P1-05 | Config-driven onboarding wizard | L |
| 17+ | P2-* | Feature parity, ordered by user reach (see §P2) | — |
| ongoing | P3-* | Quality, tests and refactors when touching files | — |

---

## P0 — Critical blockers

### P0-00 · Preserve the uncommitted mobile work · S
- **Description:** create a feature branch and commit **only** `mobile_app/` paths. The commit must not include the 384 root-level deletions of the old `backend/` and `frontend/`.
- **Reason / evidence:**
  - 169 uncommitted mobile paths (+9,270/−5,489 lines), including the whole WFH, Separation, Email Log, My Requests and Onboarding-Fields features.
  - The last mobile commit is `d6e2e55` (2026-08-13).
  - The root working tree shows `backend/` and `frontend/` as deleted (`git status`).
- **Files:** `mobile_app/**`.
- **Dependencies:** **your explicit approval** (this audit was instructed not to commit).
- **Acceptance criteria:**
  - `git status -- mobile_app` is clean.
  - `git show --stat HEAD` lists only `mobile_app/` paths.
  - Signing files stay ignored.
- **Tests:** `flutter analyze` with 0 errors; `flutter test` passes.

### P0-01 · Forgot password sends `company_code` · S
- **Description:** add a Company ID field to the forgot-password flow, pre-filled from the login form, and send it in all three requests.
- **Reason:** backend `apps/accounts/serializers.py:150-178` requires it. Today every step returns 400 (`API_COMPATIBILITY.md` §3.1).
- **Files:**
  - Mobile: `lib/features/auth/data/models/forgot_password_models.dart`, `lib/features/auth/domain/usecases/{forgot_password,verify_otp,reset_password}_usecase.dart`, `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/data/repositories/auth_repository_impl.dart`, the forgot-password screen and widgets.
  - Web reference: `components/auth/ForgotPasswordForm.tsx`.
- **Dependencies:** none.
- **Acceptance criteria:** against a test tenant, request OTP → verify → reset succeeds; a wrong company code shows the server message.
- **Tests:** unit tests for the `toJson` of all three models; a repository test with a fake Dio adapter asserting the body keys.

### P0-02 · Auth interceptor: fix the refresh deadlock and add the first tests · S–M · **recommended first code task**
- **Description:**
  - Tag the retried request (`options.extra['authRetried']=true`) and pass it straight through on any error.
  - Treat a 401 on the retry as session-expired.
  - Settle queued requests on non-Dio errors in `_resolvePending`.
  - Add the test harness: a `test/` folder structure and a fake `HttpClientAdapter`.
- **Reason / evidence:**
  - `lib/core/network/auth_interceptor.dart:92-95,123,191-193`: a plain `Interceptor` retries through the same Dio instance (`api_client.dart:45`).
  - A second 401 is queued behind the in-flight refresh. That refresh never completes, so `_isRefreshing` stays true and every later 401 in the app hangs until the app restarts.
  - Every API call depends on this class, so fixing it first also gives the project its first real tests.
- **Dependencies:** none.
- **Acceptance criteria:**
  - Refresh succeeds and the retry returns 200, so the caller resolves.
  - Refresh succeeds but the retry returns 401: the session-expired flow runs and the caller rejects. **No hang.**
  - Five concurrent 401s trigger exactly one refresh call.
  - A network error during refresh does not log the user out.
  - A non-Dio error settles every queued request.
- **Tests:** `test/core/network/auth_interceptor_test.dart` covering all five scenarios above with a scripted fake adapter.

### P0-03 · Release configuration blockers · S
- **Description:**
  - iOS: set `PRODUCT_BUNDLE_IDENTIFIER` to the agreed id (Android is `com.royalhrms.app`) and add `NSCameraUsageDescription`.
  - Android: make release builds fail when `key.properties` is missing instead of silently using debug signing.
- **Evidence:**
  - `ios/Runner.xcodeproj/project.pbxproj:512,694,716` (`com.example.mobileApp`).
  - `ios/Runner/Info.plist` has location, microphone and speech descriptions but **no camera description**. iOS terminates the app on first camera access (Face ID, image picker).
  - `android/app/build.gradle.kts:59-62` falls back to `signingConfigs.getByName("debug")`.
- **Dependencies:** your choice of iOS bundle id, and whether the Apple team or provisioning is set up.
- **Acceptance criteria:** an iOS simulator run opens the camera without a crash; `flutter build appbundle` without `key.properties` fails with a clear message.
- **Tests:** manual build checks.

### P0-04 · Face verification on mobile (bypass and cross-platform) · **Blocked: decision required**
- **Description:** align mobile clock-in with the company's mandatory-face-attendance rule.
- **Evidence:**
  - Backend `apps/attendance/services_face_matching.py:207` skips verification unless `source` is `web` or `voice`.
  - Mobile sends `source='mobile'` (`lib/features/attendance/data/datasources/attendance_remote_datasource.dart:47`).
  - `services_face_matching.py:159-162` rejects descriptors of different lengths. Mobile uses MobileFaceNet (192-d); web uses face-api.js (128-d).
- **History:**
  - On 2026-08-10 a local backend change removed the `mobile` exemption and added a server-side dlib endpoint, `/attendance/face-registration/extract-embedding/`.
  - That change was **never committed**. It existed only in the old root `backend/` working tree, which is now deleted, and no commit on any branch contains it (`git log --all -S extract-embedding` is empty).
  - Mobile later moved to on-device MobileFaceNet instead.
- **Options:**
  - (a) Backend change: verify `mobile` too and keep per-platform reference embeddings, tagged by model.
  - (b) Mobile ships a 128-d face-api-compatible model, and the backend verifies `mobile`.
  - (c) Formally make face attendance web-only, and remove face capture from ordinary mobile punches.
- **Files:**
  - Mobile: `lib/features/attendance/**`, `lib/features/facial_recognition/**`, `lib/features/voice_commands/presentation/controllers/voice_command_controller.dart`.
  - Backend: `apps/attendance/services_face_matching.py`, `apps/attendance/views/face_registration.py`.
- **Dependencies:** product and security decision; backend team approval for (a) or (b).
- **Acceptance criteria:**
  - With face attendance mandatory, a mobile punch without a matching face is rejected.
  - Each registration path is accepted by every platform that verifies against it.
- **Tests:** backend tests for the source matrix; mobile repository tests for the punch payload; device test.

### P0-05 · Enforce `must_change_password` · S
- **Description:** add a router redirect to a change-password screen when `user.mustChangePassword`. On success, clear the session and return to login with the company code and email pre-filled, as web does.
- **Evidence:**
  - Parsed at `lib/features/auth/data/models/user_model.dart:38` but never read.
  - The backend does not enforce it server-side.
  - Web: `app/change-password/page.tsx`.
- **Files:** `lib/core/router/app_router.dart` (redirect), profile change-password reuse (`lib/features/profile/data/datasources/profile_remote_datasource.dart:53`).
- **Dependencies:** none.
- **Acceptance criteria:**
  - A flagged user cannot reach `/dashboard/*` until the password is changed.
  - After the change, the login form is pre-filled.
- **Tests:** a router redirect unit test (auth state → expected location).

## P1 — Core functionality

### P1-01 · Dashboard selection by flags · S
- **Description:** replace the role-name substring logic with: `isSuperuser` → Admin, `canManageTeam` → Manager, `hasPermission('employees.view')` → HR, otherwise Employee.
- **Evidence:**
  - `lib/features/dashboard/presentation/widgets/quick_access.dart:17-23`; `screens/home_screen.dart:35`.
  - A Branch Admin is routed to the system-admin endpoints, which need `settings.edit` (`apps/dashboard/views/overview.py:24`).
  - Web: `app/dashboard/page.tsx:13-26`.
- **Dependencies:** none. The Manager view stays generic until P2-02.
- **Acceptance criteria:** system_admin, hr, manager, branch_admin and employee test users each land on a dashboard with no 403s.
- **Tests:** a pure-function unit test of the selector.

### P1-02 · Device smoke-test pass of uncommitted features · M
- **Description:** run the uncommitted features on a real Android device (and iOS after P0-03) against a test tenant. Record the results in `docs/audit/DEVICE_TEST_LOG.md`.
- **Features to cover:** WFH, Separation, Email Log, My Requests, Onboarding Fields, Notification settings, geofence pre-check, Face ID registration and capture quality, voice clock-in (TTS / Hindi fallback).
- **Evidence:** last edits 2026-08-25→27, never device-tested (memory notes and file mtimes).
- **Dependencies:** P0-00, P0-03, and a test tenant with credentials (supplied by you, never committed).
- **Acceptance criteria:** each flow is marked pass or fail, with issues filed as tasks.
- **Tests:** manual checklist.

### P1-03 · Attendance `day_completed` · S
- **Description:** parse `day_completed` and show a "Day completed" state that disables the punch button on My Attendance, the dashboard ring card and voice clock-in.
- **Evidence:**
  - `lib/features/attendance/data/models/attendance_models.dart:56-67` does not read it.
  - Backend daily limit: `apps/attendance/services_attendance.py:~305`; serializer `serializers_my_attendance.py:179`.
- **Acceptance criteria:** after clock-out, no clock-in button is offered; a server 400 message is shown verbatim if one is hit anyway.
- **Tests:** a model `fromJson` test; a provider test.

### P1-04 · My Payslips pagination · S
- **Description:** request `page_size=100`, or page through `total_pages`.
- **Evidence:** `lib/features/payroll/data/datasources/payroll_remote_datasource.dart:20-32`; backend `apps/payroll/views/payslips.py:405-409`.
- **Acceptance criteria:** a user with more than 20 payslips sees all of them.
- **Tests:** a datasource test with a two-page fake.

### P1-05 · Config-driven onboarding wizard · L
- **Description:** fetch `/onboarding/field-config/`, `/onboarding/document-type-config/` and `/onboarding/custom-file-fields/`, then render visibility, required flags, custom fields (including file and image fields) and document types dynamically.
- **Evidence:**
  - `lib/features/onboarding/data/datasources/onboarding_datasource.dart` calls only `/onboarding/`, `/step/<n>/` and `/documents/`.
  - Web: `app/onboarding/page.tsx`, `_components/DynamicStepFields.tsx`.
- **Files:** `lib/features/onboarding/**` (split the 1,684-line `onboarding_steps.dart` per step), reusing `lib/features/settings/data/models/onboarding_field_config_model.dart`.
- **Dependencies:** P0-00.
- **Acceptance criteria:** fields hidden or marked required in Settings → Onboarding Fields are reflected in the wizard; custom file fields upload successfully.
- **Tests:** widget tests for dynamic field rendering; a model parsing test.

### P1-06 · Pre-joining assessment gate and portal · M
- **Description:**
  - Add a router redirect when `assessmentStatus` is pending.
  - Build a portal: list `/assessments/my/`, respond `/assessments/<id>/respond/<item>/`, then `/complete/` and `/retry/`.
  - Exempt users with `canManageTeam`, `canManageBranch` or `isSuperuser`, as web does.
- **Evidence:**
  - `user_model.dart:44` (parsed, unused).
  - The backend blocks `/dashboard/employee/*` until assessments are complete.
  - Web: `app/onboarding/assessments/page.tsx`.
- **Acceptance criteria:** a user with a pending assessment completes it on mobile and then reaches the dashboard.
- **Tests:** router test; provider tests.

### P1-07 · Per-company module gating · M
- **Description:**
  - Map a 403 whose message contains "is not enabled for your company" to a dedicated `ModuleDisabledException` with a friendly empty state.
  - Hide menu entries for disabled modules if the backend exposes the enabled-module list. *Needs verification* (`apps/tenants/feature_gate.py`, the company settings endpoint).
- **Evidence:** `apps/tenants/feature_gate.py`. My Payslips and Attendance Approval both sit under `/api/payroll/`.
- **Acceptance criteria:** a tenant without payroll sees "Payroll is not enabled" instead of a generic error.
- **Tests:** a `parseDioException` unit test.

### P1-08 · Credential storage hygiene · M
- **Description:**
  - Keep the `PersistCookieJar`, which is the only working credential store, but move it to the application-support (no-backup) directory.
  - Set `android:allowBackup="false"` or `dataExtractionRules`.
  - Remove the dead Bearer and body-refresh token code.
  - Stop `deleteAll()` from wiping the theme preference.
  - Persist the last company code for login pre-fill.
- **Evidence:**
  - `lib/main.dart:31-39`; `lib/core/network/auth_interceptor.dart:40-56,101-120`; `lib/features/auth/data/repositories/auth_repository_impl.dart:48-53,103-109`.
  - Backend cookie-only tokens: `apps/accounts/views.py:584-613`; `apps/tenants/middleware.py:56-66`.
- **Dependencies:** P0-02 (same files; its tests protect this change).
- **Acceptance criteria:**
  - Login survives an app restart.
  - Logout clears the cookies but keeps the theme.
  - Upgrading from the old cookie location keeps the user logged in, or forces one clean re-login.
- **Tests:** extend the interceptor and repository tests.

### P1-09 · Roles: `can_manage_branch` · S
- **Description:** add `canManageBranch` to the role model and form. First verify whether the mobile role update is a full PUT that would clear the flag.
- **Evidence:** `lib/features/settings/data/models/roles_model.dart:36,80` (only `can_manage_team`); web `settings/permissions` modals.
- **Acceptance criteria:** editing the Branch Admin role on mobile preserves `can_manage_branch`.
- **Tests:** model round-trip test.

### P1-10 · Notifications refresh · S
- **Description:** refresh the unread count periodically (60 s, as web does) while the app is in the foreground, and on resume.
- **Evidence:** web bell = WebSocket + 60 s poll; mobile is REST-only (`lib/features/notifications/**`).
- **Acceptance criteria:** a new approval request appears on the bell within 60 s.

### P1-11 · Delete the face capture image after embedding · S
- **Description:** delete the still JPEG in a `finally` block after the embedding is computed.
- **Evidence:** `lib/features/facial_recognition/presentation/capture/face_capture_controller.dart:315-350` never deletes the `takePicture()` file. Biometric residue remains in the cache directory.
- **Acceptance criteria:** no face JPEG remains in the cache after registration or punch.
- **Tests:** controller test with a fake file system, or a manual check.

## P2 — Feature parity (ordered by user reach)

| ID | Feature | Description | Evidence (mobile / web / backend) | Dependencies | Acceptance criteria | Size |
|---|---|---|---|---|---|---|
| P2-01 | Employee dashboard cards | Notice-period countdown card (links to separation detail) and "my birthday" card | Mobile: `employee_dashboard_view.dart` / web: `components/dashboard/employee/*` / backend: `dashboard/employee/notice-period/`, `dashboard/birthdays/mine/` | P1-01 | An employee in notice sees the days remaining | S |
| P2-02 | Manager dashboard | Port the web Manager view | Mobile: `home_screen.dart` `_GenericDashboardView` / web: `_components/ManagerDashboard.tsx` / backend: `dashboard/manager/` (`apps/dashboard/urls.py:32`) | P1-01; confirm the web widget is real, not mock | A manager sees team KPIs | M |
| P2-03 | Announcements for all | Remove the `announcements.view` menu gate; restrict posting to `announcements.create` and org-wide posting to `settings.edit` | Mobile: `nav_config.dart:45` / web: commit `eb0ac93` | none | An employee without the permission can read announcements | S |
| P2-04 | Candidate review | Make the document "View" button open the URL (url_launcher); add HR decision (approve or reject the candidate with email) | Mobile: `candidate_review_screen.dart:1032` / web: `HRDecisionModal.tsx` / backend: `recruitment/candidates/<id>/hr-decision/` | none | Documents open; a decision updates the status | M |
| P2-05 | Assessments admin | Sections CRUD, results view, paginated lists | Mobile: `lib/features/assessments/**` / web: `app/dashboard/assessments` / backend: `/assessments/<id>/sections/`, `/results/` | none | Parity with web admin actions | M |
| P2-06 | Employee detail (HR) | Real promotion history via `/employees/<id>/promotions/`; leave credits adjust and reverse; reset password; assets (read-only) | Mobile: `employee_profile_screen.dart` (1,967 lines; split by tab) / web: `employees/[id]/_components/*` | Split the file first (P3-03) | Each tab matches web data | L |
| P2-07 | Attendance admin | Shift and weekly-off assignments (view, assign, history); import single-employee mode with dry-run preview; attendance config (working hours, weekly days) | Mobile: `attendance_screen.dart` (3,525 lines), `settings/presentation/attendance_rules/` / web: `app/dashboard/attendance/*`, `settings/attendance-config` / backend: `attendance/shift-assignments/*`, `weekly-off-assignments/*`, `import/` (`dry_run`) | Split the file first (P3-03) | HR can assign a shift on mobile | L |
| P2-08 | My Payslip detail and query | Detail view; raise a payslip query and see open queries | Mobile: `lib/features/payroll/**` / web: `app/dashboard/my-payslip` / backend: `payroll/payslips/<id>/`, `payroll/queries/` | P1-04 | A query raised on mobile appears in web Approvals | M |
| P2-09 | Approvals inbox | Add Separation and Payslip-query kinds; bulk approve or reject for leave, WFH, expense and correction | Mobile: `approvals_providers.dart:29` / web: `app/dashboard/approvals/*` | P2-08 for payslip | Parity with web kinds | M |
| P2-10 | Profile | Work Info tab (Reporting Manager, Approver, Branch HR); configurable document types and custom file fields | Mobile: `lib/features/profile/**` / web: `ProfileClient.tsx` / backend: `/employees/me/`, `/onboarding/document-type-config/`, `/onboarding/custom-file-fields/` | P1-05 (shares config models) | Matches web Work Info | M |
| P2-11 | Monthly leave management | Settings → Leave Policy → Monthly Leave tab (manual multi-select entry and assignments list; XLSX import optional) | Mobile: `settings/presentation/leave_policy/` / web: commits `d2f7a5c`…`77579fe` / backend: `leave/monthly-credits/*` | none | HR can credit monthly leave | M |
| P2-12 | Assets | Asset list and detail; assign and return (admin); bulk import excluded | Mobile: none / web: `settings/assets` / backend: `/assets/*` | Decide the mobile scope | CRUD parity for the chosen scope | L |
| P2-13 | Branches | Assign and reassign Branch Admin (two-step confirm); geofence lat/lng/radius edit | Mobile: `lib/features/branches/**` / web: `BranchManagement.tsx` / backend: `branch/branches/<id>/reassign-admin/`, `/geofencing/` | P1-09 | Matches web | M |

## P3 — Quality improvements

| ID | Task | Evidence | Acceptance criteria | Size |
|---|---|---|---|---|
| P3-01 | Test suite growth | Error parsing (`parseDioException`); router redirect matrix; leave and separation provider tests with repository overrides; add `riverpod_lint` and stricter lints | `test/widget_test.dart` placeholder only | CI-runnable `flutter test` with over 30 meaningful tests | M |
| P3-02 | Shared response unwrap and typed errors | 24 copies of `_unwrap`; only 4 datasources use `parseDioException`; 98 `_friendly(e.toString())` | One `core/network/api_response.dart`; no `package:dio` imports in presentation except where justified | M |
| P3-03 | Split god-files when touched | `attendance_screen.dart` 3,525, `my_attendance_screen.dart` 2,231, `apply_leave_tab.dart` 2,089, `employee_profile_screen.dart` 1,967, `onboarding_steps.dart` 1,684 | No file over about 800 lines in touched features | L (incremental) |
| P3-04 | Promote duplicated widgets and models | 9 `_StatusBadge`, 3 `_BranchDropdown`, duplicated dashboard cards, 2× `EmployeePickerOption` | Single shared versions | M |
| P3-05 | Paginate capped lists | interview list, candidate review, assessments, attendance (`page_size` 100–200); `fetchEmployees()` loops every page | Use the leave/separation `loadMore` pattern | M |
| P3-06 | Tolerant JSON ids | About 36 hard casts (`as int`) in settings models | Malformed ids no longer crash list parsing | S |
| P3-07 | Lifecycle leaks | Undisposed dialog `TextEditingController`s; one created in build at `branch_location_selector.dart:169` | No leaks flagged | S |
| P3-08 | Fonts offline | Poppins fetched at runtime (`google_fonts`) | Bundle the font or set `allowRuntimeFetching=false` | S |
| P3-09 | Environment via `--dart-define` | Committed LAN IP in `lib/core/config/api_config.dart`; no flavors | No IP in source; documented run commands | S |
| P3-10 | Analyzer infos | 13 `curly_braces_in_flow_control_structures` | `flutter analyze` reports 0 issues | S |
| P3-11 | Stale comments and dead code | Carry-forward "404" comment (`lib/core/constants/api_constants.dart:281`); `face_capture_state.dart:3`; AndroidManifest go_router version; unused `payslipDetail`, `settingsEmailTemplatePreview`, `DashboardScreen`, `payrollSettingsProvider` | Removed or corrected | S |
| P3-12 | Router guard gaps | `/employees/bulk-import`, `/interview-list/bulk-import` are outside the auth guard; no permission guards on routes | Guarded; optional route→permission map | S |
| P3-13 | Revalidate the cached user on cold start | `AuthNotifier.build()` trusts the cached user | Role or permission changes apply without re-login | S |
| P3-14 | Global search, ID card view, Leave Credit Rules mock | Web-only extras; `leave_credit_rules_screen.dart:337` is mock | Product decision, then implement or remove | M |
| P3-15 | Journal hygiene | `teamcontextfile.md` is stale since 2026-08-03 | Add a pointer to `docs/audit/` | S |

## Items needing backend approval (do not implement unilaterally)
1. P0-04 options (a) or (b): face verification for `source='mobile'` and per-platform embeddings.
2. Optional: return tokens in the response body and resolve the tenant from `Authorization: Bearer`. This would only be needed for Flutter web cross-origin or cookie-less clients.
3. Self-service "My ID card" and "My assets" endpoints, if wanted on mobile. Today they need `employees.view` / `assets.view`.
4. A tenant module list endpoint, if the backend doesn't already expose one (P1-07). *Needs verification.*

## Checks to unblock (need your approval)
- **Backend test suite:** create a throwaway `backend/.env` with dummy secrets and `DATABASE_URL` pointing at the **local** PostgreSQL only. Install pinned requirements into a fresh venv (the existing `.venv` has Django 5.2 rather than 5.1.15). Run `python manage.py test`, which uses the tenant-aware runner.
- **Frontend checks:** `npm ci`, then `npm run lint` and `npm test` (vitest) in `frontend/`.

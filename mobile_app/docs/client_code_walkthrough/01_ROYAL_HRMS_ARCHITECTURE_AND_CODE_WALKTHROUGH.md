# ROYAL HRMS — Mobile Application Architecture & Code Walkthrough

**Application:** Royal HRMS (Android, package `com.royalhrms.app`) · **Version in source:** 1.0.2+10 (`pubspec.yaml`)

**Document date:** 2026-11-18 · **Basis:** source code on disk (mobile app, web frontend, Django backend). No Git history was consulted. No application code was changed. No production calls were made.

**Review status:** technical review pass completed 2026-11-18 against source and the 11-19 handover folder (see `08_FINAL_VERIFICATION_CHECKLIST.md`). Corrections from that pass are already included below.

**Evidence labels used in this document**

| Label | Meaning |
|---|---|
| **Verified (source)** | Read directly in the code. File reference given. |
| **Verified (project record)** | Stated in the project's own QA/audit documents under `mobile_app/docs/`; **not re-run** while writing this document. |
| **Unverified** | Could not be confirmed from the source. Do not state as fact to the client. |

Diagram numbers refer to `05_ARCHITECTURE_DIAGRAMS.md` (also appended to the PDF).

---

## Table of contents

1. Project introduction
2. Technology stack
3. Complete system architecture
4. Flutter folder structure
5. Application startup flow
6. Authentication and security
7. Feature-based architecture
8. Three features end to end
9. State management
10. API integration
11. Database and backend
12. UI architecture and reusability
13. Error handling and performance
14. Testing and quality assurance
15. Build and deployment
16. Maintenance and future development
17. Internal readiness section — open risks (not for reading aloud as "resolved")

---

## 1. Project introduction

### Client explanation (non-technical)

Royal HRMS is a Human Resource Management System: one place where a company manages its people — who works there, whether they came to work today, who is on leave, what they are paid, what training they must complete, and who must approve each request.

It replaces spreadsheets, paper forms and chat messages. Employees can apply for leave and mark attendance from their own phone; managers approve requests from the same phone; HR sees company-wide numbers.

The **mobile app** gives employees and managers the daily tools wherever they are — especially attendance (with location and face check) and approvals. The **web app** is the full desktop version. Both talk to **one shared backend**, so a leave applied on the phone shows up instantly on the web, and the reverse.

### Developer explanation

- Three codebases: Flutter app (`mobile_app/`), Next.js frontend (`web_frontend_backend/frontend`, Next 16.2.9 / React 19.2.4), Django backend (`web_frontend_backend/backend`, Django 5.1.15 / DRF 3.15.2). *Verified (source: `package.json`, `requirements.txt`).*
- The mobile app is an API client of the **same** Django API the web uses. Its constants mirror the web's endpoints (`lib/core/constants/api_constants.dart`). *Verified.*
- The backend is **multi-tenant**: one PostgreSQL schema per company (django-tenants). *Verified (`config/settings.py`).*
- Users: **Employees, Managers, HR, Admins** and (Branch Admin as a role flag). The mobile dashboard picks a view from the user's permissions — `resolveDashboardCategory` in `lib/features/dashboard/presentation/widgets/quick_access.dart:32`. *Verified.*
- Business problems addressed by implemented modules: attendance with geofence/face, leave policy and balances, multi-level approvals and delegation, WFH, expenses, separation (exit), recruitment, assessments, training, payslips, announcements, documents.
- Why a Flutter mobile app: one Dart codebase, native camera/GPS/secure-storage access (all needed for attendance), and one team able to port web features screen by screen. *Rationale from project docs; the choice itself is verified by the code.*
- Scope boundary: the mobile team edits only `mobile_app/`; web and backend are read-only references (project rule). Platform Admin and admin Payroll are **web-only**; mobile has **My Payslips** only. *Verified: no admin payroll screens in `lib/features/payroll` (only `my_payslip_screen.dart`).*

---

## 2. Technology stack

| Area | Technology (version) | Why it is used | Source |
|---|---|---|---|
| Framework | Flutter (SDK constraint Dart `>=3.5.0 <4.0.0`) | One codebase, native device access | `pubspec.yaml` |
| Android SDK levels | compileSdk 36, targetSdk 36, minSdk 24 | Play Store requirements | *Verified (source): `build.gradle.kts` uses `flutter.minSdkVersion/targetSdkVersion`; Flutter 3.44.8 (`flutter.version.json`) defines 24/36/36. Re-check on the actual release build.* |
| State management | `flutter_riverpod ^2.6.1` | Testable, compile-safe state; `AsyncNotifier` models loading/data/error | `pubspec.yaml`, `lib/main.dart` |
| Navigation | `go_router ^14.6.2` | Path-based routes, central redirect rules for auth/permissions | `lib/core/router/app_router.dart` |
| Networking | `dio ^5.7.0`, `dio_cookie_manager`, `cookie_jar` | Interceptors for tokens, timeouts, multipart uploads, cookie persistence | `lib/core/network/api_client.dart` |
| Local secure storage | `flutter_secure_storage ^9.2.2` (Android encrypted shared preferences; iOS Keychain `first_unlock`) | Tokens, cached user, theme, device id | `lib/core/security/secure_storage.dart` |
| Connectivity | `connectivity_plus` | Global "No internet" screen | `lib/core/network/connectivity_provider.dart` |
| Location | `geolocator ^13` | Attendance geofence | `lib/core/location/location_service.dart` |
| Face ID | `camera`, `google_mlkit_face_detection` (liveness), `tflite_flutter`, `image` | On-device 128-d face descriptor | `pubspec.yaml`, `lib/features/facial_recognition/` |
| Voice | `speech_to_text`, `record`, `audioplayers` | Voice commands (backend does language/TTS) | `pubspec.yaml` comments |
| Files | `image_picker`, `file_picker`, `pdfx`, `pdf`, `printing`, `url_launcher`, `webview_flutter` | Documents, payslip PDF, ID card PDF, learning videos | `pubspec.yaml` |
| UI | `google_fonts` (Poppins), `lottie`, bundled Noto fonts | Branding, empty/404/offline animations | `lib/core/theme/` |
| Backend | Django 5.1.15, DRF 3.15.2, simplejwt 5.3.1, django-tenants 3.7.0 | REST API, JWT, per-company isolation | `backend/requirements.txt` |
| Database | PostgreSQL (django-tenants backend; SQLite default only when `DATABASE_URL` unset and multitenancy then unavailable) | Tenant schemas need Postgres | `config/settings.py:145-163` |
| Async/real-time | Celery 5.4, Channels 4.1/Daphne, Redis | Background jobs, web notifications | `settings.py`, `requirements.txt` |
| Files/media | Cloudinary | Stored uploads | `settings.py:210` |
| Auth | JWT in httpOnly cookies, Bearer-header fallback; access 15 min, refresh 7 days, rotation + blacklist | Session security | `settings.py:488`, `apps/accounts/authentication.py` |

*Unverified (production infrastructure):* Python version (requirements do not pin it), whether Redis and Celery workers run, server sizing, database host. The only deployment fact in the source is a comment in `api_constants.dart` that nginx proxies `/api/` to Django on the production host. Do not describe the production infrastructure to the client beyond that.

---

## 3. Complete system architecture

See **Diagram 1**.

| Component | Plain-language role | Status |
|---|---|---|
| Flutter mobile app | The phone app | Verified |
| Web application | Desktop app (Next.js) | Verified (source present; not run) |
| Backend API | The single "brain" both apps call (`/api/...`) | Verified |
| Authentication | Login → tokens in cookies (and in app storage for the phone) | Verified |
| Authorization | Roles → permission codes; module on/off per company | Verified |
| Database | PostgreSQL, one isolated schema per company | Verified |
| File storage | Cloudinary for uploads | Verified (settings) |
| Email | Per-company SMTP settings, sent by background jobs | Verified (settings/models) |
| Reverse geocoding | Turns GPS into an address label (Google Maps, fallback OpenStreetMap) | Verified (settings, `services_geocoding.py`) |
| Voice AI | Sarvam: speech-to-text, LLM fallback, and text-to-speech (`POST /voice/speak/` → `VoiceSpeakView`, Sarvam Bulbul TTS) | Verified (source: `apps/voice_commands/urls.py`, `views_speak.py`). Mobile end-to-end voice is **not device-tested** (project record) |
| Payments/billing | Subscription code exists in the backend tenants app | Verified present; **not used by mobile** |
| WebSocket notifications | Used by web | Verified (consumers exist); **mobile does not use it** — it polls every 60 s |

**How data travels:** Screen → Riverpod notifier → repository → data source → Dio → HTTPS → Django (authenticate → resolve company → module/subscription gate → permission check → database) → JSON envelope `{success/status, message, data}` → model → entity → UI. See **Diagram 6**.

**Implemented vs planned:** Everything above marked Verified is implemented. Reports on mobile is a placeholder and is **hidden and refused** by the router (`kUnavailablePaths` in `access_control.dart`). Admin Payroll, Platform Admin: web-only by decision.

---

## 4. Flutter folder structure

See **Diagram 3**. Real structure (trimmed):

```
mobile_app/
├── pubspec.yaml          version 1.0.2+10, dependencies
├── android/              Gradle, manifest, signing hook
├── assets/               images, Lottie, fonts, face_api/*.tflite
├── lib/
│   ├── main.dart         entry point
│   ├── app/app.dart      RoyalHrmsApp, global overlays
│   ├── core/
│   │   ├── config/       api_config.dart (which backend URL)
│   │   ├── constants/    api_constants.dart (all endpoints)
│   │   ├── network/      api_client, auth_interceptor,
│   │   │                 connectivity_provider
│   │   ├── router/       app_router, access_control
│   │   ├── security/     secure_storage.dart
│   │   ├── theme/        colors, text styles, theme mode
│   │   ├── error/        exceptions.dart
│   │   ├── location/     location_service.dart
│   │   └── utils/        device_identifier.dart
│   ├── features/<name>/  data, domain, presentation (29 folders)
│   ├── shared/           widgets, validators, formatters, ...
│   └── debug/            *_demo_main.dart demo entry points
├── test/                 core, features, shared (170 test files)
├── tool/                 face model conversion scripts
└── docs/                 audit, qa, release
```

| Folder | What it contains | Why | Interacts with |
|---|---|---|---|
| `main.dart` | Startup, `ProviderScope` | Single entry | `app/app.dart`, `core/` |
| `app/` | Root widget | Theme, router, global overlays | `core/router`, `core/theme` |
| `core/` | Cross-feature foundation | Avoid duplicating network/security/theme | Used by every feature |
| `features/*` | One business module each | Isolates change | `core`, `shared` |
| `features/*/data` | Datasources + models + repo impl | All HTTP and JSON lives here | `core/network` |
| `features/*/domain` | Entities + repository interfaces (+ use cases in auth) | UI-facing types | `data`, `presentation` |
| `features/*/presentation` | Screens, widgets, providers (Riverpod), controllers | UI and state | `domain`, `shared` |
| `shared/` | Buttons, text field, empty/error/loading states, validators | Reuse | all features |
| `debug/` | Demo mains | Visual QA without login | not part of normal runs |

Feature size (Dart files): settings 90, employees 35, attendance 33, dashboard 32, facial_recognition 30, assessments 26, wfh 25, auth 25. *Verified by count.*

---

## 5. Application startup flow

See **Diagram 4**. Trace:

1. `lib/main.dart: main()` — `WidgetsFlutterBinding.ensureInitialized()`; registers font and face-model licences; locks portrait on native; loads persisted theme via `ThemeModeNotifier.loadPersisted(SecureStorageService())` and calls `AppColors.applyMode(isDark)`; builds a `PersistCookieJar` (file storage in app documents `/.cookies/`) on native; `runApp(ProviderScope(overrides:[cookieJarProvider...], child: RoyalHrmsApp()))`.
2. **Configuration loading:** there is no `.env`. The backend URL comes from `ApiConfig` (`lib/core/config/api_config.dart`): `current = Environment.production`; `resolvedEnvironment` forces production whenever `kReleaseMode`. Production URL `https://royalhrms.com/api/`. *Verified.*
3. `lib/app/app.dart` — `RoyalHrmsApp` watches `appRouterProvider` and `themeModeProvider`; keys the app on dark mode to rebuild fully on toggle; adds `VoiceMicOverlay` and `_ConnectivityGate` around every route.
4. Router starts at `/` → `SplashScreen` (`lib/features/auth/presentation/screens/splash_screen.dart`, `_resolveSession`): waits for `authStateProvider.future` and a minimum 1.8 s, then `context.go` to dashboard or login.
5. **Session restore:** `AuthNotifier.build()` (`controllers/auth_notifier.dart`) reads the cached user from secure storage via `AuthRepositoryImpl.getCachedUser()`. No network call at this point.
6. **Routing + permissions:** `resolveAuthRedirect` (`app_router.dart:274`) — order: signed-out → login; `must_change_password` → change-password screen; onboarding pending/draft/rejected → onboarding; submitted → awaiting approval; assessments pending → assessment portal; otherwise `canAccessPath` (module + permission) else back to dashboard.
7. **Dashboard loading:** `DashboardShell` wraps all `/dashboard/*` routes; `HomeScreen` switches on `resolveDashboardCategory` to Employee / Manager / HR / Admin views, each with its own providers and endpoints (e.g. `/dashboard/manager/`, `/dashboard/hr/kpis/`).

**Say:** "Startup does not call the server. It restores what is saved, and the first real request proves the session is still valid."

---

## 6. Authentication and security

### 6.1 Login flow
See **Diagram 5**. `LoginForm._submit` → `AuthNotifier.login` → `LoginUseCase` → `AuthRepositoryImpl.login` → `AuthRemoteDataSource.login` → `POST /login/` with company code, email, password. Backend `LoginView` (`apps/accounts/views.py:512`): AllowAny, throttled (20/hour), resolves tenant from `company_code`, generic failure message, lockout (5 attempts / 30 min per settings), returns user, permissions, `can_manage_team`, `can_manage_branch`, `is_superuser`, `enabled_modules`. *Verified.*

### 6.2 Session / token handling
- Repository stores user JSON, `royal_hrms_access_token`, `royal_hrms_refresh_token` in secure storage (`AppConstants`). *Verified.*
- Native also keeps cookies in a persistent jar. Backend sets `royal_access_token` (15 min) and `royal_refresh_token` (7 days), httpOnly, SameSite=Lax. *Verified.*
- `AuthInterceptor.onRequest` adds `Authorization: Bearer`. `onError` on 401: one shared refresh (`POST /token/refresh/`, body `{refresh}`), replay once, otherwise `sessionExpiredProvider` → `AuthNotifier.logout()`. Network failure during refresh does **not** log the user out. *Verified (`auth_interceptor.dart`; tests in `test/core/network/auth_interceptor_test.dart`).*
- Refreshed access token's `modules` claim updates menus (`modulesFromAccessToken`).
- **Cookie vs Bearer (important, verified in source):** the backend authenticates from the `royal_access_token` cookie first and falls back to the Bearer header (`CookieJWTAuthentication`). But the **company (tenant) is resolved only from the cookie's `company_schema` claim** (`apps/tenants/middleware.py`); a request with a Bearer header and no cookie stays on the public schema and cannot reach company data. So on mobile the **persistent cookie jar is load-bearing**, not just the Bearer header. This is the reading of the source; a cookie-less request was not tested. The comment in `auth_interceptor.dart` describing Bearer as "the only thing that makes auth work" where cookies fail should therefore not be repeated to the client.

### 6.3 Logout
`AuthRepositoryImpl.logout` calls `POST /logout/` (401 swallowed), and **always** `clearSession()` (`deleteAll` secure storage + cookie jar). Backend blacklists the refresh token and clears cookies. *Verified.*

### 6.4 Role-based access and module permissions
- Server: `Role → RolePermission → Permission` with `module.action` codes. `has_perm`: superuser or `settings.edit` passes everything — **except** that for roles with `can_manage_branch` the `settings.edit` shortcut returns False for *data scope* (`core/permissions.py`), while `can_edit_settings()` still admits them to settings screens. *Verified in the refreshed local backend; production revision unconfirmed.*
- Mobile mirror: `userHasPermission` (`access_control.dart`) implements the same rule; `kRoutePermissions`, `kRouteModules`, `canAccessPath`. Menu, route guard and dashboard tiles all call the same functions.
- Companies can disable modules (`enabled_modules`); mobile uses `ModuleGate` and route guard; server enforces in middleware (403).

### 6.5 Mobile checks vs backend authorization
| | Mobile UI checks | Backend |
|---|---|---|
| Purpose | Hide what you cannot use; avoid pointless errors | The actual security boundary |
| Can be bypassed? | Yes, by a modified client | No |
| Example | Hide Approve button without `leave.approve` | Server rejects the call regardless |

State to the client: "The app hides things for convenience; the server enforces every rule."

### 6.6 Error handling and expiry
`parseDioException` maps timeouts, no-connection, 401, 403 (login 403 = account locked), 404, 422, 429, 5xx to typed exceptions with the server's own message where present. Raw Dio text is never shown. *Verified.*

### 6.7 Security measures verified in the app
Secure storage; debug logging only in debug and never headers/bodies (`_DebugLoggingInterceptor`); release forced to production URL; cleartext traffic not enabled (project record: no `usesCleartextTraffic`); `READ_PHONE_STATE` removed in manifest (camera permission is added by the camera plugin's merged manifest — not inspected here); on-device face descriptors, no images uploaded; profile documents viewed in-app and temporary copies cleaned at start and sign-out (`profileDocumentSessionCleanupProvider`).

> **Do not claim** any security issue below is resolved — see section 17.

---

## 7. Feature-based architecture

Pattern for every module: `presentation/screens` → `providers` (Riverpod) → `data/datasources` (Dio) → `ApiConstants` path. Permissions come from `kRoutePermissions` unless noted. Status uses the labels in the legend. **Tested** here means "automated tests with fake servers exist"; **no module has verified write workflows against production** (project record: only the Branch Admin role and read-only flows were exercised on a device; Employee, HR, Manager roles NOT TESTED).

| Module | Business purpose | Permission / module | Status |
|---|---|---|---|
| **Dashboard** | Role-based home, KPIs, quick tiles, clock card | None for home | Implemented; read paths device-checked (project record) |
| **Employees** | Directory, profile, documents, ID card, bulk import | `employees.view` (+ `employees.create/edit`) | Implemented; writes not live-verified |
| **Attendance (self)** | Clock in/out, calendar, stats, corrections | self-service; module `attendance` | Implemented; clock-in **not** live-verified |
| **Attendance (HR)** | Records, overtime, invalid punches, shifts, weekly offs, late justification | `attendance.edit` or `settings.edit` | Implemented |
| **Face recognition** | Register face; HR approve/register | `facial_recognition.approve` for HR queue | Implemented; **real-device face validation outstanding** (project record FACE-06) |
| **Leave** | Apply, balances, team calendar, cancellation, approvals | `leave.view`; module `leave` | Implemented; writes not live-verified |
| **Approvals** | One inbox for leave, WFH, expenses, corrections, separation, payslip queries; delegation | any of `leave.approve`, `expenses.approve`, `wfh.approve`, `separation.approve`, or delegator rule | Implemented |
| **Work From Home** | Request WFH, daily reports, saved locations | self; module `wfh` | Implemented |
| **Payroll / Payslips** | Employee views own payslips, raises query | module `payroll` | **Partial by design**: My Payslips only; admin payroll is web-only |
| **Recruitment** | Interview list, candidate review, referrals, email log | `recruitment.view/create` | Implemented |
| **Assessments** | HR management, employee "My Assessments", onboarding gate | `assessments.*` | Implemented |
| **Training & Learning (admin)** | Courses, materials, assign, progress, reports, authoring | `training.view`; module `training` | **PARTIAL (HO-25)**: screens built 18 Nov; read-only device-checked; **all writes mock-tested only**. Not available: *New Assessment* (web-only, HO-49), *un-archive* (no backend endpoint). Open per QA record: course-opening parity switch OFF (HO-48), PowerPoint/Word handling (HO-47), approvers section (HO-42, as of batch 1) |
| **My Learning** | Learner courses, PDF reader, video players, assessment | module `training` | **Built, learner writes unverified**: list, tabs, course page, locked assessment device-checked read-only; progress/assessment writes **mock-tested only** (29 tests); needs a staging account with disposable assignments |
| **Settings** | 19 settings sub-routes: company, departments, roles, SMTP, email templates, leave policy, holidays, attendance rules, approval rules, ID card, assets, etc. | `settings.view` / `settings.edit` and others per screen | Implemented; Credit Rules accrual editor removed (no backend) |
| **Notifications** | Bell, panel, settings | self | Implemented |
| **Onboarding** | New-hire wizard, HR approval | gated by `onboarding_status` | Implemented; endpoints fixed 2026-08-07 (project memory) |
| **Others** | Announcements, Branches, Documents, Org chart, Expenses, Separation, Contacts, My Requests, Profile, Voice commands |  | Implemented; **voice commands not device-tested** (project memory) |
| **Reports** | — | — | **Not built**; hidden |

**Module details (files, state, endpoints)**

- **Dashboard** — *Files:* `dashboard/presentation/screens/{home,employee_dashboard_view,manager_...,hr_...,admin_...}.dart`, `widgets/attendance_ring_card.dart`. *State:* `dashboard_providers.dart` (FutureProviders), `dashboardRevisitProvider`. *Endpoints:* `/dashboard/system-admin/kpis/`, `/dashboard/hr/kpis/`, `/dashboard/manager/`.
- **Employees** — *Files:* `employees/presentation/employees_screen.dart`, `screens/employee_profile_screen.dart`, `employee_id_card_screen.dart`. *State:* notifiers in `employees/presentation/providers`. *Endpoints:* `/employees/...`.
- **Attendance (self)** — *Files:* `attendance/presentation/screens/my_attendance_screen.dart`, `clock/clock_punch_flow.dart`. *State:* `TodayAttendanceNotifier` etc. in `attendance_providers.dart`. *Endpoints:* `/attendance/punch/`, `/geofence-check/`, `/today/`, `/stats/`, `/summary/`, `/calendar/`, `/correction/`.
- **Attendance (HR)** — *Files:* `attendance_screen.dart` (3,945 lines) + widgets. *State:* HR providers in same file set. *Endpoints:* `/attendance/records/`, `/overtime/`, `/un-punches/`, `/corrections/` ....
- **Face recognition** — *Files:* `facial_recognition/presentation/...`, `face_api/*`. *State:* `facial_recognition_providers.dart`, `face_capture_controller.dart`. *Endpoints:* `/attendance/face-verification/status/`, `/face-registration/me/`, `/face-registration/` ....
- **Leave** — *Files:* `leave/presentation/screens/leave_screen.dart`, `widgets/apply_leave_tab.dart`. *State:* `LeaveRequestsNotifier`, paginated `LeaveTeamPendingNotifier`. *Endpoints:* `/leave/requests/`, `/leave/balance/`, `/leave/policy/`, `/leave/calendar/` ....
- **Approvals** — *Files:* `approvals/presentation/screens/approvals_screen.dart`. *State:* `UnifiedTeamApprovalsNotifier` (`approvals_providers.dart`) merges several endpoints client-side. *Endpoints:* `/leave/...`, `/wfh/...`, `/expenses/...`, `/approvals/delegations/`.
- **Work From Home** — *Files:* `wfh/presentation/screens/wfh_screen.dart`. *State:* `wfhMyRequestsNotifier`, `wfh_report_providers`. *Endpoints:* `/wfh/requests/`, `/wfh/reports/`, `/wfh/saved-locations/`.
- **Payroll / Payslips** — *Files:* `payroll/presentation/screens/my_payslip_screen.dart`. *State:* `myPayslipsProvider`. *Endpoints:* `/payroll/my-payslips/`, `/payroll/queries/`.
- **Recruitment** — *Files:* `interview_list`, `candidate_review`, `referrals`, `email_log`. *State:* per-feature providers. *Endpoints:* `/recruitment/candidates/`, `/referrals/`, `/emails/`.
- **Assessments** — *Files:* `assessments/presentation/screens/*`. *State:* assessments providers. *Endpoints:* `/assessments/...`.
- **Training & Learning (admin)** — *Files:* `training/presentation/screens/{training,training_course}_screen.dart`. *State:* `training_providers.dart` (family FutureProviders). *Endpoints:* `/training/courses/`, `/assign/`, `/progress/`, `/dashboard/`, `/reports/`.
- **My Learning** — *Files:* `my_learning_screen.dart`, `my_course_screen.dart`, `my_material_screen.dart`, `my_assessment_screen.dart`. *State:* training providers. *Endpoints:* `/training/my/`, `.../materials/<id>/<action>/`, `.../assessment/<action>/`.
- **Settings** — *Files:* `settings/presentation/*` (90 files). *State:* per-screen notifiers. *Endpoints:* `/settings/...`, `/roles/`, `/departments/`.
- **Notifications** — *Files:* `notifications/presentation/widgets/notification_bell_button.dart`, `notification_panel.dart`. *State:* `unreadNotificationCountProvider` polls every 60 s. *Endpoints:* `/notifications/`, `/unread-count/`, `/read-all/`.
- **Onboarding** — *Files:* `onboarding/presentation/screens/*`. *State:* onboarding notifiers. *Endpoints:* `/onboarding/...`.
- **Others** — each has its own folder under `lib/features/` with the same data / domain / presentation layout.
- **Reports** — `PlaceholderScreen` only; no state or endpoints; hidden and refused by the router.

Loading/error handling is uniform: `AsyncValue` in providers → `AppLoadingWidget` / `AppErrorState` (Retry) / `AppEmptyState` in `shared/widgets`. Writes return `String?` (null = success, otherwise a friendly message) — see section 9.

---

## 8. Three features end to end

### Example A — Employee login
1. `login_form.dart: _submit()` validates form (`shared/validators/form_validators.dart`), normalises company code.
2. Calls `authStateProvider.notifier.login(...)` (`auth_notifier.dart`) → state `AsyncLoading`.
3. `LoginUseCase` → `AuthRepositoryImpl.login` → `AuthRemoteDataSource.login` → `POST /login/` (`ApiConstants.login`).
4. Backend `LoginView`: finds company by code, authenticates, lockout/throttle, builds response.
5. Repository caches user + tokens in secure storage.
6. Notifier state becomes `AuthState(user)`; `appRouterProvider` listens to it and re-evaluates `resolveAuthRedirect`.
7. `_submit` then `context.go(AppRoutes.dashboard)`; redirects may divert to change-password/onboarding.
Errors: `AccountLockedException` for 403 on the login path; backend's own message otherwise.

Diagram: **5**.

**Say:** "One tap, one request, one saved session — and the router, not the screen, decides where you land."

### Example B — Attendance clock-in
1. Button in `attendance_ring_card.dart` (dashboard) or `my_attendance_screen.dart` calls `runClockPunch(ref, context, today)` (`clock/clock_punch_flow.dart`).
2. Guards: `today.dayCompleted`; `faceLockoutProvider.remainingSeconds()`; a static `_punchInFlight` stops double-taps.
3. `LocationService.getCurrentPosition()` (high accuracy, 10 s time limit; returns null if denied).
4. `todayAttendanceModeProvider` → `'wfh'` or `'office'` from today's approved WFH request.
5. `TodayAttendanceNotifier.checkGeofence` → `POST /attendance/geofence-check/`; refusal stops before any camera.
6. `_captureFaceIfRequired`: only if `faceVerificationStatusProvider.isMandatory`; needs an **approved** own registration; opens `showFaceCaptureSheet`. Capture uses ML Kit for liveness (turn-only) and TFLite networks (`face_api/`) to compute a 128-d descriptor — frames pass a quality gate; 3 good frames averaged for verification.
7. `TodayAttendanceNotifier.punch` → `AttendanceRemoteDataSource.punch` → `POST /attendance/punch/` with `punch_type` IN/OUT, mode, `source: 'mobile'`, GPS, device info, `face_embedding`, `liveness_*`, `capture_session_id`.
8. Backend `AttendancePunchView` → `PunchService.record_punch`: one IN + one OUT per day (locked), **server-side geofence by mode**, face verification **only if `source` is web/voice** + company-mandatory + registered, store punch, recompute day.
9. On success the notifier sets new `TodayAttendanceEntity`, invalidates stats/summary/calendar; UI refreshes.

**Enforcement gaps (state plainly):**
- Face verification is **skipped by the server for `source: mobile`**, and the client chooses `source` (HO-01, P0, open). The mobile face check is app-side only.
- This flow has **never been run on a device** against any server (FACE-06/07/08); it is verified by mock-server tests and source reading only.
- Liveness is client-asserted (server receives a boolean and score).
- GPS coordinates are client-supplied; no mock-location detection found.
- Office-mode geofence is not applied when no branch has coordinates/geofencing configured.

Diagram: **7**.

**Say:** "The app guides you through location and face checks. The server independently enforces location. Face matching on the server for mobile punches is a known open item we are raising with the backend team."

### Example C — Leave application
1. `apply_leave_tab.dart` form: type selector, dates, duration (full/half), reason, optional PDF/JPG/PNG ≤5 MB (document), handover fields; live preview via `fetchLeavePreview`; `_submit()` validates.
2. `LeaveRequestsNotifier.applyLeave` builds `MultipartFile` → repository → `LeaveRemoteDataSource.applyLeave` → `POST /leave/requests/` as multipart (`leave_type`, `start_date`, `end_date`, `reason`, `duration`, ...).
3. Backend `LeaveRequestListCreateView`: serializer; working-day calculation; `_validate_leave_policy` (notice, min/max, backdate, attachment/medical certificate, eligibility); overlap with leave and WFH; balance check inside a transaction with row lock; LOP conversion / negative-balance rules.
4. Approval chain `_resolve_approval_chain` → `l1_approver`, `l2_approver`; status `pending` (or `l2_pending` when no L1).
5. Response → notifier prepends the new request, invalidates `leaveStatsProvider`; success view.
6. Approvers act via Approvals screen → `POST/PATCH /leave/requests/<id>/approve/`; stage authorization on server (`_can_approve_at_stage`, delegates via `apps/approvals/services.py`).
Balance is checked at apply but **deducted at final approval** (`_deduct_for_approval` → `_deduct_balance_safe`, `apps/hrms/views/leave.py`). Note this means a pending request does not yet reduce the visible balance; confirm how the apply screen displays pending days before telling a client.

Diagram: **8**.

**Say:** "The form is only a first filter. The company's real leave rules run on the server, so the phone and web always get the same answer."

---

## 9. State management

**Approach:** Riverpod 2 (`flutter_riverpod`), using `AsyncNotifier` / `AutoDisposeAsyncNotifier`, `FutureProvider`, `StateProvider`. *Verified.*

Beginner terms:
- **State** — the current data a screen shows (e.g. today's attendance).
- **Provider/notifier** — a small object that owns that state and the actions that change it.
- **Loading / success / error** — the three faces of `AsyncValue`.
- **UI refresh** — screens `ref.watch(provider)`; when state changes, they rebuild automatically.

Real example — `lib/features/attendance/presentation/providers/attendance_providers.dart`:

```dart
class TodayAttendanceNotifier
    extends AutoDisposeAsyncNotifier<TodayAttendanceEntity> {
  @override
  Future<TodayAttendanceEntity> build() =>
      _repo.getToday();                     // initial load

  Future<void> refresh() async {
    state = const AsyncLoading();           // loading
    state = await AsyncValue.guard(
        () => _repo.getToday());            // data or error
  }

  Future<String?> punch({...}) async {
    try {
      final updated = await _repo.punch(...);
      state = AsyncData(updated);           // success: UI refreshes
      ref.invalidate(attendanceStatsProvider);
      return null;                          // null = success
    } catch (e) {
      return friendlyAttendanceError(e);    // message for the screen
    }
  }
}
```

Other real patterns: auth state is kept alive app-wide (`ref.keepAlive()` in `AuthNotifier.build`); paginated "load more" notifiers (`LeaveTeamPendingNotifier.loadMore`); a 60-second polling notifier (`UnreadNotificationCountNotifier`); `autoDispose` so screens release data when closed.

---

## 10. API integration

| Topic | Implementation |
|---|---|
| Base URL | `ApiConfig.baseUrl` → production `https://royalhrms.com/api/`; debug can use local (`localBaseUrlNative` is a developer LAN address — **update or ignore; never ships in release**) |
| Environment | Single switch `ApiConfig.current`; release forced to production (`kReleaseMode`) |
| HTTP client | One `Dio` via `dioProvider` (`api_client.dart`), JSON headers |
| Timeouts | connect/receive/send 30 s each (`ApiConstants`) |
| Authorization | `Authorization: Bearer` from secure storage + cookie jar (native) |
| Refresh | `AuthInterceptor`, single shared refresh, retry once |
| Errors | `parseDioException`, `userFriendlyMessage`, `appErrorKind` |
| Models | `data/models/*` `fromJson`; entities in `domain/entities` |
| Envelope | Backend returns `{success/status, message, data}`; datasources `_unwrap(res.data)` |
| File upload | `FormData`/`MultipartFile` (leave document; profile/ID-card/training thumbnails etc.) |
| Pagination | Server `page`/`totalPages`; client "load more" notifiers; `PaginatedListEntity` |
| Pull-to-refresh | Providers invalidated; `dashboardRevisitProvider` refetches when returning to dashboard |

Diagram **6**. Real example: leave apply — `LeaveRemoteDataSource.applyLeave` posts multipart to `ApiConstants.leaves = '/leave/requests/'`. Note the backend base is `/api/`, so the full path is `/api/leave/requests/`.

*Tenant resolution:* see section 6.2 — the backend resolves the company from the **cookie** only, so the mobile cookie jar must keep working. Device checks against production (read-only) succeeded with this setup; a cookie-less request was not tested.

---

## 11. Database and backend

Verified from `backend/apps/*/models.py` (see **Diagram 9**).

- **Tenancy:** `tenants.Client` (company, `company_code`, `enabled_modules`) with a schema per company; domain model exists but the tenant is resolved from the JWT claim `company_schema` (and from `company_code` at login), not hostname.
- **User & access:** `User` (UUID id, role FK, `reporting_manager`, `hr`, `reporting_approver` FKs, `must_change_password`, `onboarding_status`). `Role`, `Permission`, `RolePermission`. `EmployeeProfile` one-to-one with User.
- **Org:** `Branch` (geofence latitude/longitude/radius, `geofencing_enabled`), `EmployeeBranchAccess`, `Department`, `Designation`. **`User.branch/department/designation` are text fields**, not FKs.
- **Attendance:** `AttendancePunch`, `AttendanceRecord`, `FaceRegistrationRequest` (encrypted embedding, status, liveness), `FaceVerificationAttempt`, `AttendanceFaceVerificationRules.is_mandatory`, corrections, overtime, policies. No photo fields on face models (embedding only).
- **Leave:** `LeavePolicy` (leave type rules), `LeaveBalance`, `LeaveRequest` (l1/l2 approvers, cancellation fields), `Holiday`, `LeaveCreditTransaction`.
- **WFH:** `WorkFromHomeRequest`, `WFHDailyReport`, `WFHSavedLocation`.
- **Approvals:** no generic approval table. `ApprovalWorkflowRule`/`EmployeeApprovalOverride` (matrix), `ApprovalDelegation`, `ApprovalEscalationSettings`/`ApprovalEscalation`.
- **Training:** `TrainingCourse`, `TrainingMaterial`, `TrainingAssignment`, `TrainingMaterialProgress`, `TrainingAssessmentAttempt`.
- **Payroll:** `PayrollCycle`, `SalaryStructure`, `EmployeePayslip`, `PayslipQuery`.
- **Notifications:** `Notification`, `NotificationSettings`.

Backend permission model and scoping: see sections 6.4 and 17.

---

## 12. UI architecture and reusability

- **Theme:** `AppColors` (`core/theme/app_colors.dart`) — static colour fields swapped at runtime by `applyMode(isDark)`; dark values mirror the web's CSS variables. Primary `0xFF1E4E8C`, secondary `0xFFC99A2E` (light). `AppTheme.themeFor(isDark)`.
- **Dark mode switching** rebuilds the whole app (`ValueKey('app-theme-$isDark')`) because most screens read static colours rather than `Theme.of(context)`. Trade-off: unsaved in-page state is lost on toggle.
- **Typography:** Poppins via `google_fonts` (`AppTextStyles` h1–h4, body, label, caption, button). Noto Sans / Devanagari bundled for the ID-card PDF.
- **Common widgets** (`lib/shared/widgets/`): `AppButton`, `AppTextField`, `AppLoadingWidget`, `AppErrorState`, `AppEmptyState`, `StatCard`, `BlueHeroBanner`, `ModuleGate`, `NoInternetView`, `NotFoundView`, `ExpandableFab`.
- **Responsive:** portrait-only on phones ("until tablet layout is added", `main.dart`); text-scale handling was device-verified up to 25% scale-down (project record HO-46).
- **Navigation:** go_router with a `ShellRoute` (`DashboardShell`: drawer + top bar), settings sub-screens pushed full-screen; Android back handled by `PopScope` and `enableOnBackInvokedCallback="false"` in the manifest.
- **Accessibility:** **Unverified** — no systematic accessibility audit was found. Do not claim compliance.
- **Avoiding duplication:** single error-to-message pipeline; shared state widgets; shared validators; one permission function used by router, menu and dashboard tiles; one clock-in flow reused by two screens (`runClockPunch`).

---

## 13. Error handling and performance

| Topic | What exists (verified) |
|---|---|
| API failures | Typed exceptions → friendly text → `AppErrorState` with Retry |
| Offline | `isOnlineProvider` + `_ConnectivityGate` full-screen overlay; link-layer only (not proof of internet) |
| Timeouts | 30 s each; friendly "taking too long" |
| Loading | `AsyncLoading` → `AppLoadingWidget`; buttons have `isLoading` |
| Empty states | `AppEmptyState` |
| Forms | `form_validators.dart`, `GlobalKey<FormState>`; server remains authoritative |
| Pagination | Load-more notifiers for large lists (leave team lists, announcements, etc.) |
| Large lists | Not individually profiled — **performance measurements: unverified**. Two screens are very large files (`attendance_screen.dart` 3,945 lines, `apply_leave_tab.dart` 2,097) — a maintainability risk |
| Images/files | Picker limits; 5 MB leave-document rule on server; PDFs opened with `PdfDocument.openFile` and cleaned up; thumbnails via authenticated endpoints |
| Session safety | Single-flight refresh prevents refresh storms |
| Release hardening | Debug logging compiled out; production URL forced |

No claims of optimisation beyond the above.

---

## 14. Testing and quality assurance

- **Files:** 170 `*_test.dart` under `test/` (core, features, shared) *(verified by count)*; no `integration_test/` folder present *(verified)*.
- **Kinds:** unit tests for pure logic (router `resolveAuthRedirect`, `access_control`, face math/pipeline, liveness tracker), widget tests with **fake servers** (login, clock punch flow, leave, approvals, training), interceptor tests (`test/core/network/auth_interceptor_test.dart`).
- **Latest recorded results (project record, `docs/qa/client_handover_2026-11-19/10_CLIENT_HANDOVER_READINESS.md`):** **2,806 tests passed**, `flutter analyze` **13 info, 0 warnings, 0 errors** (Task 90 batch 3). *These were not re-run for this document.*
- **Mocked vs real:** all automated tests are mocked/synthetic. **Physical-device testing** was done in debug build 1.0.2 versionCode 16 against **production, read-only, Branch Admin role only**. 92 screen units opened on the phone; no crash recorded. **No write workflow (clock-in, apply, approve, save) was verified live; clock-in and Face ID registration have never been run on a device** (FACE-06/07/08 need a written approval for one test punch on a disposable record); Employee, HR, Manager roles **NOT TESTED**. Training/My Learning writes are mock-tested only.
- **Release build verification:** none current — a release AAB exists without recorded provenance (HO-32).
- **Run yourself:** `flutter analyze` and `flutter test` in `mobile_app/`.

---

## 15. Build and deployment

| Item | Value | Source |
|---|---|---|
| Application ID / namespace | `com.royalhrms.app` | `android/app/build.gradle.kts` |
| Version | `1.0.2+10` (name 1.0.2, code 10) in `pubspec.yaml`; `versionCode = flutter.versionCode` | build files |
| Debug builds | Honour `ApiConfig.current` (currently `production`); local URLs only if switched | `api_config.dart` |
| Release builds | Always production URL | `ApiConfig.resolvedEnvironment` |
| Signing | Release uses `android/key.properties` (keystore path/alias/passwords — not shown here); Gradle **fails** if missing; never debug-signed | `build.gradle.kts` |
| Artifacts | APK for device testing; **AAB** for Play | Flutter |
| Play workflow | Update to an already-published listing (reported; Console not inspected); do not change the app ID; confirm live versionCode and upload certificate in Play Console before building; privacy policy, Data Safety answers and reviewer account needed | `docs/release/PLAY_STORE_AND_CONSOLE_CHECKLIST.md`, `FINAL_RELEASE_READINESS.md` |
| Permissions | INTERNET, ACCESS_FINE/COARSE_LOCATION, RECORD_AUDIO (+camera via plugin); READ_PHONE_STATE removed | `AndroidManifest.xml` |

**Unresolved build-provenance issues (separate, do not hide):**
- **Version numbers (explained, not a contradiction):** `pubspec.yaml` is `1.0.2+10`. Device debug builds were installed with `flutter build apk --debug --build-number=N` (codes 11–16 in the QA manifests), and local `android/local.properties` currently carries `flutter.versionCode=16`. The `pubspec.yaml` version never changed after +10, so **versionCode 16 exists only in debug artifacts**. A release AAB at code 10 would **overlap** debug code 10.
- **HO-32 (P1, open):** a clean + release AAB was built outside the audit while source edits were in progress and **its source state was not recorded**; it also deleted the 1.0.1+7 backup APK (lost). The AAB (hash prefix `e073c6f3…` per the QA record) must be **recorded or rebuilt from a recorded source state before any Play upload**. *(Project record; the file was not re-hashed for this document.)*
- **No signed release build has been verified**, installed, or tested on a phone. All device testing used **debug** builds signed with a debug certificate against the production backend.
- The release-readiness document dated 11-06 is **stale** (says version 1.0.0+6, 923 tests, nothing signed-in tested). Use the 11-19 folder. Note also that the 11-19 `10_CLIENT_HANDOVER_READINESS.md` "Counts" table still shows an older test figure (2,701); the per-task lines above it show the latest (2,806).

Release verification steps: `flutter analyze`; `flutter test`; `flutter build appbundle --release`; record SHA-256 of the AAB and the source state; install a signed build on a real phone and check login (read-only) before upload.

---

## 16. Maintenance and future development

**Understand the project:** read `lib/main.dart` → `app/app.dart` → `core/router/app_router.dart` → `core/router/access_control.dart` → one feature (e.g. `leave`) top to bottom. Then `docs/audit/MOBILE_ARCHITECTURE_AUDIT.md` and `docs/qa/client_handover_2026-11-19/10_...`. Beware: `teamcontextfile.md` notes can be stale — verify against code.

**Add a new API:** 1) add the path to `core/constants/api_constants.dart`; 2) add a method to the feature's data source (use `_dio`, unwrap envelope, catch `DioException` → `parseDioException`); 3) add model `fromJson` if needed.

**Add a feature/screen:** 1) create `lib/features/<name>/{data,domain,presentation}`; 2) entity + model; 3) repository (optional but conventional); 4) provider (`AsyncNotifier` for state with actions, `FutureProvider` for read-only); 5) screen using `AppLoadingWidget`/`AppErrorState`/`AppEmptyState`; 6) route constant + `GoRoute` in `app_router.dart`; 7) permission in `kRoutePermissions` and module in `kRouteModules` (`access_control.dart`); 8) nav entry in `dashboard/presentation/navigation/nav_config.dart`.

**Add tests:** mirror the path under `test/features/<name>/`; use a fake Dio/data source; also test permission mappings in `test/core/router/`.

**Run:** `cd mobile_app && flutter pub get && flutter run` (debug uses `ApiConfig.current`). **Build release:** section 15.

#### Onboarding checklist for a new developer
- [ ] Install Flutter matching the project; run `flutter pub get`, `flutter analyze`, `flutter test`.
- [ ] Read the 5 files listed under "Understand the project".
- [ ] Trace login and clock-in using document 03.
- [ ] Read `docs/audit/*` and the 11-19 handover folder.
- [ ] Learn the boundary rule: edit `mobile_app/` only; report API gaps, do not patch web/backend.
- [ ] Never commit `android/key.properties` or keystores.
- [ ] Ask for a **staging tenant** — until one exists, no write workflow can be safely tested.

---

## 17. Internal readiness section — open risks

*Internal. Say these honestly if asked. Do not describe any of them as resolved.*

| ID | Risk | Detail | Status (per project record + source) |
|---|---|---|---|
| **HO-01 (P0)** | **Face ID not enforced server-side for mobile punches** | `verify_for_punch` (`services_face_matching.py:207`) skips matching unless `source` is `web` or `voice`. The serializer accepts `web, mobile, biometric, manual, voice` and the **client chooses** (`serializers_my_attendance.py:34`, default `web`); mobile sends `mobile`. So with Face ID mandatory, a self-service punch can bypass matching. The app-side face check is therefore **not** a security control. Source-confirmed; **not exploit-tested on production**. Clock-in and Face ID registration have **never been exercised on a device** (FACE-06/07/08). | **OPEN (P0)** — backend fix (est. 0.5–1 day) or written client risk acceptance |
| **HO-18 (P1)** | **Branch Admin permission scope** | The Branch Admin role holds `settings.edit`. Device observation on production (earlier build) showed all 17 settings pages open to a Branch Admin, including company-wide Roles & Permissions, SMTP, Email Templates, Company Info and Financial Year. The **refreshed local backend source** now makes `has_perm(user,'settings.edit')` return False for `can_manage_branch` roles (`core/permissions.py`) so data views fall back to the user's own branch — **but** `can_edit_settings()` still lets a Branch Admin use the settings screens, and whether production runs this revision is **unconfirmed** (HO-31). HO-45 (open, backend): an empty-branch Branch Admin sees company-wide leave/WFH queues; `?employee_id=` not branch-scoped; `/birthdays/` not branch-scoped and returns emails. Payroll scoping **not audited**. Mobile's `userHasPermission` still treats `settings.edit` as full admin (differs from the backend rule — my source comparison, not a tested defect). | **OPEN — product/security decision required** |
| **HO-32 (P1)** | Release build provenance | See section 15. | OPEN |
| **HO-31 (P1)** | Local web/backend reference may lag production | The earlier clone had no Training module. The clone was refreshed on 18 Nov (now includes Training) but **its revision versus production is unconfirmed**; backend claims in this document are about the local clone. | PARTIAL |
| Coverage | Only Branch Admin + read-only live tests | No write workflow verified; Employee/HR/Manager untested | OPEN |
| Flag | `must_change_password` is client-side only | Returned at login and included in the JWT claim (`apps/accounts/tokens.py:49`); cleared by the change/reset password flows. **No endpoint or permission class was found that blocks a user who still has the flag** (searched `apps`, `core`, `config`; consistent with the comment in `app_router.dart`). Enforcement is the mobile router (and web's proxy) only. A modified client could skip the screen. | Known — not a verified security control |
| Liveness | Client-asserted | Server cannot verify it | Known |
| Geolocation | Client-supplied, no mock-location detection | Server geofence trusts coordinates | Known |
| Carry Forward (HO-37) | `preview`/`run` POST contract unverified; Run guarded behind a successful Preview | Remove guard when backend confirms | Open |
| Tests | 2,806 pass is a **mocked** result | Not evidence of production behaviour | — |
| Accessibility, performance | No audit / measurements found | Unverified | — |

**Facts still not verifiable from source:** production Python/Redis/Celery/hosting; whether production runs the same backend revision as the local clone; behaviour of a cookie-less (Bearer-only) request in practice; any live write workflow (clock-in, leave submit, approve, settings saves, training writes); Employee/HR/Manager role behaviour; any signed release build; accessibility and performance.

**Resolved by the review pass (previously unverified):** server TTS exists (Sarvam Bulbul); the serializer lets the client choose `source`; leave balance is deducted at approval; SDK levels 36/24/36.

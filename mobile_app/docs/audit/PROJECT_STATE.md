# Project State — Royal HRMS Mobile (Flutter)

*Audit date: 2026-10-28. Evidence comes from source, git and local tool runs. No application code was changed during this audit.*

## 1. Repository layout and condition

| Location | Git repo | Branch / remote | Condition |
|---|---|---|---|
| `Royal-HRMS/` (contains `mobile_app/`) | Yes (root) | `demo`; remote `origin/production` | **384 files deleted, 143 modified, 27 untracked, 2 renamed** (see §1.1) |
| `Royal-HRMS/web_frontend_backend/` | **Separate clone** | `production`, remote `Sria-Infotech-Pvt-Ltd/Royal-HRMS`; HEAD `d92cfac` (2026-10-28), clean | Up to date. 578 commits, **210 since 2026-08-13** |
| `Royal-HRMS/.venv/` | n/a | n/a | Python 3.12 virtualenv. It has **Django 5.2** installed, while `requirements.txt` pins **5.1.15** (pinned for django-tenants 3.7 compatibility), so the venv is stale for backend work. |

### 1.1 Root repo working tree: handle with care
- The old `backend/`, `frontend/`, `CLAUDE.md`, `TEAM_CONTEXT.md`, `.github/workflows/deploy.yml` and similar files show as **deleted** in the `demo` working tree, because the web code now lives in the separate clone at `web_frontend_backend/`.
- **A careless `git add -A` / commit at the root would delete the backend and frontend from the `demo` branch.** Stage only `mobile_app/` paths when committing mobile work.
- Mobile changes since the last commit are **uncommitted**: 142 modified, 2 renamed and 25 untracked paths under `mobile_app/` (+9,270 / −5,489 lines). Whole features exist **only** in the working tree:
  - `lib/features/email_log/`, `my_requests/`, `separation/`, `wfh/`
  - `lib/features/settings/presentation/notification_settings/`, `onboarding_fields/`
  - `lib/shared/widgets/stat_card.dart`, `blue_hero_banner.dart`
  - the new launcher icon and splash assets
- Signing files `android/key.properties` and `android/local.properties` exist locally and are git-ignored (`mobile_app/android/.gitignore:6,12`). Their contents were not read.

## 2. Detected technology stack

### Mobile (`mobile_app/`)

| Item | Value | Evidence |
|---|---|---|
| App id / version | Android `com.royalhrms.app`, version `1.0.0+5`. iOS bundle id is still the template `com.example.mobileApp`. | `android/app/build.gradle.kts:36`, `pubspec.yaml`, `ios/Runner.xcodeproj/project.pbxproj:512` |
| SDK | `sdk: ">=3.5.0 <4.0.0"`. Local toolchain: Flutter 3.44.8 stable, Dart 3.12.2. | `pubspec.yaml`, `flutter --version` |
| State / DI | flutter_riverpod 2.6.1 with manual providers (no codegen) | `pubspec.lock` |
| Routing | go_router 14.8.1: a single `ShellRoute(DashboardShell)` plus full-screen settings routes | `lib/core/router/app_router.dart` |
| Network | dio 5.9 + dio_cookie_manager + `PersistCookieJar` (cookie-based JWT) | `lib/core/network/api_client.dart`, `lib/main.dart` |
| Storage | flutter_secure_storage (cached user, theme, unused token slots) | `lib/core/security/` |
| Device features | geolocator (geofence), camera + google_mlkit_face_detection + tflite_flutter (on-device MobileFaceNet face embeddings, `assets/models/mobilefacenet.tflite`), speech_to_text + record + audioplayers (voice assistant with server TTS), image_picker, file_picker, url_launcher, connectivity_plus, lottie | `pubspec.yaml` |
| Size | 395 Dart files in `lib/`, about 106k lines, 27 feature folders | `find lib -name '*.dart'` |
| Environment | `ApiConfig.current = Environment.production`. Release builds are **forced** to `https://royalhrms.com/api/`, and debug can use a committed LAN IP. No flavors. | `lib/core/config/api_config.dart` |
| Release artefact | `build/app/outputs/bundle/release/app-release.aab` (129 MB), built 2026-10-27 10:55 | file timestamp |

### Web reference (`web_frontend_backend/`)

| Layer | Stack |
|---|---|
| Backend | Django 5.1.15, DRF 3.15, **django-tenants 3.7** (schema per company, PostgreSQL), simplejwt (httpOnly cookie JWT), Channels/Daphne (WebSocket notifications), Celery + Redis, Cloudinary storage, Sarvam (voice STT/TTS). 13 apps: accounts, announcements, assessments, assets, attendance, branch, dashboard, hrms, notifications, payroll, recruitment, tenants, voice_commands. |
| Frontend | Next.js 16.2, React 19.2, Tailwind 2, axios, face-api.js 0.22 (in-browser face embeddings), xlsx. Route gating is in `proxy.ts`, menu in `lib/navConfig.ts`, endpoints in `lib/api/endpoints.ts`. |
| API surface | 344 URL patterns (263 at 2026-08-12): 81 added, 0 removed |

## 3. Development timeline (reconstructed)

| Date | Evidence | Activity |
|---|---|---|
| 2026-06-29 → 07-03 | commits `58f1b26` … `6d03cfd` | Mobile scaffold; auth, employees, announcements, branches, documents, org chart, profile, interview list, onboarding wizard, payroll wizard, leave, approvals, assessments |
| 07-15 → 07-20 | `495ba4e`, `2a1ceff` | Leave and holiday wiring, UI changes |
| 07-27 | `e558822` "payroll removed" | **Admin payroll screens removed deliberately.** Only My Payslips remains. |
| 08-03 | `teamcontextfile.md` (Session 22) | Last update of the dev journal. Its pending list is partly stale (for example, Holiday Calendar is listed as mock but is wired to `/leave/holidays/`). |
| 08-03 → 08-13 | `8d55e6e`, `091781e`, `9b5ee8d`, `d6e2e55` | Bug fixes, onboarding UI. **Last mobile commit: `d6e2e55` "UI changes", 2026-08-13 17:56 IST.** |
| 08-19 → 08-20 | file mtimes (uncommitted) | UI redesign across modules onto the shared `StatCard` / `BlueHeroBanner` |
| 08-24 → 08-25 | mtimes (uncommitted / untracked) | WFH, org chart rewrite, notifications settings, voice Hindi fallback and server TTS, Email Log, My Requests, Separation (19 endpoints), Onboarding Fields settings, attendance geofence pre-check and my-corrections, `company_code` login for multi-tenancy |
| 08-26 | mtimes | Face ID step in the onboarding wizard; Face ID section in the profile |
| **08-27 11:48–11:57** | mtimes | **Last Dart edits:** face-capture quality gating in `face_capture_controller.dart` (+246 lines: framing hints, luminance, eye-occlusion, `qualityFailed` phase) wired into the voice "face proof" clock-in (`voice_command_controller.dart`), plus voice quick-action chips |
| 09-23 | `lib/core/config/api_config.dart` mtime | Switched to `Environment.production` |
| 10-27 | pubspec, assets, Android res | Launcher icon and Play Store prep; release AAB built |

**Lost backend work:** a 2026-08-10 local backend change was never committed and no longer exists anywhere (`git log --all -S extract-embedding` is empty). It added a server-side dlib face-embedding endpoint and made the server verify `source='mobile'` punches. Production still exempts mobile punches from face verification. See Roadmap P0-04.

**Most likely stopping point:** the face-capture quality gating and voice face-proof work on 2026-08-27. It is uncommitted and not device-tested. After that, only configuration and release-packaging changes were made.

## 4. What the web and backend changed while mobile was paused (highlights)

Multi-tenancy is the largest change. Since 2026-08-17 the login and forgot-password calls require `company_code`, and the tenant comes from the cookie JWT. Other changes:

- **New platform and roles:** Platform Admin panel (web only); Branch Admin role (`can_manage_branch`) with assignment and reassignment.
- **New modules:** Work From Home, Org Chart, self-service Separation with notice-period countdown, Assets (CRUD, bulk import and assign), ID card settings and print.
- **Attendance:** employee-wise shift timing; **one clock-in and one clock-out per day**; GPS accuracy warnings; human-readable addresses; attendance import with dry-run; weekly-off and shift assignments; face clock-in liveness and telemetry.
- **Leave:** custom leave types, monthly leave (import, entries, month-end expiry), and a leave tab on the employee profile with credit adjust and reverse.
- **Payroll:** employee-wise CTC components, effective-dated revisions, salary-transfer confirmation, ₹0 payslip block, payslip queries in Approvals, ECR/ESIC exports, analytics.
- **Configuration:** configurable onboarding fields and document types, per-user notification settings, reporting manager and approver matrix rules, new employee ID format (prefix + DDMM + initials).
- **Announcements:** self-service page for all users, with audience targeting.

Details: `WEB_MOBILE_PARITY.md` and `API_COMPATIBILITY.md` §5a.

## 5. Verification results (run 2026-10-28)

| Check | Command | Result |
|---|---|---|
| Dependencies | `flutter pub get` | **Pass**. "Got dependencies!" 87 packages have newer, constraint-incompatible versions. `pubspec.lock` was not changed by the run (mtime still 2026-10-27). |
| Static analysis | `flutter analyze` | **13 issues, all `info`** (`curly_braces_in_flow_control_structures`) in `assessments_screen.dart:159`, `attendance_screen.dart:642,662,672,682,1922,2255`, `candidate_review_screen.dart:465`, `departments_screen.dart:104,116`, `holiday_calendar_screen.dart:144,147,149`. **0 warnings, 0 errors.** The exit code is 1 only because infos are reported. |
| Tests | `flutter test` | **1/1 passed**, but the only test is `test('placeholder', () => expect(true, isTrue))` (`test/widget_test.dart`). **Effectively zero coverage.** |
| Backend config | `manage.py check` (throwaway env values set inline only, no DB access, no `.env` written) | **Pass**: "System check identified no issues". Run with the root `.venv` (Django 5.2 rather than the pinned 5.1.15). |
| Backend tests | not run | Needs a throwaway `.env` and a **local PostgreSQL** test database. The tenant-aware runner (`config/test_runner.py`) migrates a `TESTCO` schema. About 1,659 tests in 96 modules. Local Postgres on port 5432 is up. **Awaiting your approval**, because it creates and migrates a test DB and must never point at the production database. |
| Frontend tests / lint | not run | `frontend/node_modules` is absent; `npm ci` would download packages. Awaiting approval. |
| Debug build / device run | not run | A release AAB from 2026-10-27 exists. Device testing of face capture and voice has never been recorded. |

## 6. Known documentation

- `mobile_app/teamcontextfile.md` (260 KB dev journal, last updated 2026-08-03): useful history, but it does not describe the 08-13 → 08-27 work and its pending list is partly stale. It is kept unchanged; this audit folder supersedes its status claims.
- `web_frontend_backend/frontend/TEAMCONTEXT.md`, `AGENTS.md`, `CLAUDE.md`, and `web_frontend_backend/server-deployment-context.md` are the web team's own notes.

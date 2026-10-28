# Audit Summary — Royal HRMS Mobile (2026-10-28)

**Folder index:**
- `PROJECT_STATE.md`: repository, stack, timeline, checks
- `MOBILE_ARCHITECTURE_AUDIT.md`: architecture review
- `WEB_MOBILE_PARITY.md`: 51-row parity matrix
- `API_COMPATIBILITY.md`: verified contracts and all 281 call sites
- `IMPLEMENTATION_ROADMAP.md`: prioritised tasks

## Where the app stands
- **Broad and largely integrated.** 27 feature modules (about 106k lines of Dart) make 281 API calls. Every call resolves to an existing backend route and method, and the high-traffic contracts were hand-checked as compatible.
- **Static checks are clean:** `flutter analyze` shows 0 errors and 0 warnings (13 style infos).
- **There are no real tests.** The only test is a placeholder. No feature has been device-tested since 2026-08-13.
- **Six weeks of work is uncommitted.** The last mobile commit is `d6e2e55` (2026-08-13). Development continued uncommitted until **2026-08-27**: 169 paths, +9.3k/−5.5k lines, including four whole features. Work stopped mid-way through face-capture quality gating for voice clock-in.
- **The repository needs care.** The web code moved to a separate clone (`web_frontend_backend/`, branch `production`). The root `demo` working tree therefore shows the old backend and frontend as deleted. Commit only `mobile_app/` paths.

## What changed on web and backend (210 commits since 2026-08-13)
- **Multi-tenancy:** a company code is required, and the tenant is resolved from the JWT cookie.
- **New role and admin panel:** Platform Admin (web-only); Branch Admin role.
- **New modules:** WFH, org chart, self-service separation with notice-period countdown, assets, ID card.
- **Attendance:** one clock-in and one clock-out per day; shift and weekly-off assignments; GPS accuracy warnings.
- **Leave:** custom and monthly leave.
- **Payroll:** CTC components, payslip queries, salary-transfer confirmation.
- **Configuration:** configurable onboarding fields and document types; notification settings; reporting-manager rules; new employee-ID format.
- **API surface:** 81 new endpoints, **0 removed**.

## Module status (51 rows; see `WEB_MOBILE_PARITY.md`)

| Status | Rows |
|---|---|
| Complete | 21 |
| Partial | 13 |
| Outdated | 6 |
| Missing | 7 |
| Excluded | 3: admin payroll (removed 2026-07-27), payroll config, Platform Admin |
| Placeholder (both platforms) | 1 (Reports) |

- **Complete:** auth/login, admin and HR dashboards, attendance corrections, WFH\*, separation\*, email log\*, my requests\*, onboarding-fields settings\*, expenses, documents, org chart, interview list, referrals, face-ID HR, attendance sign-off, most settings, voice\*. Items marked \* are uncommitted or untracked.
- **Outdated:**
  - forgot password (broken);
  - onboarding wizard (ignores per-company config);
  - dashboard selection (Branch Admin gets 403s);
  - My Attendance (`day_completed` ignored; face bypass);
  - roles (`can_manage_branch` missing);
  - announcements menu gate.
- **Missing:** forced password change, assessment gate and portal, Manager dashboard, assets, ID card, global search, module-disabled handling.

## Architecture verdict
**Keep it; improve selectively.** The foundation is sound: Riverpod AsyncNotifiers with autoDispose, a datasource per feature, typed errors, release-safe logging and config. The fixes are targeted:
- the refresh deadlock;
- iOS camera permission and bundle id;
- release signing fallback;
- consistent error and response helpers;
- splitting files of 2,000–3,500 lines;
- tests.

## Top risks
1. **Mobile clock-in bypasses mandatory face verification.** The server skips the check for `source='mobile'` (`services_face_matching.py:207`). Mobile (192-d) and web (128-d) face embeddings are also incompatible. *A decision is needed.*
2. **Forgot password is broken** on mobile (400: `company_code` required).
3. **Token-refresh deadlock** can hang every API call until the app restarts (`auth_interceptor.dart:92-123`).
4. **Uncommitted work** (six weeks) has no remote backup.
5. **iOS release blockers:** no `NSCameraUsageDescription`, which crashes on first camera use; template bundle id.
6. **No automated tests;** device behaviour of face, voice and geofence is unverified.

## Recommended sequence
P0-00 preserve work → **P0-02 interceptor fix and first tests** → P0-01 forgot password → P0-05 forced password change → P0-03 release config → P0-04 face decision → P1 (dashboard flags, `day_completed`, payslip paging, module gating, credential hygiene, device smoke test, assessment gate, config-driven onboarding) → P2 parity → P3 quality.

**Recommended first code task: P0-02.** It fixes the auth-interceptor refresh deadlock and adds the project's first unit tests. Every request depends on this class, the fix is small, and the test harness it introduces protects all later auth work (P0-01, P0-05, P1-08). Before it, P0-00 (commit the existing mobile work on a branch) needs your approval.

## Checks run

| Check | Result |
|---|---|
| `flutter pub get` | Pass |
| `flutter analyze` | 13 infos, 0 warnings, 0 errors |
| `flutter test` | 1/1 pass (placeholder only) |
| Django `manage.py check` (inline dummy env, no DB) | Pass, no issues |
| Backend tests (about 1,659) | **Not run.** Need a local Postgres test DB and a throwaway `.env`; awaiting approval. |
| Frontend lint and vitest | **Not run.** `node_modules` absent; awaiting approval. |
| Device run | **Not run** |

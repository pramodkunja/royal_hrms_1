# Royal HRMS — Team Context

This file is updated at the end of each session. Read it at the start of any new session for quick orientation.

---

## Active Branch
`demo` — main working branch. All features merge here before deploy.

## Deployment
- Server: royalhrms.com
- Backend: port 8008 (Gunicorn + Django)
- Frontend: port 3001 (Next.js)
- User: royalhrmadmin
- Repo: Sriainfotech/Royal-HRMS, branch: demo

---

## Session Log — 2026-06-30

### Features Shipped

**1. Employee Onboarding Wizard — Mobile (Bug Fixes + File Upload)**
- Step 5 button row 39px overflow fixed: restructured to two-row layout (Previous alone top-left; Save Draft + Submit side-by-side on row 2)
- Submit 400 error now shows backend's friendly message (extracted from `DioException.response.data.message`) — previously showed raw DioException string
- File upload now works on Flutter Web/Chrome: `FilePicker` with `withData: true` + `MultipartFile.fromBytes` (web has no file path)
- Multipart form field renamed from `doc_type` to `document_type` to match backend serializer
- `onboarding_steps.dart` is a `part of` file — `file_picker` and `dio` imports added to host file `onboarding_screen.dart`

**2. AwaitingApprovalScreen — Polling + Approved State**
- Full rewrite as `ConsumerStatefulWidget`
- `Timer.periodic(30s)` polls `GET /api/onboarding/profile/` for status change
- When `status == 'complete'`: switches to green "Application Approved!" view with "Go to Dashboard" button
- "Go to Dashboard" calls `authNotifier.updateOnboardingStatus('complete')` — triggers router redirect to `/dashboard`

**3. `UserEntity` + `AuthNotifier` — Router Redirect Fix**
- `UserEntity.operator==` and `hashCode` now include `onboardingStatus` — previously only compared `id`, so Riverpod listener never fired on status change
- Added `UserEntity.copyWith({String? onboardingStatus})`
- Added `AuthNotifier.updateOnboardingStatus(String status)` — updates auth state without full re-login

**4. HR Web — Onboarding Approval UI**
- `frontend/app/dashboard/candidate-review/page.tsx`: error handler now correctly extracts `err.response.data.message` (axios errors have message at response body, not `err.message`)
- `frontend/app/dashboard/candidate-review/_components/OnboardingDrawer.tsx`: full rewrite — ASSIGN ROLE section (department + designation dropdowns) always visible, no two-step flow; departments and all designations loaded on mount in parallel; designations filtered client-side by selected department; single "Confirm & Activate" button validates both fields before calling `onAction`

### Files Changed This Session

```
mobile_app/lib/
  features/auth/
    domain/entities/user_entity.dart               copyWith(), operator== + hashCode include onboardingStatus
    presentation/controllers/auth_notifier.dart    updateOnboardingStatus() method
  features/onboarding/
    data/datasources/onboarding_datasource.dart    DioException handling, document_type field name
    presentation/providers/onboarding_providers.dart  error string stripping, MultipartFile param
    presentation/screens/onboarding_screen.dart    file_picker + dio imports, onUpload wired
    presentation/screens/awaiting_approval_screen.dart  full rewrite — polling + approved state
    presentation/widgets/onboarding_steps.dart     button layout fix, file picker, per-card spinner

frontend/
  app/dashboard/candidate-review/
    page.tsx                   error handling fix (response.data.message chain)
    _components/OnboardingDrawer.tsx  full rewrite — ASSIGN ROLE always visible, single-step confirm
```

---

## Session Log — 2026-06-26

### Bug Fixes Shipped

**1. Cross-device cookie / proxy fix**
- Next.js rewrites `/api/*` → backend so browser never sees a cross-origin request
- `skipTrailingSlashRedirect: true` in `next.config.ts` + trailing slash forced in rewrite destination
- `APPEND_SLASH = False` added to `backend/config/settings.py`
- Fixes Django RuntimeError on POST requests coming through the proxy

**2. Flutter mobile auth (dual-source)**
- `backend/apps/accounts/authentication.py` — `CookieJWTAuthentication` now tries cookie first, then `Authorization: Bearer` header
- Login response now returns `access` + `refresh` tokens in body (in addition to cookies) for Flutter
- Token refresh accepts `refresh` from request body OR cookie — whichever is present

**3. Add Employee modal — dropdowns not loading**
- Root cause: branches API was pointing to wrong path (`/branches/` → fixed to `/branch/branches/`)
- Root cause 2: paginated response returns `{ count, results, ... }` not a flat array — code was calling `.filter()` on the object (silent TypeError)
- Fixed in `frontend/app/dashboard/employees/_components/AddEmployeeModal.tsx`

**4. Employee profile "not found"**
- Page was reading from `MOCK_EMPLOYEES` array (mock IDs had `D` suffix, real IDs don't)
- Added `EmployeeDetailView` to backend (`GET /api/employees/<employee_id>/`)
- Rewrote `frontend/app/dashboard/employees/[id]/page.tsx` to fetch from real API

### Features Shipped

**5. Employee Code Settings** (configurable ID format)
- New singleton model `EmployeeCodeSettings` — prefix, padding, next_sequence
- `generate_employee_id()` uses `select_for_update()` + atomic `F()` increment (safe under concurrent creates)
- Employee creation in `EmployeeListCreateView.post()` now calls `EmployeeCodeSettings.generate_employee_id()` instead of unsafe `count() + 1`
- Settings page: `frontend/app/dashboard/settings/employee-code/page.tsx` — live preview of next 3 IDs
- Card added to `frontend/app/dashboard/settings/page.tsx`
- Migration: `backend/apps/accounts/migrations/0020_employee_code_settings.py` ✅ applied
- `next_sequence` auto-seeded to `max_existing + 1` on deploy (was 6 as of this session)
- API: `GET/PUT /api/settings/employee-code/` — permission: `CanManageRoles`

**6. Branch-scoped employee list**
- `system_admin` sees all employees, gets a branch switcher dropdown in filter bar (derived client-side from employee list — no extra permission required)
- `hr_admin` sees only their branch (server-enforced in `EmployeeListCreateView.get()`) — fixed branch pill in filter bar, non-editable
- Branch column added to employee table
- `branch` field added to `UserInfo` interface and saved at login

**7. Branches sidebar visibility fix**
- `navConfig.ts` and `proxy.ts` — Branches entry was guarded by `settings.view`; `hr_admin` has `settings.view` so they saw Branches but got 403 from the API
- Fixed: both files now guard Branches with `branches.view`
- `hr_admin` no longer sees Branches in sidebar; proxy also blocks direct URL navigation

---

## Key Architectural Decisions

| Decision | Reason |
|---|---|
| Next.js rewrites proxy for API | Solves cross-origin cookie problem for all devices on same network |
| `APPEND_SLASH = False` in Django | Prevents 308 redirect loop on POST through proxy |
| Dual-source token auth (cookie + header) | Web uses httpOnly cookies; Flutter mobile uses Bearer header |
| Branch filtering client-side for system_admin | Avoids `branches.view` permission dependency; branches derived from employee list |
| `EmployeeCodeSettings` as singleton (pk=1) | One global format, not per-branch — simpler, consistent employee IDs |
| `select_for_update()` for ID generation | Race-safe under concurrent employee creation |
| `branches.view` guards Branches nav (not `settings.view`) | `hr_admin` has `settings.view` for Settings page — wrong permission caused sidebar leak |

---

## Permissions Reference

| Permission | Who has it |
|---|---|
| `branches.view` | system_admin only |
| `settings.view` | system_admin, hr_admin |
| `employees.view` | system_admin, hr_admin |
| `employees.create` | system_admin, hr_admin |

---

## Files Changed This Session

```
backend/
  apps/accounts/
    authentication.py       — dual-source JWT (cookie + Bearer header)
    models.py               — EmployeeCodeSettings model
    migrations/0020_*       — migration for EmployeeCodeSettings
    serializers.py          — EmployeeCodeSettingsSerializer
    views.py                — EmployeeDetailView, EmployeeCodeSettingsView, branch scoping in list, generate_employee_id()
    urls.py                 — /employees/<id>/, /settings/employee-code/
  config/
    settings.py             — APPEND_SLASH = False

frontend/
  app/
    login/page.tsx                              — branch in UserInfo at login
    dashboard/employees/page.tsx               — branch switcher (admin) / fixed label (hr_admin)
    dashboard/employees/[id]/page.tsx          — real API fetch, replaced mock data
    dashboard/employees/_components/
      AddEmployeeModal.tsx                     — fixed paginated response + correct branch endpoint
    dashboard/settings/page.tsx               — Employee ID Format card added
    dashboard/settings/employee-code/page.tsx — new settings page (prefix, padding, next_sequence)
  lib/
    auth.ts                 — branch added to UserInfo
    api/endpoints.ts        — employees.detail, settings.employeeCode
    navConfig.ts            — branches.view guard for Branches nav item
  proxy.ts                  — branches.view guard for /dashboard/branches route
  next.config.ts            — skipTrailingSlashRedirect, trailing slash in rewrite
```

# 16 — Security Remediation Specification (Task 92, 18 Nov 2026)

**Status: investigation and plan only.**
- No backend or mobile code was changed.
- No production request was made.
- No bypass was attempted.
- No Git command was run.
- No secret was read: `android/key.properties` was checked for which keys are present, never for their values.

**Source basis**
- Local web/backend clone (`web_frontend_backend/`, refreshed 18 Nov 11:26 from branch `production`).
- Mobile source = debug versionCode 16.

**Note:** the clone's match with what production runs is itself unverified (HO-31, §5 / doc 18). Every finding below must be re-confirmed against the deployed revision before a fix is closed.

---

## 1. HO-01 — Mandatory Face ID bypass (P0)

### 1.1 Findings (source-verified)

| # | Finding | Location |
|---|---|---|
| F1 | Face verification runs only for `source` `web` / `voice`. Any other source returns "not required", **even when Face ID is mandatory**. | `apps/attendance/services_face_matching.py:207-208` (`verify_for_punch`); module docstring `:16-19` says so explicitly |
| F2 | `source` is **client-controlled** on the employee endpoint `POST /api/attendance/punch/`. The serializer accepts `web`, `mobile`, `biometric`, `manual`, `voice` (default `web`). | `apps/attendance/serializers_my_attendance.py:34-37`; passed straight through in `views/my_attendance.py:117-132` → `services_attendance.py:124, 156-163, 197` |
| F3 | So **any authenticated employee can clock in without a face** by sending `source: "mobile"` (or `biometric` / `manual`), whatever the org setting. The punch is also stored with that self-declared label (`:197`), so the audit trail is spoofable. | as above |
| F4 | The **mobile app** sends `source: "mobile"` (default in `attendance_remote_datasource.dart:49`, `attendance_repository_impl.dart:27`). When Face ID is mandatory it captures a face and sends `face_embedding`, liveness and session id (`clock_punch_flow.dart:100-128`), **but the server never compares it** (F1). Mobile users are never really verified. | mobile files above |
| F5 | A fix ("P0-04A") was written but **not landed**: `tests_face_verification_enforcement.py` (29 Oct) expects mobile punches to be verified, unsupported sources rejected ("Unsupported punch source"), and descriptors model-checked. The descriptor helper `services_face_descriptor.py` (`descriptor_error`, `SUPPORTED_FACE_MODELS`) exists but **no production code calls it**; only the test imports it. Against the current code those tests would fail. Either the integration was reverted or it was never merged. | `tests_face_verification_enforcement.py:1-5, 89-125, 211-262`; `services_face_descriptor.py:23-57` |
| F6 | Liveness is **client-asserted**: only an explicit `liveness_passed: false` is rejected; `null` (absent) passes. | `services_face_matching.py:270-281` |
| F7 | Legitimate exceptions: `manual` and `system` punches are created **server-side only** (HR corrections `services_hr_corrections.py:421`, invalid-punch conversion `services_invalid_punch.py:107`), never through `/attendance/punch/`. No biometric-device integration posts to that endpoint. Voice sets `source='voice'` server-side (`voice_commands/executor_attendance.py:157-187`, through the same serializer). **No legitimate employee-facing flow needs the exemption.** | as listed |
| F8 | What already works and should be kept: org toggle `is_face_verification_mandatory()` (`services_face_matching.py:146`); approved registration required; TLS check; attempt cap 5 failures / 15 min with a countdown (`services_face_antispoofing.py:30-31`); replay detection 5 min (`:35`); hard reject of the low-confidence band (threshold 0.60, margin 0.05; `services_face_matching.py:65, 77, 324-350`); every attempt audited (`FaceVerificationAttempt`). | — |
| F9 | Cross-platform compatibility: mobile registrations don't send `embedding_model_version` (`facial_recognition_remote_datasource.dart:53-62`), so they are stored as `face-api.js-faceRecognitionNet-v1` (model default, `models.py:1916, 1959`). The mobile model is meant to be the same face-api.js network as TFLite (128 values). **Mobile ↔ web equivalence on real faces is not yet verified** (FACE-06/07/08). If it differs, enforcing verification would lock genuine mobile users out. | — |

### 1.2 Proposed server-side design (backend)

1. **Verification is decided by policy, never by `source`.**
   - In `verify_for_punch`, remove the `source not in (web, voice)` short-circuit (`:207-208`).
   - When `is_face_verification_mandatory()` is on, **every employee-initiated punch** (all `PunchService.record_punch` callers: the punch API and the voice executor) needs an approved registration plus a matching descriptor.
2. **Whitelist sources on the employee endpoint.**
   - `PunchWriteSerializer.source` choices become `web` and `mobile` only.
   - `voice` is set by the server: the voice executor passes `source='voice'` after validation, outside the client-validated field.
   - `biometric`, `manual`, `system`, `kiosk` sent by a client → **400 "Unsupported punch source."** (matches the existing test's message).
   - Server-side creators of `manual` / `system` punches keep writing directly and are unaffected.
3. **Validate descriptors before matching.**
   - Call `services_face_descriptor.descriptor_error(embedding, registration.embedding_model_version)` and `registration_descriptor_error(registration)`.
   - A wrong length, non-finite values, or a model mismatch → reject without a distance comparison (fail closed). This is what the P0-04A tests require.
4. **Liveness (decision P-3):**
   - When mandatory, require `liveness_passed is True` (reject `null`) for clients that support it: the current web build and mobile code 16 both send it.
   - Add a transition flag if older web builds must keep working.
5. **Record a trustworthy label.** Store the server-derived channel (from endpoint plus User-Agent class) separately from any client hint, or drop the client hint. Audit reports must not rely on a client-declared source.
6. **Mobile (no change needed for enforcement).**
   - Optional hardening: send `embedding_model_version: 'face-api.js-faceRecognitionNet-v1'` on registration and punch, so the server can reject a mismatched model explicitly.
   - Mobile already respects the lockout countdown (`faceLockoutProvider`).
7. **Rollout order.** Validate mobile/web descriptor equivalence on staging (P-2) **before** turning enforcement on in production. Otherwise mandatory-Face-ID companies may lock out mobile users.

### 1.3 Tests (backend; also in matrix 17)
- Run the existing `tests_face_verification_enforcement.py` unchanged; it must pass, since it encodes the design.
- **Positive:** web, mobile and voice with a matching descriptor → 200; the punch is stored and an attempt row has `is_match=true`.
- **Negative:**
  - no registration → 400;
  - no descriptor → 400;
  - mismatch → 403;
  - low-confidence band → blocked;
  - 5 failures → locked out 15 min with `retry_after`;
  - replayed descriptor within 5 min → blocked;
  - insecure transport (non-local) → blocked;
  - wrong-length / NaN / 192-value descriptor → rejected without comparison;
  - `liveness_passed: false` → 403; `null` → 403 (after P-3).
- **Bypass attempts:**
  - `source` = `mobile` / `biometric` / `manual` / `system` / `kiosk` / `MOBILE` / `""` / missing (→ treated as web) with **no** descriptor while mandatory → all rejected;
  - voice path with no descriptor → rejected;
  - client-sent `voice` on the punch API → 400;
  - toggle OFF → every source punches without a face (existing behaviour kept).
- **Regression:** HR manual correction and invalid-punch conversion still create `manual` punches without a face (they don't go through `record_punch`).
- **Never run bypass tests against production.** Run them in the backend test suite and on staging only.

---

## 2. HO-18 / HO-50 — Branch Admin excessive permissions (P1)

### 2.1 Findings
- **Intended Branch Admin role (product configuration, in source)**
  - `accounts/migrations/0052_seed_branch_admin_role.py` withholds `settings.edit` on purpose: it is "wired throughout the codebase as an implicit bypass".
  - `0070_revoke_settings_edit_from_branch_admin.py` revokes it again. It records that it had been "granted 2026-08-10, outside of any tracked migration — via Settings → Roles", which made Branch Admins act on every branch.
  - Training's intended grants for `branch_admin`: `view, assign, view_all_progress, view_reports` only (`training/migrations/0002_seed_permissions.py:17`).
- **Actual state on production:** the demo Branch Admin holds `settings.edit` (device and live-web evidence for HO-18: company billing visible, login `is_superuser=true`). So it was **re-granted in the Roles UI after `0070`**, or `0070` was not applied there. Confirm read-only with the deploy checklist §3 (doc 18).
- **Where `settings.edit` over-grants**
  - `core/permissions.py:41`: `permission__codename__in={codename, 'settings.edit'}` makes `settings.edit` a **wildcard for every codename**.
  - `:34` withholds only the literal `settings.edit` check from `can_manage_branch` roles (so their data falls back to their own branch). It **still grants** every other codename: `training.create/edit/delete/manage_assessments`, payroll, recruitment, etc.
  - `can_edit_settings()` (`:54-64`) lets them use company settings screens (roles, company info, escalation, referral rules, birthday settings).
  - Login sets `is_superuser` for any `settings.edit` holder (`accounts/views.py:612`). Mobile and web therefore show Branch Admins every control.
- **Training is company-wide:** courses have no branch field. `CourseDetailView`, `MaterialListCreateView`, `MaterialDetailView` (`training/views.py:275-304, 352, 415-450`) check only the permission, so a Branch Admin can author, delete and link assessments for courses used by every branch.

### 2.2 Proposed least-privilege rules (pending decision P-1)

| Capability | Proposed Branch Admin rule | Enforcement |
|---|---|---|
| Training create / edit / delete | **Not allowed** (HR / System Admin only); courses are a company catalogue | Fix the wildcard (below) and the role data |
| Assessment linking (`training.manage_assessments`) | Not allowed | as above |
| Course assignment (`training.assign`) | Allowed, **own branch only** (already scoped by `scoped_employees`) | Existing |
| Progress / reports | Allowed, **own branch only**; **nobody** when the user has no branch (HO-45) | `services.employee_scope_q` fail-closed |
| Employee data | Own branch only (`_employee_out_of_branch_scope`, `accounts/views.py:3461`) | Existing + HO-45 gaps |
| Company settings (roles, company, billing, escalation) | Product decision P-1b | `can_edit_settings` |

**Backend changes (after approval)**
1. **Data:** remove `settings.edit` from the production `branch_admin` role. Use a new idempotent migration (repeat of `0070`), run through the normal deploy, not a manual DB edit.
2. **Stop re-grants:** the Roles API refuses to add `settings.edit` to a role with `can_manage_branch=True` (400 with a reason). Do the same in the web Roles UI.
3. **Narrow the wildcard:** in `has_perm`, a branch-restricted role (`is_branch_restricted`) is **not** granted other codenames through `settings.edit`; it gets only the codenames it holds. Optionally make the wildcard opt-in for system roles only.
4. **Login flag:** `is_superuser` in the login payload is true only for real superusers and system-admin roles, not every `settings.edit` holder. Mobile and web then stop showing everything.
5. **Regression risk is high:** `has_perm` is used by ~36 modules. Needs a full backend test run plus a role matrix (17 §B) on staging.

---

## 3. HO-45 — Missing branch scoping (P1)

### 3.1 Findings

| # | Scenario | Location | Behaviour today |
|---|---|---|---|
| S1 | Branch Admin with **empty branch**: leave approval queue | `hrms/views/leave.py:205-208` | `branch_q = … if branch else Q()` → **company-wide** queue |
| S2 | Same, WFH approval queue | `hrms/views/workfromhome.py:82-91` | company-wide |
| S3 | Same, Training progress / reports / dashboard / assign scope | `training/services.py:70-72` | company-wide |
| S4 | `GET leave requests?employee_id=` | `leave.py:936-943` | Any holder of `employees.view` **or** `leave.approve` reads **any** employee's requests; no branch / team check |
| S5 | `GET wfh requests?employee_id=` | `workfromhome.py:120-127` | same |
| S6 | `GET leave balances?employee_id=` | `leave.py:702-708` | any `employees.view` holder reads any employee's balances |
| S7 | `GET /birthdays/` | `hrms/views/birthdays.py:26-82` | company-wide list incl. **email** (`:159-160`) for any `employees.view` holder |
| S8 | `/company-contacts/approvers/` team list | `accounts/views_policy.py:296-317` | unpaginated, returns email + phone for everyone in scope (Task 90 audit) |

### 3.2 Fail-closed design
- **One shared helper** (e.g. `core/scoping.py`):
  - `employee_scope_q(user, prefix='')` returns: superuser / system admin → all; branch-restricted → own branch; **branch missing → `Q(pk__in=[])` (nobody)**; manager → direct reports; otherwise self only.
  - `assert_employee_in_scope(user, employee)` → 404, reusing `_employee_out_of_branch_scope`.
- Replace S1–S3 with it. An empty branch **never** widens scope. Log a warning so admins fix the account.
- **S4–S6:** resolve `employee_id`, then `assert_employee_in_scope` before returning data. Return 404 (not 403) to avoid revealing whether an ID exists.
- **S7:** scope to the requester's branch (or team), and drop `email` unless the caller can send wishes (`can_edit_settings` / HR).
- **S8:** paginate, and return contact fields only for the requester's own approvers unless the caller is HR.
- **Mobile:** no change; it renders whatever the server returns. Branch-scoped results were already observed on the device for Training.

---

## 4. HO-51 — Archived-course edits (P3)
- **Finding (confirmed):** archived courses (`archived_at` set) can still be changed through the API: course PATCH `training/views.py:276`, thumbnail `:321`, material add `:353`, material PATCH `:416` and DELETE `:440`, reorder `:457`. Each checks only the permission. Web and mobile block these in the UI only. Assign is already refused by `services.assign_course` (`:119-120`).
- **Recommendation:**
  - Add `_ensure_editable(course)` → **409 "This course is archived and can no longer be changed."** to those six handlers.
  - `DELETE` on an already-archived course → 409, or an idempotent 200 with `{archived: true}`; product to choose (P-5).
  - Keep reads, progress and reports for archived courses unchanged (history).
- **Tests:** in matrix 17 §D.

---

## 5. Product decisions requiring approval

| # | Decision | Options | Recommendation |
|---|---|---|---|
| P-1 | What may a Branch Admin do? | (a) Seeded role only: no `settings.edit`; own-branch employees, leave/WFH approval, training assign / progress / reports. (b) Also company-settings screens. (c) Status quo (company-wide admin) | **(a)** — matches `0052`, `0070` and training `0002` |
| P-1b | Which settings screens, if any, may a Branch Admin edit? | none / branch-level only (branch details, holidays for own branch) / all | none, until branch-level settings exist |
| P-2 | Turn on server-side Face ID for mobile only after staging proves mobile ↔ web descriptor equivalence? | yes / enforce immediately | **Yes**: staging first, then enforce. Until then the company should not rely on Face ID for mobile punches (written risk acceptance if the app ships first) |
| P-3 | Require `liveness_passed=true` when Face ID is mandatory? | yes / keep `null` accepted | yes, with a short grace flag for old web builds |
| P-4 | Users with no branch | fail closed (see nothing branch-scoped) / company-wide | **fail closed**, plus an admin report of branch-less accounts |
| P-5 | DELETE on an archived course | 409 / idempotent 200 | idempotent 200 (no change), other edits 409 |
| P-6 | Birthday list and approver contacts visibility | branch-scoped without email / as today | branch-scoped, no email |

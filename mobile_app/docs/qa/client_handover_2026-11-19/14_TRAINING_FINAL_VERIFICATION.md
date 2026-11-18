# 14 — Training & Learning: Final Verification (Task 91, 18 Nov 2026)

**Scope**
- Task 90 Batches 1–3, reviewed as one module.
- Reference: the local web/backend clone refreshed 18 Nov 11:26 (web `app/dashboard/training`, `app/dashboard/my-learning`, `lib/training.ts`; backend `apps/training/*`, `core/permissions.py`, `apps/tenants/feature_gate.py`).
- Mobile source = debug **versionCode 16** (`e820d54a…`): the source tree matches `build_1.0.2+16-debug_source_manifest.txt` exactly (re-checked).

**Evidence levels**
- **DEVICE-RO:** seen on the Motorola against production; read-only or view-and-cancel.
- **MOCK:** widget / unit tests against a stand-in API.
- **SOURCE:** code comparison only.
- A row is not "fully verified" on MOCK alone.

## 1. Final Training parity inventory

| Area | Feature | Status | Evidence | Notes |
|---|---|---|---|---|
| Navigation | "Training & Learning" menu, `/dashboard/training` (training.view + module) | **COMPLETE** | DEVICE-RO, MOCK | Route guard, menu and page title match web `navConfig.ts:54`, `proxy.ts:40`, `modules.ts:38` |
| Navigation | "My Learning" menu, `/dashboard/my-learning` (no permission + module) | **COMPLETE** | DEVICE-RO, MOCK | Matches web `navConfig.ts:74`; hidden when the module is off |
| Module gating | Hidden on mobile; backend 403 on `/api/training/*` | **COMPLETE** | MOCK, SOURCE | Backend `feature_gate.py:42` |
| Admin | Dashboard figures | **COMPLETE** | DEVICE-RO | Hidden on 403, as web |
| Admin | Course list, search, Show archived | **COMPLETE** | DEVICE-RO, MOCK | |
| Admin | Course detail tabs (Details / Materials / Assign / Progress), per-permission and archived rules | **COMPLETE** (display) | DEVICE-RO, MOCK | |
| Admin | New Course | **PARTIAL** (write unverified) | MOCK; dialog opened and cancelled on device | Needs staging A1 |
| Admin | Edit course (all fields, validation, new joiners) | **PARTIAL** (write unverified) | MOCK; form viewed on device | A3–A8 |
| Admin | Thumbnail upload | **PARTIAL** | MOCK | A5 |
| Admin | Assessment linking (manage_assessments) | **PARTIAL** | MOCK; list loaded with a read-only GET on device | A6–A7 |
| Admin | "+ New Assessment" from the course form | **WEB-ONLY** (decision HO-49) | — | Opens the Assessments module on web |
| Admin | Materials list + PDF preview / link open | **COMPLETE** (read) | DEVICE-RO (links), MOCK (PDF) | No PDF material exists in production |
| Admin | Material add (upload PDF/PPTX/DOCX/MP4, links), toggles, length, reorder, remove | **PARTIAL** (writes unverified) | MOCK; editor and Add form viewed on device | A9–A18 |
| Admin | Uploaded-video preview | **WEB-ONLY** (gap) | — | Mobile shows "Preview uploaded videos on the web app." |
| Admin | Delete / archive course | **PARTIAL** | MOCK | A19 |
| Admin | Un-archive | **BLOCKED** (no backend) — decision HO-49: not implemented | SOURCE | No endpoint, no web UI |
| Admin | Assign (people / groups / all, due date) | **PARTIAL** | MOCK; disabled-state seen on device | B1–B4 |
| Admin | Progress list | **COMPLETE** (read) | DEVICE-RO | Branch-scoped on device |
| Admin | Remove assignment / Reset attempts | **PARTIAL** | MOCK | B5–B6 |
| Admin | Reports + filters | **COMPLETE** (read) | DEVICE-RO, MOCK | |
| Admin | CSV export | **PARTIAL / BLOCKED on device** | MOCK | The GET is read-only, but saving a file was not exercised on the phone. A21 |
| Office files | Open PPTX / DOCX in another app (admin + learner) | **PARTIAL / BLOCKED on device** | MOCK | No PPTX/DOCX in production; phone disconnected at Task 91, so handler apps not re-checked. A10, C8 |
| Employee | My Learning list, 6 tabs, cards | **COMPLETE** | DEVICE-RO, MOCK | |
| Employee | Course page (read-only) | **COMPLETE** | DEVICE-RO, MOCK | |
| Employee | Course-opening progress (web auto-opens) | **PARTIAL** — decision HO-48: keep disabled | MOCK (ON / OFF) | Deliberate difference until staging |
| Employee | PDF reader + minimum time + confirm | **PARTIAL** (writes unverified) | MOCK | C2–C3 |
| Employee | YouTube / uploaded / direct video tracking; Vimeo confirm | **PARTIAL** (playback + writes unverified) | MOCK (fake player) | C4–C7; the WebView player has never played a video on a device |
| Employee | Assessment start / submit / retake / closed | **PARTIAL** (writes unverified) | MOCK; locked state seen on device | C9–C12 |

**Totals: 34 rows**
- COMPLETE 13
- PARTIAL 16 (all because writes are unverified)
- WEB-ONLY 2
- BLOCKED 1 (un-archive)
- PARTIAL/BLOCKED-on-device 2 (CSV, Office)
- MISSING 0

## 2. Permission and API verification (the 13 admin actions)

Mobile column: each action calls `TrainingAdminActions._require(...)` in `lib/features/training/presentation/providers/training_providers.dart` **before** the request.
- A source search finds **no** admin write that bypasses it: 0 direct datasource calls.
- MOCK: a missing permission throws `ForbiddenException` locally and sends no request (13/13 tested).

Backend column: `apps/training/views.py`.

| # | Action | Mobile check (line) | Backend check (line) | Backend enforces independently? | Discrepancy |
|---|---|---|---|---|---|
| 1 | Create course | `training.create` (:95) | `has_perm training.create` (:254) | Yes | — |
| 2 | Save course | `training.edit` and not archived (:103) | `training.edit` (:276) | Permission yes; **archived no** | HO-51 |
| 3 | Thumbnail | `edit` and not archived (:110) | `edit` (:321) | Permission yes; archived no | HO-51 |
| 4 | Assessment options | `manage_assessments` (:122) | `manage_assessments` (:569) | Yes | — |
| 5 | Add material | `edit` and not archived (:128) | `edit` (:353) | Permission yes; archived no | HO-51 |
| 6 | Update material | `edit` and not archived (:137) | `edit` (:416) | Permission yes; archived no | HO-51 |
| 7 | Remove material | `edit` and not archived (:142) | `edit` (:440) | Permission yes; archived no | HO-51 |
| 8 | Reorder | `edit` and not archived (:149) | `edit` (:457) | Permission yes; archived no | HO-51 |
| 9 | Delete course | `training.delete` and not archived (:160) | `training.delete` (:289) | Yes | — |
| 10 | Assign | `assign`, not archived, active (:165) | `assign` (:476) + assigner scope (:480) + active and not archived (`services.py:119-120`) | Yes, stronger (scope) | — |
| 11 | Remove assignment | `assign` (:172) | `assign` (:533) + scope (:535) + unstarted only (:539) | Yes, stronger | — |
| 12 | Reset attempts | `manage_assessments` (:177) | `manage_assessments` (:551) + scope (:553) + failed only (`services.py:442` `reset_assessment`) | Yes, stronger | — |
| 13 | CSV export | `view_reports` (:182) | `view_reports` (:689) + scope (`_filtered_assignments` :600) | Yes, stronger | — |

**Assessment link:** the payload carries `assessment` only for `manage_assessments` (mobile `TrainingCourseForm.toPayload`). The backend refuses a link without it (`views.py:207-208`). Consistent.

**Learner writes** (not admin actions): own assignments only.
- Backend: `_my_assignment` filters `employee=request.user`, course not archived (`views.py:729-731`), and closes a failed course (409, `:793-794`).
- Mobile: sends nothing while closed (`my_material_screen.dart` `_post`), and only after a tap (HO-48 OFF).

### Security / scope findings (backend; no unauthorised requests were made)

1. **HO-50 (NEW, P1): Branch Admin can author the company-wide course catalogue.**
   - `core/permissions.py:41` grants any codename to a role holding `settings.edit`. Only the literal `settings.edit` check is withheld from branch roles (`:34`).
   - Training seeds intend Branch Admin to have only view / assign / view_all_progress / view_reports (`training/migrations/0002_seed_permissions.py:17`).
   - Courses are not branch-scoped (`views.py` `CourseDetailView` :275-304, `MaterialListCreateView` :352, `MaterialDetailView` :415-450).
   - So a Branch Admin can create, edit, delete and manage assessments on courses used by **every** branch.
   - Mobile mirrors the backend (`access_control.dart:19`), so it shows these controls to a Branch Admin.
   - Same root cause as HO-18 and HO-45: a product/backend decision.
2. **HO-45 (extended):** a Branch Admin with an **empty branch** gets company-wide training scope (`training/services.py:72`: `Q(branch__iexact=branch) if branch else Q()`), the same pattern as leave/WFH.
3. **HO-51 (NEW, P3):** the backend accepts course edits and material changes on **archived** courses (rows 2–8). Only the web/mobile UI blocks them.
4. **File access:** `_can_open_material` (`views.py:845-849`) lets any course manager (create/edit/delete) open any material file in any course, and assigned employees open only their own non-archived ones. Acceptable; noted for HO-50 (Branch Admin counts as a course manager).
5. **Mobile/backend permission mirror:** mobile `userHasPermission` treats `settings.edit` as granting everything (`access_control.dart:19-20`). The backend withholds the literal `settings.edit` check from Branch Admins (`permissions.py:34`). No training control depends on the literal `settings.edit` check, so there is no training impact (noted in the Task 90 audit).

## 3. Automated and device results (Task 91 run)

| Check | Result |
|---|---|
| `flutter analyze` | 13 info (baseline; no warnings / errors) |
| Focused Training tests (`test/features/training`) | **85 passed** (Batch 1: 24, Batch 2: 29, Batch 3: 32) |
| Access / menu / global search tests | 43 passed |
| Full `flutter test` | **2,806 passed**, 0 failed |
| Source vs installed build | Source = code 16 manifest (re-hashed); installed APK `e820d54a…` verified at install (12:54) |
| Device in Task 91 | **Not connected** (`adb devices` empty). No new device run. Today's code 16 evidence stands: `evidence/t90/`, `t90b/`, `t90c/` |
| Office-file opening on device | **BLOCKED:** no PPTX/DOCX in production; installing a local fixture harness would replace the installed app (not allowed); needs staging (C8 / A10) |
| CSV export on device | **BLOCKED:** saving a file is a user action on the phone; no fixture path without changing the install; needs staging or approval (A21) |

## 4. Staging write-test matrix
See `15_TRAINING_STAGING_TEST_MATRIX.md`: 21 admin, 6 assignment, 13 employee and 5 permission/scope scenarios. Each has role, data, request / response, DB change, mobile behaviour, cleanup and evidence. **Not run:** no authorised staging environment or disposable accounts confirmed.

## 5. Handover blockers, separated

| Category | Items |
|---|---|
| **1. Mobile implementation defects** | None open in Training. Known limits: uploaded-video admin preview and "+ New Assessment" stay on web; the WebView video player has never played on a real device. Elsewhere: HO-39 / 40 / 41 / 42 / 43 / 44 (smaller parity gaps, from Task 90 Phase 1) |
| **2. Backend security blockers** | **HO-01** face-verification bypass (P0, open in source). **HO-18 / HO-50** Branch Admin's `settings.edit` bypass grants company-wide authoring (training catalogue, settings). **HO-45** empty-branch Branch Admin sees company-wide queues and training scope. **HO-51** archived-course edits accepted by the API (low) |
| **3. Missing staging verification** | Every Training write (matrix 15); all learner progress writes; real video playback in the WebView; Office hand-off; CSV save; all non-Branch-Admin roles (Employee / HR / Manager) |
| **4. Product decisions** | HO-48 decided: keep auto-open **disabled** pending staging. HO-49 decided: no un-archive, no duplicate assessment creator. **Open:** HO-18 / HO-50 (what a Branch Admin may author), HO-24 (Plan Details) |
| **5. Release artifact and signing** | **HO-32:** the release AAB (`e073c6f3…`, 17 Nov 16:06) was built from an unrecorded source state, **before** Task 88 / 90; it does not contain the Training module. A new release build from a recorded source and the upload key is required. **HO-31:** the reference clone was refreshed, but its revision vs production is unconfirmed. Every build in these tasks is a **debug** build signed with the debug key (`38eabe8f…`); none is releasable. The pubspec version is still 1.0.2+10 |

## 6. Recommendation

- **Training & Learning module: CONDITIONAL GO.**
  - What is ready: navigation, gating, every read screen and the safety controls (permission checks before requests, confirmations, private file handling) are implemented and verified read-only on the device.
  - Conditions before client use of writes:
    - (a) the staging matrix (15) passes;
    - (b) the product decides HO-50, what a Branch Admin may author;
    - (c) real video playback is checked on a device.
- **Overall client handover of the mobile app: NO-GO** (unchanged), for these reasons:
  - **HO-01** is a P0 backend security bypass, still open.
  - **HO-32:** there is no releasable artifact. The existing AAB predates this work and has no recorded source.
  - No write workflow has been verified on any role.
  - Becomes CONDITIONAL GO once all of these are done: HO-01 is fixed or risk-accepted in writing; HO-18 / HO-50 are decided; a release AAB is built from a recorded source state with the upload key and its hash recorded; and the staging write smoke-tests pass.

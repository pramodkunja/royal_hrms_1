# 13 — Task 90: Updated Web Source → Mobile Parity (18 Nov 2026)

**Source:** the local clone at `web_frontend_backend/` was refreshed by a pull at 11:26 on 18 Nov. It now contains the Training module that was missing before (HO-31).
- Git was not used. "Changed" means a file modified after 11:00 on 18 Nov: 91 files.
- No live web testing was done.
- Batch 1 was device-verified on debug **versionCode 13** (`7cc8f547…`), read-only.

## 1. New or changed web features and their mobile status

| # | Web feature (route / endpoint) | Permission / module | Mobile status | Gap / note | Estimate |
|---|---|---|---|---|---|
| 1 | **Training & Learning admin** `/dashboard/training`, `/dashboard/training/<id>`; `/api/training/courses|dashboard|reports|employees|progress|assign|assignments/*` | training.view (+ create/edit/delete/assign/view_all_progress/manage_assessments/view_reports); module `training` | **PARTIAL → batch 1 done** | Done: menu, route, module gate, dashboard figures, course list (search, archived), course Details (read-only), Materials (PDF preview, external links), Assign (people, groups, all; due date; confirmation), Progress (Reset attempts, Remove), Delete, Reports (6 filters). **Not done:** New Course, edit Details, material upload / edit / reorder, thumbnail, linked-assessment picker, CSV export, uploaded-video and PPTX/DOCX preview. | 2–3 days |
| 2 | **My Learning** `/dashboard/my-learning[/id]`; `/api/training/my/*` (open / progress / confirm, assessment start / submit) | none (own assignments); module `training` | **MISSING** | Tracked videos need playback heartbeats, so this needs `video_player` + `webview_flutter` (new packages; decision). Opening any material writes `opened` on the server, so the phone test can only cover the list. | 3–4 days |
| 3 | Leave type picker filtered by `eligible_for_me` (gender, inactive) | any user | **PARTIAL** | Mobile shows every built-in type, so the server refuses later with 400. | 0.5 day |
| 4 | Medical certificate rule (`medical_certificate_after_days`) | leave.apply | **PARTIAL** | The fields are parsed but never used; the server returns 400. | 0.5 day |
| 5 | Add Leave Type "Applicable to" (gender) | settings.edit / leave.approve | **PARTIAL** | The Add dialog always sends `all`. The server message "Removed N unused balance(s)" is dropped. | 0.5 day |
| 6 | Contact Matrix → My Approvers / Employee Approvers (`GET /company-contacts/approvers/?workflow=`) | any user; team needs employees.view | **MISSING** | Workflow selector, L1/L2 cards, team list. | 1–1.5 days |
| 7 | Attendance export: single employee (`employee=` parameter) | attendance.export | **MISSING** | Employee search plus the parameter; branch/department are cleared when an employee is chosen. | 1 day |
| 8 | Admin dashboard: Branch Admin action queue (`/dashboard/hr/action-queue/`) | can_manage_branch | **PARTIAL** | Reuse the existing queue widget. | 0.5 day |
| 9 | Company Plan Details (`/settings/company/plan/`) | can_edit_settings | **MISSING / decision** | Previously HO-24. | 1–2 days |
| 10 | Leave cancellation, Approvals → Leave Cancellations, Delegations, Escalation settings, Contact Matrix CRUD, Policy acknowledgement, Birthday settings, assessment scoring refactor, referral-rule write rule, dashboard module masking | various | **COMPLETE** | Contact delete wording differs from web ("Remove" vs "Delete"); P3. | — |
| 11 | Admin Payroll, Platform Admin SaaS, gender-balance cleanup command | — | **INTENTIONAL WEB-ONLY** | Unchanged decision. | — |

## 2. Permissions and security differences (backend; reported, not changed)
1. **Branch Admin data scope changed on the backend.**
   - `has_perm(user, 'settings.edit')` now returns False for branch-restricted roles, so data falls back to the user's own branch.
   - The device shows Training progress and reports limited to the user's branch.
   - The role still passes every *other* codename through the `settings.edit` bypass, including training create/edit/delete/manage_assessments.
   - **HO-18 stays open:** this is a product decision.
2. A Branch Admin with an **empty branch** sees company-wide leave/WFH approval queues (`leave.py` `_approval_scope_filter`, `workfromhome.py:88-91`).
3. The `?employee_id=` filter on the leave/WFH lists is not branch-scoped.
4. `/birthdays/` is not branch-scoped and returns emails.
5. The approvers `team` list has no pagination and returns email and phone for everyone in scope.
6. Login sets `is_superuser` for any `settings.edit` holder, so the mobile UI shows Branch Admins every control; the backend still enforces.

## 3. Batch 1 implementation (Training admin)
- **New:**
  - `lib/features/training/` (8 files: models, datasource, providers, 2 screens, 3 widgets)
  - `test/features/training/training_admin_test.dart` (24 tests)
- **Changed:**
  - `api_constants.dart`
  - `access_control.dart`: route permission `training.view`, `AppModules.training`
  - `app_router.dart`: `/dashboard/training` and `/:courseId`
  - `nav_config.dart`: HR Ops item and page title
  - `dashboard_shell.dart`: the detail route has its own app bar
  - `test/core/router/access_control_test.dart`: role fixtures gain the training codenames seeded by training migration 0002
- **Safety:**
  - Every write (Assign, Delete, Reset attempts, Remove) asks for confirmation. Mobile asks before *every* assignment, where web asks only before "everyone".
  - The PDF preview stays in memory; nothing is written to storage.
  - The admin preview records no learner progress.
- **Device (code 13, read-only):**
  - Training & Learning appears in the menu.
  - Dashboard figures and 2 live courses are shown.
  - Course Details, Materials and Progress open.
  - The Assign tab loads the branch-scoped picker; Assign stays disabled with nothing selected.
  - Reports shows 7 records with filters.
  - No write was made. Evidence is in `evidence/t90/`; names and IDs are redacted.
- **Known cosmetic items (found on device, not yet fixed):**
  - "Linked assessment" label touches its value.
  - Progress-card actions are left-aligned with extra space below.
  - The app-bar title truncates ("Training & Learni…", same pattern as HO-07).
  - No PDF material exists in production, so PDF preview is test-verified only.

---

# Batch 2: My Learning, employee side (18 Nov 2026, debug code 14 `53b14942…`)

## Contract (backend `apps/training/services.py` / `views.py`; web `app/dashboard/my-learning`)

**Access**
- Every signed-in user; no permission. Hidden when the company lacks the `training` module.
- The API returns only the caller's own, non-archived assignments.

**List** (`GET /training/my/`)
- Each row carries `status`, `progress_percent` (required materials completed ÷ required materials), `due_date`, `starts_on` and `material_count`.
- `status` is server-derived: assigned, in_progress, completed or failed. **overdue** means an open assignment whose due date has passed, so an overdue course appears only under the Overdue tab.
- Web's six tabs filter this list on the client side.

**Detail** (`GET /training/my/<id>/`)
- Read-only. Returns materials with the employee's progress, plus `assessment_state`.
- `is_required` already accounts for `videos_optional`.

**Progress writes** (`POST my/<id>/materials/<mid>/<action>/`)
- **open:** records `opened_at` and moves an assigned course to in_progress. Web sends it as soon as the viewer shows a material.
- **progress `{position, duration}`:** for tracked videos only (uploaded, YouTube, direct). The server:
  - ignores reports less than 2 s apart;
  - adds no more than real time × 1.05;
  - caps watched time at the time elapsed since opening + 10 s;
  - uses only the video length HR entered;
  - completes the video at **90%** of that length.
- **confirm:**
  - document: only after opening, and only once `min_view_seconds` have passed;
  - untracked video (Vimeo): only when HR allowed manual completion;
  - tracked video: refused.
- **Course completion:** all required materials done, plus the linked assessment passed if there is one.

**Assessment** (`POST my/<id>/assessment/start|submit/`)
- Unlocked once the required materials are complete; has a start date; attempt limit and time limit come from the Assessments module.
- Passing completes the course.
- When attempts run out without a pass, the status becomes **failed** and progress is closed (actions return 409) until HR resets the attempts.
- After a pass, up to 2 retakes are allowed; the best score is kept.

**Files**
- `materials/<id>/file/` (access-checked) and `materials/<id>/video-source/` (signed Cloudinary URL, valid 1 h) are read-only.

## Implemented
**Screens**
- My Learning: 6 scrollable tabs; course cards with access-checked thumbnail, status, line with "Mandatory · items · Assessment · Due · Starts", and progress bar.
- Course page: summary, status, description, closed and not-yet-open notices, numbered materials with web hint text, and the assessment row.
- Material viewer:
  - PDF shown in the app, with the minimum-reading countdown and "I have read this".
  - Tracked videos through a WebView running web's own YouTube IFrame / HTML5 `<video>` code, with throttled playback reports (10 s, forced on play / pause / end).
  - Vimeo embedded, with "I have watched this" only when allowed.
  - "Open the original" link, which sends nothing.
- Assessment: meta line, locked / no attempts / no questions / passed-retake states, radio questions, unanswered-questions check, submit, result banner, retake message, and a confirm-before-leaving dialog during an attempt.

**Navigation**
- Menu item "My Learning" with no permission (module gate only), routes `/dashboard/my-learning[/<id>]`, page title.

**Package**
- `webview_flutter ^4.14.1` (BSD-3, Flutter authors; minSdk 24, same as the app; no new Android permissions).
- `video_player` was **not** added: uploaded videos play from the signed URL inside the same WebView, and the HTML5 player reports the same events as web.

**Storage safety**
- Training PDFs are copied only to the app-private temporary folder with a neutral name and opened with `openFile`.
- The copy is deleted on close, before each view, at app start and at sign-out (the existing profile-document cleanup plus the viewer registry).
- **This also fixes the Batch 1 admin PDF preview**, which used `openData`; that leaves a copy in the cache.
- Nothing is shared with other apps or written to public storage.

## Deliberate differences from web
1. **Opening the course page records nothing on mobile.** Web automatically opens the first unfinished material, which records "opened" and starts the course. On mobile, "open" is sent only when the employee taps a material.
2. **PowerPoint / Word files are not handled in the app.** Web downloads them. Mobile neither downloads nor shows them, records no "open", and offers no confirm (an "I have read this" would be meaningless). The employee reads them on web.
3. **Leaving mid-assessment asks for confirmation** (mobile only).
4. **No signed URL for an uploaded video** (non-cloud storage only) shows "play on the web app". Web would stream the file through the API with its cookie.

## Verification
- **Automated:** 29 new tests (`test/features/training/my_learning_test.dart`) covering:
  - rule ports (hint, canConfirm, countdown, six filters, heartbeat throttle);
  - player page escaping, id and https checks, and the top-level navigation guard;
  - navigation and module gating;
  - list, tabs, empty, error and 403 states, and the 1.5× layout;
  - course page read-only;
  - PDF "open" sent once, then the countdown;
  - confirm;
  - Office files: no write;
  - closed course: no write;
  - tracked YouTube: throttled reports, completion only from the server;
  - Vimeo: no reports, confirm only if allowed;
  - "Open the original": no write;
  - uploaded video signed URL / no URL;
  - assessment flows.
- **Mutation checks:** 3 mutations to the progress guards were all caught.
- **Full suite:** 2,774 passed. Analyzer: 13 info.
- **Device (code 14, read-only, production):**
  - My Learning menu item; one live assignment.
  - All six tabs: the course appears under All and Not started; the other four show "Nothing here.".
  - Course page with the YouTube material and its hint, and the assessment locked.
  - Assessment page: "Pass mark 70% · 0 of 1 attempts used · 1 minute time limit", locked, **no Start**.
  - **No material was opened and no assessment was started.** Evidence: `evidence/t90b/`.
- **NOT verified (needs an approved staging account with disposable assignments):**
  - "open" being recorded;
  - real YouTube / Vimeo / uploaded-video playback inside the WebView and its progress reports;
  - server-side 90% completion;
  - document countdown and confirm against the server;
  - assessment start / submit / result;
  - closed-course 409.

## Remaining parity gaps (Training)
- PowerPoint / Word reading on mobile (decision: in-app or open-with).
- Training admin authoring: New Course, edit details, materials upload / reorder, thumbnail, assessment link. Estimate 2–3 days.
- Admin CSV export.
- Accessibility: course-card and progress-card screen-reader labels start with the progress value ("0, Python…"), because the progress bar is read before the title. Cosmetic.

---

# Batch 3: Training admin authoring, HO-46 / HO-47 (18 Nov 2026, debug code 16 `e820d54a…`)

## API contracts verified from source (`apps/training/views.py`, `validation.py`; web `CourseDetailsForm.tsx`, `MaterialsEditor.tsx`, `lib/training.ts`)

| Action | Method / path | Permission | Payload | Response / errors |
|---|---|---|---|---|
| Create course | POST `courses/` | training.create | `{title, category}` (title required, ≤200) | 201 course detail; 400 "Give the course a title." |
| Edit course | PATCH `courses/<id>/` | training.edit (`assessment` also needs manage_assessments) | web `courseFormPayload`: title, description, category, trainer_name, duration_minutes (null or 1–100000), is_mandatory, is_active, start_date, deadline (≥ start), videos_optional (needs an assessment), auto_assign_new_joiners, new_joiner_deadline_days (0–365), new_joiner_branches[], new_joiner_departments[], assessment (only for manage_assessments) | course detail; 400 with `{field: [msg]}` |
| Thumbnail | POST `courses/<id>/thumbnail/` multipart `thumbnail` | training.edit | PNG/JPG ≤ 2 MB, content-checked | `{has_thumbnail: true}` |
| Linkable assessments | GET `assessments/` | training.manage_assessments | — | `[{id, title, questions, pass_percentage}]` (active, with MCQ questions) |
| Add material | POST `courses/<id>/materials/` | training.edit | link: JSON `{material_type: external_video, title, external_url, is_required, allow_manual_completion, duration_seconds}`; upload: multipart `material_type, title, file, is_required, min_view_seconds` (documents) / `duration_seconds` (videos) | 201 material. Documents pdf/pptx/docx, videos mp4/m4v/webm, ≤ 9 MB by default (settings `TRAINING_*_MAX_MB`); content (magic bytes) checked. Tracked videos need a length. Links: https, public host, YouTube / Vimeo / direct .mp4/.webm |
| Edit material | PATCH `materials/<id>/` | training.edit | the fields web edits: `is_required`, `allow_manual_completion`, `duration_seconds` (the backend also accepts title / description / external_url / min_view_seconds, which web doesn't expose) | material |
| Remove material | DELETE `materials/<id>/` | training.edit | — | archived when there is progress (history kept), else deleted |
| Reorder | POST `courses/<id>/materials/reorder/` | training.edit | `{order: [every active id exactly once]}` | ordered materials; 400 if incomplete |
| Delete / archive course | DELETE `courses/<id>/` | training.delete | — | archived when assignments exist, else deleted (message says which) |
| **Unarchive** | **none** | — | — | **No backend endpoint and no web UI: not implemented, by design** |
| CSV export | GET `reports/?<filters>&export=csv` | training.view_reports | same filters as the report | `text/csv`, `training-report.csv`; formula-injection-safe cells |

## Implemented
- **Action layer:** `TrainingAdminActions`.
  - Every admin write checks the web/backend codename (and "not archived") and validates input **before any request**; a refusal throws locally and nothing is sent.
  - The Batch 1 writes (assign, delete, reset, remove) now go through it too.
- **New Course:** button (training.create); dialog with title required and category; on create, the new course opens.
- **Edit course** (Details tab, training.edit and not archived):
  - every web field, the web validation messages, and the past-deadline warning;
  - thumbnail upload with type and size pre-checks;
  - linked-assessment dropdown (manage_assessments; the current link stays selectable);
  - "Video watching optional" rule;
  - new-joiner days and branch / department chips (options from the employee picker, for training.assign);
  - Save, and Save & Continue.
  - Users who can't edit keep the read-only details.
  - "+ New Assessment" stays on web, because it opens the Assessments module.
- **Material management:** Required / Allow confirmation toggles, Set video length (mm:ss), move up / down, Remove with confirmation.
- **Add material:** type chips; title; file picker for uploads (bytes kept in memory) or link; minimum reading time / video length; Required; Vimeo confirmation; client checks matching web; upload progress.
- **CSV export:** Reports → Export CSV fetches the filtered CSV and saves it where the user chooses (Android's "Save to" screen, the equivalent of the web download).
- **HO-46:**
  - Details label column with a fixed gap.
  - Progress actions right-aligned.
  - Progress bars hidden from screen readers (cards read title first).
  - App-bar title scaled to fit at layout time, at most 25% smaller, then ellipsis. This applies to every screen, so it also partly fixes HO-07.
  - **Not fixed:** the 48 dp touch target under card actions is kept for accessibility.
- **HO-47:** PowerPoint / Word open in another app.
  - The file is fetched and checked to be a real Office (zip) file.
  - It is written only to the app-private `profile_docs/` cache folder, which is cleared at app start, before each view and at sign-out.
  - It is shared through a non-exported FileProvider (`<applicationId>.trainingfiles`, cache `profile_docs/` only) with a temporary read-only grant.
  - Android package-visibility queries are declared for the two Office types. "No app" and "not a real file" are reported to the user.
  - Learner: "open" is recorded on the explicit tap (web records it when the material is shown), then "I have read this" follows the server's minimum time. Admin: no write.
- **Course-opening parity:** `kMyLearningAutoOpenFirstMaterial` (**OFF**).
  - ON reproduces web: the first unfinished material opens on page load and records "open". Never for a closed or not-yet-open course.
  - Both settings are tested against the mocked API. Turning it on is a product decision and should be confirmed on staging.
- **Bug found and fixed:** the "Set video length" dialog disposed its text controller while the dialog was closing (it would crash in debug builds).

## Verification
- **Automated:** 32 new tests (`training_batch3_test.dart`) covering:
  - form validation and payloads, including the assessment link only for manage_assessments;
  - video link, length and upload rules;
  - the action layer refusing all 13 admin writes locally without permission, refusing archived-course edits, refusing invalid input, and reorder payloads;
  - New Course (permission, validation, POST, navigation, Cancel);
  - editor save payload, no assessment request without permission, invalid form;
  - thumbnail multipart;
  - materials toggle / reorder / length / remove with confirm;
  - add link (JSON) and add document (multipart fields);
  - oversize file refused;
  - view-only controls hidden;
  - CSV export success and failure;
  - Office: learner "open" then hand-off, closed course with no write, non-Office bytes refused, admin with no write;
  - parity switch OFF / ON / closed;
  - title fit and progress-bar semantics.
- **Mutation checks:** removing the save-permission check and the assessment-link gate were both caught. Removing the closed-course check before "open" is still prevented by the inner guard in `_post`; this is defence in depth, and the test shows no write.
- **Full suite:** 2,806 passed. Analyzer: 13 info.
- **Device (codes 15 → 16, production, view-and-cancel only):**
  - New Course dialog opened and **cancelled**.
  - Edit form (top, assessment / new joiners, Save buttons) viewed; no field edited, nothing saved. The linked-assessment list loaded with a read-only GET.
  - Materials editor controls and the Add-material form opened locally; no toggle tapped, nothing added.
  - Progress actions right-aligned.
  - **Title:** code 15 still truncated (the fix measured before Poppins loaded). Fixed in code 16. "Training & Learning" and "Face ID Registrations" now show in full; "Candidate Review & Onboarding" reaches the 75% floor and ellipsizes, by design.
  - Evidence: `evidence/t90c/` (progress names redacted).

## Production write workflows still UNTESTED (need a staging tenant with disposable data)
- Create course; save course; thumbnail upload.
- Link an assessment.
- Add (upload / link) / toggle / set length / reorder / remove materials.
- Delete / archive course.
- Assign; remove assignment; reset attempts.
- CSV export to a real file (the GET is read-only, but no file was saved on the phone).
- Office hand-off on a real file (production has no PPTX/DOCX material).
- All learner progress writes from Batch 2.

## Remaining Training gaps
- "+ New Assessment" (creating assessments) stays on web.
- Unarchive: not supported by the backend.
- Editing a material's title / description / link: web doesn't offer it, so mobile doesn't either.
- Previewing uploaded videos on the admin side stays on web.
- The parity switch needs a product decision.

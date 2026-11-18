# 15 — Training & Learning: Staging Write-Test Matrix (Task 91, 18 Nov 2026)

**Status:** plan only. Nothing here may be run until both of these are confirmed in writing:
- an **authorised staging tenant** (not production `DEMO2026`);
- **disposable test accounts**.

**Why:** every operation below writes data and has only been verified with mocked API tests. Batches 1–3 were device-checked read-only, or view-and-cancel.

## Prerequisites (confirm before any test)

| # | Item | Detail |
|---|---|---|
| P1 | Staging backend URL | A debug build pointing at staging. Today `api_config.dart` has `Environment.production` even in debug, so a staging build needs an approved config change and its own versionCode. |
| P2 | Company | Staging company with the **training** and **assessments** modules enabled (training depends on assessments). |
| P3 | Accounts | **ADM**: hr_admin, all 8 `training.*`. **BRA**: branch_admin with branch "B1" (has `settings.edit`). **BRX**: branch_admin with **no branch**. **EMP1** / **EMP2**: employees in B1, onboarding complete. **EMP3**: employee in branch B2. **VIEW**: custom role with `training.view` only. |
| P4 | Assessment | An active assessment "QA-Quiz" with 2 MCQ questions, pass mark 50%, max attempts 2, time limit 5 min. Also "QA-Empty", an active assessment with no questions. |
| P5 | Fixtures (synthetic, no real content) | `qa.pdf` (1 page, 50 KB); `qa.pptx` and `qa.docx` (valid OOXML, <1 MB); `qa.mp4` (H.264, 20 s, <5 MB); `big.pdf` (>9 MB); `fake.pdf` (text renamed to .pdf); `thumb.png` (<200 KB); `thumb.gif`. A public YouTube video of known length (unlisted QA video); a Vimeo link. |
| P6 | Device | Motorola, or a separate test phone, with the staging build. Check whether an app that opens PPTX/DOCX is installed (Slides / Docs / Office), using `cmd package query-activities`. |
| P7 | Evidence | Redacted screenshots; API request/response pairs (staging); DB rows read with the Django shell or admin by the backend owner (read-only queries). |

**Global cleanup:** delete the "QA-" courses created (the server archives those with history), the assignments, and the QA accounts; or restore the staging DB snapshot taken before the run (**preferred**: take a snapshot at the start).

## A. Admin authoring (Batch 3)

| ID | Scenario | Role | Test data | API request → expected response | Expected DB change | Expected mobile behaviour | Cleanup | Evidence |
|---|---|---|---|---|---|---|---|---|
| A1 | Create course | ADM | title "QA-Course-1", category "QA" | POST `/training/courses/` `{title, category}` → 201 course | New `training_courses` row; `created_by`=ADM; audit `training_course_created` | Dialog closes, "Course created.", the course opens on Details | Delete course | Screenshot, response, DB row |
| A2 | Create without permission | VIEW | — | No request (button hidden; the action layer refuses locally). Direct API call by the backend owner → 403 | none | No New Course button | — | Screenshot; backend 403 log |
| A3 | Edit all fields | ADM | QA-Course-1: description, trainer, duration 30, start date today, deadline +7 days, Mandatory on | PATCH `/training/courses/<id>/` with the web payload → 200 | Fields updated; audit `training_course_updated` | "Course saved."; values persist after reopening | Delete course | Before/after screenshots, PATCH body |
| A4 | Server-side validation | ADM | deadline < start date (bypass the client by editing the payload in a test harness only) | PATCH → 400 `{deadline: [...]}` | none | The client blocks it first: error text, Save disabled | — | Screenshot |
| A5 | Thumbnail | ADM | `thumb.png`; then `thumb.gif` | POST `/thumbnail/` multipart → 200 `{has_thumbnail: true}`. The gif is refused on the client (no request) | `thumbnail` file stored | Thumbnail shows on the list card and in the form | Delete course | Screenshots |
| A6 | Link assessment | ADM | QA-Quiz | GET `/training/assessments/` → list; PATCH `{assessment: <id>}` → 200 | `assessment_id` set | Dropdown shows "QA-Quiz (2 questions, pass 50%)" | Unlink (PATCH `assessment: null`) | Screenshot, DB |
| A7 | Assessment link without manage_assessments | Role with `training.edit` only | — | PATCH without an `assessment` key → 200 | `assessment_id` unchanged | No dropdown; read-only title | — | PATCH body |
| A8 | Videos optional without an assessment | ADM | — | Client blocks it. Backend (direct) → 400 `videos_optional` | none | Error text under the switch | — | Screenshot |
| A9 | Add PDF | ADM | `qa.pdf`, title "QA-PDF", min reading 1 min | POST `/materials/` multipart (material_type=document, min_view_seconds=60) → 201 | `training_materials` row, `file_format` pdf | "Uploading… %", then the list updates; Preview opens the PDF; the temp copy is deleted on close | Remove material | Screenshot; file-list check of the app cache (`run-as`) after close |
| A10 | Add PPTX / DOCX | ADM | `qa.pptx`, `qa.docx` | as A9 → 201 | 2 rows, `file_format` pptx / docx | "Open in another app" opens the viewer app read-only; no learner progress | Remove | Screenshots, chooser screenshot |
| A11 | Upload MP4 | ADM | `qa.mp4`, length 0:20 | multipart with duration_seconds=20 → 201 | `video_file`, `duration_seconds` 20 | Listed; "Preview uploaded videos on the web app." | Remove | Screenshot |
| A12 | Rejected uploads | ADM | `big.pdf`, `fake.pdf` | `big`: client refuses (no request). `fake`: server 400 "content does not match" | none | Error snackbar / text | — | Screenshots |
| A13 | YouTube link | ADM | QA YouTube URL, length set | JSON POST → 201, provider youtube, `is_tracked` true | row | Shows "YouTube · Required · m:ss" | Remove | Screenshot |
| A14 | Vimeo + confirmation | ADM | Vimeo URL, "let employees confirm" on | JSON POST → 201, `allow_manual_completion` true | row | Shows "completion confirmed by employee" | Remove | Screenshot |
| A15 | Toggle Required | ADM | QA-PDF | PATCH `/materials/<id>/` `{is_required: false}` → 200 | `is_required` false | Label changes to Optional | Toggle back | DB before/after |
| A16 | Set video length | ADM | tracked video without a length | PATCH `{duration_seconds: 750}` → 200 | updated | Warning button disappears | — | Screenshot |
| A17 | Reorder | ADM | 3 materials | POST `/materials/reorder/` `{order: [all ids]}` → 200 | `order` 1..3 swapped | List order changes | Reorder back | DB |
| A18 | Remove material, no progress / with progress | ADM | QA-PDF before / after EMP1 opened it | DELETE → 200 | Deleted (files removed) / `is_archived` true (history kept) | Disappears from the list | — | DB |
| A19 | Delete course, no history / with history | ADM | QA-Course-2 (never assigned) / QA-Course-1 (assigned) | DELETE → "Course deleted." / "…archived instead of deleted." | Row deleted / `archived_at` set, `is_active` false | Snackbar with the server message; the list refreshes; the archived course appears only with "Show archived" | — | Screenshots, DB |
| A20 | Archived course is read-only on mobile | ADM | archived QA-Course-1 | No requests | none | No Assign tab, no Delete, read-only Details and Materials | — | Screenshot |
| A21 | CSV export | ADM | report with ≥1 row | GET `/reports/?export=csv` → text/csv | none | Android "Save to" screen opens; file saved where chosen; "Report saved." | Delete the CSV file | Screenshot of saved file (redacted) |

## B. Assignment and attempts

| ID | Scenario | Role | Data | API → expected | DB change | Mobile | Cleanup | Evidence |
|---|---|---|---|---|---|---|---|---|
| B1 | Assign people + due date | ADM | EMP1, EMP2, due +7 days | POST `/assign/` `{employee_ids, due_date}` → "Assigned to 2 employee(s)." | 2 `training_assignments` (source individual); notifications | Confirm dialog, then snackbar, then Progress tab | Remove assignments | Screenshots |
| B2 | Assign groups / all | ADM | department / branch B1 / all | → counts; existing ones skipped ("N already had this course") | rows per source | Summary matches | Remove | Screenshot |
| B3 | Assign inactive course | ADM | course Active off | Client blocks it; backend → 400 "Only an active course can be assigned." | none | Warning, Assign disabled | — | Screenshot |
| B4 | Branch scope on assign | BRA | try EMP3 (branch B2) | Picker lists only B1 employees; a direct POST with EMP3 → 403 "not in your scope" | none | EMP3 not listed | — | Screenshot, backend 403 |
| B5 | Remove unstarted / started | ADM | EMP2 unstarted; EMP1 after opening a material | DELETE `/assignments/<id>/` → 200 / 409 | Deleted / unchanged | Remove shown only for unstarted rows; a 409 message is shown if it races | — | Screenshots |
| B6 | Reset failed attempts | ADM | EMP2 failed QA-Quiz twice | POST `/reset-assessment/` → 200 | `attempts_used` 0, status in_progress | "Reset attempts" only on failed rows | — | DB |

## C. Employee (My Learning, Batch 2)

| ID | Scenario | Role | Data | API → expected | DB change | Mobile | Cleanup | Evidence |
|---|---|---|---|---|---|---|---|---|
| C1 | Open a course page (HO-48 OFF) | EMP1 | assigned course | GET only | **none** (status stays assigned) | Course page; no progress recorded | — | DB unchanged |
| C2 | Open PDF | EMP1 | QA-PDF (min 1 min) | POST `/materials/<id>/open/` → 200 | progress `opened_at`; assignment in_progress, `started_at` | Countdown "Available in 1m"; confirm disabled | — | DB, screenshot |
| C3 | Confirm too early / on time | EMP1 | C2 | Early: client disabled; direct → 400 "(N s left)". After 60 s → 200 | `completed_at`, method read | "Marked as complete." | — | DB |
| C4 | YouTube tracked to 90% | EMP1 | 3-min QA video | `progress` every ≤10 s, then complete at ≥162 s watched | `watched_seconds` grows at real time; `completed_at` method tracked | Hint "Watched N%"; then Completed | — | DB + screen recording |
| C5 | Skipping ahead does not count | EMP1 | seek to end | progress reports | `watched_seconds` limited by real time | Not completed | — | DB |
| C6 | Vimeo confirm allowed / not | EMP1 | A14 / Vimeo without confirmation | confirm → 200 / no button (direct → 400) | completed / none | "I have watched this" only when allowed | — | Screenshots |
| C7 | Uploaded video playback | EMP1 | A11 | GET `/video-source/` → signed URL; progress reports | as C4 | Plays in the in-app player | — | Recording |
| C8 | Office file | EMP1 | A10 | Tap: POST open → 200; GET `/file/`; viewer app opens; then confirm | opened, then completed after min time | Chooser / viewer; temp copy only in app cache, cleared at sign-out | — | Screenshots; cache listing after sign-out |
| C9 | Assessment pass | EMP1 | QA-Quiz, all correct | start → questions; submit → passed | attempt row; `assessment_passed`; course completed | Result banner "Passed — 100%"; status Completed | — | Screenshots, DB |
| C10 | Fail until attempts run out | EMP2 | wrong answers ×2 | submit ×2 → failed; next start → 409 | status failed; actions closed (409) | "No attempts left…"; course page closed notice; no progress writes | Reset (B6) | Screenshots |
| C11 | Retake after pass | EMP1 | after C9 | start/submit → best score kept | `best_score_percent` = max | Retake wording, course stays Completed | — | DB |
| C12 | Course not open yet | EMP1 | start date +2 days | open → 409 "starts on" | none | "This course starts on …"; materials not tappable | — | Screenshot |
| C13 | HO-48 switch ON (separate build, only if approved) | EMP1 | fresh assignment | GET, then POST open of the first unfinished material | opened, in_progress | First material opens automatically | Remove assignment | Recording |

## D. Permission / scope negative tests (backend owner runs the direct API calls)

| ID | Check | Expected |
|---|---|---|
| D1 | VIEW calls each of the 13 admin endpoints directly | 403 for every one; mobile shows none of the controls |
| D2 | BRA edits / deletes a course created by ADM | **Today: allowed** (HO-50). Record the result; product to decide |
| D3 | BRX (no branch) opens Progress / Reports | **Today: company-wide scope** (`services.employee_scope_q`, HO-45). Record it |
| D4 | PATCH / materials on an archived course by direct API | **Today: allowed** (HO-51); mobile and web block it in the UI only |
| D5 | Training module disabled for the company | Every `/api/training/*` → 403 "not enabled"; mobile hides both menu items |

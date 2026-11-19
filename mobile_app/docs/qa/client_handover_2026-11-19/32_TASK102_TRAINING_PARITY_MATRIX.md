# 32 - Task 102: Training & Learning parity matrix and redesign (19 Nov 2026)

**Scope:** `lib/features/training/**`. Web (`app/dashboard/training`, `app/dashboard/my-learning`, `lib/training.ts`) and `backend/apps/training` were read only.
**Evidence level:** SOURCE + MOCK (widget tests against a stand-in API) + real-widget PNG renders. **No device, emulator, staging or production run.** Nothing here supersedes docs 14 and 15 (staging write matrix still not run).

## 0. What was re-verified against current source (earlier claims in doc 14)

| Doc 14 claim | Re-check | Result |
|---|---|---|
| All admin writes go through `TrainingAdminActions._require(...)` before the request (13 actions) | `training_providers.dart` still has 13 call sites; a source search finds 0 direct datasource write calls from the UI | Holds, no regression |
| 85 training tests green | Re-run at start of Task 102: 85 passed | Holds |
| Dashboard figures hidden on 403 | Still true (`_DashboardStats` renders nothing without data); test added | Holds |
| New Course payload `{title, category}`; assign / reset / remove / material payloads | Existing suites unchanged and green; new test pins `POST /training/courses/` body | Holds |
| Course-opening progress stays OFF (HO-48) | `kMyLearningAutoOpenFirstMaterial = false`, untouched | Holds |
| Un-archive, "+ New Assessment", uploaded-video preview are web only | Unchanged | Holds |

No regression found. Items found that were not covered before are in section 3.

## 1. Not present in web / backend (so not built)

- **Certificates:** none (no model, endpoint, page or string in `apps/training` or either web folder). Not invented.
- **Attendance / sign-in sheets for training:** none.
- **Un-archive:** no endpoint, no web control.
- **Course duplication, categories CRUD, notifications on assign:** none in these web folders.

## 2. Matrix

Permissions: V training.view, C create, E edit, D delete, A assign, M manage_assessments, R view_reports. "Learner" = any signed-in user, module `training` enabled, rows are the user's own.

| Web feature | Flutter implementation | Mismatch / gap found | API | Permission | Correction made (Task 102) |
|---|---|---|---|---|---|
| Courses tab: dashboard stat cards (6) | `training_screen.dart` `_DashboardStats` | Six bordered boxes, label-over-value look | GET `training/dashboard/` | V (403 hides cards) | One summary surface, icon tiles, same six figures and texts (`6 / 8`, `24 (40%)`, ...) |
| Course list: search title+category, Show archived | `_CoursesTab` | Switch row looked like a form | GET `training/courses/?archived=0|1` | V | Compact search + `FilterChip` with visible selected state and course count |
| Course row (title, category, Mandatory/Optional, New joiners, materials, assessment, assigned, completed, status) | `_CourseCard` | All facts present; flat text | same | V | Card: icon tile, status/category/mandatory chips, 2-line description snippet, facts row, completed/assigned progress bar; compact at large text |
| Empty list "No courses yet. Create the first one." | `TrainingStateView.empty` | web shows it even when a search is active | - | C only for the "Create the first one." hint | Empty and **no-match** are now different states (web wording kept for empty); no-match has Clear search |
| Load error banner | `TrainingStateView.error` | Used a generic error widget | - | - | Error / offline / denied (403, module off: no Retry) via the shared state component; failure never renders the empty look (tested) |
| New Course dialog (title *, category) -> opens course | `NewCourseDialog` | Material default tinted dialog | POST `training/courses/` `{title, category}` | C | White-surface dialog, outlined inputs, primary Create, same payload/validation text |
| Reports tab (filters course, status, department, branch, assigned from/to; count; Export CSV; rows) | `training_reports_panel.dart` | Filters were a column of dropdowns | GET `training/reports/` (+`export=csv`) | R (dept/branch lists need A, as web) | Filter card (2 columns when it fits), person cards, count + export that stack when they do not fit; "No matching records." split into empty vs filtered (Clear filters) |
| Course page header (title, category · Mandatory/Optional · state), Back, Delete | `training_course_screen.dart` | Default white app bar | GET `training/courses/<id>/`, DELETE same | D, not archived | `BlueAppBar` with `training-course-delete`; tabs on the blue bar (white label + indicator); identity header in Details |
| Details tab (form with canEdit, else read-only) | `training_course_form.dart` / `_DetailsTab` | Read-only was a label/value table | PATCH `training/courses/<id>/` | E, not archived | Read-only: Schedule / Assessment / New joiners sections with natural lines. Editor: icon section headers, outlined inputs, primary/secondary buttons; payload untouched |
| Thumbnail upload | course form | - | POST `.../thumbnail/` | E | restyled button only |
| Assessment link (+ videos optional rule) | course form | - | GET `training/assessments/`, PATCH | M | unchanged logic |
| New-joiner rules | course form | - | PATCH | E | chips restyled |
| Materials list (kind, size, length, required, preview) | `training_materials_editor.dart` | Plain text line | GET course (materials) | V | Rows: kind icon, Kind / Required-Optional / length / size chips; text strings for min reading / confirmation kept |
| Material add (PDF/PPTX/DOCX/MP4/link), required + allow-confirm toggles, length, reorder, remove | same | - | POST `.../materials/`, PATCH `materials/<id>/`, POST `.../reorder/`, DELETE | E, not archived | Restyled (primary buttons, tinted chips, white length dialog); no payload change |
| Assign (people / groups / all, due date; confirm) | `training_assign_panel.dart` | Footer clipped risk at large text | POST `.../assign/` | A, active, not archived | Footer decides one line vs stacked by measuring button text; empty / no-match / error states; styled chips; mobile still confirms every assignment (deliberate, doc 14) |
| Progress tab table + Reset attempts / Remove | `_ProgressTab`, `TrainingAssignmentCard` | Plain cards | GET `.../progress/`, POST `assignments/<id>/reset-assessment/`, DELETE `assignments/<id>/` | Reset M and status failed; Remove A, assigned and not started | Person cards (avatar, status chip, bar, due/completed/best score), summary chips, 44 dp outlined actions that wrap inside the card; empty vs error split |
| Material PDF preview (admin) | `TrainingPdfPreviewScreen` | Default white app bar | GET `materials/<id>/file/` | V | `BlueAppBar` |
| My Learning list + 6 tabs (All, Not started, In progress, Overdue, Completed, Failed) | `my_learning_screen.dart` | Identical cards for every tab | GET `training/my/` | Learner | Cards keep the web line (`Mandatory · N item(s) · Assessment · Due ...`); status chip over the cover; overdue shows "Was due"; completed shows date + best score; failed shows the reset note; primary action Start / Continue / Review / View |
| Empty text "Nothing here." / "No training has been assigned to you yet." | `_empty` | - | - | - | Titles kept; each tab has its own message and icon |
| List failure / module off | state view | - | 403 `module disabled` | - | error with Retry; module-off = denied, no Retry |
| My course page (header, status, due, %, description, closed / not-open alerts, materials, assessment row) | `my_course_screen.dart` | Default app bar; flat cards | GET `training/my/<id>/` | Learner | `BlueAppBar`; header with bar and "n of m materials"; banners; sections for materials / assessment; same keys and texts (`1. Title`, `my-course-summary`) |
| Material viewer: PDF, YouTube/Vimeo/direct/uploaded video, Office hand-off, "I have read/watched this" after minimum time, open original | `my_material_screen.dart` | Default app bar | POST `my/<id>/materials/<mid>/open|progress|confirm/`, GET `video-source/`, `file/` | Learner, not when closed | `BlueAppBar`; header card; banners; full-width confirm button; behaviour untouched |
| Assessment panel (start, questions, submit, retake, locked / closed notices) | `my_assessment_screen.dart` | Default app bar | POST `my/<id>/assessment/start|submit/` | Learner | `BlueAppBar`; answered counter + bar; full-width primary Submit; result as banner |
| Confirm dialogs (delete course, reset, remove, remove material, submit, leave) | `confirmTrainingAction` -> `TrainingDialog` | Material tint | - | - | White surface, primary or error confirm, Cancel text button |
| CSV export | reports panel | web downloads a blob; mobile "Save to" picker | GET `training/reports/?export=csv` | R | unchanged (doc 14: device save not exercised) |

## 3. Gaps / observations found

1. **Search vs empty (web quirk):** web says "No courses yet." even when a search hides everything; mobile now says "No courses match your search." with Clear search. Deliberate improvement; empty wording kept.
2. **Completed / assigned progress on the course card** is derived on the device from `completed_count / assigned_count` (both are API fields). It is not a server figure.
3. **Tabs on the blue bar:** chosen over a white strip under the bar so the identity stays one continuous header; white 70 % for inactive labels. Verified in `t102_04_course_materials.png`.
4. **Earlier unreadable overflow risks** (Progress card badge/percent row, report count + Export CSV row, Assign footer) are fixed by wrapping or stacking; covered by a 320/360/430/tablet x 1.0/1.5/2.0 text matrix.
5. No behavioural regression of doc 14 found (section 0).

## 4. Backend developer handoff (nothing worked around)

Web features the backend does not provide or rejects, or security items already known (details in docs 14, 17, 20):

- **Un-archive a course:** no endpoint (HO-49 decision: not implemented).
- **HO-50:** `settings.edit` grants every codename, so a Branch Admin can author the company-wide course catalogue.
- **HO-51:** the API accepts edits / material changes on **archived** courses; only the UI blocks them.
- **HO-45:** a Branch Admin with an empty branch gets company-wide training scope.
- Nothing new was found in Task 102 (no endpoint was added or changed; no web feature was found that the backend rejects).

## 5. Verification run

- `flutter test test/features/training test/visual`: **132 passed, 64 skipped** (skips = the screenshot cases, which only run with `T1011_SHOTS=1`).
- `dart analyze lib/features/training test/features/training test/visual`: **No issues found**.
- Render evidence: `evidence/t102/` (`before_t102_*` old UI, `t102_*` redesign, 40 screens each).
- Mutation checks (restored from a backup copy): (a) the course list error state replaced by the empty state fails 2 tests; (b) `BlueAppBar` replaced by the default `AppBar` on the course screen fails 2 tests.
- Not done: any device or emulator pass, staging write test, real video playback, real PDF rendering in a shot.

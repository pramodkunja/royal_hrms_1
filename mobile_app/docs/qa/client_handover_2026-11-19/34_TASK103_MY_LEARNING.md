# Task 103 — My Learning premium redesign, responsive layout, web parity

Flutter only; backend/web read-only. No Git, no device build, no production writes. **Render + mocked-test evidence only — no device pass.**

## 1. Web feature inventory (read in full)
Sources: `app/dashboard/my-learning/page.tsx`, `[id]/page.tsx`, `_components/MaterialViewer.tsx`, `AssessmentPanel.tsx`, `lib/training.ts`; backend `apps/training/views.py` (`MyTrainingListView`, `MyTrainingDetailView`, `my_course_out`).
- **List** (`GET /training/my/`): six client-side status filters (All, Not started, In progress, Overdue, Completed, Failed); card = thumbnail or school icon, title, status badge, line "Mandatory · N item(s) · Assessment · Due … · Starts …", progress bar "N% of required materials". Empty: "No training has been assigned to you yet." / "Nothing here.".
- **NOT in web:** search, sorting, pagination, counts, overview statistics, certificates, training attendance, enrolment. None were invented.
- **Course page** (`GET /training/my/<id>/`): title, category · due · % complete, status badge, description, closed-attempts alert, "starts on" notice, numbered material list (done tick, kind, optional, hint), Assessment entry (Passed % / Available / "Complete the materials first"), viewer.
- **Material actions:** `…/materials/<mid>/open|progress|confirm/`; **Assessment:** `…/assessment/start|submit/`. Backend list also returns description, trainer, duration, deadline (unused by the web card).

## 2. Parity matrix
| Web feature | Mobile | Status |
|---|---|---|
| Six filter tabs | Pill tabs, same labels/order/keys, **plus on-device counts** | Complete (+) |
| Card: thumbnail / school icon | Thumbnail cover when `has_thumbnail`; otherwise icon beside the title (no empty band) | Complete |
| Card: title, status badge, line, progress | Same, line kept verbatim | Complete |
| Card: description, trainer, duration | Shown (backend sends them; web card omits) | Mobile extra, API-backed |
| Empty / "Nothing here." / failure / 403 | Distinct states; failure never looks empty | Complete |
| Course page, materials, assessment row, closed/starts notices | Redesigned in Task 102, verified here | Complete |
| Material open/progress/confirm, PDF/video/link, Office open-in | Existing, unchanged | Complete (writes mocked only) |
| Assessment start/submit/retake | Existing, unchanged | Complete (writes mocked only) |
| Search / sort / pagination | Not in web → not built | Intentionally absent |
| Certificates | Not in web or backend | Not present |
| Course-opening auto progress | Deliberately off (HO-48) | Known difference |
| Uploaded-video preview | Web-only message (existing) | Known gap |

## 3. Gaps fixed this task
- Tabs had no counts → counts from the list.
- No overview → compact 4-tile overview (Assigned / In progress / Completed / Overdue), counted from the API list; hidden when empty or failed.
- Cards spent a 60dp band on an empty icon strip → icon beside title; progress text and action share one line.
- Single column on every width → 1 / 2 / 3 columns at <600 / ≥600 / ≥900dp.
- Overview labels split mid-word at 2× text → single column when large text.
- **Real bug:** a quick double-tap on a card pushed two course pages → guarded (one back returns to the list).
- Tab count colour was low-contrast on the selected pill → inherits the tab colour.

## 4–5. Screens and components
Redesigned in place: `my_learning_screen.dart` (overview, pill tabs, cards, responsive grid). Course/material/assessment screens (Task 102) verified, unchanged. Reused: `ApprovalsEmptyState/.forError`, `ApprovalsChip`, `TrainingCard/Badge/Fact/ProgressBar/StateView`, `BlueAppBar`, shell `AppTopBar`. No new colours.

## 6. Navigation flow (tests, real routes)
List → course → assessment (locked) → back → course → back → list; list → course → material → back → course; double-tap opens one course. No writes while navigating; the list is fetched once and once more per pull-to-refresh/Retry. Materials/assessment writes were already covered (my_learning_test.dart).

## 7. Screenshots (`evidence/t103/`, prefix `t103_`)
01 home; 02–06 each tab populated; 07–11 each tab empty; 12 nothing assigned; 13 error; 14 denied; 15 loading; 16 course in progress; 17 course completed; 18 material (video, placeholder player); 19 assessment locked; 20 assessment questions; 30/31 320dp @ 2× (list/course); 32 foldable 700; 33 tablet 1000; 34 landscape 800×393. Before = `evidence/t102/t102_20…25`.
Personally viewed: 01, 03, 09, 17, 30, 33 (and 01/17/30 again after fixes). Not individually reviewed by me: the other 19.

## 8. Responsive (tests)
320×568, 360×800, 430×932, 320 @ 2×, 360 @ 1.5×, 800×600 — every tab scrolls with no overflow; 393 one column; 700 two; 1000 three equal-width; very long title at 320 @ 2× keeps status and a ≥44dp action. Keyboard/search: web has no search, so none.

## 9. Tests / analyzer
`flutter test`: **3,327 passed, 89 skipped** (screenshot-only). `dart analyze`: 7 pre-existing infos, none new. New `my_learning_redesign_test.dart` (23): counts incl. uneven data, overview, card content, no cover band, layout by width, responsive matrix, error/denied/Retry once, pull-to-refresh once, three journey tests. Mutation checks: removing the double-tap guard and miscounting the Overdue tile each fail a test.

## 10. Backend dependencies / blockers
None new. Unchanged: un-archive endpoint absent; HO-45/50/51; uploaded-video preview web-only.

## 11. Device QA checklist
1. My Learning on a real phone: blue bar, counted pill tabs, overview, cards; rotate to landscape; foldable if available.
2. Pull to refresh; offline → error + Retry; 403 → denied.
3. Start/continue a course: PDF, YouTube/uploaded video, link, Office open-in; back from each lands on the course.
4. Assessment start/submit/retake (staging writes), then confirm the list refreshes status/progress.
5. Largest font on a small phone (shell bar truncates "My Learning" at 2× — existing HO-46 limit).
6. A course with a thumbnail (cover image path).

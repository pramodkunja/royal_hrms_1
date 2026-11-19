# Task 101 — Approvals: web parity + Premium Minimal redesign

Web (source of truth): `web_frontend_backend/frontend/app/dashboard/approvals/` — `page.tsx`, `_data.ts`,
`ApprovalModal.tsx`, `_components/{TeamApprovalsSection,ApprovalsToolbar,ApprovalsTable,SummaryCards,Badges,
BulkConfirmModal,RequestDetailDrawer,AttendanceApprovalTab,EmployeeAttendanceRow,FaceRegistrationApprovalsTab,
LeaveCancellationsSection,DelegationsSection}.tsx`. Backend (read-only, checked): `apps/hrms/views/expenses.py`,
`apps/hrms/views/leave.py` (LeaveApprovalView). No backend file was modified.
Flutter: `lib/features/approvals/` (+ `lib/features/leave/presentation/widgets/leave_cancellation_panel.dart`).

## 1. Web inventory
`page.tsx:17-52` — five sections, each gated (the tab bar is always shown, even for one):

| Section (web label) | Shown when (web) | Flutter |
|---|---|---|
| Team Approvals | any of leave.approve, expenses.approve, attendance.create, separation.approve | same + wfh.approve (WFH folds in here on web too) |
| Attendance Approval | attendance module and (can_manage_team, superuser or payroll.view) | **deliberately stricter** (Task 77): attendance + payroll modules and (can_manage_team or payroll.edit) — web's payroll.view gets 403 from every endpoint |
| Face Registration | facial_recognition.approve and face_attendance module | same; label was "Face ID Approvals" → fixed |
| Leave Cancellations | leave.approve | same (+ leave module) |
| Delegation | leave.approve, or attendance.create with attendance.edit / can_manage_team / branch / superuser | same |

**Team Approvals** (`TeamApprovalsSection.tsx`): fetches six kinds up front — leave (`?scope=team&page_size=100`), expense
(`page_size=100`), attendance corrections, separation (`scope=team`), WFH (`scope=team`), payslip queries (payroll.view) — each only if
its module is on; filters client-side. Type tabs (web `TYPE_TABS` order): All Requests, Leave, Work From Home, Expense, Attendance
Correction, Payslip Requests, Separation — each with its pending count. Summary cards: Pending Requests, Leave Requests, Expense
Requests, Attendance Corrections (module-gated). Toolbar: search "employee name or ID", status (All Statuses / Pending / Approved /
Rejected; default Pending), type dropdown (All tab only), submitted-from/to, Refresh. Table: sort Employee / Submitted Date / Status,
10 per page ("Showing a–b of n", Prev, ≤5 page numbers, Next), checkbox column (not for separation / payslip), "Select all n",
Approve/Reject/View per row (disabled unless the server's `can_action`). Special flows: separation → its own detail page; payslip →
Resolve (note required); late-arrival justification → its own review (reason to reject / send back); WFH and correction → direct action
(no dialog); leave → ApprovalModal (reject reason required; email template picker); expense → ApprovalModal (same).
Detail drawer: employee, request details per kind, reason, attachments (preview), approval timeline (Manager / HR), comments.
Bulk (`BulkConfirmModal`): reject needs a reason; `Promise.allSettled`; toast "N request(s) approved." / "N approved, M failed — please
retry those individually."; whole inbox refetched.

## 2. Tab-by-tab parity matrix (C complete · P partial · M missing · D deliberate difference)
Before = start of Task 101.

| Area | Web | Before | After |
|---|---|---|---|
| Section tabs, order, gating | page.tsx:17-52 | C (tab bar hidden for one section; "Face ID Approvals") | C (always shown, "Face Registration", pill tabs) |
| Header + pending total | SummaryCards | P (gradient banner, no total) | C (title, subtitle, real total badge) |
| Summary cards (4, labels, module-gated) | SummaryCards.tsx | P (5 cards incl. WFH, short labels, no gating) | C |
| Type tabs: order, labels, counts, module gating | _data.ts TYPE_TABS | P (order, "All", "WFH", "Expense") | C |
| Toolbar: search, status, dates, refresh | ApprovalsToolbar | P (hint, labels, "From/To") | C (+ sort); type dropdown skipped (tabs carry it) |
| **Sort** Employee / Submitted / Status | ApprovalsTable.tsx:45-70 | **M** | C |
| **Pagination** 10/page, Showing a–b of n | ApprovalsTable.tsx:10,75-79,176-205 | **M** (endless list) | C |
| Select page / **Select all n** / Clear | ApprovalsTable.tsx:100-118 | P (no page / all) | C |
| Row text per kind (labels, "3 Days", ₹ grouping, "Check-in Correction", original → requested, dates "5 Sept 2026") | _data.ts | P | C |
| Employee ID "—", department, type badge, status chip, submitted date | ApprovalsTable.tsx | P (no submitted date, tiny badges) | C |
| Level cue | drawer timeline | C ("Pending HR") | C — kept, a deliberate level-2 cue web lacks on the row |
| Single approve / reject, mandatory reject reason | ApprovalModal | C | C (+ name in title) |
| Success toasts per kind | TeamApprovalsSection.tsx:200-228 | P ("Approved.") | C |
| **Double-submit** | — | P (flag set after the dialog) | C (before any await, card and sheet) |
| Bulk dialog text, "Approve N", reject disabled until reason | BulkConfirmModal.tsx | P | C |
| Bulk toast text | TeamApprovalsSection.tsx:286-292 | P ("N updated successfully.") | C |
| Refresh after an action keeps rows on screen, no optimistic marking | web refetch | P (list blanked while reloading) | C |
| Detail sheet sections + row labels + timeline labels | RequestDetailDrawer.tsx | P | C (Leave Type / Duration / Dates / Total Days / LOP Days, Correction Type / Check-in / Check-out, Manager Approval / HR Approval, submitted date) |
| Detail sheet: success toast, double-tap guard | web toast | M | C |
| Attachments preview, separation / payslip / late special flows | drawer, modals | C | C |
| Empty state ("You're all caught up!"), filter-miss, loading, error + Retry | ta-empty | P | C |
| Attendance Approval (strings, picker, columns, daily breakdown) | AttendanceApprovalTab / EmployeeAttendanceRow | P | C (see §4) |
| Face Registration (badges, order, inline error, 403) | FaceRegistrationApprovalsTab | P | C |
| Leave Cancellations | LeaveCancellationsSection | C (strings) | C (+ double-tap guard) |
| Delegation | DelegationsSection | C (strings) | C (cards, 44 dp Revoke, stacked dates, guards) |
| Expense email-template picker | ApprovalModal.tsx | M | **M — HO-66, not built** (see §6) |
| "Open in Attendance Calendar" link | EmployeeAttendanceRow.tsx | M | M — HO-82 |

## 3. Redesign — component structure
`approvals_ui.dart` (new): `ApprovalsBadge`, `ApprovalsCard` (Stack accent, no intrinsic sizing), `ApprovalsEmpty`, `ApprovalsPager`.
Screen: title + pending badge (stacks under 400 dp / above 1.2× text) → pill `TabBar` (swipe between sections). Team tab = **one scroll view**:
header (summary cards, type tabs, toolbar) + page of cards + pager; only the bulk bar is pinned (bottom, thumb reach). Cards: avatar, name,
ID · department, type badge, kind lines, status + submitted date, 44 dp actions (side by side, stacked below 240 dp or above 1.3× text).
Premium Minimal, as My Profile / Company Info: 14 px cards, hairline borders, tinted pills, no gradients.

## 4. Secondary tabs (verified against web source)
Attendance Approval: web strings ("Select Payroll Period" + "Pay date:", "Loading pending approval cycles…", "Loading attendance data…",
"No payroll cycles pending your attendance approval.", "No attendance records found for this period.", "Add approval note (optional)…",
"Approving…", "L1 attendance approval recorded.", "Approval failed. Please try again."); picker always shown; all employee columns with
dimmed zeros and "n LOP" chip; daily breakdown header / "n day(s) flagged" / per-status tints / "—" hours; en-IN dates; first cycle still
auto-selected. Face: "Passed"/"Failed", "{n}%", Approve before Reject, inline error, 403 text. Not ported: calendar link (HO-82).

## 5. Responsive evidence (widget tests, `team_approvals_redesign_test.dart` + `secondary_tabs_*`)
320×568, 320×568 at 2.0×, 360×640 at 1.5×, 430×932 and 1000×800 with long names and reasons: no overflow while scrolling the whole
inbox; action buttons whole, ≥44 dp, stacked at 2.0×; summary cards one column on a narrow large-text screen; remarks dialog reachable
with the keyboard open at 320×568; same four sizes for each secondary tab. Two real defects found this way and fixed: the header badge
squeezed the title to 54 dp (858 dp tall) at 2.0× text; a card using IntrinsicHeight around a LayoutBuilder (asserts in debug).

## 6. Backend / web discrepancies (documented, nothing changed)
- **HO-79** expense remarks are collected by web (required to reject) but discarded by the backend (`expenses.py:215-216`).
- **HO-80** leave approval ignores `template_name` / `extra_context` (web's picker does nothing for leave); only expenses email
  (`expenses.py:222-224`) — **HO-66** (needs `GET /settings/email-templates/`, `POST …/resolve-context/`; not built, product decision).
- **HO-81** web bulk reject sends no reason for WFH/corrections and allows selecting rows you can't action.
- Attendance tab gate (web payroll.view vs backend 403) — unchanged from Task 77; `settings.edit` is used only as the codename it is.
Branch scoping and level rules come from the server (`can_approve` / `can_action`); the app filters nothing to hide a backend problem.

## 7. Tests and results
New: `team_approvals_redesign_test.dart` (50), `secondary_tabs_{attendance,face,cancellations,delegations}_test.dart` + harness (47).
Updated for web wording: `module_gating_test`, `admin_approvals_access_test`, `approvals_reachability_test`,
`payslip_query_resolution_test`, `late_justification_review_test`; `stat_card_layout_test` lost its Approvals-summary case (widget no
longer uses StatCardRow; covered by the new tests). 11 mutation runs on the inbox (bulk reject without a reason, generic success text,
sort ignored, pager past the end, tab order, module gating, header stacking, failed refresh dropping rows, single-action guard …) — all
caught; one survivor (double-tap) led to a stronger assertion. Full suite **3,231 passed**; `dart analyze`: the 7 pre-existing infos only.
Only files created/fully rewritten here were formatted (`-l 120`).

## 8. Files
Mine — new: `widgets/approvals_ui.dart`, `team_approvals_redesign_test.dart`. Rewritten: `approvals_list.dart`, `approvals_toolbar.dart`,
`approvals_summary_cards.dart`. Edited: `approvals_screen.dart`, `providers/approvals_providers.dart`, `approve_reject_dialog.dart`,
`approval_detail_sheet.dart`. Subagent (disjoint files): `attendance_approval_tab.dart`, `face_registration_approvals_tab.dart`,
`delegations_tab.dart`, `leave_cancellation_panel.dart`, `attendance_approval_providers.dart` (error text), new `secondary_tabs_*`.

## 9. Device / staging checklist (not done)
Pill tabs and swipe on a real phone; 320 dp and 2.0× text; each kind's row text beside web with real data; sort and paging with >10 real
requests; select page / all and a real bulk approve with a partial failure; single approve/reject per kind incl. L2; separation, late
justification, payslip resolve flows; expense decision with a real email template (HO-66); detail sheet attachments; Attendance Approval
with a real cycle (L1 and L2) and the daily breakdown; Face and Leave Cancellation queues; TalkBack on tabs, cards and dialogs; September-dated
requests against web ("Sept").

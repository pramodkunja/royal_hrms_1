# Task 101.1 — Approvals premium card-based UI

Web stays the functional source of truth; **My Profile (Task 99) is the visual reference.** Functionality from Task 101 is unchanged
(tab names/visibility, counts, search, filters, sort, paging, bulk selection, L1/L2, remarks, permissions, payloads, retry,
double-submit guards, server-confirmed updates).

## 1. What was reused from My Profile
| My Profile element (source) | Reused as |
|---|---|
| Section card: radius 14, hairline border, icon header + divider (`profile_widgets.dart` `ProfileSectionCard`) | `ApprovalsSection` = `ProfileSectionCard` directly (detail sheet, attendance, delegation form) |
| Label-over-value read-only field (`ProfileDisplayField`) + two-up that stacks when narrow / at large text (`ProfileTwoUp`) | `ApprovalsFacts` (cards and sheet use the widgets unchanged) |
| Coloured initials avatar, palette keyed by first letter (`MyProfileModel.avatarColor`, `profile_header.dart`) | `ApprovalsAvatar` (same 9 colours, same key) |
| Tinted employee-ID pill (`EMP-0042`) | `ApprovalsIdChip` |
| Icon + text meta line (branch / joined) | `ApprovalsMeta` |
| Icon tile in section headers | `ApprovalsIconBox`, `ApprovalsTypeRow` |
| Pill tab strip with icons (`ProfileTabStrip`) | section `TabBar` pills with icons (`ApprovalsTabLabel`) and type chips with icons + counts |
| Pinned bottom bar, elevated surface, Discard / Save (`_saveBar`) | `ApprovalsBulkActionBar` + `ApprovalsDecisionButtons` (Reject outlined / Approve solid primary, 44 dp) |
| Outlined input: radius 10, hairline, primary when focused (`ProfileField`) | remarks / bulk dialogs (`_fieldDecoration`), dialogs on the white surface |
| Theme tokens | `AppColors`, `AppTextStyles` only — no new colours except the existing avatar palette |

New file `approvals_ui.dart` holds only the thin composition (card with header / body / footer zones, badge, pager, empty state,
decision buttons); nothing re-styles what My Profile already provides.

## 2. All five tabs
- **Team Approvals:** `ApprovalsRequestCard` — header (avatar, name, ID pill, department, status badge, selection checkbox in selection
  mode) / body (request-type row with icon, label-over-value facts per kind, Reason) / footer (Submitted date, Details, Reject, Approve).
  Compact header (title + inline pending badge), 2×2 summary tiles, pill type tabs with icons and counts, search + wrapping pill filters
  (status, sort with an arrow icon, submitted from / to), results bar ("12 requests", **Select** / Done), pager, pinned bulk bar.
  Mobile **selection mode**: Select button or long-press; checkboxes appear, per-card actions hide, tapping a card toggles it, "Select all on
  this page" / "Select all n" / Clear, Done exits and clears. Detail sheet: handle, identity header, section cards (Request Details,
  Reason / Query, Attachments, Approval Timeline, Comments), circular timeline icons, pinned Reject / Approve.
- **Attendance Approval, Face Registration, Delegation, Leave Cancellations:** redesigned by a second engineer on the same shared
  components (details in `scratchpad/t101/secondary_visual.md`; summary in the doc's §4 table below).

| Tab | Card contents |
|---|---|
| Attendance Approval | payroll-period pills; cycle summary + manager sign-offs in section cards; each employee = card (avatar, ID chip, designation / department, "n LOP" badge) with 3-up facts (zeros dimmed) and an expandable Daily Breakdown; note + self-attest + Approve in a separate card |
| Face Registration | identity card (avatar, name, email, Pending) with Liveness / Score / Submitted facts and Approve → Reject (web's order) |
| Delegation | create form in a section card; each delegation = card (avatar, ID chip, "Your delegate" / "On behalf of", state badge) with Period / Requests / Reason and a full-width Revoke |
| Leave Cancellations | card (avatar, ID chip, "Cancellation pending") with leave-type row, Dates, Days, Reason and Reject / Approve cancellation |

## 3. Visual verification (no emulator — not authorised)
A render harness (`test/visual/shot_harness.dart`) draws the real widgets with the app's real **Poppins** (TTFs from the sibling
`royal_hrms/fonts/Poppins` folder, handed to google_fonts the way its own tests do) and the Material icon font, and writes PNGs — only with
`T1011_SHOTS=1`, so the normal suite writes nothing. Output: `docs/qa/client_handover_2026-11-19/evidence/t1011/`.
`00_my_profile_reference` · `before_01_team_approvals`, `before_04_reject_dialog` (the Task 101 look) · `01_team_approvals` ·
`02_team_selection_mode` · `03_detail_sheet` · `04_reject_dialog` · `05_bulk_reject_dialog` · `06_team_320dp_2x_text` ·
`07_attendance_approval` · `07b_attendance_daily_breakdown` · `08_face_registration` · `09_delegation` · `10_leave_cancellations`.
I looked at each against the reference (radius, spacing, type hierarchy, avatar, ID pill, label/value style, button styling).

## 4. Found by looking at the renders (and fixed)
Task 101 cards were three loose text lines with a washed-out initials circle, an always-visible checkbox and wide green buttons; the
toolbar took four stacked boxes. After the redesign, further passes fixed: "Work From Home" printed twice in the type row; the date
range wrapping inside a half-width column (now full-width); a dash-only ID pill on expenses (hidden when there is no id); the sort
arrow typed as a "↓" character that rendered as a missing-glyph box (now an icon); purple Material defaults on text buttons, outlined
buttons and checkboxes (now the app's primary navy — see HO-83); a lavender-tinted dialog with a purple underline field (now white
surface + outlined input); a bulk-bar spinner shown while only the dialog was open (now only while the batch runs); a long
single-column request-detail list (now paired).

## 5. Responsive results (widget tests)
320×568, 320×568 at 2.0×, 360×640 at 1.5×, 430×932, tablet 1000×800 with long names and reasons: no overflow while scrolling the whole
inbox; actions ≥ 44 dp and stacked at 2.0×; summary tiles one column when narrow; remarks dialog reachable with the keyboard open;
same sizes for the four secondary tabs. `06_team_320dp_2x_text.png` shows the 2.0× render: everything wraps, pills ellipsize, nothing clipped.

## 6. Limits and open items
- Renders are test renders, not device screenshots. The "→" in "original → requested" and date ranges draws as a box in them (Poppins has no
  arrow); real Android falls back to a system font — **verify on a device**.
- Screenshots are evidence, not golden comparisons: golden files would depend on the machine's fonts. The flag-gated tests regenerate them.
- HO-83: Material-default purple likely affects other screens; fix in the app theme. HO-84: Delegation form inputs still floating-label.
- Approve / Reject order: Team, detail sheet, bulk bar and cancellations put Reject then Approve (My Profile Discard / Save pattern); Face
  Registration keeps web's Approve → Reject.

## 7. Tests and results
Mine: `team_approvals_redesign_test.dart` 60 (+10: card structure, My Profile avatar palette, footer, selection mode, long press,
non-actionable rows, "Pending HR", primary colours, reload keeps rows) and `test/visual/*` (6 flag-gated renders). Subagent:
`test/visual/secondary_tabs_visual_test.dart` (7 + 5 flag-gated) and updates to `secondary_tabs_*`. Tests updated for the deliberate layout /
wording changes: `approvals_l2_pending`, `payslip_query_resolution`, `admin_approvals_access`, `approvals_reachability`,
`leave_cancellation`, `route_access_policy`. 6 mutation runs on the new behaviours (actions visible in selection mode, tap opens details,
long-press on a non-actionable card, Approve not primary, header divider, reload blanking the list) — one survivor led to a new test; all now caught.
Full suite **3,248 passed** (12 skipped = the flag-gated renders); `dart analyze`: the 7 pre-existing infos. Only files created or
fully rewritten were formatted (`-l 120`). No Git commands; no backend files touched.

## 8. Files
Mine — new: `widgets/approvals_ui.dart` additions, `test/visual/shot_harness.dart`, `approvals_visual_test.dart`,
`team_approvals_visual_test.dart`. Rewritten: `approvals_list.dart`, `approvals_toolbar.dart`, `approvals_summary_cards.dart`.
Edited: `approvals_screen.dart`, `providers/approvals_providers.dart` (facts, selection mode), `approve_reject_dialog.dart`,
`approval_detail_sheet.dart`. Subagent: the four secondary tab files + `secondary_tabs_visual_test.dart`.

## 9. Still required on a device / staging
Arrow glyph and Poppins rendering; the cards at 320 dp / 2.0× on a real phone; selection mode with a real long-press; bulk approve with a
partial failure; Attendance Approval with a real cycle; dark mode (if shipped); TalkBack on cards, tabs and dialogs.

# Task 101.3 — Approvals inbox UI rebuild

Scope: Flutter only (`mobile_app/lib/features/approvals`). No API, permission, approval-level or business-rule change. No Git, no device build, no production writes.

## New card architecture (`widgets/approvals_kit.dart`)
| Piece | Role |
|---|---|
| `ApprovalsCardShell` | Person row (avatar, bold name, "ID · department/branch"), status badge with a subtle "Submitted …" note beneath, body, hairline, footer. Stacks badge/note under the name on narrow or large-text screens. |
| `ApprovalsHeadline` / `ApprovalsChip` | Request-type icon, title and chips (duration, days, LOP, category) on one wrapping line. |
| `ApprovalsInfoRow`, `ApprovalsKeyFigure`, `ApprovalsQuote`, `ApprovalsFineprint` | Dates/schedule line, amount/score/hours figure, short reason, quiet meta text. No label-over-value fields. |
| `ApprovalsActionRow` | Details · Reject · Approve on one line **only when measured text fits**, otherwise Details above stacked ≥44dp buttons. |
| `ApprovalsEmptyState` (+ `.forError`) | One component, five kinds: `empty` (success look), `noMatch` (+ Clear filters), `error` (+ Retry), `offline` (+ Retry), `denied` (lock, no Retry). `ApprovalsLoading` for loading. |

Per-tab compositions: Team (one composition per request kind), Attendance Approval (cycle summary card, employee cards with stat pills, hours figure, breakdown inside card, separate sign-off card), Face Registration (score key figure + bar, Passed/Failed chip), Delegation (sentence cards, state badge, compact Revoke), Leave Cancellations (type headline, day chip, dates, quoted reason).

Toolbar: search + Filters button (active-count badge) + Refresh; removable chips (status always, sort/from/to when changed, Clear all). Filter sheet keeps every web filter: Status, Sort by (tap again toggles direction), Submitted from / to. Detail sheet uses a specification list.

## Evidence (`evidence/t1011/`)
Before: `before_01_team_approvals`, `before_04_reject_dialog`. After, Team: `01_team_approvals`, `01e` empty, `01f` no match, `01g` error, `01h` denied, `01i` filter sheet, `01j` filtered, `02` selection mode, `03` details, `04/05` dialogs, `06` 320dp @ 2× text.
Populated: `07` attendance (+`07b` breakdown), `08` face, `09` delegation, `10` cancellations. Empty: `07e`, `08e`, `09e`, `10e`; errors/denied `10x`, `08d`.
Rendered from real widgets with real Poppins (`T1011_SHOTS=1`); reviewed by eye, not just by test.

## Defects found by the work
- Action row overflowed at 412dp with wider fonts (threshold rule) → now measured. Caught by the existing suite.
- Sheet date tiles said "From/To"; web says "Submitted from/to" → fixed.

## Results
- `flutter test`: **3,260 passed, 24 skipped** (screenshot-only). `dart analyze`: 7 pre-existing infos, none new.
- New `approvals_inbox_states_test.dart` (10): five empty-state kinds, Clear filters/Retry recovery, error→kind mapping, chips, Clear all, one-line vs stacked action row. Existing approvals/leave/payslip assertions updated for the new composition.
- Mutation checks: forcing the one-line action row fails the suite; removing the Clear filters action fails the no-match test.
- Responsive: 320×568, 320 @ 2.0×, 360 @ 1.5×, 430×932, tablet 1000×800 — no overflow.

## Deliberate differences / notes
- Empty-state messages keep the web sentence (e.g. "No pending face registration requests."); titles are friendlier. The brief's example sentences ("New registration requests will appear here.") differ from web wording — say if you prefer them.
- Delegation list empties are small inline blocks (two full illustrations under the form drowned the page).
- Attendance period line keeps web's "→"; Poppins lacks that glyph so test renders show a box; device falls back to a system font — confirm on device.
- Only the five files created/fully rewritten were formatted.

## Device verification checklist
1. All five tabs populated and empty on a real phone; swipe between tabs.
2. Team: long-press → selection mode; bulk approve/reject with remarks; pagination.
3. Filter sheet: each filter, chips, Clear all, date pickers.
4. 320dp-class phone at largest font: cards, actions, filter sheet.
5. Offline and 403 states; Retry.
6. "→" glyph on the attendance period line.
7. Staging write checks (mocked tests only so far): approve/reject, bulk, face, delegation, cancellation.

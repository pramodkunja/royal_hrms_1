# Task 104.1 — Complete Assets page redesign + Announcements app-bar parity

Flutter only; backend/web read-only. No Git, no device build, no production writes. **Render + mocked-test evidence only — no device pass.**

## 1. App bar: the exact component reused
- **Announcements has no app bar of its own.** It is a child of `DashboardShell`, which draws **`AppTopBar`** (`lib/features/dashboard/presentation/widgets/app_top_bar.dart`): `AppColors.primary` fill, `kToolbarHeight` + status-bar inset, bold white `AppTextStyles.h4` title (scaled to fit), Search / theme / notifications bell / Sign out, light status-bar icons. Under it sits the `BlueHeroBanner` (rounded blue band).
- Assets is a **top-level route outside the shell** (`/settings/assets`), which is why it had the white `SettingsAppBar`. It now uses the **same `AppTopBar`**:
  - `AppTopBar` gained an optional `onBack` (the hamburger becomes a back arrow; `onMenuTap` is optional; defaults and look unchanged — Announcements untouched).
  - New `PushedAppTopBar` (`dashboard/presentation/widgets/pushed_app_top_bar.dart`) wires the same actions the shell wires (global search, theme toggle, sign-out → login) and the same visible-path publish the Settings bar did; Back pops, or goes to Settings on a direct link.
- Add/Edit form keeps `BlueAppBar` (same blue treatment, pushed detail screen).
- Compare: `evidence/t1041/before_t1041_00_announcements_reference.png` vs `t1041_01_main_populated.png`.

## 2. Before → after (whole page; `before_t1041_*` vs `t1041_*`)
| Area | Before | After |
|---|---|---|
| Header | White Settings bar, plain text line | Shell's blue `AppTopBar` + blue hero band (icon, intro line, **white search field**, **Filters** button with active-count badge) |
| Status filter | A dropdown | One-tap **pills** (All + web's 7 statuses), same `status` param |
| Other filters | Four inline inputs (two dropdowns, two text) | **Filter sheet** (Branch, Category, Asset Type) + **removable chips** + Clear all |
| Actions | Two outlined buttons under a text line | Pill buttons (Bulk Assign `assets.edit`, Bulk Import `assets.create`) |
| List rows | Bordered box: tag, name, grey caption lines, icon-only buttons | **Cards**: status-coloured accent edge and icon, bold name, tag pill, **chips** (category, type, branch, condition-toned), labelled actions (Maintenance / Complete / Edit / Delete, ≥44dp) |
| Result info | none | "N assets" from the API `count` |
| Paging | Text buttons | Pill Prev / "Page x of y" / Next |
| Empty / error | An icon and a line; error text + Retry | Distinct states: **empty** ("No assets yet"), **no match** (+ Clear filters), **error** ("Couldn't load assets" + Retry), **denied** (403, no Retry) |
| Add button | default FAB | Same FAB style as Announcements' "Post Announcement" |
| Wide screens | one stretched column | 1 / 2 / 3 columns (<600 / ≥600 / ≥900dp), centred ≤1120dp |
| Maintenance sheets, delete dialog | old floating-label inputs, grey dialog | label-above rounded inputs, friendly dates, handle, pill buttons (stack at large text), white dialog with icon |

## 3. Web → mobile parity (web `settings/assets/page.tsx`, `types/assets.ts`)
| Web feature | Mobile | Status |
|---|---|---|
| Table columns: tag, name, category (Other (…)), type (Other (…)), branch, status, condition | Same data on the card (no invented fields; assignee stays in Edit, as web) | Complete |
| Search tag/name/serial (resets to page 1) | Hero search, 350 ms debounce | Complete |
| Status select (7 + All) | Pills, same values | Complete |
| Category / Asset Type (free text), Branch select | Filter sheet + chips | Complete |
| Pagination Prev / Page x of y / Next | Pager | Complete |
| Bulk Assign (`assets.edit`), Bulk Import (`assets.create`) | Same gating, same sheets | Complete |
| Add Asset (`assets.create`) / Edit (`assets.edit`) | Full-screen form from Task 104 | Complete |
| Send to Maintenance (damaged), Complete Maintenance (under repair + active record) | Same conditions, same payloads | Complete |
| Delete (`assets.delete`), server refusals shown | Same | Complete |
| Quick-add Category / Type (in the form) | Same | Complete |
| Loading / failure / "No assets found." | Loading, error + Retry, same message under friendlier titles | Complete |
| **Tabs** | **None exist on the web Assets page** (only filters), so none were added | n/a |

## 4. Files changed
Modified: `app_top_bar.dart` (optional `onBack`), `assets_settings_screen.dart` (page, cards, sheets, dialog, helpers), `asset_catalogue.dart` (`AssetPage.count`), `approvals_kit.dart` (`ApprovalsEmptyState.forError(what:)`, default unchanged), tests `assets_settings_test.dart` (assertions moved to pills / filter sheet / chips / new keys; reformatted `-l 120`).
New: `pushed_app_top_bar.dart`, `test/features/settings/assets_page_redesign_test.dart` (28 tests), `test/visual/assets_page_visual_test.dart`, this doc.

## 5. Real defects found by the work
- Branch options weren't loaded when the filter sheet opened (only the old inline filter had watched the provider) → the page now watches it; regression test added.
- `IntrinsicHeight` over a `LayoutBuilder` crashed the cards → accent edge drawn with a `Stack`.

## 6. Evidence (`evidence/t1041/`, 18 before + 22 after)
Announcements reference; main populated; search; filter sheet; status + branch filters; empty; no match; error; denied; viewer (no actions); Add form; Edit form; 320dp @ 2×; 360; 430; 700 foldable; 1000 tablet; delete dialog; maintenance sheet; paging. All 22 "after" shots reviewed by me (before: reference + main viewed).
Notes: the FAB shows a dark ring in every render (test-render focus artefact, old and new); the Edit screen's "→" is a missing-glyph box in test renders (text pre-dates this task); the paging fixture's "20 assets" is the test API's count; at 320dp @ 2× the shell bar clips the title ("Ass…", existing HO-46 limit) and condition chips wrap to two lines.

## 7. Responsive (tests)
320×568, 360×800, 393×852, 430×932, 700×1000, 1000×800, 320 @ 2×, 360 @ 1.5×: scrolls end to end, no overflow, FAB present; columns 1/2/3 by width; very long name + 60-character tag wrap/ellipsize; keyboard over search on a 320×568 screen; actions ≥44dp.

## 8. Tests / analyzer
`flutter test`: **3,392 passed, 122 skipped** (screenshot-only). `dart analyze`: 7 pre-existing infos, none new. All earlier Assets tests (list, payloads, permissions, maintenance, delete, form) pass. Mutation checks: putting the white `SettingsAppBar` back fails 2 tests; dropping the branch-options watch fails 2.

## 9. Backend / decisions
No backend dependency. The list API also returns the active assignee, but web's table doesn't show it, so the card doesn't either — say if you want "Assigned to <name>" on assigned cards.

## 10. Device QA
1. Assets on a phone: bar identical to Announcements (back arrow instead of menu; search, theme, bell, sign-out all work from here), hero, pills scrolling, filter sheet, chips, cards.
2. Real data: long names/tags, "Other (…)" categories, each status colour.
3. Actions on staging: Maintenance, Complete, Edit, Delete, Bulk Assign/Import, Add.
4. Back arrow lands on Settings; system back; sign-out from this screen.
5. Offline → error + Retry; 403 account → denied.
6. Largest font on a small phone; landscape; tablet/foldable columns.

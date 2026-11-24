# Task 107 — Departments & Designations: dropdown overflow and responsive fix

Evidence is render/mocked-API only (no device or emulator pass, no production calls). Screenshots: `evidence/t107/before_t107_*` and `t107_*`.

## 1. Root cause (reproduced before changing anything)
`desig_form_sheet.dart` used `DropdownButtonFormField<int>` **without `isExpanded`**. The selected value is then laid out at its natural width, so a long department name overflowed the field by 442px (RenderFlex, `before_t107_d_02`). The popup menu was fine (it wraps) — only the selected-value rendering and the surrounding Row overflowed. Contributing issues found while testing:
- Departments-request error state rendered nothing (`SizedBox.shrink`), so the form could only fail with "Department is required".
- The form borrowed the screen's `ref`, so it would not rebuild on a retry.
- Server errors went to a snackbar that sits behind the dialog scrim.

## 2. Fix
New `department_select_field.dart`: the field shows the **whole** department name (wraps), and tapping opens a searchable, scrollable bottom sheet (max height above the keyboard, ≥52dp rows, inactive marker, current selection ticked). Loading, empty ("No departments available. Add a department first.") and failed (Retry) states are handled in the field. The form keeps the chosen department and typed name on validation/server failure and sends `{name, department: <id>, is_active}`. Edit preselects the designation's department.

## 3. Other confirmed issues fixed (`dept_list_item.dart`, `departments_screen.dart`, form sheets)
- Screen header/stats/search sat in a fixed Column that overflowed at 320dp@2× → one scrolling list.
- Department name and designation name were ellipsized (`maxLines: 1`) → now wrap fully; status moves under the name at large text.
- Designation banner Row, count chips and badges overflowed at 2× → Wrap/Flexible.
- Edit/Delete icons were ~32dp → 44dp, keyed; they move under the details at large text/narrow cards.
- Dialog header broke "Designation" mid-word at 2× and the dialog margin left ~400px → compact header (icon/subtitle hidden at large text), tighter margins on short screens.
- Server errors in the Department and Designation dialogs now show inline (as web's `saveError` alert).
- Designation panel hard-coded a light background → theme-aware.

## 4. Web parity (read-only: `app/dashboard/settings/departments/page.tsx`)
Required fields: name (web: "Designation name is required."; mobile keeps its existing wording). `settings.edit` gates add/edit/delete — unchanged. Create posts `{name, is_active, department}`, edit PUTs name/is_active, then both lists refresh; delete asks for confirmation; server messages are shown inline.
**Documented difference (kept, existing mobile behaviour):** web's designation modal has **no Department selector** — it uses the department selected in the list and the edit PUT never sends a department. Mobile has always exposed a selector (preselected) and sends `department`. Not removed (would change existing behaviour); flagged for a product decision. Duplicate-name handling is whatever the backend returns (shown as received).

## 5. Files
Lib: `departments/widgets/{department_select_field (new),desig_form_sheet,dept_form_sheet,dept_list_item}.dart`, `departments/departments_screen.dart`. Existing `p0_permission_parity_test.dart` untouched and passing (key `dept-actions-<id>` preserved).
Tests: `test/features/settings/departments_designations_test.dart` (new, 36), harness `test/visual/departments_visual_test.dart` (new, 10 shots).

## 6. Results
Responsive matrix 320×568, 360×800, 393×852, 430×932, 600, 800, 1000 wide, plus 1.5×/2× text — add dialog, selector, edit, no overflow; dark theme; keyboard-open at 320×568. Full `flutter test`: 3653 passed, 0 failed. `dart analyze`: 7 infos (pre-existing `curly_braces`, unchanged baseline).

## 7. Remaining
- No device/emulator pass; keyboard behaviour is widget-test only.
- Shared `StatCard` still ellipsizes "Departments"/"Designations" labels at 1× (app-wide widget, not changed).
- Departments screen still uses `SettingsAppBar`, not the Announcements-style `AppTopBar` (not changed; navigation pattern decision).
- Product decision: keep or drop the mobile-only Department selector (web has none).

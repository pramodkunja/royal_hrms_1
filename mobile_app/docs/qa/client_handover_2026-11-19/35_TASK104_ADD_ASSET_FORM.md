# Task 104 — Add / Edit Asset form: premium redesign, strict web parity

Flutter only; backend/web read-only. No Git, no device build, no production writes. **Render + mocked-test evidence only — no device pass.**

## 1. Problems found in the old form (screenshots `before_t104_*`)
- A modal bottom sheet over the Assets list: cramped, the list showing behind, no app bar, no title bar match with the rest of the app.
- 17 fields in one undifferentiated column; no grouping, very long scroll.
- Labels half-hidden on the border (floating label overlapping the outline), inconsistent when empty vs filled; default sharp Material outline, not the app's rounded style.
- Validation text truncated ("…before the start d…"); only one line of error allowed.
- Category / Asset Type / Branch lists silently empty while loading or after a failed load (no loading, empty or error state).
- Dates showed "—" and ISO text; no friendly format.
- Save / Cancel scrolled with the sheet; Save had no distinct "saving" look; the sheet resized with the keyboard.
- After a refused save a field error far down the form could be off screen.

## 2. Web → mobile field parity (web `settings/assets/page.tsx`, `types/assets.ts`; backend `apps/assets/serializers.py` read-only)
| Field | Web | Mobile | Notes |
|---|---|---|---|
| Asset Tag | text, **required**, placeholder e.g. LAP-001 | same | server: required, unique (case-insensitive) |
| Asset Name | text, **required** | same | |
| Category | select **required** + "+" quick-add | same (+ gated by `assets.create`) | change clears type |
| Other category | text when Category = Other | same | server requires it |
| Asset Type | select **required**, disabled until a category, + "+" | same | |
| Other asset type | text when Type = Other | same | |
| Brand / Model | text | text (side by side) | |
| Serial Number | text, sent as null when blank | same | server: unique |
| Branch | select **required** (branch names) | same | |
| Purchase Date | date, null when blank | date picker, ISO payload, shown "13 Nov 2026" | |
| Purchase Price | number min 0 step 0.01, null when blank | decimal keyboard, sent as typed, **no local limits** | server validates |
| Vendor | text | text | |
| Condition | select, default `new` | same | |
| Warranty Start / End | date, null when blank | same | server: end ≥ start |
| Description / Remarks | textarea | multi-line | |
| Footer | Cancel / "Create Asset" ("Save Changes" on edit) | same labels | |
| Validation | **none on the client**, server messages (banner + per field) | **none on the device**; banner + per-field messages; input kept | tested |
| Edit extras | read-only Assignment Details | same, restyled | |
Payload, defaults and null handling unchanged (existing `assetPayload` rules + tests).

## 3. What changed (`lib/features/settings/presentation/assets/assets_settings_screen.dart`)
- **Full-screen route** (`AssetFormScreen`, replaces the sheet; pushed from Add Asset / the edit pencil; pops `true` only after the server confirmed, then the list refetches).
- **Blue app bar** (`BlueAppBar`): "Add Asset" / "Edit: <tag>".
- **Section cards** (`ProfileSectionCard`, same as My Profile / Company Info): Asset Information, Classification, Condition & Location, Purchase Details, Warranty, Notes. Brand/Model, Purchase Date/Price, Warranty Start/End pair up (`ProfileTwoUp` stacks when narrow or text is large).
- **Fields:** label above (red `*` for the five required), rounded 10dp outlined inputs, readable hints, errors wrap to 4 lines.
- **Dropdowns:** keep the selected value on one line with an ellipsis; menu max height; loading spinner + "Loading…"; empty note ("No branches available."); failure line "Couldn't load … options." with Retry (providers no longer swallow load errors — the Assets list filters still just offer none).
- **Pinned action bar:** Cancel (secondary) + Create Asset / Save Changes (primary), ≥48dp, stacks at large text, hides only when the keyboard leaves < 480dp of height, respects safe area. Saving: blue button with spinner, fields locked, a second tap does nothing, back is blocked.
- **Refused save:** the first refused field (or the banner) is scrolled into view (non-lazy scroll view so far fields exist); nothing is cleared.
- Tablet: centred 640dp column. Quick-add dialog and Assignment Details restyled to match.

## 4. Reused components
`BlueAppBar`, `ProfileSectionCard`, `ProfileTwoUp`, `formatEnInDate`, theme tokens only. New colours: none.

## 5. Files
Modified: `assets_settings_screen.dart`; tests `assets_settings_test.dart` (added a hold-write hook, load-failure hooks, and one extra settle in `tapKey` for the page transition; reformatted with `dart format -l 120`). New: `test/features/settings/asset_form_redesign_test.dart` (29 tests), `test/visual/asset_form_visual_test.dart`, this doc.

## 6. Evidence (`evidence/t104/`, 13 before + 13 after)
Empty, partial, full, dropdown open, real date picker, validation errors, server error, saving, 320dp @ 2×, 320dp @ 2× keyboard, tablet 1000, edit, phone keyboard. All 13 "after" shots reviewed by me; before shots viewed: 03, 06 (the others generated, not individually opened).
Notes: the edit screen's "→" renders as a box in test renders (Poppins lacks it; text pre-dates this task); in keyboard shots the keyboard area is blank (simulated inset); at 320dp @ 2× dropdown placeholders truncate ("Select cat…") beside the + button.

## 7. Responsive (tests)
320×568, 360×800, 393×852, 430×932, 700×1000, 1000×800, 320 @ 2×, 360 @ 1.5×: scroll end to end, no overflow, Save ≥48dp and on screen; 2× text stacks the actions; tablet is a centred column; keyboard on a 320×568 screen hides the bar and it returns; a very long category name causes no overflow.

## 8. Tests / analyzer
`flutter test`: **3,364 passed, 102 skipped** (screenshot-only). `dart analyze`: 7 pre-existing infos, none new. New tests cover: every field present, exactly five `*`, section grouping, edit prefill/title/order, nothing validated locally (empty save posts), server field + banner errors with input kept, scroll-to-error, date ISO/format/clear→null, decimal keyboard and payload, type disabled until category and cleared on change, "Other" fields, failed/empty pick lists with Retry, `assets.create` gating of "+", success closes and refreshes, saving state + single POST, refusal keeps data and re-enables Save, Cancel and back send nothing. Mutation checks: removing the double-save guard, and adding a local "tag required" check, each fail tests. Existing Assets tests (24) pass.

## 9. Backend notes
No discrepancy found: required fields, uniqueness, warranty-order and "Other" rules match what the web relies on. Category/type/branch list failures are not retried automatically.

## 10. Device checks
1. Add Asset on a real phone: blue bar, sections, keyboard with every field type (decimal price), pinned bar above the keyboard.
2. Dropdown menus with real categories/branches (long names), the + quick-add dialogs.
3. Real date picker for all three dates; clear buttons.
4. Staging create/edit: success returns to the list and shows the asset; duplicate tag, bad warranty order, negative price show field errors in place and scroll to the first.
5. Airplane mode: pick lists show Retry; Save shows the real network error and keeps the data.
6. Largest font on a small phone; landscape.
7. Back arrow / system back while saving (blocked) and after a refusal (leaves without saving).
Decision for you: the Assets list screen itself still uses the white `SettingsAppBar` (same as the other Settings screens) — switch it to blue?

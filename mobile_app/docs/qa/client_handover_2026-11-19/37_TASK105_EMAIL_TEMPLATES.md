# Task 105 — Email Templates: full page redesign, preview, editor, web parity

Flutter only; backend/web read-only. No Git, no device build, no production writes. **Render + mocked-test evidence only — no device pass; the HTML preview's WebView has never run (it cannot in widget tests).**

## 1. Web feature inventory (`settings/email-templates/page.tsx`, `_data.ts`, `EditTemplateModal.tsx`, `lib/emailPreview.ts`; backend `apps/accounts/views.py` read-only)
- Header: Back, **Add Template**. Cards: **Email Header & Footer** (preview of the logo/name header and website | address footer; inline edit of logo, company name, website, phone, address, city, state → `PATCH /settings/company/`), **Automatic Birthday Wishes** (enable switch + 4 texts → `PATCH /birthdays/settings/`).
- **Search** (name, type, description) · templates **grouped by type** (document, notification, reminder, wish, others) from `GET /settings/email-templates/` (paged on the server; web reads page 1 only).
- Card: icon, display name, description, subject, **Preview** (eye), **Edit** (pencil), **Active switch** (`PATCH {is_active}`).
- **Preview**: sandboxed iframe (`sandbox="allow-same-origin"`, no scripts) of `buildEmailPreview(body, company)` = branded wrapper + the template body.
- **Add/Edit modal**: display name, slug, category (+ create category), subject, rich-text body (contentEditable toolbar: bold, italic, underline, strikethrough, lists, align, link/unlink, image, clear format), variables, attachments. Edit sends subject/body/variables(+files).
- Not on the web page: delete (backend supports it for custom templates; built-in refused), category filter, pagination UI.

## 2. Parity matrix
| Web | Mobile now | Status |
|---|---|---|
| Header + footer branding card, inline edit | Same card, restyled (Header / Footer samples + Edit) and **an error + Retry when the load fails** (was silently hidden) | Complete |
| Birthday card (status, text, edit) | Same, restyled | Complete |
| Search, grouping, order | Search (name, subject, type, description — superset), same groups/order; **type pills with counts** as a view filter (mobile convenience, no API) | Complete (+) |
| Card actions Preview / Edit / Active switch | Same, labelled buttons, switch with accessible label | Complete |
| Delete | Custom templates only, confirm first (backend-supported; not on web's page) | Mobile-only, API-backed |
| Preview HTML in sandbox | **Real HTML in a JS-off WebView** with CSP, navigation blocked, responsive CSS; Text toggle | Complete in code; **device-unverified** |
| `{placeholders}` shown as typed | Same (web never substitutes: its `preview` key isn't in the backend's GET response) | Complete |
| Add/Edit modal fields + validation + payloads | Full-screen form, same fields/validation/notifier calls | Complete |
| Rich-text editor (align, unlink, image, clear format) | Raw-HTML field with bold/italic/underline/strike/bullets/numbered/link only | **Gap — not full editor parity** |
| Edit: web hides name/category | Mobile shows them locked; keeps an Active switch in the editor | Known difference |
| Attachments removed on Save | Mobile uploads/removes immediately (confirm before delete) | Known difference |
| Slug auto-generation | Fixed to web `toSlug` (keeps `_`, must start with a letter) | **Fixed this task** |
| Edit payload (multipart: subject/body/variables) | Mobile PATCHes JSON incl. display_name/template_type/is_active | Unconfirmed that the backend ignores extras — backend check |

## 3. Problems with the old UI (`before_t105_*`)
White Settings bar; branding card as a blue banner and a cramped birthday card (title cut: "Automatic B…"); clipped stat cards; tall template rows with a footer strip of badges + switch + monospace subject; overflow at 320dp @ 2× in the card footer; preview was **tag-stripped plain text**; editor was a tall dialog; the branding card vanished on error.

## 4. Redesign (all under `lib/features/settings/presentation/email_templates/`)
- **App bar:** the shell's `AppTopBar` via `PushedAppTopBar` (same component as Announcements and Assets), back to Settings. Hero band: intro line + search.
- **Page:** type pills with counts → summary (Total / Active / Custom, counted from the loaded list) → **Email settings** (branding + birthday, side by side from 600dp) → templates by type with section headers → cards. While searching/filtering the summary and settings step aside so results come first; "N of M templates".
- **Card** (`template_card.dart`): type-coloured accent edge and icon (theme tokens only), name, Active/Inactive word + dot, Built-in/Custom chip, description, tinted **Subject** block, labelled Preview / Edit / Delete (≥44dp), Active switch. 1 / 2 / 3 columns (<600 / ≥600 / ≥900dp).
- **States:** loading; empty (+ Add Template); no match (+ Clear filters); error "Couldn't load templates" (+ Retry); denied (403, no Retry).
- **Preview** (`template_preview_sheet.dart` → `TemplatePreviewScreen`, `email_preview_html.dart`): blue-bar full screen, metadata (name, category, status, wrapping subject, variable chips, attachments), **Rendered | Text** toggle, pinned Edit Template / Close. HTML = web's wrapper + viewport meta + CSP (no script/frame/form/external CSS) + responsive CSS; company fields HTML-escaped; logo only http(s)/data:image.
- **Editor** (`template_editor_sheet.dart` → `TemplateEditorScreen`): full-screen, section cards (Basics, Message, Variables, Attachments, Status), labels above inputs, pinned Cancel/Save bar (stacks at large text, hidden only under a short keyboard), saving state, scroll to the first problem, input kept on server failure. Toolbar gained strikethrough and numbered list. Fixed: the category dropdown kept the "create" row when a new category was refused.
- **Navigation:** Add/Edit/Preview are pushed full screens; Preview → "Edit Template" opens the editor; a confirmed save returns with "Email template created/updated".

## 5. Evidence (`evidence/t105/`)
Before: page ×11, preview dialog, editor add/edit dialogs. After page: populated, top viewport, search match, no match, empty, error, denied, 320dp @ 2×, tablet 1000, foldable 700, **dark**. After preview (**stand-in view — the email itself is not drawn**): standard, Text mode, long subject, 320dp @ 2×, tablet. After editor: empty, partly filled, fully filled, category dropdown, validation errors, server error, saving, keyboard, 320dp @ 2×, tablet, edit.
Reviewed by me: the page shots (all), preview 01/03/04, editor 10b, before preview. The subagent reviewed the rest of its set; I did not open: editor 11, 14, 17/17b, 18/18b, 19, 20/20b, preview 02/04b/05 (04b is stale for the tight-screen details cap).

## 6. Responsive (tests)
Page: 320×568, 360×800, 393×852, 430×932, 700×1000, 1000×800, 320 @ 2×, 360 @ 1.5× with a very long name/description/subject — no overflow; columns by width. Preview and editor: 6 sizes × 3 text scales, keyboard on a short screen. Dark mode checked.

## 7. Tests / analyzer
`flutter test`: **3,538 passed, 155 skipped** (screenshot-only). `dart analyze`: 7 pre-existing infos, none new. New: `email_templates_page_redesign_test.dart` (page, 32 tests), `email_template_preview_test.dart` (45), `email_template_editor_test.dart` (62), shared fakes. Existing paging/birthday tests pass; one assertion deliberately updated (title "Email Header & Footer", web wording; birthday card is beside/below it). Mutation checks: white `SettingsAppBar` back; settings not stepping aside; editor edit-save popping without `true`; removing the `<` escape in the company HTML — each failed tests.

## 8. Remaining / needs a device
1. **The WebView**: that real HTML renders, JavaScript is off, the CSP holds, links/navigation are blocked, wide tables/long URLs fit — on a phone, with a real template and a logo.
2. Editor on a phone: toolbar, long body, attachments (real file picker), keyboard.
3. Branding editor and birthday editor were only restyled at the card level; their dialogs/sheets keep the old look (not part of this redesign).
4. Staging writes: toggle, create, edit, delete a custom template, attachments.
5. Backend: confirm the PATCH with extra fields (`display_name`, `template_type`, `is_active`) is accepted/ignored; web's preview call reads a `preview` key the backend never returns (web quirk, mirrored).
6. Rich-text parity (alignment, image, unlink, clear format) is **not** implemented.

# Task 99 — My Profile redesign + web parity

Web source: `web_frontend_backend/frontend/app/dashboard/profile/ProfileClient.tsx`, `ChangePasswordForm.tsx`,
`components/ProfilePhotoModal.tsx`. Flutter: `mobile_app/lib/features/profile/`. Self-service only — no HR-only controls added.

## Parity matrix (C = complete, P = partial, M = missing, **before → after**)

| Area | Web | Before | After |
|---|---|---|---|
| Identity banner: photo/initials, name, designation · department, ID chip, branch, joined date | yes | P (name + role only) | C (`ProfileHeaderCard`) |
| Reporting Manager / Approver / Assigned HR in the banner | yes | M | C |
| Photo change / remove, JPG-PNG 100–200 KB | yes | P (own wording) | C (web wording: "Image must be between 100 KB and 200 KB (selected file is N KB).", "Only JPG, JPEG, and PNG files are allowed.") |
| Section navigation (7 tabs, Face ID hidden when feature off) | yes | M (one long scroll) | C (pinned tab strip) |
| Field-visibility config applied to built-in fields (steps 0–3) | yes | **M** | C (DOB, gender, marital, blood group, father's name, both addresses, education ×8, bank ×6, emergency ×4) |
| Labels / order / placeholders (Qualification, Previous Role, Account Holder, Name/Phone/Email, …) | yes | P | C |
| Date format "5 Nov 2026" | yes | P ("Nov 5, 2026") | C |
| Save only on Personal tab; success "Profile updated successfully." | yes | P | C |
| Bank: last-4 masking, "Contact HR to update", read-only | yes | C | C (kept) |
| Custom fields (text/file) per step, Emergency editable only | yes | C | C (kept) |
| Work Info incl. onboarding/assessment badges, notice period, separation card | yes | C | C (own tab) |
| Documents view/upload/replace | yes | C | C (own tab, unchanged) |
| Face ID register/update/status | yes | C | C (own tab; badge/button no longer overflow) |
| Change password: web labels/messages, show/hide eye | yes | P (own messages, no eye) | C |
| Loading / error + retry | yes | C | C |

**Missing features found (all closed):** built-in field visibility; reporting people in header; tabbed sections;
password show/hide; web labels/messages/date format; photo message wording.

**Deliberate differences (documented):** Discard button (asked for in Task 99; web has none); the server's own
error text is shown on a failed save (web shows a generic line); mobile keeps pre-save phone/email checks that web
lacks (they only prevent a round-trip 400); Save bar hides while the keyboard is open; after a password change the
app signs out (backend blacklists the session) — web redirects likewise.

## Redesign
Premium-minimal: plain label-over-value fields (no boxed look-alike inputs), 14-px light cards, subtle icons, one
primary action. Responsive: field pairs stack when narrower than 300 dp or text > 1.3×; content capped at 760 dp
(tablets); tab strip pinned and horizontally scrollable; long values wrap; semantics on fields, tabs, photo.

## Evidence (widget tests; no screenshots)
`test/features/profile/my_profile_redesign_test.dart` — 40 tests: helpers, header, tabs, labels/values, visibility,
save/discard payloads, security tab, photo rules + mock upload/remove, error/retry, 320×568, 2.0× text, 1.5× text,
tablet, keyboard-open. Measured geometry (stacked vs side-by-side, ≤760 width, Save bar inside the screen) replaces
screenshots: test fonts render as blocks, so a PNG would not show the real design.
Mutation checks (8) all caught: full account number, ignored bank-name visibility (initially survived → test added),
label drift, always-enabled Discard, never-stack, no photo minimum, Save bar with keyboard.

## Found while testing (fixed)
- Tab strip fell below the fold on a 320-px phone with a long name → made it a pinned sliver.
- `FaceStatusBadge` Row overflowed at 2× text (shared widget; label now `Flexible`). Face section: badge stacked
  under the status text; capture button label wraps.

## Results
Full suite **3,047 passed** (3,007 + 40; 2 existing tests updated for the tabs/Work section); `dart analyze`: 7
pre-existing infos, none new. Formatting: only files this task created/rewrote were formatted (`-l 120`).

## Files
New: `profile_header.dart`, `test/features/profile/my_profile_redesign_test.dart`, this doc.
Changed: `profile_screen.dart`, `profile_sections.dart`, `profile_widgets.dart`, `profile_face_id_section.dart`,
`facial_recognition/.../face_status_badge.dart`, tests `profile_work_info_test.dart`, `profile_documents_section_test.dart`.

## Backend dependencies
None. (`PATCH /employees/me/`, `/employees/me/photo/`, field-config endpoints unchanged.)

## Still required on a device / staging (not done)
Real-phone visual pass (small/large phones, tablet, dark mode if any); camera capture + gallery picker; photo
upload/remove against a test tenant; field-visibility with a real hidden-field config; password change + forced
sign-out; Face ID capture flow; TalkBack on tabs/fields.

## Process notes
One read-only `git status --short` was run by mistake at the end of the mutation script (output discarded) —
Task 99 said no Git commands.

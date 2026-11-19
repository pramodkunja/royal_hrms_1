# Task 100.1 — Company Info final polish

## 1. SVG logo preview
- **Dependency:** Flutter 3.44.8 / Dart ≥3.5. `flutter_svg ^2.3.0` was already in the local pub cache; `flutter pub add --offline`
  added exactly four packages (`flutter_svg 2.3.0`, `vector_graphics 1.2.3`, `vector_graphics_codec 1.1.13`,
  `vector_graphics_compiler 1.3.0`) and **changed no existing version**. Compatible — no upgrade forced.
- **Saved logo:** an `.svg` link (path-based, query/fragment ignored) is fetched **once** with the app's login-free file
  client (`employeeDocumentExternalDioProvider` — no auth header, no cookies), https only, ≤5 MB, content sniffed for an
  `<svg>` root before parsing, bytes held in memory only, link never logged or shown. Anything else uses the unchanged
  `Image.network` (JPEG/PNG/WebP): no second request, no change.
- **Picked logo:** `SvgPicture.file` for `.svg`, `Image.file` otherwise.
- **Failure:** malformed, empty, unsupported, oversized, non-https, unreachable → the logo icon (no exception).
  Elements flutter_svg doesn't support (scripts, foreignObject) are ignored; external references are not fetched.
- Upload contract unchanged (multipart `logo` / `remove_logo`). Files: `company_logo_svg.dart` (new),
  `widgets/company_widgets.dart` (`CompanyLogoView`), `pubspec.yaml` / `pubspec.lock`.
- Not covered: the payslip PDF logo (`isEmbeddableImage` excludes SVG) — separate feature, not changed.

## 2. HO-76 date audit
Method: for each of the 48 mobile files with a month table, a read-only reviewer found the web screen and its formatter;
I re-read every cited web line for the 35 corrections (en-IN / en-GB → "Sept", confirmed with Node Intl).
- **Corrected ("Sep" → "Sept", one token each, no reformatting):** approvals ×2, assessments ×2, attendance ×3, candidate
  review, dashboards ×3 (admin, employee card dates, manager), documents ×2, email log, employees ×4 (promotions, assets +
  salary/payroll dates, leave tab ×2, salary month), expenses list, interview list ×2, leave ×6 (incl. Apply Leave's date
  field and summary, verified by web's en-IN caption of the same value), my-requests ×2, payslip queries, referrals,
  assessment config, SMTP. Also `_fmtMonthYear` (attendance approval) now writes the full month, as web `fmtMonth`.
- **Left as "Sep" on purpose (18 files):** web writes "Sep" (holiday calendar, separation, WFH ×3, employee profile ×3);
  native date/month inputs (late-arrival card, expense form, add-employee); no web counterpart (assessment item row,
  employee month picker, dashboard today label, branches); dead code (payslip `_shortDate`); locale-less web call
  (leave credits); debug demo. A test locks this list.
- **Found, not fixed (not September):** day zero-padding; am/pm case and 24h-vs-12h (activity log, payslip queries);
  comma after the month in weekday forms ("Sat, 05 Sept, 2026"); WFH/separation use "Sep 5, 2026" order on web; dashboard
  today label on the HR console is "Saturday, 5 September 2026"; `kConsoleMonthNames` is shared with the HR dashboard.

## 3. Tests (28 new)
`test/features/settings/company_logo_svg_test.dart` (21): URL/content recognition, loader (https-only, no credentials,
signature not sent in headers, non-SVG / error / oversize / exactly-5 MB), valid, failed, malformed and unsupported SVG,
raster unchanged and loader untouched, picked SVG/raster files, invalid/empty/junk SVG files, wide SVG contained, 320 px at
2.0×, screen: header preview, Remove (SVG and raster) → `remove_logo=true`, picked SVG uploaded as `logo`, broken saved SVG,
tablet. `test/shared/date_format_sept_parity_test.dart` (7): public helpers against Node-derived strings, other months
unchanged, en-US screen keeps "Sep", audit-lock allow-list. 9 mutants (http allowed, no sniff, no cap, loose URL, SVG as
raster, two helpers reverted, en-US changed, allow-list drift) all caught. Existing tests updated: one payroll expectation
("28 Sept 2026").

## 4. Results
Full suite **3,137 passed** (3,109 + 28). `dart analyze`: 7 pre-existing infos, none new. Only the four files created in this
task were formatted.

## 5. Remaining dependencies / device checks
No backend dependency. On a device: an SVG logo from a real tenant (header render, tablet, 2.0× text); a signed-link
SVG that expires; a tenant whose SVG URL has no `.svg` extension (would show the icon — path-based detection); picking
SVG/JPEG/PNG/WebP from the Android picker; September-dated records on a few screens against web side by side; shape
differences listed in §2 if parity is wanted.

## 6. Process notes
No Git commands were run (including from scripts). `pubspec.yaml` / `pubspec.lock` were backed up to the scratchpad before
`pub add` and diffed afterwards (additive only).

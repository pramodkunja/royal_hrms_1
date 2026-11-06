# Final Release Readiness — Royal HRMS Android update

**For:** the release owner, the Play Console owner and the company's administrator.
**Assessed:** 2026-11-06 (updated from the 2026-11-05 assessment). **Submission deadline: 11 November 2026.**
**Related documents (this folder):** `INTERNAL_TEST_CHECKLIST.md`, `PLAY_STORE_AND_CONSOLE_CHECKLIST.md`, `PRIVACY_INVENTORY_AND_POLICY_DRAFT.md`, `DATA_SAFETY_WORKSHEET.md`.

## Release decision

## ❌ Not ready — blockers remain

The code for every planned feature is finished and covered by automated tests, but the update cannot be submitted yet:
- the **live version code and upload certificate have not been checked** in Play Console;
- the current work is **not yet committed**, so no release build can be traced to a commit;
- there is **no current signed release build** (AAB: **NOT DONE**);
- **nothing has been tested signed in or on a real phone**;
- the **privacy policy is not published**;
- the **Data Safety answers are not confirmed**;
- **no reviewer or test account** exists;
- submission to Google Play: **NOT DONE**.

Most of these depend on the company, the administrator or the Play Console owner, not on further development.

## 1. Application identity

| Item | Value | Status |
|---|---|---|
| App name | Royal HRMS | Verified (app label) |
| Application ID / namespace | `com.royalhrms.app` / `com.royalhrms.app` | Verified (build file, 2026-11-06) |
| Store presence | Reported as already published; this is an **update** to the existing listing | Requires confirmation (Console not inspected). Do not create a new listing or change the application ID. |
| Production API | `https://royalhrms.com/api/` (forced in release builds; local URLs are used only in debug builds) | Verified (code, 2026-11-06) |
| Cleartext traffic | No `usesCleartextTraffic` or network-security override, so Android 9+ blocks cleartext | Verified (manifest) |

## 2. Release version

| Item | Value | Status |
|---|---|---|
| Version in the source | 1.0.0 (versionCode 6) | Verified (`pubspec.yaml`, 2026-11-06) |
| Version code to ship | 6 is **not** assumed to be acceptable. An AAB with versionCode 6 was built on 2026-11-04; if that or any bundle with code 6 or above was ever uploaded, the version must be raised (for example `1.0.1+7`) before building. | **Requires confirmation** in Play Console → App bundle explorer, before building |
| Upload certificate | Project upload certificate SHA-256 begins `C3:64:02` (full value in `PLAY_STORE_AND_CONSOLE_CHECKLIST.md`) | **Requires confirmation** that it matches the upload key registered in Play (Setup → App signing) |
| Target / min / compile SDK | 36 / 24 / 36 (Flutter 3.44.8 defaults) | Verified from the build configuration; re-check on the new AAB |

## 3. Completed development

| Work | Scope |
|---|---|
| Phases 1–10 | Original P0/P1 parity work, release hardening (signing, permissions, version), release documents |
| Phases 11.1–11.8 | Announcements pagination; Candidate Review onboarding approval; attendance policy fields; profile documents (upload, replace, secure in-app viewing and cleanup); employee notice-period card; custom file field messages; attendance month navigation |
| HR Employee Detail | Notice period shown; Reset Password (`employees.edit`) |
| Attendance export | HR CSV export for a day, a month or a date range (`attendance.export`); the file is saved where the user chooses |
| Dashboards | Upcoming Holidays card; HR employee-lifecycle notice details; global employee search (`employees.view`) |
| HR attendance detail | Punch location and GPS accuracy guidance (display only) |
| Monthly leave | Monthly Leave Management (manual entry, current assignments, bulk assign, CSV/XLSX import with preview); Monthly Credit Settings |
| Shifts and weekly offs | Shift Assignment and Weekly Off Assignment tabs; Shift Masters create/edit/deactivate; Weekly Off Patterns create/edit/deactivate/set default |
| P0 permission parity | Settings writes (company, financial year, departments, designations, roles), branches, carry-forward rules and attendance import now follow the server's permissions; actions are hidden and refused before any request without permission |
| P1-1 Employee Leave Credits | Credit statement, adjustments and reversals on Employee Detail → Leave (`leave.approve`), with confirm step and duplicate protection |
| P1-2 Notice Period | Settings → Notice Period: per-employee notice period (`employees.edit` to change) and CSV/XLSX import with preview and confirmation |
| P1-3 Birthday visibility | Employee dashboard shows today's birthdays from the endpoint open to all employees (name, designation, department; no age or date of birth) |
| P1-4 Attendance import | Bulk and single-employee modes (employee plus optional date range); import results now read the production response correctly |
| P1-5 Weekly Off | The legacy Weekly Off Days grid is removed from Attendance Rules, as on web; the stored setting is still sent back unchanged on Save All. A notice appears when no active default Weekly Off Pattern exists. |

P2 items remain deferred.

## 4. Verification evidence

Each kind of evidence is recorded separately. Automated tests do **not** prove behaviour on a real phone, signed in, in a release (shrunk) build, or against the production server.

| Evidence | Status |
|---|---|
| Automated tests (fake servers, synthetic data) | **923 passing**, 0 failing (last full run 2026-11-06). One test file, `day_completed_test.dart`, stalled once during a run and passed on later runs; it is a known, separate issue. |
| Static analysis (`flutter analyze`) | **0 errors, 0 warnings, 13 informational notes** (2026-11-06) |
| Emulator | Install and launch to Sign In only (Phase 9 release APK; debug builds through Phase 11.5). **None of the features added after Phase 11.8 has been checked on an emulator.** |
| Real device | **NOT VERIFIED** |
| Signed in against a server (any role) | **NOT VERIFIED** — no authorised test account |
| Live production | **NOT VERIFIED** |

## 5. Signed-in (authenticated) testing

**Not done.** No authorised employee, manager, HR or reviewer test account has been provided. Every signed-in item in `INTERNAL_TEST_CHECKLIST.md` is ☐. No feature has been checked against production behaviour.

## 6. Real-device testing

**Not done.** **Release-build risks that only a real device can clear:**
- sign-in, session restoration and session expiry;
- face capture and liveness (ML Kit / TensorFlow Lite) under code shrinking, and clock-in/out with location;
- in-app PDF viewing (`pdfx` native renderer);
- camera, file picker, system save dialog (attendance export, import samples) and location prompts;
- HR flows added this week (attendance tabs, imports and export, Weekly Off Patterns, Notice Period, Leave Credits, Monthly Leave).

## 7. Privacy policy

**Draft only; not published; no public URL.** `PRIVACY_INVENTORY_AND_POLICY_DRAFT.md` holds a code-verified inventory (Part A, now including the HR import and export file flows), 16 open questions (Part B) and a draft policy with placeholders (Part C). It needs:
- the company's answers, including its legal identity, contact details, retention periods, legal basis, the deletion process and vendor terms;
- a legal review;
- publication at a public HTTPS URL.

## 8. Data Safety

**Worksheet prepared; Console form not filled in.** `DATA_SAFETY_WORKSHEET.md` lists every data type with evidence. All sharing, retention and deletion answers are marked **Requires confirmation**: third-party processors (Cloudinary, Sarvam AI, the email provider, Google services) are not assumed to be "not shared". This week's features add **no new permission and no new SDK**; the HR import and export flows are recorded under Files and docs for confirmation.

## 9. Store assets

| Asset | Status |
|---|---|
| 512×512 icon | Prepared in the repository; live listing use requires confirmation |
| 1024×500 feature graphic | Missing in the repository; requires confirmation whether the live listing has one |
| Phone screenshots | Missing in the repository; need a test company with dummy data |
| Short and full description, release notes | Drafts prepared (update wording); not submitted. Release notes may mention the new HR features once they are verified. |

## 10. Reviewer account

**Missing.** Google reviewers cannot get past sign-in without one. It must be onboarding-complete, assessment-complete, free of a forced password change, and not subject to mandatory Face ID (or come with instructions).

## 11. AAB build and signing

| Item | Status |
|---|---|
| Signing configuration | Verified (2026-11-06, values not read): release always uses the upload key; `android/key.properties` exists, is git-ignored, and has all four entries; the keystore file it names exists; a missing or incomplete configuration fails the release build — there is no debug-signing fallback |
| Existing AAB (2026-11-04, SHA-256 `c8827b4f…`) | **Out of date — must not be uploaded** |
| New AAB from current source | **NOT DONE** (not built) |
| Upload certificate match with Play | **Requires confirmation** |
| Submission to Google Play | **NOT DONE** |

## 12. Remaining release blockers

| # | Priority | Blocker | Owner | Depends on |
|---|---|---|---|---|
| B1 | P0 | Confirm the live version code and upload certificate; raise the version code if needed | Play Console owner | — |
| B2 | P0 | Commit the current work (only `mobile_app/` paths — the parent repository also holds unrelated deletions that must not be committed), so the release build is traceable | Product owner (the development team makes no git writes) | — |
| B3 | P0 | Build and verify a new signed release AAB from the committed source (version, upload-key signature, SDK 36, permissions) | Development | B1, B2 |
| B4 | P0 | Real-device check of the release build (sign-in, session expiry, face capture, clock-in/out, PDF viewing, pickers, save dialog, location) | Development + tester | B3, a phone, a test account |
| B5 | P0 | Answer the privacy questions, review and publish the privacy policy at a public URL | Company / legal | — |
| B6 | P0 | Complete the Data Safety form | Play Console owner | B5 |
| B7 | P0 | Issue a reviewer account and fill in App access | Administrator / owner | — |
| B8 | P1 | Internal testing track upload, pre-launch report, signed-in test by role (employee, manager, HR), including this week's HR features | Owner + tester | B3, B7, test accounts |
| B9 | P1 | Confirm or create screenshots and the feature graphic | Owner / design | Test company with dummy data |
| B10 | P1 | Confirm the remaining Console declarations (content rating, audience, ads, government/financial/health) and whether the closed-testing rule applies | Play Console owner | — |

## 13. Recommended order (7–11 November)

1. **7 Nov:** B1 (Console check), B7 and test accounts (administrator), B5 (privacy answers started), B2 (commit).
2. **8 Nov:** set the version if needed; run the full test suite and analyzer; B3 (build and verify the AAB); start B4 on a real phone.
3. **9 Nov:** upload to the internal testing track; review the pre-launch report; B8 (signed-in tests by role, test data only); fix critical issues only.
4. **10 Nov:** B5 and B6 completed; App access with the reviewer account; B9 and B10; rebuild only if a critical fix was made.
5. **11 Nov:** submit the production update only when every P0 item is closed.

Google's review time and approval cannot be predicted or guaranteed. B1, B5, B6 and B7 depend on people outside the development team.

## 14. Deadline

**11 November 2026.** The code is ready. Meeting the date depends mainly on B1, B2, B5, B6 and B7 being supplied in time for B3, B4 and B8 to run.

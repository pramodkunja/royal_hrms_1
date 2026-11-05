# Final Release Readiness — Royal HRMS Android update

**For:** the release owner, the Play Console owner and the company's administrator.
**Assessed:** 2026-11-05. **Submission deadline: 11 November 2026.**
**Related documents (this folder):** `INTERNAL_TEST_CHECKLIST.md`, `PLAY_STORE_AND_CONSOLE_CHECKLIST.md`, `PRIVACY_INVENTORY_AND_POLICY_DRAFT.md`, `DATA_SAFETY_WORKSHEET.md`.

## Release decision

## ❌ Not ready — blockers remain

The code for every planned feature is finished and covered by automated tests, but the update cannot be submitted yet:
- there is **no current signed release build**;
- the **privacy policy is not published**;
- the **Data Safety answers are not confirmed**;
- **no reviewer or test account** exists;
- the **Play Console values have not been checked**;
- **nothing has been tested signed in or on a real phone**.

Most of these depend on the company, the administrator or the Play Console owner, not on further development.

## 1. Application identity

| Item | Value | Status |
|---|---|---|
| App name | Royal HRMS | Verified (app label) |
| Application ID | `com.royalhrms.app` | Verified (build file) |
| Store presence | Reported as already published; this is an update | Requires confirmation (Console not inspected) |
| Production API | `https://royalhrms.com/api/` (forced in release builds) | Verified (code) |

## 2. Release version

| Item | Value | Status |
|---|---|---|
| Version in the source | 1.0.0 (versionCode 6) | Verified (`pubspec.yaml`) |
| Version code to ship | 6, **or higher** if Play already has a bundle with code 6 or above | Requires confirmation (App bundle explorer) |
| Target / min SDK | 36 / 24 | Verified on the debug APK; re-check on the new AAB |

## 3. Completed development

| Phases | Scope |
|---|---|
| 1–10 | Original P0/P1 parity work, release hardening (signing, permissions, version), release documents |
| 11.1 | Announcements pagination |
| 11.2 | Candidate Review onboarding-approval details |
| 11.3 | Attendance policy fields and rules |
| 11.4 | Profile documents: upload, replace, secure in-app viewing, cleanup on close, start, sign-out and session expiry |
| 11.5 | Employee notice-period dashboard card |
| 11.6 | Read-only verification of all original P1 gaps (all implemented; two small gaps found) |
| 11.7 | Custom file field error messages (no raw technical errors) |
| 11.8 | Tests for future-month and year-boundary attendance navigation |

No P1 feature gap remains in the code. P2 items are deferred (listed in the Phase 11.6 report).

## 4. Automated tests and analysis

| Item | Result (2026-11-05) |
|---|---|
| Flutter test suite | **575 passing**, 0 failing |
| Flutter analyzer | 13 information notes, **0 errors**, 0 warnings |
| What the tests prove | Behaviour against fake servers with synthetic data. They do **not** prove behaviour against the production server, on real phones, or in a release (shrunk) build. |

## 5. Signed-in (authenticated) testing

**Not done.** No authorised employee, manager, HR or reviewer test account has been provided. Every signed-in item in `INTERNAL_TEST_CHECKLIST.md` is ☐. No feature has been checked against production behaviour.

## 6. Real-device testing

**Not done.** Hand checks so far were on an Android emulator only: install and launch to Sign In (Phase 9 release APK; debug builds through Phase 11.5) and clearing of leftover temporary documents at start. **Release-build risks that only a real device can clear:**
- face capture and liveness (ML Kit / TensorFlow Lite) under code shrinking;
- in-app PDF viewing (`pdfx` native renderer);
- camera, file picker and location prompts.

## 7. Privacy policy

**Draft only; not published; no public URL.** `PRIVACY_INVENTORY_AND_POLICY_DRAFT.md` holds a code-verified inventory (Part A), 15 open questions (Part B) and a draft policy with placeholders (Part C). It needs:
- the company's answers, including its legal identity, contact details, retention periods, legal basis, the deletion process and vendor terms;
- a legal review;
- publication at a public HTTPS URL.

## 8. Data Safety

**Worksheet prepared; Console form not filled in.** `DATA_SAFETY_WORKSHEET.md` lists every data type with evidence. All sharing, retention and deletion answers are marked **Requires confirmation**: third-party processors (Cloudinary, Sarvam AI, the email provider, Google services) are not assumed to be "not shared".

## 9. Store assets

| Asset | Status |
|---|---|
| 512×512 icon | Prepared in the repository; live listing use requires confirmation |
| 1024×500 feature graphic | Missing in the repository; requires confirmation whether the live listing has one |
| Phone screenshots | Missing in the repository; need a test company with dummy data |
| Short and full description, release notes | Drafts prepared (update wording); not submitted |

## 10. Reviewer account

**Missing.** Google reviewers cannot get past sign-in without one. It must be onboarding-complete, assessment-complete, free of a forced password change, and not subject to mandatory Face ID (or come with instructions).

## 11. AAB build and signing

| Item | Status |
|---|---|
| Signing configuration | Verified: release always uses the upload key; credentials and keystore present; no debug fallback |
| Existing AAB (2026-11-04, SHA-256 `c8827b4f…`) | **Out of date — must not be uploaded** |
| New AAB from current source | **Not built** |
| Upload certificate match with Play | Requires confirmation (project certificate SHA-256 `C3:64:02:…:92:A7`) |

## 12. Remaining release blockers

| # | Priority | Blocker | Owner | Depends on |
|---|---|---|---|---|
| B1 | P0 | Confirm the live version code and upload certificate; raise the version code if needed | Play Console owner | — |
| B2 | P0 | Build and verify a new signed release AAB from current source | Development | B1 |
| B3 | P0 | Real-device check of the release build (sign-in, face capture, PDF viewing, pickers, location) | Development + tester | B2, a phone, a test account |
| B4 | P0 | Answer the privacy questions, review and publish the privacy policy at a public URL | Company / legal | — |
| B5 | P0 | Complete the Data Safety form | Play Console owner | B4 |
| B6 | P0 | Issue a reviewer account and fill in App access | Administrator / owner | — |
| B7 | P1 | Internal testing track upload, pre-launch report, signed-in test by role (employee, manager, HR) | Owner + tester | B2, B6, test accounts |
| B8 | P1 | Confirm or create screenshots and the feature graphic | Owner / design | Test company with dummy data |
| B9 | P1 | Confirm the remaining Console declarations (content rating, audience, ads, government/financial/health) and whether the closed-testing rule applies | Play Console owner | — |
| — | Recommended | Commit the current uncommitted work so the release source is recorded | Product owner (the development team makes no git writes) | — |

## 13. Recommended order (5–11 November)

1. **Now, in parallel:** B1 (Console check), B6 and test accounts (administrator), B4 (privacy answers started), commit the work.
2. **After B1:** set the version if needed; B2 (build and verify the AAB).
3. **Next:** B3 (real-device release check). Upload to the internal testing track; review the pre-launch report.
4. **Then:** B7 (signed-in internal test by role, test data only); fix critical issues only.
5. **Before the deadline:** B4 to B6, B8 and B9 completed in the Console; submit the production update only when every P0 item is closed.

Google's review time and approval cannot be predicted or guaranteed. B4 to B6 depend on people outside the development team.

## 14. Deadline

**11 November 2026.** The code is ready. Meeting the date depends mainly on B1, B4, B5 and B6 being supplied in time for B2, B3 and B7 to run.

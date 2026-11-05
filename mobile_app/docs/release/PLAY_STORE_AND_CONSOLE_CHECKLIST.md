# Play Store Listing and Play Console Checklist — Royal HRMS Android update

**For:** the Play Console owner and the release owner.
**Updated:** 2026-11-05 (source through Phase 11.8). **Submission deadline: 11 November 2026.**
**Nothing in Play Console has been inspected or changed by the development team.** Every Console value below is either taken from the project files or is a manual check for the owner.

## Status key

| Status | Meaning |
|---|---|
| **Complete and verified** | Checked directly in the project files or build output on the date shown |
| **Prepared, not submitted** | Draft or asset ready in the repository; nothing entered in the Console |
| **Requires confirmation** | Depends on Play Console, the company or the administrator; not verified by the development team |
| **Missing** | Does not exist yet |
| **Not applicable** | Does not apply to this app |

## 1. Existing application

| Item | Value | Status |
|---|---|---|
| Application ID | `com.royalhrms.app` (`android/app/build.gradle.kts`) | Complete and verified (2026-11-05) |
| Existing Play Store listing | Reported by the product owner as already published | **Requires confirmation** (Console not inspected) |
| Previously reported version | 1.0.0 (versionCode 6) — the version in `pubspec.yaml` | Complete and verified (project file) |
| Live version code on Google Play | Unknown. If any release or bundle with code ≥ 6 already exists, `pubspec.yaml` must be raised (e.g. `1.0.1+7`) before building. | **Requires confirmation** (Release → App bundle explorer) |
| Play App Signing enrolled | — | **Requires confirmation** (Setup → App signing) |
| Upload certificate matches the project's upload key | Project upload certificate SHA-256: `C3:64:02:52:0D:91:0B:77:8C:9B:D4:91:08:52:0D:3B:1B:EB:DC:A1:8A:F6:06:76:3B:DC:F0:C8:7E:2B:92:A7` (from the 2026-11-04 build). If the Console's upload-key certificate differs, **stop**: the bundle will be refused. | **Requires confirmation** |

## 2. Release build

| Item | Value | Status |
|---|---|---|
| Version name / code | `1.0.0` / `6` in `pubspec.yaml` | Complete and verified (file); **final code requires confirmation** against the live version |
| Production API | Release builds are forced to `https://royalhrms.com/api/` (`lib/core/config/api_config.dart`, `resolvedEnvironment`) | Complete and verified (code, 2026-11-05) |
| Target / min SDK | 36 / 24 (Flutter defaults; read from the latest debug APK on 2026-11-05) | Complete and verified (APK) — re-check on the new AAB |
| Release signing configuration | Release always uses the upload key (`signingConfigs.release`); the build fails if `android/key.properties` or the keystore is missing. `key.properties` is present with all four entries and is git-ignored; the keystore is present. | Complete and verified (2026-11-05; values not displayed) |
| No debug signing in release | Enforced by the build script (no debug fallback) | Complete and verified (build script) — confirm on the new AAB signature |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, CAMERA, RECORD_AUDIO, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE (Android 9 and below, from the camera library), plus the AndroidX-internal `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. READ_PHONE_STATE is removed. Providers: `image_provider`, `mlkitinitprovider`, `androidx-startup` only. | Complete and verified on the debug APK (2026-11-05) — re-check on the new AAB |
| Existing AAB | `build/app/outputs/bundle/release/app-release.aab`, built 2026-11-04 12:14, SHA-256 `c8827b4f1b5d9de0c21dfd6d5fa9751ce336195762acc382dcde65db8a2e41da` | **Out of date — do not upload.** It predates Phases 11.1–11.8 (36 source files changed, including the `pdfx` dependency). |
| New AAB build and signature check | `flutter build appbundle --release` from the current source, then verify the signer and upload certificate, version code, permissions and SHA-256 | **Missing** (not built yet) |
| Release-build device check | Face capture (ML Kit / TFLite) and in-app PDF viewing (`pdfx`) in the release build on a real phone | **Missing** (see `INTERNAL_TEST_CHECKLIST.md` 6.4, 7.4) |

## 3. Store listing assets

This is an update to an existing listing. Assets may already be live; each must be confirmed in the Console.

| Asset | Status | Notes |
|---|---|---|
| App icon 512×512 | Prepared, not submitted | `mobile_app/assets/icon/play_store_icon_512.png` (Royal emblem; replaces the icon rejected in October). Whether the live listing already uses it: **Requires confirmation** |
| Feature graphic 1024×500 | **Missing** in the repository — **Requires confirmation** whether the live listing has one | Use the brand emblem and name only |
| Phone screenshots (2–8) | **Missing** in the repository — **Requires confirmation** whether the live listing has current ones | Real signed-in screens from a **test company with dummy data only**; no real names, salaries, IDs or documents. Suggested: dashboard, attendance clock-in, leave, payslip, profile documents, manager dashboard |
| App name | Complete and verified: "Royal HRMS" matches the app label | |
| Short description (≤ 80) | Prepared, not submitted | Draft below |
| Full description (≤ 4000) | Prepared, not submitted | Draft below — lists only features in this build |
| Release notes | Prepared, not submitted | Draft below — written as an update |

### Short description — draft (74 characters)
> Attendance, leave, payslips and HR approvals for Royal HRMS employees.

### Full description — draft (only features in this build)
> Royal HRMS is the mobile companion for organisations that use Royal HRMS. Sign in with the company code and account your employer provides.
>
> **For employees**
> • Clock in and out with location-based attendance and optional Face ID verification
> • View your attendance calendar, including upcoming months, and request corrections
> • Apply for leave and work from home, including medical WFH with proof
> • View payslips and raise a query on a payslip
> • Complete onboarding: personal details, documents and assessments
> • Upload and view your profile documents securely inside the app
> • Read company documents and acknowledge policies
> • Submit expenses and separation requests, and follow your notice period
> • See announcements, your requests and the company Contact Matrix
> • Optional voice commands for common actions
>
> **For managers and HR**
> • Team dashboard with today's attendance, pending approvals and upcoming leave
> • Approve leave, WFH, expenses, attendance corrections and separation requests
> • Review onboarding applicants, manage documents and see who has acknowledged policies
>
> An account from your employer is required. Features shown depend on your role and on what your employer has enabled.

### Release notes — draft (update)
> This update adds: profile document upload and secure in-app viewing; your notice-period countdown on the dashboard; payslip queries; separation approvals; the manager dashboard; policy acknowledgements; the Contact Matrix; more announcements as you scroll; onboarding with your company's own fields and files; attendance month browsing including upcoming months; and many reliability and permission improvements.

*Confirm the release notes against what the currently published version already contains before submitting.*

## 4. Play Console — declarations and testing (owner)

| # | Item | How | Status |
|---|---|---|---|
| 1 | Version code free | Release → App bundle explorer: no bundle with the chosen code (6 or higher) exists | **Requires confirmation** |
| 2 | Play App Signing / upload certificate | See section 1 | **Requires confirmation** |
| 3 | Privacy policy URL | App content → Privacy policy: public HTTPS URL of the reviewed policy | **Missing** (policy is a draft; no URL) |
| 4 | Data safety | Complete from `DATA_SAFETY_WORKSHEET.md` once every "Requires confirmation" answer is resolved | Prepared, not submitted (worksheet only) |
| 5 | App access (reviewer account) | "All or some functionality is restricted"; reviewer account (company code, email, password) that is onboarding-complete, assessment-complete, not flagged for a password change, with Face ID not mandatory (or instructions), plus a note on location | **Missing** (no reviewer account issued) |
| 6 | Permissions declarations | Location is foreground-only, so no background-location declaration. Camera and microphone: no special form, but disclose in Data safety and the policy. No SMS, call-log, all-files-access or media-permission declarations needed (none requested). | Prepared, not submitted — **Requires confirmation** in the Console |
| 7 | Content rating | IARC questionnaire: utility/productivity; no violence, sexual content, gambling or public user-to-user sharing | **Requires confirmation** (may already be set for the live app) |
| 8 | Target audience | 18+ only; not designed for children | **Requires confirmation** |
| 9 | Ads | "No, my app does not contain ads" (no ad SDK in the build) | **Requires confirmation** (code supports "No") |
| 10 | Government / financial-features declarations | Not a government app; no payments or lending (payslips are display-only) | **Requires confirmation** |
| 11 | Health declaration (if asked) | Limited health info (medical proof) for HR purposes; not a health app | **Requires confirmation** |
| 12 | Internal testing track | Create the release, upload the **new** AAB, add testers, install from Play, run `INTERNAL_TEST_CHECKLIST.md` including face capture and PDF viewing | **Missing** (not started) |
| 13 | Pre-launch report | Review after the internal upload (crashes, accessibility). The robot cannot sign in without credentials. | **Missing** |
| 14 | Closed-testing requirement | Applies only to personal developer accounts created after November 2023 (≥ 12 testers for 14 days before production). An app that is already published in production is normally past this. | **Requires confirmation** (account type and current production status) |
| 15 | Production release | Only after items 1–13 and a passing signed-in internal test | **Missing** (not submitted) |

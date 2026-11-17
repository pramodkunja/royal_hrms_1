# 01 — Environment and Build

Audit: Royal HRMS client handover (target 19 Nov 2026)
Recorded: 17 Nov 2026, 11:28 IST (device clock)
Phase: A — environment and version check (read-only)

All facts below were observed with read-only commands (`adb shell getprop`, `wm`, `settings get`, `dumpsys package`, `pm path`, `sha256sum`, `screencap`, `uiautomator dump`) and by reading source files. Nothing has been installed, uninstalled, cleared or changed on the device. No login has been attempted.

## 1. Source locations

| Item | Location / value | Evidence |
|---|---|---|
| Flutter project | `Royal-HRMS/mobile_app/` | — |
| Web frontend (read-only) | `Royal-HRMS/web_frontend_backend/frontend/` (Next.js) | — |
| Backend (read-only) | `Royal-HRMS/web_frontend_backend/backend/` (Django) | — |
| Flutter SDK | 3.44.8, stable channel | `flutter --version` |
| App version in source | `1.0.1+7` | `mobile_app/pubspec.yaml` |
| Android application ID | `com.royalhrms.app` | `android/app/build.gradle(.kts)` |

## 2. Connected device

| Property | Value |
|---|---|
| Device | Motorola moto g06 power (`lagos_gpi`), serial ending `…BVMPM` |
| Connection | USB, adb state `device` (authorized) |
| Android | 15 (API 35) |
| Physical resolution | 720 × 1640 px |
| Density | 280 dpi (≈ 1.75×; logical width ≈ 411 dp) |
| Font scale | 1.0 (normal) |
| Display size override | none |
| Power | USB-powered, battery 100% |
| Screen timeout | 10 minutes |

## 3. Installed Royal HRMS app

| Property | Value |
|---|---|
| Package | `com.royalhrms.app` |
| versionName / versionCode | `1.0.1` / `7` |
| Build type | **Debug** (`DEBUGGABLE` flag set) |
| Installer | none (`installerPackageName=null`): sideloaded through adb / `flutter run`, **not a Play Store build** |
| First installed | 2026-11-12 11:35:02 |
| Last updated | **2026-11-17 11:08:59** |
| Installed APK SHA-256 | `abbcacd0b893…c095128e0` |
| Runtime permissions | Camera **not granted**, Location (fine/coarse) **not granted**, Storage not granted, Microphone granted |
| State at audit start | Running, in the foreground, on the **Sign In** screen (not logged in) |

Another HRMS-like package, `com.aira.hrms`, is also installed. It is not part of this audit and was not opened.

## 4. Does the installed app match the current source?

**Partly. It contains everything up to and including Task 83, but not the finished Task 84.**

- The installed APK is byte-identical to `mobile_app/build/app/outputs/flutter-apk/app-debug.apk` (same SHA-256 and the same size, 236,146,937 bytes). That local APK was built on 17 Nov 2026 at 11:08.
- The version number cannot distinguish builds: the source has stayed at `1.0.1+7` since the earlier Play release candidate. **Any build made from current source still reports 1.0.1+7.** A version bump is needed before any client build so that builds can be told apart.
- These source files were modified **after** that build, so their changes are **not** on the phone:
  - `lib/features/leave/data/models/leave_models.dart`
  - `lib/features/leave/domain/entities/leave_entity.dart`
  - `lib/features/leave/presentation/widgets/apply_leave_tab.dart`
  - `lib/features/leave/presentation/widgets/apply_leave_type_selector.dart`
  - `lib/features/leave/presentation/widgets/leave_number_format.dart` (new)
  - `lib/features/leave/presentation/widgets/leave_preview_panel.dart` (new)

  These are the Task 84 changes (fractional leave balances and the Apply Leave preview panel). On the phone, Apply Leave will still show rounded balances and the old preview.
- The previously reported Play build, 1.0.1+7, is **not** what the phone runs. The phone runs a newer debug build with the same version number.

## 5. API environment used by the installed app

| Item | Value | Evidence |
|---|---|---|
| Environment constant | `Environment.production` | `lib/core/config/api_config.dart:20` |
| Debug override | none: the constant applies in debug builds too (`kReleaseMode ? production : current`) | `api_config.dart:28-29` |
| Base URL | `https://royalhrms.com/api/` (**production**) | `api_config.dart` |

**Consequence:** every action taken in the installed app reads and writes the **production** database (the DEMO2026 tenant). Read-only navigation is low-risk. Clock-in/out, applying for leave, approving, editing records, uploading documents and similar actions are **real production writes**. They are classified **BLOCKED — MUTATION APPROVAL REQUIRED** until the user authorizes them for the demo tenant.

## 6. Test account

| Item | Value |
|---|---|
| Company code | DEMO2026 (supplied by the user) |
| Login email | s\*\*\*\*\*\*\*\*\*\*\*\*\*\*3@gmail.com (masked) |
| Password | Not handled by the auditor. The user entered it on the device (Phase B, 17 Nov ~11:38). |
| Login result | **PASS**: landed on the Admin dashboard ("System Console") |
| Role | **Branch Admin** (`branch_admin`, system role, 73 permissions, 1 user). Designation "HR Manager", department Human Resources |
| Branch | Suryapet (employee lists and attendance scoped to 7 employees) |
| Dashboard category | admin (the role holds `settings.edit`) |
| Accessible destinations | 30 drawer items: Dashboard, Announcements, Interview List, Review & Onboarding, Assessments, Email Logs, Employees, Org Chart, Branches, Attendance, Leave Management, Work From Home, Expenses, Approvals, Separation & Exit, Document Center, Face ID Registrations, My Attendance, My Payslips, My Assessments, My Referrals, My Requests, Contact Matrix, My Profile, Audit Log, Settings (+ header Search, Notifications, Sign out, dark mode) |
| Modules not enabled for the tenant | assets (Settings → Assets tile hidden; same rule as web) |
| Effective permissions (device Permission Matrix, Branch Admin column) | Full: announcements, assessments, audit, departments, designations, documents, employees, expenses, facial_recognition, leave, onboarding, org_chart, payroll, recruitment, referrals, reports, separation, settings (view + edit), wfh. Partial: attendance (create/delete/edit/export/view), assets (create/edit/view), training (assign/view/view_all_progress/view_reports). None: branches (reachable anyway via settings.edit) |
| Roles NOT available to this account | Employee-only, HR (employees.view without settings.edit) and Manager (can_manage_team) experiences: separate test accounts needed |

## 7. Tooling availability

| Capability | Status | Notes |
|---|---|---|
| adb (platform-tools 1.0.41) | Available | `~/Library/Android/sdk/platform-tools/adb` (not on PATH) |
| Device screenshots | Available | `adb exec-out screencap -p` (verified) |
| UI hierarchy dump | Available | `uiautomator dump` (verified; Flutter exposes semantics nodes) |
| Tap / swipe / text input | Available | `adb shell input` |
| Logs | Available | `adb logcat`; debug build, so Flutter errors and overflow messages appear in the log |
| Font-scale change for large-text testing | Available, **needs approval** | Changes a device-wide setting (`settings put system font_scale`). It will be restored afterwards. |
| Flutter integration tests on device | Technically available | They would install a separate test build over the app and would hit production. **Not used without approval.** |
| Browser automation (web comparison) | **Not available** | No Playwright, Puppeteer or Cypress installed, and no browser-automation tool in this session. Chrome is installed but can't be driven. **Web screens can't be captured or exercised by the auditor.** |
| Web source (read-only) | Available | Used for the expected-behaviour column of the matrices |

## 8. Backend P0 (FACE-06), source status

The **local** backend copy (production branch clone, read-only) still has the bypass:

- `apps/attendance/services_face_matching.py`, `FaceVerificationService.verify_for_punch`: `if source not in (SOURCE_WEB, SOURCE_VOICE): return cls._not_required(...)`. Face matching is skipped for `mobile`, `biometric` and `manual`.
- `apps/attendance/serializers_my_attendance.py`: `source` is a client-supplied `ChoiceField` that accepts `'mobile'`, `'biometric'` and `'manual'`.

So when Face ID is mandatory, an authenticated self-service punch sent with `source='mobile'` (or `biometric` / `manual`) is not face-matched on the server.

- **Status:** OPEN in source. Whether the deployed production server runs this exact code can't be verified without a production exploit test, which this audit won't do.
- **Classification:** P0, backend-owned. Release readiness is **BLOCKED** on this item until the backend team fixes it or the client formally accepts the risk.

## 9. Phase B finding: a `flutter run` session is attached to the phone

- A process on the developer Mac, `flutter_tools … run` (PID 82980, started **17 Nov 11:08:07** from an interactive terminal), is still attached to the device. Its children are the frontend compiler, a device `logcat` reader (`adb -s ZA223BVMPM shell logcat … -T '11-17 11:08:13'`) and the Dart Development Service.
- The running app shows Task 84 behaviour (fractional balances "82.5d left" / "4.5d left", the new preview panel) that the **installed APK doesn't contain**. Those changes came through the debug session (hot reload/restart), not through an install.
- **Consequence:** what the phone shows depends on how the app was started. A **cold launch from the home screen** runs the 11:08 APK without Task 84, and closing that terminal or rebooting the phone drops the reloaded code. This is a direct cause of "reported as done but not visible".
- The auditor didn't touch that session.

## 10. Proposed build update (NOT executed; needs approval)

| Item | Finding |
|---|---|
| Installed APK certificate | Same file as local `app-debug.apk`: **CN=Android Debug, O=Android, C=US**, SHA-256 `38:EA:BE:8F:82:9E:19:70:91:F3:AD:87:29:22:54:F5:88:62:93:33:3A:79:5F:6F:A5:5E:C2:F7:6D:73:C1:28` (`apksigner verify --print-certs`, v2 scheme) |
| Proposed APK certificate | A new **debug** build is signed with this Mac's `~/.android/debug.keystore`: `keytool` shows the same SHA-256 `38:EA:BE:8F…C1:28`. **Identical certificate.** |
| Package / version | `com.royalhrms.app`; source still `1.0.1+7`. Recommend bumping to `1.0.2+8` first (a source change, needs approval) so the build can be identified on the device. |
| Data-loss risk | **Low** for a debug build installed with `adb install -r`: same package and signer, so data and the login are kept. **High** for a *release* build: it's signed with the upload key (`signingConfigs.release`), and Android refuses to update a debug-signed install with a different certificate. That path needs uninstall = data loss. |
| Backend used | The proposed debug build **also uses production** (`Environment.production` applies to debug builds). |

**Proposed low-risk procedure (for approval):**
1. Keep the current APK for rollback. It's already at `build/app/outputs/flutter-apk/app-debug.apk`; copy it to a dated file name first, because the next build overwrites it. SHA-256 `abbcacd0…c095128e0`.
2. Optionally bump the version to `1.0.2+8`.
3. Run `flutter build apk --debug`. Record its SHA-256 and confirm with `apksigner` that the certificate is `38:EA:BE:8F…`.
4. Ask the user to stop the attached `flutter run` session (press `q` in that terminal), so the device isn't running two code sources.
5. Run `adb install -r <new apk>`. No uninstall, no data clear.
6. Verify: `dumpsys package` shows the new version and lastUpdateTime; cold-launch from the home screen; check Apply Leave fractional balances and the preview panel.
7. Rollback if needed: `adb install -r -d <saved 1.0.1+7 apk>` (same signer, downgrade allowed for a debuggable app).

## 11. Blockers needing user decisions (status after Phase B)

1. **Login:** DONE. The user typed the password; the auditor only pre-filled the company code and email.
2. **Production writes:** NOT AUTHORIZED in Phase B (this replaces the earlier verbal "full demo-tenant writes"). Every data-changing action is logged as BLOCKED — MUTATION APPROVAL REQUIRED.
3. **Installing a current build:** needs approval. The procedure and signing facts are in §10.
4. **Web comparison:** no browser automation. Web is compared from source, labeled SOURCE-COMPARED; nothing is labeled as verified on both platforms. Option: install Playwright in the session scratchpad only (network download, nothing in the project). Needs approval.
5. **Large-text testing:** permission to change the device font scale temporarily and restore it afterwards.
6. **Other roles:** Employee, HR and Manager test accounts are needed to test those dashboards and menus.

## 12. C1: build 1.0.2+8 installed (17 Nov 2026)

| Step | Evidence |
|---|---|
| Attached `flutter run` session stopped | PID 82980 (started 11:08:07, from an interactive terminal) confirmed, then SIGINT (= Ctrl-C). It and its 3 children (frontend compiler, logcat reader, dev service) exited. No other process was touched. The app on the phone was stopped by the tool, as `flutter run` does on quit. |
| Installed-identical APK preserved | Device APK SHA-256 = local `app-debug.apk` = `abbcacd0b8931009682fa459aace9d43ab85fdccf214d5aa23e7a12c095128e0` → copied to `mobile_app/build/apk_backups/royalhrms-1.0.1+7-debug-20261117-1108-installed.apk` (236,146,937 bytes). This folder is under `build/`, so `flutter clean` would delete it; move it somewhere durable if it's needed beyond this week. |
| Version code check | `1.0.2+8` appears only in this QA folder's own proposals; release docs record `1.0.1+7` as the latest Play build. **The Play Console itself wasn't checked** (no access). Confirm there before any Play upload. |
| Version bump | `pubspec.yaml` `version: 1.0.2+8` (was `1.0.1+7`) |
| Source state (no Git) | `build_1.0.2+8_source_manifest.txt`: SHA-256 of 570 files (lib/, pubspec.yaml/.lock, Android Gradle + manifest, assets/models). Aggregate SHA-256 of the list: `d93fdf0630d2d400feadb01a311786694ab9aaa23727eb5c413b8fc0be74dbd6`. Generated 13:37 on 17 Nov, right before the final build. |
| Final build | `flutter build apk --debug`, 2026-11-17 13:37:01–13:37:12. `build/app/outputs/flutter-apk/app-debug.apk`, 271,039,153 bytes, SHA-256 **`3240b5c5ae3fd6dbecf2174d4474f4c2d4453bc136fdba61a736561c88a8577d`**. An intermediate 1.0.2+8 build (13:10, `0aab8150…`) was installed briefly and replaced after HO-23. |
| Candidate identity | aapt2: `com.royalhrms.app`, versionCode 8, versionName 1.0.2, debuggable. apksigner: v2 signer CN=Android Debug, SHA-256 `38eabe8f…c128`, **identical to the installed build's**. |
| Backend | Still **production** (`api_config.dart` `Environment.production`). No mutation was performed. |
| Install | `adb install -r` (no uninstall, no data clear, no -d / -t / force). Result: Success. Installed APK SHA-256 = `3240b5c5…8577d`. `firstInstallTime` unchanged (2026-11-12 11:35:02), so this was an in-place update; lastUpdateTime 2026-11-17 13:37:34. The user stayed signed in. |
| Hot-reload check | No `flutter_tools … run` process on the Mac. The app was cold-launched via the launcher intent after `am force-stop`. Task 84 behaviour (82.5d / 4.5d) is visible, so it comes from the installed APK. |

**Rollback and its limits.** `adb install -r -d build/apk_backups/royalhrms-1.0.1+7-debug-20261117-1108-installed.apk` reinstalls the old build: same signer, and a downgrade is allowed for a debuggable app. App data is kept, but compatibility isn't guaranteed:
- **Stored preferences:** written by 1.0.2+8 (e.g. secure-storage or cache formats); in practice none changed in C1.
- **Downgrade rules:** a downgrade may be refused on some Android versions without `-d`, or if the system blocks downgrades.
- **No full-state snapshot:** there's no snapshot of app data (no `adb backup`), so "everything exactly as before" can't be promised.

## 13. C2: build 1.0.2+9 installed (17 Nov 2026)

| Item | Value |
|---|---|
| Version | `1.0.2+9` (build number only, to tell it apart from +8) |
| Source manifest | `build_1.0.2+9_source_manifest.txt`: 569 files, aggregate SHA-256 `9f3d36e79dfdf8bddffe00ea17ebd6cb6eb6bf367fcd67cfdf0871a4119c2e76` |
| Build | `flutter build apk --debug`, 2026-11-17 15:46:55–15:47:17, 271,025,017 bytes, SHA-256 **`cae983539bb9e8a02d6305c200f8f2aa3b2af305bb1c09c6bef0d4fde714165c`** |
| Identity | `com.royalhrms.app`, versionCode 9, versionName 1.0.2, debuggable; signer CN=Android Debug `38eabe8f…c128` (unchanged); `Environment.production` |
| Install | `adb install -r` → Success; installed SHA-256 = build; firstInstallTime unchanged (2026-11-12 11:35:02) → in-place update, data and login kept; lastUpdateTime 2026-11-17 15:47:39 |
| Device font scale | Changed to 1.3 and 1.5 for testing, restored to **1.0** and verified after each pass |
| Browser automation | `playwright-core@1.48.2` installed **only** in the session scratchpad (`…/scratchpad/pw`, 8 MB, its own npm cache). It drove the installed Google Chrome with a throw-away profile. The user typed the web password. Every non-GET `/api` request was blocked; that included the web app's own token-refresh POST, which writes nothing. Nothing was installed in the project or globally. |

## 14. C3: build-folder incident and debug 1.0.2+10 install (17 Nov 2026)

- **Incident (HO-32):** between C2 (15:47) and C3 (16:30), a **clean + release app-bundle build** ran outside this audit. It produced `build/app/outputs/bundle/release/app-release.aab` (141,482,970 bytes, 16:06:54) through an Android Studio Gradle daemon (started 16:04:30), and `pubspec.yaml` became `1.0.2+10`.
  - **Deleted:** the clean removed `build/apk_backups/`, with the preserved **1.0.1+7** (installed-identical, `abbcacd0…`) and **1.0.2+9** APKs.
  - **What the auditor did:** neither modified nor used the AAB, and didn't change the version back.
- **Re-preserved:** before installing anything, the installed 1.0.2+9 APK was **pulled from the phone** to the session scratchpad (`…/scratchpad/apk_backups/royalhrms-1.0.2+9-debug-installed.apk`). Its SHA-256 `cae98353…714165c` matches the C2 record. This location is outside `build/` but is session-scoped: copy it somewhere durable if it's needed later. The 1.0.1+7 APK is not recoverable from this machine.
- **Debug build** (the user approved keeping their version 1.0.2+10):
  - **Build:** 16:31:31–16:32:24, `app-debug.apk` 271,060,921 bytes, SHA-256 **`517159eb44954cf60892cc09cb918dc277de700f1a6a2a2ad6524e9ee54501e1`**.
  - **Identity:** versionCode 10, debuggable; signer `38eabe8f…c128` (unchanged); production backend.
  - **Source manifest:** `build_1.0.2+10-debug_source_manifest.txt`, aggregate `aa9a8f79…ff64b00`.
- **Install:** `adb install -r` → Success. Installed hash = build; firstInstallTime unchanged; lastUpdateTime 16:32:45.
  - **Code 10 overlap:** debug versionCode 10 is the same code as the user's release AAB. A release build can only replace this debug install after an uninstall (different signer), which needs explicit approval.
- **Live web session:** expired once (the C2 guard had blocked the token refresh); the user signed in again. The C3 capture scripts allow the `POST /api/token/refresh/` session renewal (it writes no business data) and block every other non-GET call.

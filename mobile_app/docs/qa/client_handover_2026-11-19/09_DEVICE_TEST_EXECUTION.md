# 09 — Device Test Execution Log

Device: moto g06 power (serial …BVMPM), Android 15, 720 × 1640 @ 280 dpi, font scale 1.0
App: `com.royalhrms.app` 1.0.1+7 debug; installed APK SHA-256 `abbcacd0…c095128e0`, plus code hot-reloaded through an attached `flutter run` session (PID 82980, started 11:08:07)
Backend: production (`https://royalhrms.com/api/`), DEMO2026 tenant
Account: Branch Admin (email masked; the user typed the password on the device)
Tools: adb `screencap`, `uiautomator dump`, `input tap/swipe/text/keyevent`, `logcat`. Taps were scripted from the on-screen layout dumps; every screen was checked against its screenshot.

Results: PASS = behaved correctly on Android. Web parity is **not** asserted here (see 02).

| # | Time (IST) | Test | Steps | Result | Evidence |
|---|---|---|---|---|---|
| 1 | 11:28 | Installed build identification | `dumpsys package`; `sha256sum` of installed APK vs local `app-debug.apk` | PASS: identical (debug, 11:08) | 01 §3–4 |
| 2 | 11:36 | Login pre-fill | Typed company code and email via adb; first attempt landed both in Company Code (auditor tap error: the keyboard shifted the layout); field cleared and re-entered with keyboard Next | PASS (after correction) | qa_raw 001–003 (private) |
| 3 | 11:38 | Login | User typed the password and tapped Sign In | PASS | evidence/dashboard/dashboard_admin_android_top.png |
| 4 | 11:39 | Admin dashboard top | Screenshot + layout dump | PARTIAL (HO-03, HO-13) | same |
| 5 | 11:40 | Drawer inventory | Opened menu; scrolled; listed 30 destinations | PASS | qa_raw 020–022 |
| 6 | 11:40 | Announcements | Drawer → Announcements | PARTIAL (HO-03, HO-16) | evidence/announcements/ |
| 7 | 11:41 | Interview List / Review & Onboarding / Assessments / Email Logs | Drawer navigation | PASS / PASS / PARTIAL (HO-07) / PASS | evidence/recruitment/ |
| 8 | 11:42 | Employees / Org Chart / Branches | Drawer navigation; scrolled Branches | PARTIAL / PASS / PARTIAL (HO-11, HO-16) | evidence/employees/, evidence/branches/ |
| 9 | 11:43 | Attendance (admin) / Leave dashboard | Drawer navigation; swiped leave balance strip | PARTIAL / PASS | evidence/attendance/, evidence/leave/ |
| 10 | 11:44 | Apply Leave form | Leave → Apply Leave; scrolled | PARTIAL: fractional balances visible (HO-04 context) | evidence/leave/leave_apply_android_fractional_balances.png |
| 11 | 11:45 | Apply Leave date selection | Start date picker → 24 Nov → OK | **FAIL**: OK covered by the voice robot; the tap started a recording; assistant closed by the auditor (HO-02) | evidence/leave/leave_apply_android_robot_covers_datepicker_ok.png |
| 12 | 11:46–11:47 | Apply Leave preview (read-only GET) | Start 28 Nov, end 30 Nov (OK tapped on its uncovered edge) | PASS: server preview panel rendered (3 / 1 / 11 / 1 / 0; week-offs Sat/Sun). Not submitted. | evidence/leave/leave_apply_android_preview_panel.png |
| 13 | 11:47 | WFH / Expenses / Approvals / Separation | Drawer navigation | PARTIAL / PASS / PASS / PARTIAL | evidence/wfh/, expenses/, approvals/, separation/ |
| 14 | 11:48–11:49 | Document Center / Face ID Registrations / My Attendance / My Payslips | Drawer navigation | PASS / PARTIAL (HO-12) / PARTIAL / PARTIAL | evidence/documents/, face_id/, attendance/, payroll/ |
| 15 | 11:49–11:50 | My Assessments / My Referrals / My Requests / Contact Matrix | Drawer navigation | PASS / PARTIAL / PASS / PASS | evidence/self/, recruitment/, requests/ |
| 16 | 11:51 | My Profile / Audit Log / Settings hub | Drawer navigation; scrolled Settings | PARTIAL / PARTIAL (HO-14) / PASS | evidence/profile/, settings/ |
| 17 | 11:52–11:57 | 16 Settings pages | Tapped each tile, captured, pressed Back; no saves | PASS ×14, PARTIAL ×2 (Roles & Permissions HO-10 / HO-18; Depts HO-17) | evidence/settings/ |
| 18 | 11:53 | Roles & Permissions matrix | Scrolled the read-only matrix; recorded the Branch Admin column. **Did not** tap the unlabeled Active switch (found by source to be a role-deactivate toggle). | PASS (read) | evidence/settings/roles_permissions_android.png |
| 19 | 11:58 | Notifications panel | Bell → panel → Back. No item tapped (tapping marks it read). | PASS | evidence/dashboard/notifications_panel_android.png |
| 20 | 11:58–11:59 | Dashboard full scroll | 5 swipes to the end | PARTIAL (HO-03) | evidence/dashboard/ |
| 21 | 12:00 | Employee profile (View) | Employees → eye on the first card | PARTIAL (HO-05, HO-06, HO-09, HO-10) | evidence/employees/employee_profile_android_double_header.png |
| 22 | 12:00–12:01 | Employee profile tabs | Salary, Payroll, Leave, Approval Matrix; scrolled the tab bar to see Promotion / Send Wishes | PASS (load) | evidence/employees/employee_profile_salary_tab_android.png |
| 23 | 12:02 | Approvals sub-tabs | Attendance Approval, Face ID, Leave Cancellations, Delegation | PASS ×4 | evidence/approvals/ |
| 24 | 12:03 | Leave Team Calendar / Analytics | Leave tabs 3 and 4 | PASS / PASS (year 2026) | evidence/leave/ |
| 25 | 12:03 | Runtime log scan | `logcat --pid` capture for the whole session + device buffer `flutter` tag | ~~PASS~~ **INVALID (C1, HO-22):** 0 lines were logged, but this device's logcat doesn't receive Flutter error output at all, so the check proves nothing | 04 §1 |
| 26 | 12:05 | Signing comparison | `apksigner verify --print-certs` on the installed-identical APK; `keytool` on the local debug keystore | PASS: same "Android Debug" certificate (SHA-256 38:EA:BE:8F…C1:28) | 01 §10 |

## C1 execution (17 Nov 2026, 12:20–14:00 IST)

Build under test: **1.0.2+8 debug**, SHA-256 `3240b5c5ae3fd6dbecf2174d4474f4c2d4453bc136fdba61a736561c88a8577d`, installed 13:37:34 with `adb install -r`, launched cold through the launcher intent, no `flutter run` attached (checked: 0 processes).

| # | Time | Test | Steps | Result | Evidence |
|---|---|---|---|---|---|
| C1-1 | 13:08 | Stop the attached debug session | SIGINT to `flutter run` PID 82980 (= Ctrl-C), after confirming its start time 11:08:07; its 3 child processes exited | PASS | 01 §12 |
| C1-2 | 13:09 | Preserve the installed APK | Device SHA-256 = local `app-debug.apk` → copied to `mobile_app/build/apk_backups/royalhrms-1.0.1+7-debug-20261117-1108-installed.apk` | PASS | 01 §12 |
| C1-3 | 13:10 / 13:37 | Build and verify candidate | `flutter build apk --debug`; aapt2: com.royalhrms.app, versionCode 8, 1.0.2, debuggable; apksigner: same Android Debug cert (38eabe8f…); `Environment.production` unchanged | PASS | 01 §12 |
| C1-4 | 13:10 / 13:37 | Install | `adb install -r` (no uninstall, no clear); firstInstallTime still 2026-11-12 (in-place update); login kept | PASS | 01 §12 |
| C1-5 | 13:34 | Lock screen | Phone was locked (secure); the user unlocked it. Two captures that showed lock-screen notifications were deleted unpublished. | — | — |
| C1-6 | 13:34 | First 1.0.2+8 build: handle semantics | uiautomator: "Show voice assistant" node = whole screen | **FAIL → fixed (HO-23)**, rebuilt 13:37 | — |
| C1-7 | 13:37 | Cold launch, final build | force-stop + launcher intent; dashboard loads signed in; handle node [685,1395][720,1493] | PASS | c1_retest/after_dashboard_v1.0.2_handle.png |
| C1-8 | 13:38 | Task 84 fractional balances without hot reload | Leave → Apply Leave | PASS: 82.5d / 4.5d | c1_retest/after_leave_apply_fractional_balances_cold_launch.png |
| C1-9 | 13:38 | Auditor mis-tap | A tap meant for Start Date hit "Tap to select file" → Android file picker (personal files) opened; closed with Back; nothing selected or attached; captures deleted unpublished | — (no data change) | — |
| C1-10 | 13:38 | HO-02 retest | Start Date → picker (no assistant node present) → 28 → OK tapped at its centre (605,1265) | PASS: date set, no recording | c1_retest/after_leave_apply_datepicker_* |
| C1-11 | 13:39 | Preview unobstructed | End Date 30 Nov → preview 3 / 1 / 11 / 1 / 0 fully visible; keyboard up → handle hidden | PASS | c1_retest/after_leave_apply_preview_unobstructed.png |
| C1-12 | 13:40 | Payslip amounts | My Payslips scrolled to deductions / net | PASS: ₹ values unobstructed; net card scrolls clear of the nav bar | c1_retest/after_payslip_amounts_unobstructed.png |
| C1-13 | 13:41 | HO-05 / HO-06 | Employees → View | PASS: one header, full title, icon actions, no Save bar, Edit present | c1_retest/after_employee_profile_single_header_no_savebar.png |
| C1-14 | 13:42 | Robot expand / auto-collapse / hide | Tap handle → robot + Hide control (no audio recording registered); 13 s idle → handle; expand → Hide → handle | PASS | c1_retest/after_robot_* |
| C1-15 | 13:42–14:00 | Font scale 1.3 and 1.5 | `settings put system font_scale`; 7 screens each; restored to 1.0 (verified) | PARTIAL: HO-19, HO-20, HO-21 found; dialog reachability NOT TESTED at large text | evidence/font_scale/ |
| C1-16 | 14:00 | Log scan (C1) | logcat for the app PID + full buffer | **No Flutter output reaches logcat** although overflow stripes were on screen → HO-22 | 04 §1 |

## C2 execution (17 Nov 2026, 14:00–16:00 IST)

| # | Test | Result | Evidence |
|---|---|---|---|
| C2-1 | Playwright set up in scratch (approved); web login by the user in a visible Chrome | PASS (logged in, URL /dashboard) | 01 §13 |
| C2-2 | Read-only capture of 16 web pages (Dashboard, Employees, Employee profile, Attendance, My Attendance, Leave, Apply Leave, WFH, Approvals, Settings, Company Info, Plan Details, Leave Policy, Approval Rules, My Payslips, Branches) | 16/16 loaded; non-GET API calls blocked (only the token-refresh POST was attempted) | evidence/web_live/ |
| C2-3 | Build and install 1.0.2+9 (`-r`) | PASS (hash, signer, firstInstallTime) | 01 §13 |
| C2-4 | Font 1.0 sweep: dashboard, drawer, Employees, Payslips, Approvals, Assessments, Leave → Apply → date picker (Cancel), robot expand + outside tap | PASS | evidence/c2_text_scale/after_font1.0_* |
| C2-5 | Font 1.3 sweep (same) | PASS; dashboard captured while loading | evidence/c2_text_scale/after_font1.3_* |
| C2-6 | Font 1.5 sweep (same) | PASS (HO-19 / 20 / 21 fixed); HO-07 titles still truncate | evidence/c2_text_scale/after_font1.5_* |
| C2-7 | Font restored | 1.0 verified | — |

## C3 execution (17 Nov 2026, 16:00–16:40 IST)

| # | Test | Result | Evidence |
|---|---|---|---|
| C3-1 | Live web: sidebar routes for Training & Learning, My Learning, Payroll (navigation clicks) | /dashboard/training, /dashboard/my-learning, /dashboard/payroll | 07 HO-25 |
| C3-2 | Live web capture (read-only, tab controls only): Training (+Courses, Reports), My Learning (+6 tabs), Payroll (+6 tabs), Attendance (+7 tabs), WFH (+3 tabs), Employee profile, Leave Policy, Interview List, Candidate Review | All loaded; GET endpoints recorded; profile and leave-policy tabs not automatable | evidence/web_live/c3_* |
| C3-3 | Back up the installed 1.0.2+9 by pulling it from the phone | PASS (hash cae98353… verified) | 01 §14 |
| C3-4 | Build and install debug 1.0.2+10 (`-r`) | PASS (signer, hash, firstInstallTime) | 01 §14 |
| C3-5 | My Payslips: Print / Save PDF | PASS: Android print dialog with an A4 preview of the own payslip; cancelled | evidence/c3/after_payslip_android_print_preview_v1.0.2+10.png |
| C3-6 | My Payslips: Share PDF | PASS: Android share chooser opened; closed (not captured: it lists personal contacts) | — |
| C3-7 | My Payslips: Download PDF state | PASS: disabled "(not yet available)", as on web | evidence/c3/after_payslip_print_share_download_v1.0.2+10.png |
| C3-8 | Employee profile: Current Experience | PASS: "1 year 9 months" (= live web) | evidence/c3/after_profile_current_experience_v1.0.2+10.png |

## Not executed

| Area | Status | Reason |
|---|---|---|
| Clock in/out, Face ID registration | BLOCKED: mutation not authorized | Also: camera and location not granted to the app |
| Leave / WFH / expense / separation submit, cancel | BLOCKED: mutation approval required | — |
| Approve / reject, bulk actions | BLOCKED: mutation approval required | — |
| Any Save on settings or profile, uploads, imports, SMTP Test, Mark all read | BLOCKED: mutation approval required | — |
| Logout / session expiry / forgot password | NOT TESTED | Logout would require the user to retype the password; forgot-password sends email |
| Employee / HR / Manager dashboards and menus | NOT TESTED: role access | Needs Employee, HR (employees.view without settings.edit) and Manager (can_manage_team) test accounts |
| Onboarding wizard, candidate document viewing | NOT TESTED | No onboarding submissions or candidates in the tenant |
| Global search, ID Card page, OT Entry / Invalid Punches / Un-punches tabs, WFH My Requests / Daily Work Report tabs | NOT TESTED | Phase C |
| Large text, dark mode, landscape | NOT TESTED | Device setting changes not authorized / Phase C |
| Web screens | NOT TESTED: no browser access | Source used as reference |

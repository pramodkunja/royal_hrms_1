# Internal Testing Checklist — Royal HRMS Android update

**For:** the internal tester named by the administrator, and the release owner.
**Updated:** 2026-11-06 (covers all work through Phase 11.8 and the 2026-11-06 work: P0 permission parity, HR attendance tabs, Monthly Leave, Leave Credits, Notice Period, birthday visibility, attendance import modes, Weekly Off Patterns).
**Build to test:** a **new** signed release build made from the current source (version 1.0.0, versionCode 6 unless the live version code requires a higher one; see `PLAY_STORE_AND_CONSOLE_CHECKLIST.md`). Install it from the Play **internal testing** track, not as a sideloaded debug build. The AAB built on 2026-11-04 is out of date and must not be used.
**Accounts:** use only test accounts the administrator has issued for this purpose, in a test company or with HR's agreement. Do not use real employees' accounts.

## Rules

- Do not submit real attendance, leave, WFH, expense, separation, payslip-query, acknowledgement, approval or document records unless HR has said the record is a test and will be cleaned up.
- Where a step would create a real business record and there is no approved test data, mark it **Not run (needs approved test data)**. Do not mark it passed.
- Record the device model, Android version, account role and time for every run.
- Take a screenshot as evidence for each Pass or Fail. Use test data only; no real employee's name, ID numbers, salary or documents may appear.
- An automated test passing is **not** the same as the item being verified in the app. Only tick **Device**, **Employee** or **HR/Admin** after doing the step yourself.

## Accounts needed (from the administrator)

| Role | Needed for |
|---|---|
| Employee, onboarding complete | Most employee flows |
| Employee with forced password change set | Section 3 |
| New hire with onboarding pending (company with custom fields and a custom file field configured) | Section 4 |
| Employee with a pending assessment (after HR approval) | Section 4 |
| Employee whose separation is fully approved (test company) | Section 12 (notice-period card) |
| Employee with a birthday set to the test day, and a colleague account (test company) | Section 20 |
| Manager (team-managing role with direct reports) | Sections 12, 14, 24 |
| HR (`employees.view`, `employees.edit`, `documents.edit`, `separation.approve`, onboarding approval, `settings.edit` for attendance rules) | Sections 4, 10–12, 15, 18, 19, 24 |
| HR with attendance permissions (`attendance.view`, `attendance.export`, `attendance.create`, `attendance.edit`, `attendance.delete`) | Sections 16, 17, 21 |
| HR with `leave.approve` (and a test employee in the same branch) | Sections 22, 23 |
| HR **without** `employees.edit`, `attendance.create` or `leave.approve` (read-only checks) | Sections 16, 18, 22, 24 |
| Reviewer account for Google | App access instructions (see the Console checklist) |

## Verification columns

| Column | Meaning |
|---|---|
| **Auto** | The automated Flutter tests for this item pass (fake server, no real account). Evidence: the test file named. |
| **Emu** | Checked by hand on an Android emulator. |
| **Device** | Checked by hand on a real Android phone with the release build. |
| **Employee** | Checked signed in with an authorised employee test account. |
| **HR/Admin** | Checked signed in with an authorised manager, HR or admin test account. |

✅ = done · ☐ = not yet verified · — = not applicable.

**Status on 2026-11-06:** automated tests only (full suite: **923 passing**; analyzer: 0 errors, 0 warnings, 13 info notes). The only hand checks so far are on the emulator: the app installs, launches to Sign In without errors (debug builds through Phase 11.5; the Phase 9 release APK), and clears leftover temporary document files at start. **No real-device, employee or HR/admin check has been done**, because no authorised test account or test device has been provided. Sections 16–24 (added 2026-11-06) have automated tests only.

## Checklist

### 1. Sign-in, sign-out and session

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 1.1 | Sign in with company code, email and password → the role's dashboard opens | Partly: dashboard chosen by role (`dashboard_category_test`); the sign-in form itself has no automated test | ☐ | ☐ | ☐ | ☐ |
| 1.2 | Wrong password → the server's message, you stay on Sign In | — (no automated test) | ☐ | ☐ | ☐ | — |
| 1.3 | Log out → Sign In; Back does not reopen the dashboard | Partly: signed-out redirects (`auth_redirect_test`) | ☐ | ☐ | ☐ | ☐ |
| 1.4 | Kill and reopen the app → still signed in | Partly: session restoration (`auth_redirect_test`) | ☐ | ☐ | ☐ | — |
| 1.5 | Use the app after the access token expires → silent refresh, keeps working | ✅ `auth_interceptor_test` | ☐ | ☐ | ☐ | — |
| 1.6 | Session revoked on the server (HR logs the user out or changes the password) → next action returns to Sign In, no loop | ✅ `auth_interceptor_test` | ☐ | ☐ | ☐ | — |
| 1.7 | Forgot password with company code → OTP → reset | ✅ `forgot_password_flow_test` | ☐ | ☐ | ☐ | — |
| 1.8 | Leave the app idle until the session can no longer be refreshed (or sign the user out from web) → the next action returns to Sign In with no loop, and any open document viewer closes | ✅ `auth_interceptor_test`, `profile_document_cleanup_test` | ☐ | ☐ | ☐ | ☐ |
| 1.9 | Sign in on each role (Employee, Manager, HR) → only that role's menus and dashboard | ✅ `dashboard_category_test`, `access_control_test` | ☐ | ☐ | ☐ | ☐ |

### 2. Release build basics (release owner)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 2.1 | New AAB is signed with the upload key (not debug); SHA-256 recorded | — | — | ☐ | — | — |
| 2.2 | The installed build talks to `https://royalhrms.com/api/` (release builds are forced to production) | — | ☐ | ☐ | ☐ | — |
| 2.3 | Permissions requested are only location, camera, microphone (voice) and storage as listed in the Console checklist; no others (the debug APK's merged manifest was read on 2026-11-05 and matches; the release AAB must be re-checked) | — | ☐ | ☐ | — | — |
| 2.4 | App name "Royal HRMS" and the Royal emblem icon on the launcher (label confirmed in the APK; icon not yet checked by eye on a launcher) | — | ☐ | ☐ | — | — |

### 3. Forced password change

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 3.1 | Flagged account → only Change Password is reachable | ✅ `force_change_password_flow_test` | ☐ | ☐ | ☐ | — |
| 3.2 | Change the password → continue to onboarding or the dashboard, not asked again | ✅ `force_change_password_flow_test` | ☐ | ☐ | ☐ | — |

### 4. Onboarding, custom file fields, assessments and approval

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 4.1 | New hire sees only the wizard, with the company's configured fields (built-in and custom) in order, with required markers | ✅ `onboarding_config_test` | ☐ | ☐ | ☐ | — |
| 4.2 | Reopen mid-way → resumes at the first unfinished step | ✅ `onboarding_hardening_test` | ☐ | ☐ | ☐ | — |
| 4.3 | Custom file field: upload PDF/JPG/PNG ≤ 5 MB; a single-file field replaces, a multi-file field adds; Remove works *(test data)* | ✅ `onboarding_config_test` | ☐ | ☐ | ☐ | — |
| 4.4 | Custom file field: a wrong type or a file over 5 MB is refused before upload; a required file field blocks Save & Continue | ✅ `onboarding_config_test` | ☐ | ☐ | ☐ | — |
| 4.5 | Custom file field with no connection (airplane mode) → "Unable to upload/remove the document. Please check your internet connection…", no technical text | ✅ `onboarding_config_test` (Phase 11.7) | ☐ | ☐ | ☐ | — |
| 4.6 | Two file fields on one step work independently | ✅ `onboarding_config_test` | ☐ | ☐ | ☐ | — |
| 4.7 | PAN: invalid PAN refused before upload; valid PAN saved, then the PAN card uploads *(test data)* | ✅ `onboarding_hardening_test` | ☐ | ☐ | ☐ | — |
| 4.8 | Documents step: configured document types; Save Draft shows the server's verdict; submit only when required documents are present | ✅ `onboarding_config_test`, `onboarding_hardening_test` | ☐ | ☐ | ☐ | — |
| 4.9 | HR: Candidate Review → onboarding approval shows the identity section with masked identifiers; optional UAN, name as per Aadhaar, PAN and assessment; "Needs Revision" label *(test applicant only)* | ✅ `candidate_review_approval_test` | ☐ | ☐ | — | ☐ |
| 4.10 | After approval with a pending assessment → only the assessment portal is reachable; take the assessment → dashboard opens once the server confirms | ✅ `assessment_gate_test`, `assessment_take_test` | ☐ | ☐ | ☐ | — |
| 4.11 | My Assessments lists assigned assessments and results | ✅ `my_assessments_test` | ☐ | ☐ | ☐ | — |

### 5. Dashboard and profile

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 5.1 | Dashboard matches the role (Employee / Manager / HR / Admin); Quick Access shows only permitted tiles | ✅ `dashboard_category_test`, `dashboard_shortcuts_test` | ☐ | ☐ | ☐ | ☐ |
| 5.2 | Profile → Work Information: Reporting Manager, Reporting Approver, HR, Notice Period; "Not assigned" where empty | ✅ `profile_work_info_test` | ☐ | ☐ | ☐ | — |

### 6. Profile documents (upload, replace, in-app viewing, cleanup)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 6.1 | Profile → Documents lists configured types in order, "Not uploaded" where missing; retired types view-only | ✅ `profile_documents_section_test`, `profile_document_listing_test` | ☐ | ☐ | ☐ | — |
| 6.2 | Upload a missing document (PDF/JPG/PNG ≤ 5 MB); success only after the server saves it *(test data)* | ✅ `profile_documents_section_test`, `profile_documents_datasource_test` | ☐ | ☐ | ☐ | — |
| 6.3 | Replace a single-file document asks first; Cancel sends nothing; a multi-file type adds without asking | ✅ `profile_documents_section_test` | ☐ | ☐ | ☐ | — |
| 6.4 | View a **PDF** → opens inside the app (pinch-zoom), not in another app | ✅ `profile_documents_section_test` (PDF view replaced by a stand-in) | ☐ | ☐ **release-build risk (`pdfx` native renderer)** | ☐ | — |
| 6.5 | View a **JPG/PNG** → opens inside the app with zoom | ✅ `profile_documents_section_test`, `profile_document_cleanup_test` | ☐ | ☐ | ☐ | — |
| 6.6 | Close the viewer (Close and system Back) → back on Documents | ✅ `profile_document_cleanup_test` | ☐ | ☐ | ☐ | — |
| 6.7 | Sign out (or let the session expire) while a document is open → the viewer closes at once and Sign In is shown | ✅ `profile_document_cleanup_test` | ☐ | ☐ | ☐ | — |
| 6.8 | Downloads use the user's own sign-in; no file is handed to another app | ✅ `profile_document_viewer_test` | ☐ | ☐ | ☐ | — |
| 6.9 | Leftover temporary document files are cleared at app start | ✅ `profile_document_cleanup_test` | ✅ (2026-11-05, synthetic files) | ☐ | — | — |

### 7. Attendance, work mode, face capture, GPS, month navigation
*Real punches create attendance records. Test-company accounts only.*

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 7.1 | First clock-in asks for location; deny it → a clear message, no punch | — (permission denial has no automated test) | ☐ | ☐ | ☐ | — |
| 7.2 | Outside the geofence → the server's refusal; inside → punch succeeds | ✅ `clock_punch_flow_test` | ☐ | ☐ | ☐ | — |
| 7.3 | Work mode: with an approved WFH request for today the punch is WFH, otherwise office — on both the dashboard card and My Attendance | ✅ `clock_punch_flow_test` | ☐ | ☐ | ☐ | — |
| 7.4 | Face capture (when the company requires it): camera prompt, liveness check, match accepted; a covered face or a photo of a face fails | ✅ `clock_punch_flow_test` (capture simulated) | ☐ | ☐ **release-build risk (ML Kit / TFLite)** | ☐ | — |
| 7.5 | Clock-out works; today's ring updates; a completed day shows "Attendance Completed" | ✅ `day_completed_test` | ☐ | ☐ | ☐ | — |
| 7.6 | My Attendance: Next month moves forward one month at a time, into future months, with no limit | ✅ `attendance_month_navigation_test` | ☐ | ☐ | ☐ | — |
| 7.7 | December → January of the next year, and January → December of the previous year; the heading and figures match the month shown | ✅ `attendance_month_navigation_test` | ☐ | ☐ | ☐ | — |

### 8. WFH

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 8.1 | Medical WFH: proof required; only PDF/JPG/PNG within the limit; a normal WFH needs no file *(test data)* | ✅ `wfh_medical_request_test` | ☐ | ☐ | ☐ | — |
| 8.2 | WFH daily report: submit and history; manager review *(test data)* | ✅ `wfh_daily_reports_tab_test`, `wfh_report_data_test` | ☐ | ☐ | ☐ | ☐ |

### 9. Announcements and Contact Matrix

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 9.1 | Announcements load more as you scroll beyond the first page; pull to refresh | ✅ `announcements_pagination_test` | ☐ | ☐ | ☐ | — |
| 9.2 | Post / Edit / Delete only for those permitted | ✅ `permission_visibility_test` | ☐ | ☐ | ☐ | ☐ |
| 9.3 | Contact Matrix shows contacts by escalation level; manage actions only with `can_manage` | ✅ `contact_matrix_test` | ☐ | ☐ | ☐ | ☐ |

### 10–11. Documents and policy acknowledgement

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 10.1 | Documents list opens; preview and download work; Upload/Delete only with permission | ✅ `permission_visibility_test` | ☐ | ☐ | ☐ | ☐ |
| 10.2 | Employee: pending policy banner → Open → read → tick → Acknowledge → banner disappears *(test policy)* | ✅ `policy_ack_test` | ☐ | ☐ | ☐ | — |
| 10.3 | HR: View acknowledgements shows "X of Y" with filters *(test policy)* | ✅ `policy_ack_test` | ☐ | ☐ | — | ☐ |
| 10.4 | HR: upload with "Employees must read and acknowledge" ticked *(test document)* | ✅ `policy_ack_test` | ☐ | ☐ | — | ☐ |

### 12. Leave, separation and notice period

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 12.1 | Apply for leave and cancel it *(test data)* | — (existing feature) | ☐ | ☐ | ☐ | — |
| 12.2 | Separation form pre-fills the assigned notice period and expected last working day *(submit only in a test company)* | ✅ `separation_notice_period_test` | ☐ | ☐ | ☐ | — |
| 12.3 | Manager/HR: separation in Team Approvals → Approve (optional notes) or Reject (reason required); refusals shown, never success *(test request)* | ✅ `separation_approvals_test` | ☐ | ☐ | — | ☐ |
| 12.4 | Employee with a fully approved separation: dashboard Notice Period card shows days remaining, approval date, last working day, type; "Done / Notice completed" after the last day; View details opens the request | ✅ `employee_notice_period_test` | ☐ | ☐ | ☐ | — |
| 12.5 | Employee without an approved separation: no Notice Period card; Manager/HR/Admin dashboards never show it | ✅ `employee_notice_period_test` | ☐ | ☐ | ☐ | ☐ |

### 13. Payslips

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 13.1 | My Payslips shows payslips (the 20 newest, as on web); Acknowledge works on a sent payslip | — (existing feature) | ☐ | ☐ | ☐ | — |
| 13.2 | Raise Query on a sent/acknowledged payslip → appears as Open; Raise Query disappears *(test payslip)* | ✅ `payslip_queries_test` | ☐ | ☐ | ☐ | — |
| 13.3 | Open a payslip → earnings, deductions, reimbursements and net pay are shown on screen and match the test payslip | — (existing feature) | ☐ | ☐ | ☐ | — |
| 13.4 | **Download / print:** the mobile app has **no print function**. An "Open PDF" button appears only when the server supplies a payslip PDF link (`payslip_pdf`); the code notes the backend does not populate it today, so the button is **expected to be absent**. If it does appear, it opens the PDF in another app (browser/viewer) — record which. Printing, if needed, is done from that app or from web. | — (no automated test) | ☐ | ☐ | ☐ | — |
| 13.5 | HR: a payslip query is resolved from Approvals and the employee sees the response *(test payslip)* | ✅ `payslip_query_resolution_test` | ☐ | ☐ | ☐ | ☐ |

### 14. Manager dashboard, permissions and disabled modules

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 14.1 | Manager sees the Team Console: team size, pending approvals, team attendance, upcoming leaves, birthdays | ✅ `manager_dashboard_test` | ☐ | ☐ | — | ☐ |
| 14.2 | An employee does not see manager, HR or admin menus; deep links return to the dashboard | ✅ `access_control_test` | ☐ | ☐ | ☐ | — |
| 14.3 | Buttons for actions the user can't perform are hidden (employees Add/Edit/Bulk Import, documents Upload/Delete, announcements Post) | ✅ `permission_visibility_test` | ☐ | ☐ | ☐ | ☐ |
| 14.4 | A disabled module shows "… is not enabled for your company", not an empty screen | ✅ `module_disabled_test` | ☐ | ☐ | ☐ | ☐ |
| 14.5 | Airplane mode → "No internet connection" with Retry | — (no automated test) | ☐ | ☐ | ☐ | — |

### 15. Attendance policy settings (HR/Admin)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 15.1 | Settings → Attendance Rules shows Missing Clock Out, Permitted Early Leaves, WFH daily report rule, Late Mark rule (every N / after allowance), Full Day 7.5 hours | ✅ `attendance_policy_rules_test` | ☐ | ☐ | — | ☐ |
| 15.2 | Saving a card changes only that section; values set on web that the app doesn't list are shown as "(current)" and kept *(test company only)* | ✅ `attendance_policy_rules_test` | ☐ | ☐ | — | ☐ |
| 15.3 | Without `settings.edit` the screen is read-only, with no Save | ✅ `attendance_policy_rules_test` | ☐ | ☐ | — | ☐ |

### 16. HR Attendance tabs (HR/Admin)
*Test company only. Exports contain colleagues' attendance data: save them only to a test location and delete them afterwards.*

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 16.1 | Attendance opens with its tabs (records, corrections, Shift Assignment, Weekly Off Assignment and the others shown for the role); switching tabs keeps filters | Partly: `attendance_export_test`, `shift_assignment_test`, `weekly_off_assignment_test` | ☐ | ☐ | — | ☐ |
| 16.2 | Open a record → detail with Clock In / Clock Out location and GPS accuracy guidance (display only); corrections and audit history listed | ✅ `punch_location_detail_test` | ☐ | ☐ | — | ☐ |
| 16.3 | HR correction card: approve / reject a test correction; the server's refusal is shown, never a false success *(test correction)* | — (existing feature) | ☐ | ☐ | — | ☐ |
| 16.4 | Without `attendance.create` there is no Import button; Export stays when `attendance.export` is held | ✅ `attendance_export_test`, `attendance_import_modes_test`, `p0_permission_parity_test` | ☐ | ☐ | — | ☐ |

### 17. Attendance export and import (HR/Admin)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 17.1 | Export a single day, a month and a date range → the system save dialog opens; the CSV is saved where chosen with the expected file name; cancelling saves nothing | ✅ `attendance_export_test` | ☐ | ☐ | — | ☐ |
| 17.2 | Import — **All Employees** (bulk): choose a test CSV → Upload → result shows the server's message, Total / Success / Failed / Skipped and row errors with how to fix them; the list refreshes *(test company, test CSV only)* | ✅ `attendance_import_modes_test` | ☐ | ☐ | — | ☐ |
| 17.3 | Import — **One Employee**: search and pick a test employee, optionally a From/To date → only that employee's rows in range are imported; rows for others or outside the range are reported as row errors *(test data)* | ✅ `attendance_import_modes_test` | ☐ | ☐ | — | ☐ |
| 17.4 | One Employee mode without an employee, or with From after To → refused before upload; switching back to All Employees clears the employee and dates | ✅ `attendance_import_modes_test` | ☐ | ☐ | — | ☐ |
| 17.5 | Upload a file where every row fails → the result and its row errors are shown (not a bare error); a file over 500 rows reports it is processed in the background | ✅ `attendance_import_modes_test` | ☐ | ☐ | — | ☐ |
| 17.6 | Download the sample CSV/XLSX → saved through the system save dialog | — (no automated test) | ☐ | ☐ | — | ☐ |

### 18. Notice Period settings and import (HR/Admin)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 18.1 | Settings → Notice Period tile opens the list (search, department filter, paging); Back returns to Settings | ✅ `notice_period_settings_test` | ☐ | ☐ | — | ☐ |
| 18.2 | With `employees.edit`: change a test employee's notice period (whole days 0–365; blank clears it) → saved, tick shown, list refreshed; invalid values refused with web's messages *(test employee)* | ✅ `notice_period_settings_test` | ☐ | ☐ | — | ☐ |
| 18.3 | Without `employees.edit`: values read-only with the "You can view notice periods…" note and no Import | ✅ `notice_period_settings_test` | ☐ | ☐ | — | ☐ |
| 18.4 | Import a test CSV and a test XLSX → Preview (nothing saved) with per-row status → "Update N employee(s)…" → confirm → result; wrong type, over 5 MB or empty file refused before upload *(test company only)* | ✅ `notice_period_settings_test` | ☐ | ☐ | — | ☐ |
| 18.5 | The new value shows on Employee Detail and pre-fills the employee's separation form | ✅ `employee_detail_notice_reset_test`, `separation_notice_period_test` | ☐ | ☐ | ☐ | ☐ |

### 19. Monthly Leave Management and Monthly Credit Settings (HR/Admin)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 19.1 | Settings → Leave Policy → Monthly Leave: current assignments for a month; manual entry for a test employee; bulk assign *(test company)* | ✅ `monthly_leave_management_test` | ☐ | ☐ | — | ☐ |
| 19.2 | Monthly CSV/XLSX import: sample download, preview, confirm; errors shown per row *(test file)* | ✅ `monthly_leave_management_test` | ☐ | ☐ | — | ☐ |
| 19.3 | Monthly Credit Settings on a leave type: Annual/Monthly schedule, carry-forward toggle and rules-from date load; Save sends them with the policy; Discard restores; a server refusal is shown and the values kept. As on web, the section is shown to Settings viewers and the server decides whether a save is allowed. | ✅ `monthly_credit_settings_test` | ☐ | ☐ | — | ☐ |
| 19.4 | Employee sees the monthly breakdown of the credited leave type | ✅ `leave_monthly_breakdown_test` | ☐ | ☐ | ☐ | — |

### 20. Dashboard additions

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 20.1 | Upcoming Holidays card lists the next holidays with the correct dates (company and own branch) | ✅ `upcoming_holidays_test` | ☐ | ☐ | ☐ | — |
| 20.2 | Employee (no `employees.view`) with a colleague's birthday today → card shows name and designation · department only (no age or date of birth); nothing shown on a day without birthdays | ✅ `employee_birthdays_test` | ☐ | ☐ | ☐ | — |
| 20.3 | HR and Admin dashboards still show their own birthday widgets | ✅ `employee_birthdays_test` | ☐ | ☐ | — | ☐ |
| 20.4 | Global search (users with `employees.view`) finds a test employee by name or ID; absent for others | ✅ `global_search_test` | ☐ | ☐ | ☐ | ☐ |
| 20.5 | HR dashboard: employee lifecycle notice details for a test separation | ✅ `hr_notice_period_lifecycle_test` | ☐ | ☐ | — | ☐ |

### 21. Shifts, Weekly Off Patterns and assignments (HR/Admin)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 21.1 | Shift Masters: create, edit, deactivate a test shift; actions follow `attendance.create/edit/delete` | ✅ `shift_master_test` | ☐ | ☐ | — | ☐ |
| 21.2 | Shift Assignment: assign a test shift to a test employee from a date; the list updates; the server's refusal shown | ✅ `shift_assignment_test` | ☐ | ☐ | — | ☐ |
| 21.3 | Settings → Attendance Rules → Weekly Off Patterns: create, edit and deactivate a test pattern; the default and assigned patterns cannot be deactivated | ✅ `weekly_off_pattern_test` | ☐ | ☐ | — | ☐ |
| 21.4 | Mark a test pattern as Default → it shows the Default badge; the "No default Weekly Off Pattern is configured" notice disappears. With no active default (test company only) the notice is shown. | ✅ `weekly_off_pattern_test`, `attendance_rules_weekly_off_grid_test` | ☐ | ☐ | — | ☐ |
| 21.5 | Weekly Off Assignment: assign a pattern to a test employee; only active patterns offered | ✅ `weekly_off_assignment_test` | ☐ | ☐ | — | ☐ |
| 21.6 | The old "Weekly Off Days" grid is no longer shown on Attendance Rules; Save All still succeeds and other sections are unchanged | ✅ `attendance_rules_weekly_off_grid_test` | ☐ | ☐ | — | ☐ |

### 22. Employee Leave Credits (HR with `leave.approve`)
*Adjustments and reversals change real leave balances. Test employee in a test company only.*

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 22.1 | Employee Detail → Leave → "Manage Leave Credits": statement for the year (annual leave types), previous year, monthly view, adjustment history | ✅ `employee_leave_credits_test` | ☐ | ☐ | — | ☐ |
| 22.2 | Adjust: leave type, days (e.g. 1 or -0.5), reason → Review → Confirm → success message; statement and Leave tab refresh *(test employee)* | ✅ `employee_leave_credits_test` | ☐ | ☐ | — | ☐ |
| 22.3 | Reverse an adjustment with a reason → "Adjustment reversed."; already-reversed entries and reversals offer no Reverse | ✅ `employee_leave_credits_test` | ☐ | ☐ | — | ☐ |
| 22.4 | Double-tap Confirm → one change only; a server refusal (e.g. balance below zero) is shown and nothing changes | ✅ `employee_leave_credits_test` | ☐ | ☐ | — | ☐ |
| 22.5 | Without `leave.approve`, or for an employee outside the user's scope, the section is not shown | ✅ `employee_leave_credits_test` | ☐ | ☐ | — | ☐ |

### 23. Leave apply and approval by role

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 23.1 | Employee applies for leave *(test data)* → Manager sees it in Team Approvals and approves; the employee's balance and request status update | — (existing feature) | ☐ | ☐ | ☐ | ☐ |
| 23.2 | Manager rejects with a reason → the employee sees the reason | — (existing feature) | ☐ | ☐ | ☐ | ☐ |

### 24. Permissions by role (P0 parity)

| # | Step and expected result | Auto | Emu | Device | Employee | HR/Admin |
|---|---|---|---|---|---|---|
| 24.1 | Without `settings.edit`: Company, Financial Year, Departments/Designations and Roles are read-only (no Save, Add, Edit or toggles) | ✅ `p0_permission_parity_test` | ☐ | ☐ | — | ☐ |
| 24.2 | Branches: add/edit/delete only with the branch-management permission | ✅ `p0_permission_parity_test` | ☐ | ☐ | — | ☐ |
| 24.3 | Leave Policy → carry-forward rules editable only with `leave.edit` | ✅ `p0_permission_parity_test` | ☐ | ☐ | — | ☐ |
| 24.4 | Employee and Manager accounts never see HR settings, imports, exports, Leave Credits or Notice Period editing | ✅ `access_control_test`, `p0_permission_parity_test` | ☐ | ☐ | ☐ | ☐ |

## Role coverage summary

| Role | Sections to run signed in |
|---|---|
| Employee | 1, 3–13, 20.1, 20.2, 23 |
| Manager | 1, 12.3, 14, 23, 24.4 |
| HR / Admin | 1, 4.9, 9–12, 13.5, 15–22, 24 |

## Results log

| Date | Build | Device / emulator | Account role | Items | Result | Evidence |
|---|---|---|---|---|---|---|
| 2026-11-04 | Phase 9 release APK (versionCode 6) | Emulator, Android 14 | none | Install and launch to Sign In | Pass | No crashes in logcat |
| 2026-11-05 | Debug APK (Phase 11.5 source) | Emulator `flutter_emulator` | none | Install and launch to Sign In; 6.9 temp-file cleanup at start | Pass | logcat clean; folders emptied |
| — | New release AAB (**not yet built**) | Real device | Employee, Manager, HR | All signed-in items, including sections 16–24 | **Not run** | No authorised test account or device provided yet |

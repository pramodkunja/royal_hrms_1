# Internal Testing Checklist — Royal HRMS Android 1.0.0 (6)

**For:** the internal tester named by the administrator.
**Build:** `app-release.aab` (versionCode 6), installed from the Play **internal testing** track (not a sideloaded debug build).
**Accounts:** use only test accounts the administrator has issued for this purpose, in a test company or with HR's agreement. Do not use real employees' accounts.

## Rules

- Do not submit real attendance, leave, WFH, expense, separation, payslip-query or acknowledgement records unless HR has said the record is a test and will be cleaned up.
- Where a step would create a real business record and there is no approved test data, mark it **Not run (needs approved test data)**. Do not mark it passed.
- Record the device model, Android version, account role and time for every run.
- Take a screenshot as evidence for each Pass or Fail.

## Accounts needed (from the administrator)

| Role | Needed for |
|---|---|
| Employee, onboarding complete | Most employee flows |
| Employee with forced password change set | Section 3 |
| New hire with onboarding pending | Section 4 |
| Manager (team-managing role with direct reports) | Section 14 and approvals |
| HR (documents.edit, separation.approve) | Policy report, separation approvals |
| Reviewer account for Google | App access instructions (see the Console checklist) |

## Checklist

Result: Pass / Fail / Not run. Add notes and evidence for each item.

### 1. Login and logout
- [ ] Sign in with company code, email and password. Expected: the role's dashboard opens.
- [ ] Wrong password. Expected: the server's message is shown and you stay on Sign In.
- [ ] Log out. Expected: you return to Sign In, and Back does not reopen the dashboard.

### 2. Session
- [ ] Kill the app and reopen it. Expected: still signed in.
- [ ] Leave the app idle past the access-token lifetime, then use it. Expected: it refreshes silently and keeps working.
- [ ] Revoke the session on the server (HR logs the user out or changes the password). Expected: the next action returns you to Sign In with no loop.

### 3. Forced password change
- [ ] Sign in with the flagged account. Expected: only Change Password is reachable.
- [ ] Change the password. Expected: you continue to onboarding or the dashboard and are not asked again.

### 4. Onboarding and assessment gate
- [ ] A new hire sees only the onboarding wizard, with the admin-configured fields and document types.
- [ ] Reopen the app mid-way. Expected: it resumes at the first unfinished step.
- [ ] PAN: an invalid PAN is refused before upload. A valid PAN is saved, then the PAN card uploads. *(Test data only.)*
- [ ] Save Draft on Documents shows the server's verdict.
- [ ] After HR approval with a pending assessment, only the assessment portal is reachable. Take the assessment. Expected: the dashboard opens after the server confirms completion.

### 5. Dashboard and profile
- [ ] The dashboard matches the role (Employee / Manager / HR / Admin).
- [ ] My Profile → Work Information shows Reporting Manager, Reporting Approver, HR and Notice Period, with "Not assigned" where empty.

### 6–8. Attendance, face capture, GPS
*Real punches create attendance records. Test-company accounts only.*
- [ ] First clock-in asks for location permission. Deny it. Expected: a clear message and no punch.
- [ ] Allow location. Outside the branch geofence the server's refusal is shown. Inside it, the punch succeeds.
- [ ] Face capture (when the company requires it): the camera permission prompt appears, the liveness check runs, and a match is accepted. Covering the face or using a photo of a face fails.
- [ ] **Release-build risk:** confirm face capture works in this Play-installed build. It uses on-device ML libraries that code shrinking could affect.
- [ ] Clock-out works, and today's ring updates.

### 9. WFH and medical proof
- [ ] Apply for medical WFH. Expected: the proof upload is required, and only PDF/JPG/PNG up to the size limit is accepted. *(Test data only.)*

### 10–11. Documents and policy acknowledgement
- [ ] Documents list opens; preview and download work.
- [ ] Employee: pending policy banner on the dashboard → Open → read → tick → Acknowledge. Expected: the banner disappears. *(Test policy only.)*
- [ ] HR: View acknowledgements shows "X of Y" with the filters. *(Test policy only.)*
- [ ] HR: upload with "Employees must read and acknowledge" ticked. *(Test document only.)*

### 12. Leave and separation
- [ ] Apply for leave and cancel it. *(Test data.)*
- [ ] Separation: the form pre-fills the notice period and expected last working day. *(Submit only in a test company.)*
- [ ] Manager or HR: the separation appears in Team Approvals. Review & decide → Approve (optional notes) or Reject (reason required). *(Test request only.)*

### 13. Payslips
- [ ] My Payslips shows payslips. Acknowledge works on a sent payslip.
- [ ] Raise Query (sent or acknowledged payslip): sends, the query appears as Open, and Raise Query disappears. *(Test payslip only.)*

### 14. Manager dashboard and permissions
- [ ] Manager sees the Team Console: team size, pending approvals, team attendance, upcoming leaves.
- [ ] An employee does not see manager, HR or admin menus, and deep links to them return to the dashboard.
- [ ] A disabled module shows "… is not enabled for your company", not an empty screen.
- [ ] Airplane mode shows "No internet connection" with Retry.

## Results so far

| Item | Result | Evidence |
|---|---|---|
| Release build installs and launches to Sign In (emulator, Android 14) | Pass | Phase 9 release APK, same configuration as the AAB; no crashes in logcat |
| Every signed-in item above | **Not run** | No authorized test account has been provided |

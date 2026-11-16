# Royal HRMS — Web-to-Mobile Parity Re-Audit (Task 79)

**Date:** 2026-11-16 · **Type:** audit only (no code changes) · **Scope:** current web frontend + Django backend (read-only) vs Flutter app in `mobile_app/`.

**How this was produced.**
- Seven read-only static reviews ran in parallel, one per module group: auth and dashboards; employees and organisation; attendance and Face ID; leave and WFH; payroll, expenses, assets, documents and separation; recruitment and referrals; approvals, settings and audit.
- Every high-severity finding below was then re-checked directly in the code by the lead reviewer.
- Each slice's row counts were recounted from its table; three slices had reported inconsistent totals.

**What this audit is not.**
- Nothing was run on an emulator or device.
- No production API was called.
- No test suite was run for this audit; the last full run, after Task 78, passed 2,550 tests.

"Complete" means the code paths match on reading. It does not mean the flow was exercised live. **No row in this report is device-verified.**

---

## A. Executive summary

**Inventory:** 357 auditable web features (screens, tabs, sections, actions, filters, forms and states) across 58 non–Platform-Admin web routes, plus the cross-cutting auth, notification and module-gating behaviour.

**Platform Admin is an approved web-only exception.** Its 14 routes are listed separately in the next section and are not counted in the totals.

| Classification | Count | Share of 357 |
|---|---|---|
| Complete | 236 | 66.1 % |
| Partial | 47 | 13.2 % |
| Missing | 4 | 1.1 % |
| Intentional exception | 24 | 6.7 % |
| Blocked (needs backend / web / product decision) | 16 | 4.5 % |
| Unverified (evidence insufficient) | 30 | 8.4 % |
| **Total** | **357** | 100 % |

**Completion = Complete ÷ (all rows − Intentional exceptions) = 236 ÷ 333 = 70.9 %.**
- **Denominator:** every audited feature that mobile is expected to match. That leaves out the 24 approved or deliberate exceptions, Platform Admin, and the web-only admin payroll screens.
- **Unverified and Blocked rows** stay in the denominator. They are not counted as complete.
- **If the 30 Unverified rows all turn out Complete,** the ceiling is 266 ÷ 333 = 79.9 %.

**Per module group**

| Group | Rows | Complete | Partial | Missing | Intentional | Blocked | Unverified |
|---|---|---|---|---|---|---|---|
| Auth, dashboards, profile, self-service | 67 | 34 | 11 | 0 | 3 | 3 | 16 |
| Employees, organisation, roles | 50 | 35 | 6 | 1 | 2 | 0 | 6 |
| Attendance, Face ID | 48 | 31 | 7 | 1 | 1 | 5 | 3 |
| Leave, leave policy, holidays, WFH | 41 | 31 | 9 | 0 | 1 | 0 | 0 |
| Payroll, expenses, assets, documents, separation | 48 | 38 | 5 | 1 | 2 | 2 | 0 |
| Recruitment, assessments, referrals | 57 | 39 | 3 | 0 | 9 | 1 | 5 |
| Approvals, settings, audit, reports, announcements, modules | 46 | 28 | 6 | 1 | 6 | 5 | 0 |
| **Total** | **357** | **236** | **47** | **4** | **24** | **16** | **30** |

**Headline risks**
1. **P0, backend: mobile punches are never face-checked by the server.**
   - Where: `apps/attendance/services_face_matching.py:207` verifies only `source in (web, voice)`; mobile sends `source='mobile'` (`attendance_remote_datasource.dart:49`), and the client chooses the value.
   - Effect: with Face ID mandatory, any authenticated client can clock in with no face. On mobile, only on-device liveness stands between a user and a no-face punch, and that liveness is itself unverified on devices (FACE-06/07/08).
2. **P1, Flutter: Approvals inbox hides second-level items.** The default "Pending" filter compares the raw status, so `l2_pending` leave, WFH and correction rows are hidden (APR-05).
3. **P1, Flutter: onboarding document preview does nothing.** The candidate-review "View" button is `onPressed: () {}` (REC-27).
4. **P1, Flutter: Leave Analytics and the Home leave widget use the financial year.** They send no `year`, so from January to March they show different figures from web (LV-18).
5. **P1, backend: several branch-scoping and data-exposure gaps.** They cover the audit log, Document Center, email logs, All Referrals, the onboarding pipeline, employee documents by ID, attendance lookups and the geofence modes. See Section D.

---

## Platform Admin — approved web-only exception (not counted)

`/platform-admin`, `/platform-admin/login`, `/platform-admin/forgot-password`, `/platform-admin/account`, `/platform-admin/admins`, `/platform-admin/audit-log`, `/platform-admin/companies`, `/platform-admin/email-settings`, `/platform-admin/settings`, `/platform-admin/saas`, `/platform-admin/saas/history`, `/platform-admin/saas/plans`, `/platform-admin/saas/registrations`, `/platform-admin/saas/subscriptions`.

Mobile contains no Platform Admin code (`grep -r platform-admin mobile_app/lib` returns nothing), which is consistent with the exception. The other approved web-only areas are admin payroll runs, payslips and payroll config (PAY-09, PAY-10) and the dashboard Payroll tiles (DASH-20, DASH-23). These are counted as Intentional exceptions.

---

## Known unresolved issues — re-check results

| Issue | Status now | Rows |
|---|---|---|
| Admin dashboard large-text overflows (quick-access tiles, dashboard_section widgets) | **Still open** | DASH-28 (P2), DASH-29, DASH-30 |
| Leave cancellation's redundant year-less balance refresh | Still in code, but nothing watches that provider, so **no live request** (dead code) | LV-07 (P3) |
| `admin_dashboard_view.dart` whitespace churn from Task 74 | **Unchanged**; no authorised pre-format source exists (see Task 78) | — |
| Promotion / holiday notification behaviour | Mobile routing correct; **backend still never creates holiday notifications** | DASH-35, DASH-36 |
| Approvals reachability policy gaps | **Still open on both platforms** (needs a decision) | APR-02 |
| Referral branch permissions / backend not persisting `branch` | Mobile gate correct; **backend still drops branch** | REF-08 |
| Audit Log module mapping / subscription filtering | Mobile correct; **backend key mismatch and missing exclusion remain** | AUD-04, AUD-07 |
| Leave balance import permission mismatch (leave.edit vs leave.approve) | **Shared web/backend mismatch remains** | LVP-13, LVP-11 |
| Notification Settings permission | **Product decision outstanding** | DASH-37, SET-06 |
| Backend authorisation / branch scoping from earlier audits | Several **confirmed and newly found** | Section D |

---

## C. Missing and partial features — prioritised

### P0
| ID | Owner | Issue |
|---|---|---|
| FACE-06 | Backend | The server face check is skipped for `source='mobile'`. A punch with no face is possible whenever Face ID is mandatory. |

### P1
| ID | Owner | Issue |
|---|---|---|
| APR-05 | Flutter | The Approvals "Pending" filter hides `l2_pending` and `resubmit` rows. HR L2 approvers see an empty inbox. |
| REC-27 | Flutter | Onboarding document "View" does nothing. Approvers can't inspect ID or bank documents before approving. |
| LV-18 | Flutter | Analytics and the Home leave widget send no year, so they use the financial year where web uses the calendar year. |
| FACE-07, FACE-08 | Flutter (device) | Descriptor parity and liveness are unproven on real devices. Mobile liveness uses different signals from web. |
| DOC-09, AUD-05, ATT-34, ATT-35, REC B1/B2, EMP backend P1s, LV backend B1/B2 | Backend | Scoping and data-exposure gaps; see Section D. |

### P2
| ID | Owner | Issue |
|---|---|---|
| APR-08, APR-12 | Flutter | Leave approval remarks are collected, then dropped from the request (single and bulk). |
| LV-08 | Flutter | Apply Leave rounds balances (2.5 shows as 3). |
| LV-11 | Flutter | The preview shows only counts, not web's full breakdown. |
| LV-15 | Flutter | The "Draft" button says "Draft saved" but saves nothing. |
| LVP-05 | Flutter | Carry-forward type, mode and expiry can't be configured; the code comment wrongly calls them non-existent. |
| LVP-09 | Flutter | The accrual-rules list is local seed data with Add/Edit and no backend. |
| REF-06 | Flutter | Hard-coded ₹10,000 referral bonus panel with no data source. |
| ASM-12 | Flutter (device) | The assessment timer may drift when the app is in the background. |
| EMP-06 | Flutter | Employee stats depend on `departments.view` and are unscoped. |
| EMP-10 | Flutter | Add Employee always requires Department, so a Branch Admin can't be created. |
| ROLE-03 | Flutter | Role presets differ from web. |
| ATT-13 | Flutter | The HR attendance branch filter isn't locked for restricted users. |
| ATT-15 | Product | Mobile-only Reprocess / Add Record actions have no client permission check. |
| ATT-16 | Flutter | Employee Month View is read-only. |
| FACE-11 | Flutter | The toggle text implies the server face-checks mobile punches. |
| AUTH-07 | Flutter | Permissions in a refreshed token are not applied until the next login. |
| DASH-28 | Flutter | Quick-access tiles overflow at large text. |
| DOC-02 | Flutter | Document search runs on the client over the first 50 documents only. |
| PAY-04 | Flutter / product | No way to produce a payslip PDF on mobile. |
| APR-02, DASH-37, SET-09, ATT-36, AUD-04, EXP-06, REF-05 | Decision / backend | See Section D. |

### P3 (cosmetic or low risk)
- **Flutter display:**
  - AUTH-06 session-expired notice;
  - DASH-03 birthday modal;
  - DASH-09 two missing employee tiles;
  - DASH-12 truncated count;
  - DASH-29/30 large-text risks;
  - DASH-31 avatar photo.
- **Notifications:** DASH-34 polling only; DASH-38 Approval toggle.
- **Org chart:** PROF-15 zoom and header.
- **Employees:** EMP-03/04 filters; EMP-09 subtitle; EMP-12 import sample and error report.
- **Company:** ORG-08 plan tab.
- **Attendance and face:** ATT-12 branch banner; ATT-22 shared web 403; FACE-01 card; FACE-10 telemetry.
- **Leave:** LV-07 dead refresh; LVP-03 delete UX; LVP-16 holiday branch filter.
- **Expenses and documents:** EXP-01 tiles; EXP-03 date limits; DOC-04 size check.
- **Separation:** SEP-08 assignee tick; SEP-11 backend serializer.
- **Recruitment and referrals:** REC-10 "Set Details"; REF-03 paging.
- **Settings, audit, approvals:** SET-02 hub tiles; SET-06 toggle; AUD-02 default dates; APR-09 template picker.
- **Dead code and stale comments:**
  - `dashboard_screen.dart` placeholder;
  - stale comments in `nav_config.dart:62-65`, `api_constants.dart:487-490`, `access_control.dart:158` (Reports) and the carry-forward tab "404".

---

## D. Web / backend blockers (need another team's decision or implementation)

**Security and data exposure (backend)**

| Sev | Where | Problem |
|---|---|---|
| P0 | `attendance/services_face_matching.py:207` + `serializers_my_attendance.py:34` | Mobile punches are never face-matched, and the client sets `source` (FACE-06). |
| P1 | `attendance/services_geofencing.py:418-429` | The `field`, `client_location` and `remote_office` modes skip the geofence, and the client chooses the mode (ATT-34). |
| P1 | `attendance/views/my_attendance.py:54-77` | Another employee's stats and calendar are readable with attendance.view or employees.view; a user with no branch can read everyone (ATT-35). |
| P1 | `accounts/views.py:4169` | The audit log isn't branch-filtered when the user's branch is blank (AUD-05). |
| P1 | `accounts/views.py:2503-2546` | The Document Center ignores document branch visibility for list and detail (DOC-09). Mutations check only the codename. |
| P1 | `recruitment/views.py:1052-1083`, `1659-1697` | Email logs and All Referrals are company-wide for any recruitment.view holder (candidate personal data). |
| P1 | `accounts/views.py:5938-5957` | The onboarding pipeline view is unscoped (name, email and phone of pending hires). |
| P1 | `accounts/views.py:5155` | Employee onboarding/KYC documents can be streamed by sequential ID with no branch check. |
| P1 | `hrms/views/leave.py:849-858` vs `1011-1027` | Leave preview and submit disagree for monthly-credit policies, so LOP and the "sufficient balance" message can be wrong on both apps. |
| P1 | `hrms/views/leave.py` (import 1988-1993; credit-all 696-705; carry-forward 1702-1725), `holidays.py` | Company-wide balance, policy and holiday writes for any leave.approve holder, who are commonly managers. |
| P2 | `accounts/views.py:5417, 5512` | Custom employee files can be viewed or deleted by ID across branches. |
| P2 | `accounts/views.py:3109+, 6676+` | Employee create and bulk import aren't limited to the creator's branch. |
| P2 | `hrms/views/expenses.py:366-372` | Expense stats are company-wide for approvers (EXP-06). |
| P2 | `separation.py:187-193` | employees.view alone can file a separation for others. |
| P2 | `recruitment/views.py:758, 946, 1467; 366-368` | Candidate GETs skip the access check; the candidate list fails open for users with no branch. |
| P2 | many helpers | A user with an empty branch is treated as unrestricted. |
| P2 | `core/permissions.py:58-82` | HasSettingsPermission denies reads to settings.edit-only roles (SET-09). |
| P2 | `apps/dashboard/views/overview.py`, `people.py` | Several HR dashboard widgets are company-wide for branch HR. |
| P2 | tenants | Attendance APIs don't enforce subscription modules (ATT-36). The settings audit list doesn't hide rows from switched-off modules (AUD-04). `AUDIT_MODULES` uses the wrong announcements key (AUD-07). |

**Product / web decisions**
- **APR-02:** Approvals reachability for managers without approve codes (L1 attendance sign-off), payroll.edit-only HR and Face-only approvers. This is the same on web.
- **DASH-37:** Notification Settings is limited to settings.edit on both apps, although the backend allows self-service.
- **REF-05:** the employee-facing Referral Rules tab returns 403, because the backend needs settings.view.
- **REF-08:** the backend drops referral `branch`. Web's branch picker can leave users with no way to submit.
- **LVP-11, LVP-13:** Carry Forward and Opening Balance Import are gated on leave.edit in the UI but need leave.approve on the backend.
- **AUTH-10:** web's onboarding exemption for settings.edit holders is inconsistent between its login page and its route guard.
- **ATT-15:** should mobile keep the Reprocess and Add Record actions that web lacks?
- **PAY-03, PAY-04:** the backend never generates `payslip_pdf`. Decide whether mobile needs a PDF.
- **ORG-08:** is the company plan view in mobile scope?
- **DASH-36:** there is no producer for holiday notifications.
- **Web bugs to report:**
  - AuditLogsWidget sends labels that match nothing.
  - The Settings audit page is missing ten modules.
  - The Attendance Approval tab uses payroll.view.
  - The Leave Cancellations tab ignores the leave module.
  - The orphan `/dashboard/employees/new` page.
  - The dead `HRDecisionModal.tsx`.

---

## E. Mobile-only remaining work (safe in Flutter)

1. **APR-05:** normalise `l2_pending`/`stage2_pending`/`resubmit` in the Approvals status filter, as web's `toDisplayStatus` does. Add tests.
2. **APR-08, APR-12:** send leave approval remarks (single and bulk) as web does.
3. **REC-27:** wire candidate-review document "View" to the existing in-app preview (`document_links.dart`).
4. **LV-18:** move Analytics and the Home leave widget to the calendar-year own-scope stats, or pass the year; keep the approver scope.
5. **Misleading UI (needs a quick product nod):** remove or implement the LV-15 draft button, the LVP-09 local accrual rules and the REF-06 hard-coded bonus panel.
6. **LV-08, LV-11:** exact balances in Apply Leave, and web's full preview breakdown.
7. **LVP-05:** carry-forward type, mode and expiry fields, and fix the misleading comment.
8. **Layout:** DASH-28/29/30, quick-access tiles and dashboard sections at large text.
9. **Employees:**
   - EMP-06: stats from `/employees/stats/`, honouring scope.
   - EMP-10: Department optional for branch-manager roles.
   - EMP-03/04: lock the filters as web does.
   - EMP-12: sample download and error report.
10. **ROLE-03:** align role presets with web.
11. **Attendance:**
    - ATT-13: lock the branch filter.
    - ATT-16: Mark Attendance and the edit/audit drawer in Employee Month View.
    - ATT-15: client permission checks on Reprocess/Add Record, subject to the decision.
    - FACE-11: copy.
12. **AUTH-07:** refresh permissions and status flags from refreshed tokens. AUTH-06: session-expired notice.
13. **DOC-02:** server-side document search with paging. DOC-04: client size check.
14. **P3 polish:**
    - Display: DASH-03/09/12/31 and PROF-15.
    - Notifications and settings: DASH-34/38, SET-06, AUD-02 default dates.
    - Leave: LVP-03 delete UX, LV-07 dead refresh.
    - Expenses: EXP-01 tiles.
    - Cleanup: stale comments and the dead `dashboard_screen.dart`.
15. **Verify the 30 Unverified rows:** mostly dashboard KPI widgets, profile sections, departments and designations, and email branding. Add tests where none exist.
16. **Test gaps:**
    - No tests at all for: expenses, Document Center list/search/upload/delete, Email Logs, Referral Rules settings, Assessment Config, Approval Rules, Notification Settings, the Settings hub tiles.
    - No dedicated tests for: the Attendance Approval and Face registration approval tabs.

---

## F. Physical-device test plan (cannot be fully verified by automated tests)

| Area | What to check on real Android devices (low, mid and high-end; Android 10–15) |
|---|---|
| Face ID | Registration (self and HR-assisted). Punch with a matching face, a different face, a photo, and a screen replay. Liveness prompts in poor or bright light and with glasses. Descriptor distances against registrations made on web, at threshold 0.6 with the ±0.05 band. Lockout once FACE-06 is fixed. |
| Location | GPS accuracy, inside and outside the branch radius, mock-location apps, WFH saved and captured locations, location permission denied or "approximate only". |
| Camera and files | Camera permission denied. Picking files for leave documents, expense receipts, document uploads, separation documents, bulk imports and the payslip query (5/25 MB limits). |
| External links | Signed document, receipt and payslip links opening in other apps. Back navigation. Behaviour after the 2-hour token expires. |
| PDF / print / share | ID card print and share; payslip view. |
| Timers and lifecycle | Assessment timer with the app backgrounded, screen locked or killed. Token refresh after a long idle. Notification polling after resume. |
| Navigation | Android back button and predictive back (known go_router issue, test twice). Deep links if added. |
| Accessibility | System font size 1.3–2.0× on every dashboard and list screen; TalkBack labels. |
| Network | Offline or slow network on punch, apply leave and approvals. Retry and error states. |

---

## G. Recommended task sequence (one bounded task each)

| Task | Scope |
|---|---|
| 80 | Approvals status normalisation (APR-05) and leave approval remarks (APR-08/12), with tests. |
| 81 | Candidate review onboarding document preview (REC-27), with tests. |
| 82 | Calendar-year stats for Leave Analytics and the Home leave widget (LV-18), with tests. |
| 83 | Remove or implement misleading UI: draft button, local accrual rules, hard-coded referral bonus (LV-15, LVP-09, REF-06). Needs product confirmation first. |
| 84 | Apply Leave precision and preview breakdown (LV-08, LV-11). |
| 85 | Carry-forward settings fields (LVP-05). |
| 86 | Large-text responsive fixes for dashboard tiles and sections (DASH-28/29/30). |
| 87 | Employees list stats, filters, Add Employee department rule, bulk-import sample (EMP-03/04/06/10/12). |
| 88 | Role preset alignment (ROLE-03). |
| 89 | HR attendance branch lock and Employee Month View actions (ATT-13, ATT-16), plus a decision on ATT-15. |
| 90 | Token-claim refresh and session-expired notice (AUTH-07, AUTH-06). |
| 91 | Document Center server search and size check (DOC-02, DOC-04). |
| 92 | Verify the Unverified rows and close the test gaps listed in Section E. |
| 93 | P3 polish batch and dead-code / stale-comment cleanup. |
| 94 | Physical-device test session per Section F, especially once the backend fixes FACE-06. |

**In parallel (other owners):**
- **Backend:** the security items in Section D, starting with FACE-06 and the P1 scoping gaps.
- **Product:** the decisions in Section D.

---

## B. Full parity matrix

Every row gives the web and mobile evidence (file:line), the backend endpoint, the permission and module rule, the classification, the specific gap, the mobile tests and the severity. Device verification is "none" for every row.

---

### B. Authentication, Dashboards, Profile and self-service (AUTH / DASH / PROF)

Paths: W = `web_frontend_backend/frontend`, M = `mobile_app/lib`, B = `web_frontend_backend/backend`, T = `mobile_app/test`.

| ID | Feature | Web | Mobile | Backend | Perm / module | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| AUTH-01 | Login (company code, email, password; prefill after forced change; post-login routing) | W app/login/page.tsx:87-140 | M features/auth/presentation/widgets/login_form.dart:24-170 | POST /login/ | public | Complete | — | T login_company_code_test, login_password_validation_test | — |
| AUTH-02 | Forgot password (email → OTP → reset, company_code each step) | W components/auth/ForgotPasswordForm.tsx:59-110 | M features/auth/.../forgot_password_form.dart | /forgot-password/, /verify-otp/, /reset-password/ | public | Complete | — | T forgot_password_flow_test, forgot_password_form_test | — |
| AUTH-03 | Must-change-password gate | W proxy.ts:183-192; app/change-password/page.tsx | M force_change_password_screen.dart:17-91 | POST /change-password/ | authenticated | Complete | — | T force_change_password_flow_test, auth_redirect_test | — |
| AUTH-04 | Change password from profile | W profile/ChangePasswordForm.tsx:32 | M profile_screen.dart:121,239 | POST /change-password/ | self | Complete | — | none | — |
| AUTH-05 | Silent token refresh (single flight) | W lib/clientApi.ts:46-78 | M core/network/auth_interceptor.dart:35-117 | /token/refresh/ | — | Complete | — | T auth_interceptor_test | — |
| AUTH-06 | Session-expired notice | W components/SessionExpiredOverlay.tsx | M auth_notifier.dart:23-28 | — | — | Partial | Mobile logs out without telling the user why | none | P3 |
| AUTH-07 | Fresh claims after refresh | W proxy.ts:60-100 | M auth_interceptor.dart:245; auth_notifier.dart:31-34 | B accounts/tokens.py:23 | — | Partial | Mobile syncs only `modules` from refreshed tokens; permissions and status flags stay as at login (server still enforces) | none | P2 |
| AUTH-08 | Logout | W DashboardShell.tsx:99-103 | M app_top_bar.dart:118-122 | POST /logout/ | — | Complete | — | none | — |
| AUTH-09 | Guard order (auth → must-change → onboarding → assessments → module → permission) | W proxy.ts:183-260 | M app_router.dart resolveAuthRedirect; access_control.dart | — | — | Complete | — | T auth_redirect_test, route_access_policy_test, module_gating_test, access_control_test | — |
| AUTH-10 | Onboarding exemption for settings.edit holders | W login/page.tsx vs proxy.ts:105 | M user_entity.dart:68-85 | B accounts/views.py:612 vs tokens.py:23 | — | Blocked | Web is inconsistent (login widens is_superuser, JWT doesn't); mobile consistently exempts | T auth_redirect_test | P3 |
| AUTH-11 | Onboarding wizard (5 steps, face step, custom fields, documents, submit) | W app/onboarding/page.tsx:33-341 | M onboarding_screen.dart:41-119; onboarding_steps.dart | /onboarding/… | onboarding status | Complete | — | T onboarding_config_test, onboarding_hardening_test | — |
| AUTH-12 | Rejected onboarding with HR notes | W onboarding/page.tsx | M app_router.dart; onboarding_steps.dart | /onboarding/ | — | Unverified | Redirect correct; rendering of notes not compared | none | — |
| AUTH-13 | Awaiting approval (poll, logout) | W onboarding/page.tsx:119-127,366 | M awaiting_approval_screen.dart:20-144 | /onboarding/, /assessments/my/ | submitted | Complete | — | none | — |
| AUTH-14 | Onboarding assessments gate | W app/onboarding/assessments/page.tsx:95-281 | M assessment_gate_screen.dart | /assessments/my/… | exemptions for managers/superusers | Complete | — | T assessment_gate_test | — |
| DASH-01 | Role dashboard resolution | W app/dashboard/page.tsx:7-17 | M quick_access.dart:32-38; home_screen.dart:36-48 | — | superuser/settings.edit → admin; team → manager; employees.view → HR | Complete | — | T dashboard_category_test | — |
| DASH-02 | Employee console (KPIs, attendance strip) | W employee/EmpConsole.tsx | M employee_dashboard_view.dart:134 | /dashboard/employee/kpis/ | — | Unverified | KPI fields not compared | none | — |
| DASH-03 | Employee birthday announcement | W employee/EmpBirthdayAnnouncement.tsx | M employee_dashboard_view.dart:1207-1230 | birthdays/today/ | — | Partial | No tap-to-celebrate modal on mobile | T employee_birthdays_test | P3 |
| DASH-04 | Promotion celebration | W EmpPromotionCelebration.tsx | M emp_celebration_cards.dart | /notifications/ | — | Complete | — | T celebration_cards_test | — |
| DASH-05 | Team/manager birthday cards | W TeamBirthdayCard.tsx, ManagerBirthdayCard.tsx | M emp_celebration_cards.dart | /dashboard/birthdays/mine/ | — | Complete | — | T celebration_cards_test | — |
| DASH-06 | Own notice-period countdown | W EmpNoticePeriodCard.tsx | M emp_notice_period_card.dart | /dashboard/employee/notice-period/ | — | Complete | — | T employee_notice_period_test | — |
| DASH-07 | Pending acknowledgements banner | W EmployeeDashboard.tsx | M employee_dashboard_view.dart:79 | documents | documents module | Complete | — | none | — |
| DASH-08 | Updates card (announcement + birthdays) | W EmpUpdatesCard.tsx:28-92 | M employee_dashboard_view.dart:1073-1193 | /dashboard/announcement/ | — | Complete | Split into two cards on mobile | T dashboard_announcement_order_test | — |
| DASH-09 | Employee quick actions | W EmployeeDashboard.tsx:19-28 | M quick_access.dart:94-139 | — | module + permission | Partial | Mobile lacks "Company Policy" and "Contact Matrix" tiles | T dashboard_shortcuts_test | P3 |
| DASH-10 | Leave balances and upcoming holidays | W EmpLeaveBalances.tsx, EmpUpcomingHolidays.tsx | M employee_dashboard_view.dart:93-98 | /dashboard/employee/leave-balances/ | leave module | Complete | — | T upcoming_holidays_test, leave_monthly_breakdown_test | — |
| DASH-11 | Action items and recent requests | W EmpActionItems.tsx, EmpRecentRequests.tsx | M employee_dashboard_view.dart:108-110 | action-items, recent-requests | — | Unverified | navigation_url handling not compared | none | — |
| DASH-12 | Manager dashboard | W _components/ManagerDashboard.tsx:20-330 | M manager_dashboard_view.dart:50-170 | /dashboard/manager/ | modules | Partial | Quick-action count appended to a one-line ellipsized label can be cut off | T manager_dashboard_test | P3 |
| DASH-13 | HR console KPIs | W hr/HrConsole.tsx | M hr_dashboard_view.dart:105 | /dashboard/hr/kpis/ | employees.view | Unverified | Fields not compared | none | — |
| DASH-14 | HR attendance summary | W hr/HrAttendanceSummary.tsx | M hr_dashboard_view.dart:272 | /dashboard/hr/attendance-summary/ | attendance module | Unverified | — | none | — |
| DASH-15 | HR action queue | W hr/HrActionQueue.tsx:19-81 | M hr_dashboard_view.dart:356-470 | /dashboard/hr/action-queue/ | per row | Complete | — | T hr_separation_queue_count_test | — |
| DASH-16 | HR recruitment funnel | W hr/HrRecruitmentFunnel.tsx | M hr_dashboard_view.dart:488 | recruitment-funnel | recruitment module | Unverified | — | none | — |
| DASH-17 | HR lifecycle tabs | W hr/HrEmployeeLifecycleTabs.tsx | M hr_dashboard_view.dart:542 | hr/employee-lifecycle | — | Complete | — | T hr_notice_period_lifecycle_test | — |
| DASH-18 | HR department headcount | W DeptHeadcountChart.tsx | M hr_dashboard_view.dart:727 | hr/department-headcount | — | Unverified | — | none | — |
| DASH-19 | HR birthdays | W hr/HrBirthdaysWidget.tsx | M hr_dashboard_view.dart:790-872 | hr/birthdays/* | — | Unverified | — | none | — |
| DASH-20 | HR quick actions | W HRDashboard.tsx:16-23 | M quick_access.dart:183-215 | — | — | Intentional exception | "Run Payroll" omitted (admin payroll is web-only) | T dashboard_shortcuts_test | — |
| DASH-21 | Admin console (KPIs, health pills, clock) | W KpiConsole.tsx | M admin_dashboard_view.dart:106-210 | system-admin/kpis | settings.edit | Unverified | — | none | — |
| DASH-22 | Admin announcement card | W AnnouncementCard.tsx | M admin_dashboard_view.dart:457 | system-admin/announcement | announcements module | Unverified | — | T dashboard_announcement_order_test | — |
| DASH-23 | Admin quick actions | W AdminDashboard.tsx:25-32 | M quick_access.dart:217-249 | — | — | Intentional exception | "Payroll" tile omitted (web-only) | T dashboard_shortcuts_test | — |
| DASH-24 | Admin pending approvals | W PendingApprovalsWidget.tsx | M admin_dashboard_view.dart:242-360 | system-admin/pending-approvals | per row | Unverified | — | none | — |
| DASH-25 | Admin headcount and lifecycle | W DeptHeadcountChart.tsx, EmployeeLifecycleTabs.tsx | M admin_dashboard_view.dart:408,554 | system-admin/* | — | Complete | — | T admin_notice_period_lifecycle_test | — |
| DASH-26 | Admin birthdays, Send Wish / Send All | W BirthdayWidget.tsx, SendWishModal.tsx | M admin_dashboard_view.dart:787-970 | system-admin/birthdays/* | — | Complete | — | T admin_birthday_wishes_test | — |
| DASH-27 | Admin audit logs card | W AuditLogsWidget.tsx:59,106 | M admin_dashboard_view.dart:971-1200 | system-admin/audit-logs | settings.edit | Complete | Mobile sends real module values (web's labels match nothing) | T admin_audit_card_module_filter_test | — |
| DASH-28 | Quick-access tiles at large text (re-check) | — | M quick_access.dart:328-370 | — | — | Partial | Fixed 92 px tile; label likely overflows above ~1.5× text; no test | none | P2 |
| DASH-29 | dashboard_section widgets at large text (re-check) | — | M dashboard_section.dart:518-540, 553-590 | — | — | Unverified | RoleBadgePill not Flexible; fixed-width "Not Clocked In"; known overflow from Task 74 probe | none | P3 |
| DASH-30 | Employee "Quick Links" card (mobile-only) | — | M employee_dashboard_view.dart:1300-1310 | — | — | Partial | Fixed 46 px rows risk overflow at large text | none | P3 |
| DASH-31 | Top bar / drawer avatar | W DashboardShell.tsx:246-289 | M app_sidebar.dart:229 | /employees/me/ | — | Partial | Drawer shows initials only, not the photo | none | P3 |
| DASH-32 | Drawer menu (permission + module) | W lib/navConfig.ts:23-98 | M nav_config.dart:44-143 | — | — | Complete | — | T access_control_test | — |
| DASH-33 | Global search | W GlobalSearch.tsx:25-115 | M global_search_controller.dart:14-45 | /employees/?search= | employees.view | Complete | — | T global_search_test | — |
| DASH-34 | Notification bell and panel | W NotificationBell.tsx; hooks/useNotifications.ts | M notification_panel.dart:92-130 | /notifications/*, ws | — | Partial | Mobile polls only; web adds a WebSocket, so mobile updates arrive later | none | P3 |
| DASH-35 | Notification tap routing (re-check) | W NotificationBell.tsx:8-16,57 | M notification_panel.dart:17-44 | — | canAccessPath | Complete | holiday/promotion/role_change behave as designed (Tasks 75, 78) | T notification_navigation_test | — |
| DASH-36 | Holiday notifications (re-check) | — | — | B notifications/models.py:38 | — | Blocked | Backend never creates holiday notifications | — | P3 |
| DASH-37 | Notification Settings permission (re-check) | W settings/notifications/page.tsx:45,151 | M notification_settings_screen.dart:152,194 | B notifications/views.py:82-96 (any user may PATCH own) | settings.view to open, settings.edit to edit | Blocked | Ordinary employees can't manage their own preferences on either platform although the backend allows it; product decision | none | P2 |
| DASH-38 | Notification Settings Approval toggle | W settings/notifications/page.tsx:36 (locked) | M notification_settings_screen.dart:66 | backend forces true | — | Partial | Editable on mobile and silently reverted by backend; mobile uses batch Save | none | P3 |
| PROF-01 | Profile header, photo upload/remove | W components/ProfilePhotoModal.tsx | M profile_remote_datasource.dart:57-70 | /employees/me/photo/ | self | Unverified | — | none | — |
| PROF-02 | Personal section | W ProfileClient.tsx:112-125,347 | M profile_screen.dart:210-222 | PATCH /employees/me/ | self | Complete | — | T profile_custom_fields_test | — |
| PROF-03 | Work info | W ProfileClient.tsx:657-700 | M profile_sections.dart:258-267 | /employees/me/ | — | Complete | — | T profile_work_info_test | — |
| PROF-04 | Education and bank (read-only) | W ProfileClient.tsx | M profile_screen.dart:225-229 | — | — | Complete | — | T profile_custom_fields_test | — |
| PROF-05 | Emergency contact | W ProfileClient.tsx:336-347 | M profile_screen.dart:230-237 | PATCH /employees/me/ | — | Complete | — | T profile_custom_fields_test | — |
| PROF-06 | Documents (upload/replace/view, custom files) | W ProfileClient.tsx:267-301 | M profile_documents_section.dart | /employees/{id}/documents/… | self | Complete | — | T profile_documents_* (5 files) | — |
| PROF-07 | Face ID section | W ProfileClient.tsx:247,858-936 | M profile_face_id_section.dart | face-registration/me | face_attendance | Unverified | Real face/device validation outstanding | T facial_recognition/* | — |
| PROF-08 | Security tab | W ProfileClient.tsx:925 | M profile_screen.dart:239 | see AUTH-04 | — | Complete | — | none | — |
| PROF-09 | Separation card | W profile/_components/SeparationCard.tsx | M profile_screen.dart:218 | separation | — | Unverified | — | none | — |
| PROF-10 | Profile tab layout | W ProfileClient.tsx:203-212 | single scrolling page | — | — | Intentional exception | Mobile layout choice | — | — |
| PROF-11 | My Requests (kinds by module; search/status/date) | W my-requests/_client.tsx:46-107 | M my_requests_screen.dart:88-333 | leave, wfh, expenses, corrections | modules | Complete | Mobile also cancels WFH | none | — |
| PROF-12 | Correction / late-justification detail | W MyCorrectionDetailModal.tsx | M my_correction_detail_sheet.dart | — | — | Unverified | — | T late_justification_test (partial) | — |
| PROF-13 | Cancel leave from My Requests | W _client.tsx:122-129 | M my_requests_providers.dart:254-262 | PATCH leave | — | Complete | — | none | — |
| PROF-14 | Contact Matrix | W dashboard/contacts/page.tsx:22-132 | M contact_matrix_screen.dart:82-151 | /company-contacts/ | documents module | Complete | — | T contact_matrix_test | — |
| PROF-15 | Org Chart | W org-chart/_components/OrgChartClient.tsx:22-245 | M org_chart_screen.dart:39-145 | /org-chart/ | org_chart.view | Partial | No zoom; header says "All branches" for single-branch viewers | T org_chart_profile_access_test | P3 |

Counts (67 rows): Complete 34 · Partial 11 · Missing 0 · Intentional exception 3 · Blocked 3 · Unverified 16.

Also: `M features/dashboard/presentation/screens/dashboard_screen.dart` is an unused "coming soon" placeholder (dead code, P3).
Backend scoping (report): several HR dashboard widgets (recruitment funnel, attendance summary, department headcount, new joiners/anniversaries, birthdays) are company-wide for branch HR (B apps/dashboard/views/overview.py:246-255, 463-520; people.py:256-330), while KPIs/action queue are branch-scoped.

---

### B. Employees, Organisation, Roles (EMP / ORG / ROLE)

Paths: W = `web_frontend_backend/frontend/app/dashboard`, M = `mobile_app/lib/features`, B = `web_frontend_backend/backend/apps/accounts/views.py` unless named.

| ID | Feature | Web | Mobile | Backend | Perm / module | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| EMP-01 | Employees list route + gate | W/employees/page.tsx:94 | M/employees/presentation/employees_screen.dart:23 | GET /employees/ (B:3018) | employees.view | Complete | — | access_control_test | — |
| EMP-02 | Search | page.tsx:168 | employees_screen.dart:80 | B:3058 | — | Complete | — | none | — |
| EMP-03 | Branch filter | page.tsx:296 (locked for non-admins) | employees_screen.dart:163 | B:3051 | superuser picks | Partial | Mobile shows a free picker to anyone who can load branches; server scopes results, so non-admins get empty lists | none | P3 |
| EMP-04 | Department filter | page.tsx:302 (superuser only) | employees_screen.dart:177 | B:3056 | superuser | Partial | Shown to non-admins; options from company-wide list | none | P3 |
| EMP-05 | Status filter | page.tsx:316 | employees_screen.dart:190 | B:3058 | — | Complete | — | none | — |
| EMP-06 | Stats cards | page.tsx:152-196 (/employees/stats/) | employee_providers.dart:245 | B:3396 | employees.view | Partial | Mobile builds stats from 3 list calls and the departments list: needs departments.view (else all 0), Depts count company-wide, ignores branch filter | none | P2 |
| EMP-07 | Pagination | page.tsx:439 | employees_screen.dart:64 | paginated | — | Complete | — | none | — |
| EMP-08 | Activate / deactivate | page.tsx:202-220 | employee_profile_screen.dart:143,249,2229 | PATCH /employees/<id>/ | employees.edit | Complete | Moved to profile; same payload | employee_status_confirm_test | — |
| EMP-09 | Scope subtitle | page.tsx:229-238 | not found | — | — | Unverified | No mobile equivalent seen | none | P3 |
| EMP-10 | Add Employee | _components/AddEmployeeModal.tsx:139,236-280 | add_employee_sheet.dart | POST /employees/ (B:3109) | employees.create | Partial | Mobile always requires Department (web/backend optional for Branch Admin roles); no name regex check | add_employee_reporting_pickers_test | P2 |
| EMP-11 | /dashboard/employees/new page | employees/new/page.tsx | — | POST /employees/ | — | Intentional exception | Orphan web page; modal is the live flow | — | — |
| EMP-12 | Bulk import | _components/BulkImportModal.tsx:11-47 | employee_bulk_import_screen.dart:28-85 | POST /employees/bulk-import/ | employees.create | Partial | No sample template download, no error-report CSV export | none | P3 |
| EMP-13 | Bulk import gating | page.tsx:248 | access_control.dart:74 | B:6681 | employees.create | Complete | — | access_control_test | — |
| EMP-14 | Detail header + pending onboarding | [id]/page.tsx:590-625 | employee_profile_screen.dart:240-297 | GET /employees/<id>/ (scoped) | employees.view | Complete | — | employee_pending_onboarding_test | — |
| EMP-15 | Profile tab (sections, edit, custom fields) | [id]/page.tsx:653-790 | employee_profile_screen.dart:775-1120 | PUT /employees/<id>/ | employees.edit | Complete | — | employee_section_edit_test, employee_custom_fields_test, employee_statutory_fields_test | — |
| EMP-16 | Reporting manager / HR / branch edits | [id]/page.tsx:700-760 | add_employee_sheet edit mode | PATCH …/reporting-manager/, …/hr/ | employees.edit | Complete | — | employee_edit_branch_hr_test, employee_edit_manager_reporting_test | — |
| EMP-17 | Documents tab | [id]/page.tsx:528 | employee_profile_screen.dart:1273 | POST /employees/<id>/documents/ | documents.create + scope | Complete | — | employee_documents_view_test | — |
| EMP-18 | Custom file fields | [id]/page.tsx:558-579 | employees_remote_datasource.dart:433-449 | custom-file-fields/ | as above | Complete | — | employee_custom_files_view_test | — |
| EMP-19 | Reset password | ResetPasswordModal.tsx | reset_password_dialog.dart | B:4002 | employees.edit + scope | Complete | — | employee_detail_notice_reset_test | — |
| EMP-20 | Salary tab | SalaryTab.tsx:20-56 | employee_salary_payroll_tabs.dart | payroll salary history | payroll.edit; module payroll | Complete | — | employee_salary_payroll_test | — |
| EMP-21 | Payroll tab | PayrollTab.tsx:40 | employee_salary_payroll_tabs.dart:83 | payslip history | module payroll | Complete | — | employee_salary_payroll_test | — |
| EMP-22 | Leave tab, credits, monthly statement | LeaveTab.tsx; LeaveCreditsSection.tsx | employee_leave_tab.dart; leave_credits_section.dart | /leave/credits/… | module leave | Complete | — | employee_leave_credits_test, employee_monthly_leave_statement_test | — |
| EMP-23 | Attendance tab | AttendanceTab.tsx | employee_attendance_tab.dart | attendance APIs | module attendance | Unverified | Not compared in depth (see ATT-16) | none | P3 |
| EMP-24 | Approval Matrix tab + overrides | ApprovalMatrixTab.tsx | employee_profile_screen.dart:1627-2173 | approval-matrix/ | employees.edit + scope | Complete | — | employee_approval_matrix_test | — |
| EMP-25 | Promotion tab | PromotionTab.tsx:82-148 | promotion_tab.dart:41 | promotions/ | employees.edit | Complete | — | promotion_history_test | — |
| EMP-26 | Assets tab | AssetsTab.tsx:23-113 | employee_assets_tab.dart | EmployeeAssetsView (scoped) | assets.edit; module | Complete | — | employee_assets_tab_test | — |
| EMP-27 | Send Wishes tab | WishesTab.tsx | wishes_tab.dart; send_wish_sheet.dart | hrms wishes | — | Unverified | Not compared field by field | none | P3 |
| EMP-28 | Tab module gating | ProfileTabBar.tsx:8 | employee_profile_screen.dart:89-97 | — | modules | Complete | — | none | — |
| EMP-29 | ID card (preview, print) | [id]/id-card/page.tsx:22-90 | employee_id_card_screen.dart; id_card_pdf.dart | id-card/ (scoped) | employees.view | Complete | Mobile adds Share PDF | employee_id_card_test (+2) | — |
| EMP-30 | Onboarding approvals | onboarding-approvals/page.tsx:8 (redirect) | candidate_review_screen.dart | /onboarding/approvals/ | employees.approve / onboarding.approve | Complete | — | candidate_review_approval_test | — |
| ORG-01 | Branch list, stats, distribution | W/branches/_components/BranchManagement.tsx:305-312 | branches_screen.dart; branch_stats_row.dart | branch/views.py:149,634,660 | branches.view | Complete | — | branch_hq_name_test | — |
| ORG-02 | Branch create/edit/delete | BranchManagement.tsx:231 | branch_form_dialog.dart | branch/views.py:206,252,313 | settings.edit (UI); branches.* (API) | Complete | — | add_branch_admin_test, edit_branch_admin_test | — |
| ORG-03 | Branch admin reassignment | BranchManagement.tsx:459-500 | branch_admin_reassign.dart | branch/views.py:352 | settings.edit + branches.edit | Complete | — | branch_admin_reassign_test | — |
| ORG-04 | Geofencing | BranchManagement.tsx:398-414 | branch_geofence.dart | branch/views.py:530 | branches.edit | Complete | — | branch_geofence_test | — |
| ORG-05 | Branches route gate | proxy.ts:24 settings.view | access_control.dart branches.view | branch/views.py:153 | — | Intentional exception | Mobile follows API and web menu (web proxy inconsistent) | access_control_test | — |
| ORG-06 | Company info + logo | settings/company/page.tsx:92 | company_screen.dart:42 | B:2857 | settings.edit | Complete | — | company_logo_removal_test | — |
| ORG-07 | Financial year | FinancialYearSection.tsx:19 | financial_year_section.dart:31 | B:2935 | settings.edit | Complete | Mobile follows backend; web UI stricter | none | — |
| ORG-08 | Company plan details tab | company/page.tsx:103-109; PlanDetailsTab.tsx | none | /settings/company/plan/ | settings.edit | Missing | Needs product decision on mobile scope | none | P3 |
| ORG-09 | Departments CRUD | settings/departments/page.tsx:43 | departments_screen.dart:37 | B:1287-1491 | departments.* | Unverified | Validation/delete-with-employees not compared; no test | none | P3 |
| ORG-10 | Designations CRUD | departments/page.tsx | desig_form_sheet.dart | B:1630-1781 | designations.* | Unverified | As ORG-09 | none | P3 |
| ORG-11 | Employee code settings | settings/employee-code/page.tsx:23-41 | employee_code_screen.dart:67-108 | B:4219 | settings.edit | Complete | — | employee_code_settings_test, employee_code_format_test | — |
| ORG-12 | ID card settings + reference PDF | settings/id-card/page.tsx:63 | id_card_settings_screen.dart | views_id_card.py:144,206 | settings.edit | Complete | — | id_card_settings_test | — |
| ORG-13 | SMTP | settings/smtp/page.tsx | smtp_screen.dart | B:1787-1942 | settings.edit | Complete | — | smtp_provider_test | — |
| ORG-14 | Email templates | email-templates/page.tsx:242-279 | email_templates/* | B:1968-2303 | settings.view / settings.edit | Complete | — | email_templates_paging_test | — |
| ORG-15 | Email branding + birthday settings | email-templates/page.tsx:96,175 | email_branding_card.dart; birthday_settings_card.dart | company patch, birthday-settings | settings.edit | Unverified | Not compared field by field | none | P3 |
| ROLE-01 | Roles list + permission matrix | settings/permissions/page.tsx:52-53 | roles_screen.dart:33-91 | B:944,1144 | CanManageRoles | Complete | — | role_capabilities_test | — |
| ROLE-02 | Create/edit role | page.tsx:71-106 | role_form_sheet.dart:153-162 | B:965,1040 | settings.edit | Complete | Mobile also handles 409 conflict | role_capabilities_test | — |
| ROLE-03 | Permission presets | permissions/_data.ts:102-145 | role_form_sheet.dart:12-37 | — | — | Partial | Manager and Employee presets differ from web, so the same preset grants different rights per platform | none | P2 |
| ROLE-04 | Role activate/deactivate | page.tsx:135 | roles_screen.dart:112 | PATCH /roles/<id>/ | settings.edit | Complete | — | none | — |
| ROLE-05 | Settings hub tile visibility | settings/page.tsx:71-72 | settings_screen.dart:60-206 | — | settings.view + module | Complete | — | permission_visibility_test | — |

Counts (50 rows): Complete 35 · Partial 6 · Missing 1 · Intentional exception 2 · Blocked 0 · Unverified 6.

Backend concerns (report only):
- P1: onboarding pipeline view (`GET /onboarding/approvals/?view=pipeline`, B:5938-5957) has no branch/team filter; exposes name/email/phone of every pending hire to any onboarding.approve holder (unused by both clients).
- P1: `EmployeeDocumentView._get_doc` (B:5155) streams any employee's onboarding/KYC document by sequential ID to any employees.edit holder, without branch scope.
- P2: custom file view/delete by ID ignores branch (B:5417, 5512); mobile calls the delete route.
- P2: employee create and bulk import not restricted to the creator's branch (B:3109+, 6676+).
- Employee list/detail branch scoping itself is correct (B:3051-3056, 3457-3479).

---

### B. Attendance and Face ID (ATT / FACE)

Paths: W = `web_frontend_backend/frontend`, B = `web_frontend_backend/backend/apps/attendance`, M = `mobile_app/lib`, T = `mobile_app/test/features`.

| ID | Feature | Web | Mobile | Backend | Perm / module | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| ATT-01 | HR Attendance route guard | W/proxy.ts:27 | M/core/router/access_control.dart:80 | — | attendance.edit or settings.edit; module attendance | Complete | — | access_control_test, hr_attendance_permissions_test | — |
| ATT-02 | Nav and quick-access entries | W/lib/navConfig.ts:42,56 | M/.../nav_config.dart:66; quick_access.dart:235 | — | same | Complete | Stale comment in nav_config.dart:62-65 | access_control_test | — |
| ATT-03 | My Attendance tabs, stats, monthly summary | W/app/dashboard/my-attendance/_components/AttendanceTab.tsx:57-176 | M/.../my_attendance_screen.dart:131-347 | today/, stats/, summary/ | authenticated | Complete | — | attendance_month_navigation_test | — |
| ATT-04 | Monthly late arrivals card | AttendanceTab.tsx:116 | my_attendance_screen.dart:275 | stats.late_limit | — | Complete | — | late_arrival_limit_test | — |
| ATT-05 | Clock in/out flow | ClockWidget.tsx:64 | M/.../clock/clock_punch_flow.dart:77 | punch/, geofence-check/ | self | Complete | Same step order as web | clock_punch_flow_test, day_completed_test | — |
| ATT-06 | Punch log, geofence dot, location | ClockWidget.tsx:178 | punch_location_section.dart | today/ | self | Complete | — | punch_location_detail_test | — |
| ATT-07 | Calendar and history | CalendarAndHistory.tsx | my_attendance_screen.dart:405-412,1764 | calendar/ | self | Complete | — | attendance_month_navigation_test | — |
| ATT-08 | Regularize from a calendar day | CorrectionModal.tsx | my_attendance_screen.dart:1895 | correction/ | self | Complete | — | none | — |
| ATT-09 | Corrections tab | AttendanceCorrectionsTab.tsx | my_attendance_screen.dart:1156-1562 | corrections/my/ | self | Complete | — | none dedicated | — |
| ATT-10 | Late justification submit/resubmit | LateJustificationModal.tsx | late_justification.dart:58-308 | late-justification/… | self | Complete | Rules match (10–1000 chars, proof, 5 MB) | late_justification_test | — |
| ATT-11 | My late justifications | MyLateJustifications.tsx | late_justification.dart:515 | corrections/my/ | self | Complete | — | late_justification_test | — |
| ATT-12 | HR stat cards + branch banner | W/app/dashboard/attendance/page.tsx:47,84 | M/.../attendance_screen.dart:273 | dashboard/ | server-scoped | Partial | No "Viewing data for {branch} only" banner/title suffix | none | P3 |
| ATT-13 | Team Day View filters | _components/AttendanceTab.tsx:144-221 | attendance_screen.dart:1011-1030 | records/ | server branch scope | Partial | Branch dropdown not locked for restricted users; list can be labelled with a branch the server ignored | hr_attendance_permissions_test | P2 |
| ATT-14 | Record detail, edit, audit history | AttendanceDetailDrawer.tsx:88-175 | attendance_screen.dart:2209 | records/<id>/, …/audit/ | server-enforced | Complete | — | record_correction_review_test | — |
| ATT-15 | "Add Record" / "Reprocess" | none on web (create via Employee Month) | attendance_screen.dart:430-510,804 | reprocess/, records/create/ | can_manage_attendance | Blocked (product) | Mobile-only actions with no client permission check (server gates); Reprocess rewrites a whole day for a branch | none | P2 |
| ATT-16 | Employee Month View | EmployeeMonthView.tsx:147,328-361 | M/features/employees/.../employee_attendance_tab.dart:421 | web employee-calendar/; mobile calendar/?employee_id | attendance.view | Partial | Read-only on mobile: no "Mark Attendance", no edit/audit drawer; different endpoint (ATT-35) | none | P2 |
| ATT-17 | Export CSV | AttendanceTab.tsx:69,236 | attendance_export.dart; attendance_export_sheet.dart | export/ | attendance.export | Complete | — | attendance_export_test | — |
| ATT-18 | Import (dry run, sample) | ImportModal.tsx:95-130 | attendance_screen.dart:1325-1900 | import/, import/sample/ | attendance.create | Complete | — | attendance_import_modes_test | — |
| ATT-19 | OT records | OtEntryTab.tsx | attendance_screen.dart:2589 | overtime/ | attendance.view | Complete | — | none | — |
| ATT-20 | Add OT entry | OtEntryTab.tsx:35 | attendance_screen.dart:2647-2652 | overtime/create/ | attendance.create | Complete | — | ot_approver_picker_test | — |
| ATT-21 | Invalid punches list + badge | InvalidPunchesTab.tsx | attendance_screen.dart:196,3025 | invalid-punches/ | attendance.view | Complete | — | none | — |
| ATT-22 | Invalid punch actions | InvalidPunchesTab.tsx:29 | attendance_screen.dart:3085,3141 | hr_audit_actions.py:73,98,123 | client attendance.edit; server can_manage_attendance | Partial | Same as web; edit-only users see buttons that 403 | hr_attendance_permissions_test | P3 |
| ATT-23 | Un-punches tab | UnpunchesTab.tsx | attendance_screen.dart:197,3510 | un-punches/ | attendance.view | Complete | — | none | — |
| ATT-24 | Late justifications review (HR) | LateJustificationsTab.tsx | late_justification_review.dart | corrections/… | view / create | Complete | — | late_justification_review_test | — |
| ATT-25 | Corrections queue in Approvals | approvals/page.tsx:18-24 | approvals_screen.dart:79 | hr_attendance.py:808 | attendance.create + module | Complete | Backend review checks attendance.create + stage approver; mobile matches | record_correction_review_test | — |
| ATT-26 | Weekly off assignment | WeeklyOffAssignmentTab.tsx | weekly_off_assignment_tab.dart | weekly-off-assignments/ | view/create | Complete | — | weekly_off_assignment_test | — |
| ATT-27 | Shift assignment | ShiftAssignmentTab.tsx | shift_assignment_tab.dart | shift-assignments/ | view/create | Complete | — | shift_assignment_test | — |
| ATT-28 | Shift master | ShiftMasterCard.tsx | shift_master_card.dart | working-hours/ | create/edit/delete | Complete | — | shift_master_test | — |
| ATT-29 | Weekly off patterns | WeeklyOffPatternsCard.tsx | weekly_off_patterns_card.dart | weekly-days/ | create/edit/delete | Complete | — | weekly_off_pattern_test | — |
| ATT-30 | Attendance Rules sections | AttendanceSettings.tsx:92-360 | attendance_rules_screen.dart:436-838 | settings/ | settings.view to read | Complete | All fields present | attendance_policy_rules_test, attendance_rules_weekly_off_grid_test | — |
| ATT-31 | Rules edit gating | Save shown to settings.view | attendance_rules_screen.dart:87 | settings_view.py:39 (settings.edit) | settings.edit | Complete | Mobile correct and stricter; stale comment api_constants.dart:487-490 | attendance_policy_rules_test | — |
| ATT-32 | Late-arrival limit setting | Leave Policy | late_arrival_limit_card.dart | late-arrival-limit/ | settings.edit / leave.approve | Complete | — | late_arrival_limit_test | — |
| ATT-33 | Geofence configuration | Branch settings | features/branches | branch API | — | Unverified | Covered in ORG-04; not re-audited here | branch_geofence_test | — |
| ATT-34 | Server geofence by attendance_mode | — | sends office or wfh | services_geofencing.py:197,418-429 | — | Blocked (backend) | field/client_location/remote_office modes always pass; client chooses the mode | none | P1 |
| ATT-35 | Lookup of another employee's stats/calendar | — | used by ATT-16 | views/my_attendance.py:54-77 | attendance.view or employees.view | Blocked (backend) | Not limited to attendance staff; a user with no branch can read everyone | none | P1 |
| ATT-36 | Attendance / face module gating | W/lib/modules.ts:25-42 | access_control.dart | APIs don't enforce modules | module | Blocked (backend) | Client gating matches web; server doesn't enforce subscription on attendance APIs | access_control_test | P2 |
| ATT-37 | Permission / short leave | not on web | — | — | — | Intentional exception | Not a web feature | — | — |
| FACE-01 | Employee self-registration | W/app/dashboard/profile/ProfileClient.tsx:247 | profile_face_id_section.dart:78-142 | face-registration/… | self | Partial | Web hides the tab when the feature is off; mobile shows a "Contact admin" card | face_registration_payload_test | P3 |
| FACE-02 | Onboarding face step | W/app/onboarding/page.tsx | onboarding_steps.dart | same | self | Complete | — | face_registration_payload_test | — |
| FACE-03 | HR registration screen | W/app/dashboard/face-id-registrations/page.tsx:25-200 | face_id_registrations_screen.dart:46-234 | register/, employees/… | facial_recognition.approve; face_attendance | Complete | — | access_control_test | — |
| FACE-04 | Registration approvals tab | approvals/page.tsx:21 | approvals_screen.dart:105 | pending/, <id>/review/ | approve + module | Complete | — | admin_approvals_access_test | — |
| FACE-05 | Face check at punch (client) | ClockWidget.tsx:68-104 | clock_punch_flow.dart:43-57 | punch/ | mandatory toggle | Complete | Fails closed | clock_punch_flow_test | — |
| FACE-06 | Server-side face match for mobile punches | — | datasource sends `source='mobile'` | services_face_matching.py:207; serializers_my_attendance.py:34 | — | Blocked (backend) | Server verifies only `web`/`voice`; mobile face data ignored and any client can skip the face check with `source=mobile` | none | P0 |
| FACE-07 | Descriptor parity (128-d, CLAHE, quality gate, 3-frame average) | W/lib/faceApi/qualityGate.ts:48 | face_api_math.dart:233-241; face_api_pipeline.dart:28-29 | threshold 0.6, band 0.05 | — | Unverified | Constants match; not checked with real faces on a device | face_api_port_test, face_api_pipeline_test | P1 |
| FACE-08 | Liveness | W/lib/faceApi/liveness.ts:29-34 | liveness_tracker.dart:15-17 | liveness_passed only | — | Partial | Different signals/thresholds from web; spoof resistance unproven | liveness_tracker_test | P1 |
| FACE-09 | Face lockout countdown | ClockWidget | face_lockout.dart | punch/ 403 blocked | — | Unverified | Can't fire for mobile while FACE-06 stands | face_lockout_test | P2 |
| FACE-10 | Face capture telemetry | W/lib/faceApi/telemetry.ts:131 | absent | face-capture-telemetry/ | — | Missing | No retry diagnostics sent from mobile | none | P3 |
| FACE-11 | Face ID mandatory toggle text | AttendanceSettings.tsx:375-396 | attendance_rules_screen.dart:871-883 | settings face_verification | settings.edit | Partial | Mobile text implies server face matching for all punches; web text scopes it to web punches (matches FACE-06) | attendance_policy_rules_test | P2 |

Counts (48 rows): Complete 31 · Partial 7 · Missing 1 · Intentional exception 1 · Blocked 5 · Unverified 3.

Physical-device needs: camera capture, ML Kit liveness and spoof attempts; TFLite descriptor distances against web registrations; GPS accuracy and geofence radius; WFH punches; face lockout (after FACE-06); camera/location permission denial; self and HR-assisted registration end to end.

---

### B. Leave, Leave Policy, Holidays, Notice Period, WFH (LV / LVP / WFH)

Paths: W = `web_frontend_backend/frontend/app/dashboard`, M = `mobile_app/lib/features`, B = `web_frontend_backend/backend/apps/hrms/views`, T = `mobile_app/test`.

| ID | Feature | Web | Mobile | Backend | Perm / module | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| LV-01 | Leave route, 4 tabs | W/leave/_client.tsx:16 | M/leave/presentation/screens/leave_screen.dart:39 | — | leave.view + module leave | Complete | — | T/features/leave/leave_screen_parity_test.dart | — |
| LV-02 | Dashboard Casual/Sick/Earned cards, calendar year | W/leave/_components/LeaveDashboard.tsx:37-90 | leave_dashboard_tab.dart:16-18,66,304 | GET leave/balance/?year= | self | Complete | — | leave_screen_parity_test | — |
| LV-03 | Dashboard LOP card | LeaveDashboard.tsx:96-121 | leave_dashboard_tab.dart:76,381-430 | GET leave/stats/?year&scope=own | self | Complete | — | leave_screen_parity_test | — |
| LV-04 | Recent own requests, empty state, detail | LeaveDashboard.tsx:22,148-180 | leave_dashboard_tab.dart:72,247,264 | GET leave/requests/ | self | Complete | — | leave_screen_parity_test | — |
| LV-05 | Request detail (L1/L2 trail, LOP split, handover, document) | LeaveRequestDetailModal.tsx | leave_request_detail_sheet.dart:112,375-502 | GET leave/requests/<id>/ | self | Complete | — | none | — |
| LV-06 | Cancel pending leave | LeaveDashboard.tsx:52 | leave_remote_datasource.dart:145; detail sheet:229 | PATCH leave/requests/<id>/ | server can_cancel | Complete | — | none | — |
| LV-07 | Cancellation request/decision workflow | LeaveCancellationPanel.tsx | leave_cancellation_panel.dart:31-36,153-213 | …/cancellation/, …/decision/, GET leave/cancellations/ | server flags; list needs leave.approve | Partial | Still invalidates the unwatched year-less `leaveBalancesProvider` (panel.dart:74): dead code, no live request | T/features/leave/leave_cancellation_test.dart | P3 |
| LV-08 | Apply: types + calendar-year balances | ApplyLeaveForm.tsx:63-72 | apply_leave_tab.dart:596-600 | GET leave/policy/, leave/balance/?year= | self | Partial | Balance shown/checked as `available.round()` (apply_leave_type_selector.dart:51): 2.5 shows as 3 | T/features/leave/apply_leave_types_documents_test.dart | P2 |
| LV-09 | Full / Half AM / Half PM | ApplyLeaveForm.tsx:272-286 | apply_leave_tab.dart:1165-1172 | — | — | Complete | Mobile also hides half day when not allowed (backend rule) | apply_leave_types_documents_test | — |
| LV-10 | Dates and validation | ApplyLeaveForm.tsx:118-131 | apply_leave_tab.dart:817-828 | POST leave/requests/ | — | Complete | — | apply_leave_types_documents_test | — |
| LV-11 | Server preview (holidays, week-offs, LOP, sandwich) | ApplyLeaveForm.tsx:95-108,349-408 | apply_leave_tab.dart:252-290,638-655,1390 | GET leave/requests/?action=preview | — | Partial | Mobile shows only counts + warning; web shows full grid and per-date lists | none | P2 |
| LV-12 | Balance block vs LOP vs negative | ApplyLeaveForm.tsx:86-91,108 | apply_leave_tab.dart:57-105,272-290 | POST computes lop_days | — | Complete | Mirrors backend | none | — |
| LV-13 | Supporting document | ApplyLeaveForm.tsx:438-465 | apply_leave_tab.dart:20,218-232 | multipart document | — | Complete | — | apply_leave_types_documents_test | — |
| LV-14 | Handover fields | ApplyLeaveForm.tsx:478-492 | apply_leave_tab.dart:889-924 | same POST | — | Complete | — | none | — |
| LV-15 | Drafts | none on web | apply_leave_tab.dart:452-468,995 | none | — | Partial | Mobile-only "Draft" button shows "Draft saved" but saves nothing (misleading) | none | P2 |
| LV-16 | Success screen | ApplyLeaveForm.tsx:156-185 | apply_leave_tab.dart:440-447 | — | — | Complete | — | none | — |
| LV-17 | Team Calendar | TeamCalendar.tsx:40,211 | team_calendar_tab.dart:101,369 | GET leave/calendar/ | server-scoped | Complete | — | none | — |
| LV-18 | Analytics | LeaveAnalytics.tsx:15-21 | leave_analytics_tab.dart:17,47-48 | GET leave/stats/ | own vs approver | Partial | (a) Mobile sends no year (backend falls back to FY start year); web sends calendar year. Home leave widget uses the same provider. (b) `isEmployee` from role name | none | P1 (a), P3 (b) |
| LVP-01 | Leave Policy route and tabs | W/settings/leave-policy/page.tsx:28-37 | leave_policy_screen.dart:76-81,110-117 | — | settings.view + module leave | Complete | — | T/core/permissions/p0_permission_parity_test.dart | — |
| LVP-02 | Leave Types list/create/edit/activate | PolicyTab.tsx:117,142,226 | leave_policy_screen.dart:219-233; add_leave_type_dialog.dart | PUT/POST leave/policy/ | settings.edit or leave.approve | Complete | — | none | — |
| LVP-03 | Leave Types delete (in-use → deactivate) | PolicyTab.tsx:162-198,345 | leave_policy_screen.dart:235-268 | DELETE leave/policy/<t>/ | same | Partial | Mobile shows only the raw error; no usage view or "Deactivate instead" | none | P3 |
| LVP-04 | Leave Policy rules | LeavePoliciesTab.tsx:391-440 | leave_policy_rules_tab.dart:533-797 | PUT leave/policy/<t>/ | settings.edit / leave.approve | Complete | — | T/features/settings/leave_policy_long_leave_test.dart | — |
| LVP-05 | Carry-forward settings (type, mode, expiry) | CarryForwardSettingsSection.tsx:59-73 | leave_policy_rules_tab.dart:825-850 | PATCH leave/policy/<t>/ | same | Partial | Mobile omits carry_forward_type/mode/expiry_days (comment wrongly calls them "phantom"; they exist in models.py:218-220) | none | P2 |
| LVP-06 | Monthly Credit Settings | MonthlyCreditSettingsSection.tsx | monthly_credit_settings_section.dart | PATCH policy | same | Complete | — | T/features/settings/monthly_credit_settings_test.dart | — |
| LVP-07 | Late-arrival limit card | LateArrivalLimitCard.tsx:26,53 | late_arrival_limit_card.dart:34,102 | PUT late-arrival-limit | attendance.edit for list | Complete | — | T/features/settings/late_arrival_limit_test.dart | — |
| LVP-08 | Credit All Employees | CreditTab.tsx:20-35 | leave_credit_rules_screen.dart:113-148 | POST leave/balance/credit/ | leave.approve | Complete | — | none | — |
| LVP-09 | Accrual rules list | none (web route is a redirect) | leave_credit_rules_screen.dart:9-70; leave_credit_rule_model.dart:3-9 | none | — | Partial | Mobile shows local seed rules with Add/Edit and no backend; reset on restart | none | P2 |
| LVP-10 | /settings/leave-credit-rules route | redirect to leave-policy | Credit Rules tab | — | settings.view | Intentional exception | Web route is only a redirect | — | — |
| LVP-11 | Carry Forward tab | CarryForwardTab.tsx:28-109 | leave_carry_forward_tab.dart:17,157,532 | leave/carry-forward/… | UI leave.edit; backend leave.approve | Complete (parity) | Shared web/backend permission mismatch; stale "404" comments on mobile | p0_permission_parity_test | P3 |
| LVP-12 | Monthly Leave Management | MonthlyLeaveTab.tsx:132-338 | monthly_leave/*.dart | leave/monthly-credits/… | leave.approve | Complete | — | T/features/settings/monthly_leave_management_test.dart | — |
| LVP-13 | Opening balance import | OpeningBalanceImportModal.tsx:65-115 | leave_balance_import_screen.dart; access_control.dart:139 | leave/balance/import/… | UI settings.view + leave.edit; backend leave.approve | Complete (parity) | Same shared mismatch; backend import not employee/branch-scoped | T/features/settings/leave_balance_import_access_test.dart | P2 (backend) |
| LVP-14 | Holiday Calendar views, filters, paging | W/settings/holiday-calendar/page.tsx:32-131 | holiday_calendar_screen.dart:55-250 | GET leave/holidays/?year | settings.view + module leave | Complete | — | none (module_gating_test only) | — |
| LVP-15 | Holiday CRUD | HolidayFormModal.tsx:29-146 | holiday_form_dialog.dart:25-165 | POST/PATCH/DELETE leave/holidays/<id>/ | settings.edit or leave.approve | Complete | — | none | — |
| LVP-16 | Holiday branch filter | page.tsx:81-86 (client-side) | holiday_calendar_providers.dart:11-26 (server ?branch=) | GET ?branch= | — | Partial | Backend honours ?branch= for anyone (holidays.py:65-66), so mobile shows other branches' holidays to restricted users | none | P3 |
| LVP-17 | Notice Period settings | W/settings/notice-period/page.tsx:36-155 | M/settings/presentation/notice_period/*.dart | GET/PUT employees/, notice-period/import/ | employees.edit | Complete | — | T/features/settings/notice_period_settings_test.dart | — |
| WFH-01 | WFH route, 3 tabs | W/work-from-home/_client.tsx:16-20 | M/wfh/presentation/screens/wfh_screen.dart:65-85 | — | wfh.view; module wfh | Complete | — | none | — |
| WFH-02 | Request form (location, medical proof) | RequestWfhForm.tsx:165-198 | request_wfh_tab.dart:121,191-219 | POST wfh/requests/ | self | Complete | — | T/features/wfh/wfh_medical_request_test.dart | — |
| WFH-03 | Saved locations | RequestWfhForm.tsx:66-159 | wfh_saved_location_picker.dart:30-47 | wfh/saved-locations/ | self | Complete | — | none | — |
| WFH-04 | My Requests (status, L1/L2, cancel) | MyWfhRequestsList.tsx:28-110 | my_wfh_requests_tab.dart:47-155 | GET/PATCH wfh/requests/ | can_cancel | Complete | — | none | — |
| WFH-05 | Daily work reports | WfhDailyReports.tsx:28-127 | wfh_daily_reports_tab.dart; wfh_report_providers.dart | wfh/reports/… | server-scoped | Complete | — | T/features/wfh/wfh_daily_reports_tab_test.dart, wfh_report_data_test.dart | — |
| WFH-06 | Approve/reject (Approvals) | TeamApprovalsSection.tsx:63 | approvals_providers.dart:312 | wfh/requests/<id>/approve/ | wfh.approve + module | Complete | Mobile also adds wfh.approve to the Approvals gate | none | — |

Counts (41 rows): Complete 30 · Partial 10 · Missing 0 · Intentional exception 1 · Blocked 0 · Unverified 0.

Concerns:
- LV-18a (P1, Flutter): Analytics and Home leave widget use the year-less stats provider; Jan–Mar they show the financial-year figures while web shows the calendar year.
- Backend B1 (P1): leave preview and submit disagree for monthly-credit policies (leave.py:849-858 vs 1011-1027); neither subtracts pending requests on the yearly path.
- Backend B2 (P1): company-wide balance writes for any leave.approve holder (opening import, credit-all, carry-forward run, policy/holiday writes) with no employee/branch scope.
- Shared permission mismatch: Opening Balance Import and Carry Forward UI gate on leave.edit; backend requires leave.approve.
- Misleading mobile UI (P2): fake "Draft saved" button; local-only accrual rules; rounded balances; carry-forward fields missing.

---

### B. Payroll, Expenses, Assets, Document Center, Separation (PAY / EXP / AST / DOC / SEP)

Paths: W = `web_frontend_backend/frontend/app/dashboard`, M = `mobile_app/lib/features`, B = `web_frontend_backend/backend/apps`, T = `mobile_app/test/features`.

| ID | Feature | Web | Mobile | Backend endpoint | Perm / module rule | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| PAY-01 | My Payslips list | W/my-payslip/page.tsx:127 | M/payroll/presentation/screens/my_payslip_screen.dart:118 | GET /payroll/my-payslips/ (payslips.py:389) | payroll.view_own; module payroll | Complete | Page 1 only (default 20) on both apps | T/payroll/payslip_document_parity_test.dart | P3 |
| PAY-02 | Payslip detail (letterhead, earnings, bank mask) | page.tsx:216 | my_payslip_screen.dart:325-447 | same | same | Complete | — | payslip_document_parity_test.dart | — |
| PAY-03 | Download PDF | page.tsx:265 | my_payslip_screen.dart:330 (external app) | payslip_pdf field | — | Complete | Backend never writes `payslip_pdf`, so the button is disabled/hidden on both | none | — |
| PAY-04 | Print / Save as PDF | page.tsx:261 window.print() | none | — | — | Missing | No way to get a payslip PDF on mobile | none | P2 |
| PAY-05 | Acknowledge payslip | page.tsx:145,246 | my_payslip_screen.dart:171,340 | POST my-payslips/<id>/acknowledge/ | own payslip, status sent | Complete | — | none | — |
| PAY-06 | Raise query (2000 chars, deadline, eligibility) | page.tsx:166, lib/payslipQuery.ts | M/payroll/presentation/widgets/payslip_queries_section.dart:33,216 | POST /payroll/queries/ | view_own; server checks window | Complete | — | T/payroll/payslip_queries_test.dart | — |
| PAY-07 | My query history | page.tsx:131 | payroll_remote_datasource.dart:42 | GET queries/?mine=1 | — | Complete | — | payslip_queries_test.dart | — |
| PAY-08 | HR resolve payslip query | web Approvals | M/approvals/.../approvals_providers.dart:322,481 | POST queries/<id>/resolve/ | payroll.view + module to list; payroll.edit to resolve; branch-scoped | Complete | — | T/approvals/payslip_query_resolution_test.dart | — |
| PAY-09 | Admin payroll runs, cycle payslips, dispatch, ECR/ESIC | W/payroll (+runs, payslips) | none | /payroll/cycles/… | payroll.view/edit | Intentional exception | Web-only by product decision | — | — |
| PAY-10 | Payroll config | W/settings/payroll-config | none | /payroll/settings/ etc. | settings/payroll | Intentional exception | Web-only by product decision | — | — |
| PAY-11 | Employee profile Salary tab | employees/[id] | M/employees/presentation/widgets/employee_salary_payroll_tabs.dart:75,162 | /payroll/employee-salary/history/<id>/ | payroll.view; edit payroll.edit; branch-scoped | Complete | — | T/employees/employee_salary_payroll_test.dart | — |
| PAY-12 | Employee profile Payroll tab | employees/[id] | employee_salary_payroll_tabs.dart:82 | /payroll/employees/<id>/payslips/ | payroll.view + branch | Complete | Page 1 only | employee_salary_payroll_test.dart | P3 |
| EXP-01 | List and stats tiles | W/expenses/_components/ExpenseClaims.tsx:91-150 | M/expenses/presentation/screens/expense_screen.dart:38,198 | GET /expenses/, /expenses/stats/ | expenses.view; module expenses | Partial | No "Rejected" tile or pending/approved amounts on mobile; page 1 only on both | none | P3 |
| EXP-02 | Category filter chips | not on web | expense_screen.dart:21 | ?category= | — | Complete | Mobile-only extra; categories match the backend model | none | — |
| EXP-03 | Submit with receipts (multi-file, 5 MB) | ExpenseFormModal.tsx:51-94 | M/expenses/presentation/widgets/expense_form_sheet.dart:101-173 | POST /expenses/ | IsAuthenticated | Partial | Mobile-only limits: date within past 365 days, no future dates; description 500 chars | none | P3 |
| EXP-04 | Detail and receipt open | ExpenseDetailModal.tsx:102 | M/expenses/presentation/widgets/expense_detail_dialog.dart:31 | GET /expenses/<n>/ | owner or access check | Complete | — | none | — |
| EXP-05 | Approve / reject | Approvals | approvals_providers.dart:299,399,430 | PUT /expenses/<n>/ | expenses.approve + module; no self-approval | Complete | Mobile sends no template_name (no decision email; optional on web too) | T/approvals/approvals_reachability_test.dart | — |
| EXP-06 | Stats branch scoping | ExpenseClaims.tsx:92 | expense_screen.dart:38 | /expenses/stats/ (expenses.py:366) | approvers get `Expense.objects.all()` | Blocked (backend) | Approvers see company-wide counts and amounts while their list is scoped | none | P2 |
| EXP-07 | Edit/delete expense, remove receipt | not exposed | not exposed | PUT/PATCH/DELETE /expenses/<n>/ | — | Complete (neither app) | — | — | — |
| AST-01 | Assets list, filters, pagination | W/settings/assets/page.tsx:34-55 | M/settings/presentation/assets/assets_settings_screen.dart:27-216 | GET /assets/ (branch-scoped) | assets.view; module assets | Complete | — | T/settings/assets_settings_test.dart | — |
| AST-02 | Add/edit/delete asset, inline category/type | page.tsx:145-224 | assets_settings_screen.dart:113-115,846 | POST/PUT/DELETE /assets/… | assets.create/edit/delete; own branch | Complete | — | assets_settings_test.dart | — |
| AST-03 | Maintenance send / complete | page.tsx:259,298 | assets_settings_screen.dart:100 | /assets/<id>/send-to-maintenance/… | assets.edit | Complete | — | assets_settings_test.dart | — |
| AST-04 | Bulk import + sample | BulkImportAssetsModal.tsx | M/settings/presentation/assets/asset_bulk_sheet.dart:74-157 | /assets/import/… | assets.create | Complete | — | T/settings/asset_bulk_test.dart | — |
| AST-05 | Bulk assign | BulkAssignAssetsModal.tsx | asset_bulk_sheet.dart | /assets/assignments/import/ | assets.edit | Complete | — | asset_bulk_test.dart | — |
| AST-06 | Employee Assets tab: assign, return, history | W/employees/[id]/_components/AssetsTab.tsx:23 | M/employees/presentation/widgets/employee_assets_tab.dart:32,75,88 | /assets/employees/<id>/… | own or assets.view in scope; assets.edit to change | Complete | — | T/employees/employee_assets_tab_test.dart | — |
| AST-07 | Employee acknowledge asset | not on web | none | none | — | Complete (N/A) | Not built on web or backend | — | — |
| DOC-01 | List, category tabs, ?category= deep link | W/documents/page.tsx:100-133 | M/documents/presentation/screens/documents_screen.dart | GET /documents/ | documents.view; module documents | Complete | Mobile loads one page of 50 (web 20) | none | — |
| DOC-02 | Search | page.tsx:79-106 (server, debounced, title + description) | document_providers.dart:178-189 (client-side) | ?search= | — | Partial | Mobile filters only the 50 loaded documents and ignores descriptions | none | P2 |
| DOC-03 | Stats | page.tsx:136-139 | M/documents/presentation/widgets/document_stats_row.dart | /documents/stats/ | documents.view; company-wide | Complete | Company-wide on both (backend) | none | — |
| DOC-04 | Upload (25 MB, requires-ack) | page.tsx:151-165,603 | M/documents/presentation/widgets/document_upload_dialog.dart | POST /documents/ | documents.create | Partial | No client-side 25 MB check (server enforces) | none | P3 |
| DOC-05 | In-app preview | page.tsx:215-265 | document_detail_dialog.dart:201; shared/documents/document_links.dart:86 | file_url (2 h signed token) | documents.view | Complete | — | T/shared/document_links_test.dart | — |
| DOC-06 | Download | page.tsx:521,580 | document_detail_dialog.dart:218 (external app) | ?t= signed stream | token only | Complete | Signed 2 h link handed to an external app (see security notes) | document_links_test.dart | — |
| DOC-07 | Delete | page.tsx:186 | document_detail_dialog.dart:160 | DELETE /documents/<id>/ | documents.delete | Complete | Backend has no owner/branch check | none | — |
| DOC-08 | Policy acknowledgement (pending, ack, HR report, toggle) | page.tsx:494 | acknowledgement_panel.dart; pending_acknowledgements.dart | /documents/… acknowledgement endpoints | documents.view / documents.edit | Complete | — | T/documents/policy_ack_test.dart | — |
| DOC-09 | Branch-restricted document visibility | page.tsx:479 ("Access: Branch X") | document detail | GET /documents/ (views.py:2503) | none | Blocked (backend) | List and detail ignore the document's branch: every documents.view holder sees every branch's documents | none | P1 |
| SEP-01 | Create request for self | W/separation/_components/SeparationFormModal.tsx:98-126 | M/separation/presentation/widgets/separation_form_sheet.dart:178-231 | POST /separation/requests/ | IsAuthenticated; module separation | Complete | — | T/separation/separation_notice_period_test.dart | — |
| SEP-02 | Create for another employee | _access.ts canPickEmployee | separation_screen.dart:109; employee_picker_field.dart | POST with employee_id | employees.view or settings.edit; branch check | Complete | Backend lets employees.view alone file for others (separation.py:187) | separation_employee_filter_test.dart | P2 (backend) |
| SEP-03 | My / Team scope | page.tsx:21,92-98 | separation_screen.dart:40,148-158 | ?scope=team | separation.approve or settings.edit | Complete | — | T/separation/separation_approvals_test.dart | — |
| SEP-04 | Employee-code filter | page.tsx:32 | separation_screen.dart:47,80-112 | ?employee_id= exact | employees.view or separation.approve | Complete | — | T/separation/separation_employee_filter_test.dart | — |
| SEP-05 | Status filter | not on web | separation_screen.dart:204 | ?status= | — | Complete | Mobile-only extra | none | — |
| SEP-06 | Edit / cancel / delete request | [id]/page.tsx:118-169 | separation_detail_screen.dart:226-260 | PATCH / DELETE | server can_* flags | Complete | — | separation_approvals_test.dart | — |
| SEP-07 | Approval stages and decisions | [id]/_components/ApprovalSection.tsx | separation_approval_section.dart; separation_decision_dialog.dart | POST …/stages/<id>/action/ | server can_action | Complete | — | separation_approvals_test.dart | — |
| SEP-08 | KT handover add / toggle / delete | KtHandoverSection.tsx:33 | separation_handover_section.dart:95 | …/tasks/ | approve and not own | Complete | Neither app lets the assignee tick their own task, though the backend allows it | T/separation/separation_handover_documents_permissions_test.dart | P3 |
| SEP-09 | Clearances approve / reject | ClearanceSection.tsx:30-80 | separation_clearance_section.dart | …/clearances/<id>/action/ | can_action | Complete | — | none dedicated | — |
| SEP-10 | Documents upload | DocumentsSection.tsx:27 | separation_detail_screen.dart:297 | POST …/documents/ | own or separation.approve | Complete | Mobile follows the backend rule (deliberately differs from web) | separation_handover_documents_permissions_test.dart | — |
| SEP-11 | Documents delete | DocumentsSection.tsx:102 | separation_documents_section.dart:32-39 | DELETE …/documents/<id>/ | approver or uploader | Partial | Serializer sends no uploaded_by/can_delete, so employees can't delete their own upload (backend gap) | separation_handover_documents_permissions_test.dart | P3 |
| SEP-12 | Activity log | ActivitySection.tsx | separation_activity_section.dart | …/activities/ | visibility | Complete | — | none | — |
| SEP-13 | Notice period | SeparationDetailsSection.tsx | notice_period.dart; separation_detail_screen.dart:204-208 | serializer fields | — | Complete | — | separation_notice_period_test.dart | — |

Counts (43 rows): Complete 33 · Partial 5 · Missing 1 · Intentional exception 2 · Blocked 2 · Unverified 0.

Security notes (backend unless stated):
- DOC-09 (P1): `DocumentListCreateView.get` (accounts/views.py:2503-2546) filters only `is_active`; detail has no branch check either.
- Document PUT/PATCH/DELETE (views.py:2704-2820) check only the codename (P2). Document stats company-wide.
- `ExpenseStatsView` (hrms/views/expenses.py:366-372) aggregates all expenses for any approver (P2).
- Expense delete has no submitter check (expenses.py:316-342); not exposed by either app (P3).
- Separation create-for-other needs only employees.view (separation.py:187-193) (P2).
- Branch helpers treat a user with no branch as unrestricted (P2).
- Flutter: signed 2 h document/receipt/payslip links are handed to external apps (matches web) (P3).
- Test gaps: no expense tests; no Document Center list/search/upload/delete tests.

---

### B. Recruitment, Assessments, Referrals (REC / ASM / REF)

Paths: W = `web_frontend_backend/frontend`, B = `web_frontend_backend/backend`, M = `mobile_app/lib/features`, T = `mobile_app/test/features`.

| ID | Feature | Web | Mobile | Backend endpoint | Perm / module | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| REC-01 | Interview List route + module gate | W/app/dashboard/interview-list/page.tsx; proxy.ts:13 | M/interview_list/.../interview_list_screen.dart | GET recruitment/candidates/ | recruitment.view; module recruitment | Complete | — | interview_list_paging_test | — |
| REC-02 | Stats tiles | page.tsx:262 | interview_list_screen.dart `_StatsRow` | candidates/stats/ | recruitment.view | Complete | Backend counts company-wide (views.py:1260) | none | P3 |
| REC-03 | Search | page.tsx:213 | interview_providers.dart | ?search= | — | Complete | — | interview_list_paging_test | — |
| REC-04 | Status filter | page.tsx:388 (8 options) | interview_list_widgets.dart:132 (All/Pending/Selected/Rejected) | ?status= honours only pending/selected/rejected (views.py:371) | — | Intentional exception | Web offers 5 options the server ignores; mobile shows only working ones | none | — |
| REC-05 | Branch filter / locked label | page.tsx:292-325 | interview_providers.dart:79-97 | ?branch= honoured only with settings.edit | settings.edit | Complete | Mobile relies on server scoping (see B6) | interview_list_branch_filter_test | — |
| REC-06 | Pagination | page.tsx:516-556 (numbered) | infinite scroll | ?page= (10) | — | Complete | Different UX, same data | interview_list_paging_test | — |
| REC-07 | Empty / error states | page.tsx:411 | `_EmptyView`, `AppErrorState` | — | — | Complete | — | none | — |
| REC-08 | Add Candidate | AddCandidateModal.tsx:80-113 | add_candidate_sheet.dart:84-196 | POST candidates/ | recruitment.create | Complete | — | add_candidate_permission_test, candidate_branch_picker_test | — |
| REC-09 | Edit candidate | EditCandidateModal.tsx (PATCH) | add_candidate_sheet.dart:170-248 (PUT) | PUT/PATCH candidates/<id>/ | recruitment.edit | Complete | Mobile uses PUT with required fields | candidate_edit_permission_test | — |
| REC-10 | "Set Details" warning for referrals missing branch/date | page.tsx:458-460 | candidate_card.dart:199-224 | — | recruitment.edit | Partial | No highlight/label on mobile | none | P3 |
| REC-11 | Scheduling (date, time, mode, meeting link) | AddCandidateModal.tsx:186-207 | add_candidate_sheet.dart:168-184 | same | — | Complete | — | interview_scheduling_test | — |
| REC-12 | Interviewer picker | AddCandidateModal.tsx:58 | add_candidate_form.dart:356 | GET accounts/employees/ | — | Complete | Both capped at 50 rows by backend | interview_scheduling_test | — |
| REC-13 | Inline status change | page.tsx:63-91 | candidate_card.dart `_StatusChangeButton` | PATCH candidates/<id>/status/ | recruitment.edit | Complete | — | candidate_status_menu_test | — |
| REC-14 | Select/Reject modal (template preview, remarks) | MarkCandidateModal.tsx:60-135 | mark_candidate_sheet.dart:53-110 | status PATCH sends email | recruitment.edit | Unverified | Template-preview rendering not compared in detail | candidate_email_dedup_test | — |
| REC-15 | Send Login | page.tsx:475 | candidate_card.dart:291-327 | POST send-portal-login/ | recruitment.edit | Complete | — | candidate_send_login_test | — |
| REC-16 | "Login Sent" / "Employee" badges | page.tsx:491-501 | candidate_card.dart | — | — | Unverified | Mobile badges for offer_sent/converted not confirmed | none | — |
| REC-17 | Activity logs | LogsModal.tsx:33 | activity_log_dialog.dart:63-102 | GET candidates/<id>/ | recruitment.view | Complete | — | none | — |
| REC-18 | Bulk import | CandidateBulkImportModal.tsx:11-25 | candidate_bulk_import_screen.dart:15-75 | POST candidates/bulk-import/ | recruitment.create | Complete | — | candidate_bulk_import_access_test | — |
| REC-19 | Sample download | CandidateBulkImportModal.tsx:38-51 | interview_datasource.dart:111 | GET bulk-import/sample/ | recruitment.view | Complete | — | candidate_import_sample_test | — |
| REC-20 | Resume upload/preview | not a web feature | none | — | — | Intentional exception | — | — | — |
| REC-21 | Candidate detail page | no web route (modals) | sheets | — | — | Intentional exception | — | — | — |
| REC-22 | Delete candidate | no web UI | none | DELETE exists (views.py:604) | recruitment.delete | Intentional exception | — | — | — |
| REC-23 | Candidate Review (onboarding approvals list, stats) | W/app/dashboard/candidate-review/page.tsx:15-151 | M/candidate_review/.../candidate_review_screen.dart:127-178 | GET onboarding/approvals/ (branch-scoped) | recruitment.view; actions employees.approve/onboarding.approve | Complete | — | candidate_review_permission_test, candidate_review_branch_column_test | — |
| REC-24 | Approve (dept/designation, UAN, PAN, assessment) | OnboardingDrawer.tsx:139-205 | candidate_review_screen.dart:497-519 | POST onboarding/approvals/<id>/ | onboarding.approve | Complete | — | candidate_review_approval_test, candidate_review_epf_fields_test | — |
| REC-25 | Send back for corrections | OnboardingDrawer.tsx:226 | candidate_review_screen.dart:878 | same, decision=reject | same | Complete | — | candidate_review_approval_test | — |
| REC-26 | Applicant detail (masked bank, emergency contact) | OnboardingDrawer.tsx:259-293 | candidate_review_screen.dart:743-745 | GET onboarding/approvals/<id>/ | same | Complete | — | none | — |
| REC-27 | Onboarding document preview | OnboardingDrawer.tsx:208-213 | candidate_review_screen.dart:1149-1151 `onPressed: () {}` | file_url | same | Partial | Open button does nothing: approvers can't view ID/bank documents | none | P1 |
| REC-28 | Legacy HR decision modal | HRDecisionModal.tsx (imported nowhere) | none | candidates/review/ | — | Intentional exception | Dead code on web | — | — |
| REC-29 | Email Logs | W/app/dashboard/email-logs/page.tsx:41-131 | M/email_log/.../email_log_screen.dart | GET recruitment/emails/ | recruitment.view; module recruitment | Complete | Backend company-wide (B1) | none | — |
| ASM-01 | Admin view vs My Assessments | W/app/dashboard/assessments/page.tsx:129,281 | assessments_providers.dart:149-169 | GET assessments/ needs .view | any assessments.*; module | Complete | Create-only user gets 403 on both | assessments_permission_test | — |
| ASM-02 | Stats header | page.tsx:185,305 | assessments_screen.dart | — | — | Unverified | Not compared | none | — |
| ASM-03 | Create/Edit assessment | page.tsx:193-226 | assessment_form_dialog.dart | POST/PUT assessments/ | .create/.edit | Complete | — | assessments_permission_test | — |
| ASM-04 | Delete | page.tsx:233 | assessments_providers.dart:56 | DELETE | .delete | Complete | — | assessments_permission_test | — |
| ASM-05 | "Publish" | none (is_active toggle) | is_active | — | — | Intentional exception | No separate publish step anywhere | — | — |
| ASM-06 | Sections CRUD | ItemsModal.tsx:98-120 | items_manager_dialog.dart | sections/ | .edit | Complete | — | items_manager_sections_test | — |
| ASM-07 | Items (quiz/true-false/video) | ItemsModal.tsx:125-154 | item_form.dart, item_row.dart | items/ | .edit | Complete | — | items_true_false_video_test, assessment_item_payload_test | — |
| ASM-08 | Assign | page.tsx:240-275 | assign_dialog.dart | POST assessments/assign/ | .edit | Complete | Employee list capped at 50 on both (accounts/views.py:3094) | none | P2 |
| ASM-09 | Results expand | page.tsx:396-420 | assessment_results_section.dart | list payload | .view | Complete | — | none | — |
| ASM-10 | My Assessments | EmployeeMyAssessments.tsx:35-162 | my_assessments_screen.dart | GET assessments/my/ | self; module | Complete | — | my_assessments_test | — |
| ASM-11 | Taking an assessment | W/app/onboarding/assessments/page.tsx:244-272 | assessment_take_screen.dart | POST respond/ | self | Complete | — | assessment_take_test | — |
| ASM-12 | Timer + auto-submit | page.tsx:167-205 | assessment_take_screen.dart:72-81 | POST complete/ | self | Unverified | Tick-based countdown may drift when the app is backgrounded; needs a device test | assessment_take_test | P2 |
| ASM-13 | Attempts / retake | page.tsx:285 | assessment_take_rules.dart:35-51 | POST retry/ | self | Complete | — | assessment_take_test | — |
| ASM-14 | Completion result | page.tsx:95-130 | assessment_result_view.dart | — | — | Complete | — | assessment_take_test | — |
| ASM-15 | Onboarding assessments gate | proxy.ts:195-236 | app_router.dart:300-333; assessment_gate_screen.dart | assessments/my/ | — | Complete | — | assessment_gate_test | — |
| ASM-16 | Assessment Config edit controls | W/.../settings/assessment-config/page.tsx (shown to all) | assessment_config_screen.dart:22-24 (assessments.edit) | GET/PUT assessments/settings/ | GET .view, PUT .edit | Intentional exception | Mobile hides controls the backend refuses | none | — |
| ASM-17 | Config field validation | page.tsx:77-88 | assessment_config_screen.dart:281-294 | PUT | .edit | Complete | — | none | — |
| REF-01 | Referrals route + module | navConfig.ts:72; modules.ts:36 | access_control.dart | — | module recruitment | Complete | — | refer_candidate_branch_picker_test | — |
| REF-02 | Stats (all vs my fallback) | page.tsx:203-225 | referrals_screen.dart | referrals/all/ stats | — | Unverified | Fallback logic not compared | none | — |
| REF-03 | My Referrals + search | page.tsx:64-105 | referrals_screen.dart:166-173,308 | GET referrals/ | self | Complete | Page 1 (20) only on both | none | P3 |
| REF-04 | All Referrals tab | page.tsx:163,334 | referrals_screen.dart:35-38 | referrals/all/ | recruitment.view | Complete | — | none | — |
| REF-05 | Referral Rules tab | page.tsx:195-201 | referrals_screen.dart:373-430 | GET referral-rules/ needs settings.view (views.py:1704) | — | Blocked | Ordinary employees get 403 on both platforms | none | P2 |
| REF-06 | "Referral Bonus Breakdown" panel | not on web | referral_rule_card.dart:113-121 (hard-coded ₹10,000 / 90 days) | none | — | Partial | Mobile-only static figures with no data source; may misstate policy | none | P2 |
| REF-07 | Refer dialog | page.tsx:234-466 | refer_candidate_dialog.dart | POST referrals/ | any user | Complete | — | refer_candidate_branch_picker_test | — |
| REF-08 | Branch picker | page.tsx:187-194,433 | referral_providers.dart:101-109 | serializer drops branch | — | Intentional exception | Cosmetic on both; web can strand users on an empty required select | refer_candidate_branch_picker_test | P3 |
| REF-09 | Referral bonuses admin | no web UI | none | referral-bonuses/* | — | Intentional exception | — | — | — |
| REF-10 | Referral Rules settings CRUD | W/.../settings/referral-rules/page.tsx:39-64 | referral_rules_settings_screen.dart:21-122 | POST/PATCH/DELETE need settings.edit | settings.view route | Complete | Mobile hides controls the backend refuses | none | — |
| REF-11 | Rule validation and delete confirm | page.tsx:37-64 | referral_rules_settings_screen.dart:97-283 | same | settings.edit | Complete | — | none | — |

Counts (57 rows): Complete 39 · Partial 3 · Missing 0 · Intentional exception 9 · Blocked 1 · Unverified 5.

Security (backend unless stated):
- B1 (P1): Email logs not branch-scoped (`CandidateEmailLogView.get`, recruitment/views.py:1052-1083): candidate names/emails/subjects company-wide to any recruitment.view holder.
- B2 (P1): All Referrals not branch-scoped (`ReferralAllView`, views.py:1659-1697).
- B3 (P3): Candidate stats company-wide.
- B4 (P2, latent): `CandidateReviewListView` (views.py:999) unscoped; unused by both clients.
- B5 (P2): Three candidate GET endpoints skip `_can_access_candidate` (status views.py:758, hr-decision :946, send-portal-login :1467).
- B6 (P2): Candidate list fails open for a non-admin with no branch (views.py:366-368).
- B7 (P2): GET referral-rules needs settings.view, so ordinary employees get 403 on the Rules tab.
- B8 (info): Referral serializer drops branch.
- F1 (P1, Flutter): onboarding document preview does nothing (candidate_review_screen.dart:1151).
- F2 (P2, Flutter): hard-coded referral bonus panel.
- F3 (P2, Flutter): assessment timer may drift when backgrounded (device test).
- Test gaps: Email Logs, Referral Rules settings, Assessment Config, referral tabs/stats, candidate review document preview.

---

### B. Approvals, Settings hub, Audit Log, Reports, Announcements, Modules (APR / SET / AUD / RPT / ANN / MOD)

Paths: W = `web_frontend_backend/frontend`, B = `web_frontend_backend/backend`, M = `mobile_app/lib`.

| ID | Feature | Web | Mobile | Backend | Perm / module | Class | Gap | Tests | Sev |
|---|---|---|---|---|---|---|---|---|---|
| APR-01 | Approvals route gate | W/proxy.ts:31 [leave.approve, expenses.approve] | M/core/router/access_control.dart:85,100 (+wfh, separation, delegators) | — | backend-authorised queues | Intentional exception | Mobile follows the backend rule (Tasks 71a/71g) | approvals_reachability_test | — |
| APR-02 | Reach for Face-only, payroll.edit-only, manager-only users | W/proxy.ts:31 | access_control.dart:85 | payroll/views/attendance_approval.py:39 | — | Blocked | Managers without leave.approve can't reach L1 attendance sign-off on either platform; same for payroll.edit-only HR (Face approvers have the Face ID screen) | approvals_reachability_test | P2 |
| APR-03 | Team Approvals tab visibility | W/app/dashboard/approvals/page.tsx:18 | approvals_screen.dart | — | any approve code; mobile adds wfh.approve | Complete | — | admin_approvals_access_test | — |
| APR-04 | Per-kind fetch + module gate | TeamApprovalsSection.tsx:46-63 | approvals_providers.dart:298-323 | team queues | module + permission | Complete | Mobile stricter | admin_approvals_access_test | — |
| APR-05 | Status filter (default Pending) | _data.ts:172 toDisplayStatus | approvals_providers.dart:588 (raw status) | — | — | Partial | Default "Pending" hides `l2_pending` leave/WFH/correction rows and `resubmit` corrections (only separation is normalised): HR L2 approvers see an empty inbox (verified) | none | P1 |
| APR-06 | Search and date range | TeamApprovalsSection.tsx:121-127 | approvals_providers.dart:575-592 | — | — | Complete | — | none | — |
| APR-07 | Type tabs and summary cards | _data.ts; SummaryCards.tsx | approvals_toolbar.dart; approvals_summary_cards.dart | — | module | Complete | — | stat_card_layout_test | — |
| APR-08 | Leave approve with remarks | TeamApprovalsSection.tsx:261 (remarks, template) | approvals_list.dart:286 → leave_remote_datasource.dart:175 sends only {action} | leave.py:1228 stores remarks | leave.approve | Partial | Remarks typed on mobile are silently dropped for leave approvals (verified) | none | P2 |
| APR-09 | Decision email-template picker | ApprovalModal.tsx:22-156 | none | template_name | — | Missing | Mobile can't send templated decision emails | none | P3 |
| APR-10 | Reject requires remarks | ApprovalModal.tsx:173 | approve_reject_dialog.dart | — | — | Complete | Backend drops expense remarks on both platforms | none | — |
| APR-11 | can_action handling | _data.ts:209-324 | approvals_providers.dart:128-263 | server flags | — | Complete | — | payslip_query_resolution_test | — |
| APR-12 | Bulk approve/reject | TeamApprovalsSection.tsx:135-160 | approvals_list.dart:150-170 | per item | — | Partial | Same remark loss as APR-08 | none | P2 |
| APR-13 | Late-justification rows | own review modal | review flow | /attendance/corrections | attendance.create | Complete | — | late_justification_review_test | — |
| APR-14 | Separation (detail page) | TeamApprovalsSection.tsx:161-187 | approvals_providers.dart:88-104 | stage action | separation.approve | Complete | — | separation_approvals_test | — |
| APR-15 | Payslip query resolve | _data.ts:305 | resolve_payslip_query_dialog.dart | /payroll/queries | payroll module | Complete | Reachable only with another approve code (APR-02) | payslip_query_resolution_test | — |
| APR-16 | Attendance Approval tab gate | page.tsx:30 (payroll.view) | approvals_screen.dart:102 (manager or payroll.edit; attendance + payroll modules) | attendance_approval.py:39; feature_gate.py:39 | — | Intentional exception | Mobile follows the backend (Task 77); web shows the tab to payroll.view users who get 403 | approvals_reachability_test | — |
| APR-17 | Attendance cycle L1/L2 approve + drill-down | AttendanceApprovalTab.tsx:68-93 | attendance_approval_tab.dart | /payroll/cycles/… | as APR-16 | Complete | No dedicated tests | none | P3 |
| APR-18 | Face registration approvals | FaceRegistrationApprovalsTab.tsx:25-33 | face_registration_approvals_tab.dart:24-82 | pending + review | facial_recognition.approve + module | Complete | No dedicated tests | none | P3 |
| APR-19 | Leave cancellations | LeaveCancellationsSection.tsx:15-80 | leave_cancellation_panel.dart | /leave/cancellations | leave.approve + module | Complete | Mobile correctly checks the module | leave_cancellation_test | — |
| APR-20 | Delegation | DelegationsSection.tsx:16-151 | delegations_tab.dart | /approvals/delegations… | canDelegateApprovals | Complete | — | delegations_escalation_test | — |
| SET-01 | Settings hub tiles | W/app/dashboard/settings/page.tsx:9-27 (19) | settings_screen.dart:54-225 (18) | — | module-filtered | Intentional exception | Payroll Rules tile is web-only | module_gating_test | — |
| SET-02 | Hub tile vs per-tile permission | not hidden on web | not hidden | — | — | Partial | settings.view users see e.g. the Audit tile; mobile router refuses, web 403s | none | P3 |
| SET-03 | Hub category tabs | page.tsx:31-37 | settings_screen.dart:13-25 | — | — | Complete | — | none | — |
| SET-04 | Approval rules list/edit | approval-rules/page.tsx:40-80 | approval_rules_screen.dart:33-321 | CanManageRoles (settings.edit, GET too) | — | Complete | settings.view-only users get an error on both | none | P3 |
| SET-05 | Escalation settings card | EscalationSettingsCard.tsx | escalation_settings_card.dart | /approvals/escalation-settings | server can_edit | Complete | Neither exposes the escalation log | delegations_escalation_test | — |
| SET-06 | Notification settings toggles | settings/notifications/page.tsx:32-79 | notification_settings_screen.dart | /notifications/settings | settings.edit on both | Partial | Approval toggle locked on web, editable on mobile (backend reverts) | none | P3 |
| SET-07 | Onboarding fields | FieldConfigTable.tsx:32-111 | onboarding_fields_screen.dart:72-366 | /settings/onboarding-fields | settings.edit | Complete | Drag reorder vs up/down; both work | onboarding_config_test | — |
| SET-08 | Document types CRUD/reorder | DocumentTypeConfigTable.tsx:22-56 | onboarding_fields_screen.dart; document_type_form_sheet.dart | /settings/document-types | settings.edit | Complete | — | onboarding_config_test | — |
| SET-09 | settings.edit without settings.view | — | treats settings.edit as everything | core/permissions.py:58-82 | — | Blocked | Such roles get 403 on HasSettingsPermission reads on both platforms | none | P2 |
| AUD-01 | Audit log route | proxy settings.view; backend audit.view | access_control.dart:89 audit.view | accounts/views.py:4158 | audit.view | Intentional exception | Mobile follows the backend | access_control_test | — |
| AUD-02 | Audit filters | settings/audit/page.tsx (6 modules, last 30 days default) | audit_screen.dart; settings_providers.dart (16 values) | same | — | Partial | Mobile date range defaults to all time (web: last 30 days). (`voice_commands` is a real stored value, written by voice_commands/audit.py — verified in Task 74) | audit_log_paging_test | P3 |
| AUD-03 | Audit paging | numbered, 10/page | Load more | page/page_size | — | Complete | — | audit_log_paging_test | — |
| AUD-04 | Settings audit hides module-off rows | none | none | AuditLogListView has no exclusion | subscription | Blocked | Backend gap | none | P2 |
| AUD-05 | Audit branch scoping | — | — | views.py:4169 (filters only when user.branch set) | audit.view | Blocked | Non-org-wide audit.view holder with blank branch sees the whole company's audit trail (verified) | none | P1 |
| AUD-06 | Admin dashboard audit card | AuditLogsWidget.tsx:11-16 (labels) | admin_dashboard_view.dart | people.py:213 | system admin | Complete | Mobile better (real values) | admin_audit_card_module_filter_test | — |
| AUD-07 | AUDIT_MODULES key | — | — | tenants/access.py:84-87 'announcement' vs stored 'announcements' | — | Blocked | Announcement rows never hidden | none | P3 |
| RPT-01 | Reports | W/app/dashboard/reports/page.tsx (ComingSoon, not in nav) | kUnavailablePaths | none | reports.view | Intentional exception | Web has no real reports module; mobile comment at access_control.dart:158 is inaccurate | access_control_test | — |
| ANN-01 | List, category filter, paging, stats | announcements/page.tsx:174-231 | announcements_screen.dart:148-341 | /announcements/ | module | Complete | — | announcements_pagination_test | — |
| ANN-02 | Create/edit (audience, branch lock, pin, email) | page.tsx:274-380 | post_announcement_sheet.dart | POST/PUT /announcements/ | create/edit + can_edit | Complete | — | announcement_branch_scope_test | — |
| ANN-03 | Delete | page.tsx:404 | announcements_screen.dart:91 | DELETE | delete + can_edit | Complete | — | none | — |
| ANN-04 | Views and reactions | page.tsx:252,423 | datasource:62-76 | /view/, /react/ | — | Complete | — | none | — |
| ANN-05 | Attachments | none on web | none | none | — | Intentional exception | Not a web feature | — | — |
| MOD-01 | Route → module map | W/lib/modules.ts:24-50 | access_control.dart:192-217 | feature_gate.py:23-66 | — | Complete | Differences are web-only screens | module_gating_test | — |
| MOD-02 | Session modules claim | modules.ts:64 | api_client.dart; auth_interceptor.dart | token claims | — | Complete | — | module_gating_test | — |
| MOD-03 | Menu and route hiding by module | proxy.ts:248-250 | nav_config.dart; canAccessPath | — | — | Complete | — | module_gating_test, dashboard_shortcuts_test | — |
| MOD-04 | In-screen module gates | partial on web | gated | backend enforces | — | Complete | Mobile stricter | approvals_reachability_test | — |

Counts (46 rows): Complete 28 · Partial 6 · Missing 1 · Intentional exception 6 · Blocked 5 · Unverified 0.

Test gaps: Attendance Approval tab, Face registration tab, Approval Rules, Notification Settings, Settings hub tiles, Approvals status filtering.

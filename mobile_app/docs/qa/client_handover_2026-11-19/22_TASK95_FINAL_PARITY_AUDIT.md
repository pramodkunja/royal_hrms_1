# 22 — Task 95: Final Web-to-Mobile Parity Audit (18 Nov 2026)

**Method:** source-level comparison of the web app (`web_frontend_backend/frontend`, source of truth) with the Flutter app, by seven read-only auditors (A–G), each writing a row-level matrix (stored under `evidence/t95/`). Backend inspected read-only. No backend/web edits, no git, no production writes, no phone install, release AAB untouched.
**Evidence legend:** SRC = source compared; TEST = mocked-API test exists (**not** production verification); DEVICE = run on the phone (only navigation/screen loads exist for the admin role; **no write flow has a device run**). COMPLETE below means *source + test evidence*, never production-verified.

## 1. Final counts (area matrices A–F; rows can overlap between areas, e.g. departments)
| Area | Rows | COMPLETE | PARTIAL | MISSING | BLOCKED | WEB-ONLY | UNTESTED |
|---|---|---|---|---|---|---|---|
| A Auth, dashboards, self-service, shell | 98 | 67 | 20 | 4 | 0 | 2 | 5 |
| B Attendance, leave, approvals, expenses, separation | 50 | 31 | 11 | 0 | 0 | 2 | 6 |
| C Employees, profile, branches, org data | 68 | 39 | 21 | 5 | 0 | 2 | 1 |
| D Recruitment, assessments, referrals, email log | 57 | 37 | 17 | 0 | 0 | 2 | 1 |
| E Training, payroll, reports, documents, audit | 51 | 28 | 15 | 4 | 0 | 4 | 0 |
| F Settings (+ Platform Admin routes) | 79 | 47 | 14 | 3 | 0 | 15 | 0 |
| **Total** | **403** | **249** | **98** | **16** | **0** | **27** | **13** |
Counts are as classified by the auditors **before** this task's fixes; items fixed in §6 move PARTIAL/MISSING → COMPLETE (source + mocked test) but stay unverified on device. Role matrix G (63 rows): 54 COMPLETE (7 deliberate differences), 1 PARTIAL, 4 MISSING (Reports, admin Payroll, onboarding-approvals route, Platform Admin — all scope decisions), 0 BLOCKED; all rows UNTESTED live (static audit). BLOCKED = 0 everywhere, but role-contract work (§3) is **contract-dependent**.

## 2. Web route → mobile inventory
Full route tables are in the area files (section 1 of each). Summary of the 76 web pages:
- **Mobile equivalent exists (COMPLETE/PARTIAL):** login, change-password, forgot-password flow, onboarding + assessments portal, dashboard (Employee/Manager/HR/Admin), profile, my-attendance, attendance, face-id-registrations, leave, work-from-home, approvals, onboarding-approvals (merged into Approvals/Candidate Review), expenses, separation (+[id]), my-requests, announcements, contacts, org-chart, documents, employees (+[id], id-card, new), branches, candidate-review, interview-list, assessments, referrals, email-logs, training (+[id]), my-learning (+[id]), my-payslip, every `/dashboard/settings/*` page except payroll-config.
- **WEB-ONLY by approval (27 rows):** Platform Admin (14 routes), admin Payroll (`/dashboard/payroll`, runs, payslips admin), `settings/payroll-config`.
- **MISSING with a reason:** `/dashboard/reports` — the web page is a "coming soon" stub (nothing to port; mobile hides it via `kUnavailablePaths`; the comment at `access_control.dart:160` is stale).

## 3. Role / permission parity (details: `evidence/t95/G_roles_permissions.md`)
- Personas are defined by login payload fields (`permissions`, `is_superuser`, `can_manage_team`, `can_manage_branch`, `branch`, `enabled_modules`), not role names. Every codename list compared matches web or is a documented deliberate difference; no safe small fix needed.
- **Contract-dependent mobile work (do not start until the backend contract is fixed — HO-18/HO-50):**
  1. Mobile treats `isSuperuser || settings.edit` as a wildcard (`access_control.dart:19-22`, ~60 call sites, ~25 inline copies). That matches the backend today, not web's raw-codename sidebar. If branch roles stop receiving the wildcard: consolidate the inline copies into `userHasPermission` first (safe refactor), then re-test nav/routes.
  2. A Branch Admin that still holds `settings.edit` gets all-branch pickers (`employee_providers.dart:561`, `attendance_export.dart:78`, `shift_assignment_models.dart:25`); a branch-restricted helper should be added **after** the contract is fixed.
  3. Login `is_superuser` = flag OR `settings.edit`, but the token claim is the Django flag only, so onboarding/assessment exemptions differ between web proxy and mobile.
- **Test gaps:** no test for a role with `can_manage_branch` + `settings.edit` (the live HO-18 state); none for permissions changing after login; no persona tests for the raw-permission sites.

## 4. Gaps by severity (P1/P2 only; P3 rows are in the area files)
| Ref | Gap | Web ref | Flutter ref | API | Status | Next action |
|---|---|---|---|---|---|---|
| E-31/32 | **P1** My Payslip drops one-time adjustments / additions-arrears, no `wage_slip` template; net may not reconcile | `PayslipDocument.tsx:150-215`, `payslipLayout.ts` | `payslip_model.dart`, `my_payslip_screen.dart` | payslip serializer (exists) | PARTIAL/MISSING | Plan G-1 (below); confirm real payload on staging first |
| E-33/34 | P2 No UAN/ESIC strip, letterhead snapshot, designation, stamp (code comment claiming no UAN is stale) | `my-payslip/page.tsx:255-263` | `my_payslip_screen.dart:460` | `uan_display`, `esic_display` exist | MISSING | with G-1 |
| A (S-01) | **P1 (fixed)** Employee dashboard Action Items / Recent Activity read wrong response keys | `EmployeeActionItemsView` (paginated) | `employee_dashboard_models.dart` | exists | **FIXED** (source + mocked test; staging verify) | verify with real employee login |
| A-80b | P2 Profile ignores built-in field visibility config | `ProfileClient.tsx:425-440` | `profile_sections.dart` | `/onboarding/field-config/` | MISSING | Plan P-3 |
| C-10/11 | P2 Add Employee ignores Branch Admin roles (department "Not applicable", designation free text, role filter by permission) | `AddEmployeeModal.tsx:139,244-248` | `add_employee_sheet.dart` | exists | PARTIAL | Plan P-2 |
| C-29/30 | P2 Edit form: hidden DOB still blocks Save; Department no longer required (fixed) | `_data.ts` | `employee_model.dart:735` | exists | PARTIAL | Plan P-2 |
| C-02/03 | P2 Employees stats/filters not from `GET /employees/stats/` (counts ignore branch filter) | `employees/page.tsx` | `employee_providers.dart` | exists | PARTIAL | Plan P-2 |
| C-13/14 | P2/P3 Bulk import: no sample download or error-report export | `BulkImportModal.tsx:48-60` | `employee_bulk_import_screen.dart` | `/employees/bulk-import/sample/` | MISSING | Plan P-2 |
| C-49 | P2 Branch add: no "Other (type city name)" | `BranchManagement.tsx:979-1010` | `branch_location_selector.dart` | `new_city_name` | MISSING | Plan P-4 |
| D-27 | P2 Mark Selected/Rejected: no email preview / unfilled-variable warning | `MarkCandidateModal.tsx:133-231` | `mark_candidate_sheet.dart` | `resolve-context` | PARTIAL | Plan P-5 |
| D-35/37/48 | P2 Assessment create ignores global defaults; results lack Pass/Fail badge + section breakdown; referral stats ignore org-wide `stats` | web assessments, referrals | mobile equivalents | exist | PARTIAL | Plan P-5 |
| B-36 | P2 Expense approve/reject: no email-template choice, so no email is sent | `ApprovalModal.tsx` | `approve_reject_dialog.dart` | `template_name`, `extra_context` | PARTIAL | **product decision** |
| B-06 | P2 HR attendance detail omits Late/Early banner and per-punch geofence/source/distance | `AttendanceDetailDrawer.tsx:216-322` | `attendance_screen.dart ~1812` | already parsed | PARTIAL | Plan P-6 (small, not applied) |
| F-13 | P2 Company → Plan Details tab missing | `PlanDetailsTab.tsx` | — | `GET /settings/company/plan/` | MISSING | Plan P-7 |
| F-31/33 | P2 Leave Type name not editable; delete lacks usage-count / "Deactivate Instead" | `PolicyTab.tsx` | `leave_policy_form_sheet.dart` | exists | MISSING/PARTIAL | Plan P-7 |
| F-52/53 | P2 Role presets (Manager/Employee) differ from web; no "Role created"/re-login message | `permissions/page.tsx` | `role_form_sheet.dart` | exists | PARTIAL | Plan P-7 (permission change — needs product sign-off) |
| E-35/44/50 | P2 Payslip status labels, document "Access" row (**fixed**), Approval notification toggle (**fixed**) | — | — | — | see §6 | — |

## 5. Newly discovered (not in earlier audits)
Employee dashboard response-shape bug (P1, fixed); payslip fidelity gaps and stale UAN comment; Branch "Other city"; Add-Employee Branch Admin flow; employees stats endpoint unused; Plan Details tab; leave-type rename/delete flow; role presets; approval-notification toggle (fixed); document Access row (fixed); `11_FINAL_SCREEN_INVENTORY.csv:86` still lists Training as MISSING (stale, Training is built).

## 6. Small Flutter fixes applied in Task 95 (all with existing APIs; tests updated/added)
| Fix | Source ref | Evidence |
|---|---|---|
| Employee dashboard Action Items / Recent Activity read paginated `results`/`count` (old keys still accepted) | `employee_dashboard_models.dart`; backend `people.py:389-410` | new `employee_dashboard_envelope_test.dart` (3) — **mocked; verify on staging** |
| Profile header phone is tap-to-call (`tel:`), error snackbar if no dialer | web `ProfileHeader.tsx:145`; `employee_profile_screen.dart` | test (launcher override). Real dialer **needs device check** |
| Profile edit: Department no longer required (Branch Admin employees have none; server accepts) | `employee_model.dart` `EmployeeUpdateFormData.validate` | unit test |
| Self-service Profile: bank account shows last 4 digits only (as web) | web `ProfileClient.tsx:658`; `profile_sections.dart` | source only (no dedicated test) |
| Dashboard titles "Recent Activity", "Expense Claims" | web `EmpRecentRequests.tsx`, `EmpConsole.tsx:86` | source |
| Apply Leave messages: "Start date is required.", "End date is required.", "Please provide a reason.", "Reason must be at least 10 characters." | web `ApplyLeaveForm.tsx:133-138` | source |
| Assessment card chips: "Unlimited", "(global)", "No limit" | web `assessments/page.tsx:379-380` | source |
| Send Login: success snackbar "Portal login sent."; Email Log subtitle; interview search hint; Candidate Review error uses friendly message | web interview-list / email-logs | test updated (`candidate_send_login_test`) |
| Document detail "Access" shows branch name when set | web documents page | source |
| Approval notification toggle shown locked ON with web's description (server forces it on) | web `notifications/page.tsx` | source |
Earlier in Task 94 (same day): HO-42/43/44 and profile fixes (doc 21).
**Not applied (reason):** role presets (permission change, product sign-off), payslip status labels (shared by profile Payroll tab + PDF, needs web confirmation), reject-row behaviour (SF-6, behaviour change), audit default 30-day window and logo type/size checks (need test/API checks), quick-action tile (layout + test changes), expense email (product decision), everything in §7.

## 7. Remaining mobile implementation plan (separate batches; none started)
| Batch | Scope | Rough effort | Depends on |
|---|---|---|---|
| P-1 Payslip fidelity (E-31…35) | adjustments/additions, wage_slip template, UAN/ESIC, letterhead snapshot, designation, stamp; status labels | 2–3 days | staging payload sample |
| P-2 Employees module | Add Employee Branch Admin flow, `employees/stats`, hidden-field handling in edit form, bulk-import sample + error report, page subtitle | 3 days | — |
| P-3 Profile config | field-visibility on self-service profile; Company Policy/Contact quick tiles + documents category deep link | 1–1.5 days | — |
| P-4 Branches | "Other (type city name)", copy | 0.5 day | — |
| P-5 Recruitment/assessments | Mark-candidate email preview, assessment defaults, result badge + breakdown, referral stats, take-flow history | 3 days | — |
| P-6 Attendance polish | detail banner + geofence rows, wording pass, Rejected expense card, approvals sort (decision) | 1–1.5 days | — |
| P-7 Settings | Plan Details tab, leave-type rename/delete flow, role presets + success messages, carry-forward validation, hub copy | 2–3 days | product sign-off for presets |
| P-8 Role contract | consolidate permission copies; branch-restricted helper; new persona tests | 1–2 days | backend HO-18/HO-50 contract |
| P-9 Notifications live updates, session-expired notice, birthday cards | 2 days | WebSocket decision |
| P-10 Test debt | tests for invalid-punch actions, un-punches, record form, expense form, correction dialog, approvals bulk, email logs, referral rules, assessment config | 3 days | — |

## 8. Backend developer dependencies
Existing items in doc 20 stand (HO-01, HO-18, HO-45, HO-50, HO-51; current_address; UAN/Aadhaar/ESI). Added by Task 95 (confirm before acting): two meanings of login `is_superuser` vs token claim (`views.py:612`, `tokens.py:23`); expense `remarks` never saved and leave email template ignored (B audit); attendance-approval endpoints require `payroll.edit` while web shows the tab for `payroll.view`; seeded `system_admin` lacks many codenames so web nav hides items the API allows. Details in doc 20 rows 10–13.

## 9. Device / staging verification checklist (nothing below has been run)
1. Employee login (non-admin): dashboard Action Items + Recent Activity populate (fix 1), bank number masked, header phone opens dialer.
2. HR login (`employees.view` only) and Manager login: dashboards, approvals, attendance.
3. Branch Admin login: Action Queue on Admin dashboard (HO-44), branch pickers, Add Employee.
4. Writes on a **test** tenant only: apply leave, attendance correction, expense submit, approve/reject, employee edit, document upload, relationship save, candidate flows, assessment take, training create/assign, payslip acknowledge/query, roles/notification save.
5. Face ID punch verification (HO-01 dependent), forced password change, forgot password, session expiry, onboarding wizard.
6. Staging payslip with adjustments/arrears (for P-1).
7. Assets tab with the module enabled (read-only).

## 10. Release readiness recommendation (advice, not a sign-off)
**Not ready to call "100% parity" or to release without the checks below.** Source parity is high (about 62% of audited rows COMPLETE, ~24% PARTIAL, 4% MISSING, the rest web-only/untested), but evidence is mostly mocked tests; no write path has a device run, and the Employee/HR/Manager roles have never been exercised on a device.
- **Before any release:** (a) device/staging pass of §9 items 1–5; (b) confirm the P1 payslip gap against real payloads and decide P-1 scope; (c) backend HO-01 (face verification) and HO-18/50 remediation or an explicit risk acceptance; (d) a decision on expense approval emails (B-36).
- **Acceptable to defer (documented):** P3 copy/wording rows, live notification sockets, birthday cards, Plan Details tab, role-preset alignment.
- No release, build, deployment or git action was taken.

## 11. Updated register & files
Register rows HO-60…HO-72 added (`07_MASTER_DEFECT_REGISTER.csv`); backend items in doc 20; area matrices in `evidence/t95/A…G`. Verification: focused tests for every change, full suite 2,860 passed, `flutter analyze` 7 infos (all pre-existing; baseline 13), 0 errors/warnings.

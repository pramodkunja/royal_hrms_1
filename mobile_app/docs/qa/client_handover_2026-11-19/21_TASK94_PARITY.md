# 21 — Task 94: Strict Web Parity + Employee Assets (18 Nov 2026)

**Scope:** HO-42 My Approvers, HO-43 Single-Employee Attendance Export, HO-44 Branch Admin Task List, HO-54 Employee Profile Assets, plus a full Employee Profile audit.
**Rules kept:** mobile-only edits; backend and web source read-only; no git commands; no production writes; no phone build installed; no release. Device is still on debug code 17.
**Evidence levels:** *implemented* = source changed; *mocked* = unit/widget tests against a stand-in server; *device* and *staging* = **not done in this task**.

## 1. HO-54 Employee Assets — investigation result: no code gap
| Item | Web (`employees/[id]/_components/AssetsTab.tsx`) | Mobile | Status |
|---|---|---|---|
| Tab gate | `assets` module (`TAB_MODULES`) | `_kTabModules['assets']` → `AppModules.assets` (`employee_profile_screen.dart`) | COMPLETE |
| Who can act | `usePermission("assets.edit")` | same gate | COMPLETE |
| Assigned Assets columns | Asset Tag, Asset Name, Type, Serial Number, Assigned Date, Condition, Status, Return | `widgets/employee_assets_tab.dart` — same | COMPLETE |
| Asset History | Tag, Name, Assigned, Returned, Return Condition, Return Reason | same | COMPLETE |
| Assign dialog | Asset* (available, `page_size=200`), Assigned Date* (today), Condition* (New/Good/Fair/Damaged), Expected Return, Remarks; messages "Select an asset to assign." / "Assigned date is required." / "Failed to assign asset." | same fields, defaults and messages | COMPLETE |
| Return dialog | Return Date*, Return Condition*, Return Reason*, Remarks | same | COMPLETE |
| Success / empty | "Asset assigned/returned successfully." (5 s); "No assets assigned" / "No returned assets yet" | same; mobile adds error + Retry | COMPLETE (+extra) |
| Self-service My Profile | **no** Assets tab (`ProfileClient.tsx` tabs: Personal, Work Info, Education, Bank Details, Documents, Face ID, Security) | none | matches web |

**Why it can look "missing":** (a) the company's Assets module is off — Task 86 recorded "Assets module off for tenant" (DEMO2026); mobile reads the same `modules` claim as web; (b) Assets is the 8th of 9 tabs in a horizontally scrolling bar; (c) comparing against the self-service profile, where web has none either. APIs: `GET /assets/employees/{uuid}/`, `POST …/assign/` and return (existing). **Needs a device/staging check** with Assets enabled (read-only viewing is enough). No production asset or employee record was touched.

## 2. HO-42 Contacts → My Approvers (web `contacts/_components/ApproversSection.tsx`, `lib/contactMatrix.ts`; backend `ContactApproversView`)
| Web element | Mobile | Status |
|---|---|---|
| "My Approvers" card, workflow select (server list; "Leave Request" fallback) | `contact_approvers_section.dart`, key `approvers-workflow` | COMPLETE |
| L1/L2: name, email (mailto) / "No email", phone (tel) / "No phone", "Not Assigned" | same | COMPLETE |
| Expense note text | same text (verbatim) | COMPLETE |
| "Employee Approvers" table only when `team != null` (employees.view) | card hidden when null | COMPLETE |
| Search "Search name, ID, department…" (name/ID/department/branch, local) | same | COMPLETE |
| Empty: "No matching employees." / "No employees in your scope." | same | COMPLETE |
| API `GET /company-contacts/approvers/?workflow=` | `fetchApprovers` | COMPLETE |
Layout-only adaptation: table rows are stacked cards. Pull-to-refresh also reloads approvers. Tests: `test/features/contacts/contact_approvers_test.dart` (7). A defect found and fixed by tests: the workflow picker lost the server list while another workflow loaded.

## 3. HO-43 Single-Employee Attendance Export (web `lib/attendanceExport.ts`, `AttendanceTab.tsx`; backend `hr_attendance.py:876-881`, `serializers_hr.py:48-52`)
| Web | Mobile | Status |
|---|---|---|
| "Export employees": All Employees / Single Employee | scope select in the export sheet (`export-scope`) | COMPLETE |
| Search "Search employee by name or ID…", ≥2 chars, 300 ms, `GET /employees/?search=&page_size=20`, inactive dropped, first 8 | same (`attendance_remote_datasource.dart searchExportEmployees`) | COMPLETE |
| States "Searching…", error text, "No matching employees." | same | COMPLETE |
| Option `full_name` + `ID · department`; pick sets "Name (ID)"; typing clears the pick | same | COMPLETE |
| Export disabled until picked; alert "Select an employee from the list to export." | same (button disabled + message) | COMPLETE |
| `employee=<ID>` replaces branch/department; works for day / month / range | `AttendanceExportRequest.params()` | COMPLETE |
| File `attendance_<ID with [^A-Za-z0-9_-]→_>_<period>.csv` (branch slug ignored) | `fileName()` | COMPLETE |
| Server 404 "Employee not found." (out of scope) | shown in the sheet | COMPLETE |
Tests: `attendance_export_single_employee_test.dart` (11) + existing 26 still pass. Minor: web's disabled-button tooltip "Select an employee to export." is a hover title; mobile shows the visible alert only (constant kept).

## 4. HO-44 Branch Admin dashboard task list (web `AdminDashboard.tsx:83` → `HrActionQueue`)
Mobile `HrActionQueueCard` (the HR dashboard card, now public) is rendered on the Admin dashboard when `canManageBranch`, between Pending Approvals and Department Headcount; refreshed with the dashboard. Counts are scoped by the API (`GET /dashboard/hr/action-queue/`); rows still obey module and permission gates. A plain System Admin sees none (no request). Tests: `admin_branch_action_queue_test.dart` (4).

## 5. Full Employee Profile inventory (web vs mobile) — after this task
Status: COMPLETE / PARTIAL / MISSING / WEB-ONLY; **FIXED** = changed in Task 94.
| # | Area | Web ref | Mobile ref | Status |
|---|---|---|---|---|
| 1 | Not found / loading | `[id]/page.tsx:370-396` | `EmployeeProfileScreen` | **FIXED** ("No employee exists with code …", Back to Employees, "Loading employee…") |
| 2 | Header identity | `ProfileHeader.tsx:124-154` | `employee_profile_screen.dart` header | PARTIAL (minor): Phone is plain text, web is a `tel:` link; web status badge vs text. Left open (needs device check of the dialer launch) |
| 3 | Back/breadcrumb, avatar | `ProfileHeader.tsx` | AppBar | COMPLETE (layout); "Change photo" is a web no-op (WEB-4) |
| 4 | ID Card / Reset Password buttons | `ProfileHeader.tsx` | same | COMPLETE (ID-card size label **FIXED** "Card size (50 × 85 mm)") |
| 5 | Tab bar + module gating | `ProfileTabBar.tsx` | `_kTabModules` | COMPLETE (same 9 tabs/order) |
| 6 | Pending onboarding view | `page.tsx:588-625` | same | COMPLETE |
| 7 | Personal | `_data.ts:144-176` | `_PersonalContent` | **FIXED** (First/Last Name, Login Email, Date of Joining, Branch, Reporting Approver, "Branch HR", Phone not locked, step-0 field visibility, save toast "Changes saved successfully.") |
| 8 | Education, Bank, Emergency | `_data.ts:180-219` | `employee_profile_sections.dart` | COMPLETE |
| 9 | Statutory (UAN/Aadhaar name/ESI) | `_data.ts:222-230` | statutory section | COMPLETE — deliberate difference (changed-fields-only save; web wipes values, HO-59b) |
| 10 | Custom fields / custom files | `page.tsx:478,762` | `custom_fields_block.dart` | COMPLETE (layout: separate block) |
| 11 | Documents | `page.tsx:81-105`, `ProfileForm.tsx:411-519` | `_DocumentsContent` | **FIXED** (config-driven slots, "Not uploaded", Upload/Replace, Preview, intro text; no free type picker). Deliberate difference: uploads outside slots stay listed. |
| 12 | Salary / Payroll tabs | `SalaryTab.tsx`, `PayrollTab.tsx` | `employee_salary_payroll_tabs.dart` | COMPLETE |
| 13 | Leave tab + credits | `LeaveTab.tsx`, `LeaveCreditsSection.tsx` | `employee_leave_tab.dart` | COMPLETE (mobile extra: Approve/Reject in request detail when permitted) |
| 14 | Attendance tab | `AttendanceTab.tsx:26-94` | `employee_attendance_tab.dart` | **FIXED** (sub-lines, progress bars, unrounded values). Deliberate difference: web's hard-coded "Above threshold" omitted (WEB-2) |
| 15 | Approval Matrix | `ApprovalMatrixTab.tsx` | `_ApprovalMatrixTab`, `approval_override_sheet.dart` | **FIXED** (relationship editor can no longer clear; headings, subtitle, empty text, override-sheet copy). Deliberate difference: override sheet starts at "Global default" (WEB-3) |
| 16 | Promotion | `PromotionTab.tsx` | `promotion_tab.dart` | **FIXED** (button, labels, "Update Employee", role warning text) |
| 17 | Assets | `AssetsTab.tsx` | `employee_assets_tab.dart` | COMPLETE (see §1) |
| 18 | Send Wishes | `WishesTab.tsx` | `wishes_tab.dart` | COMPLETE |
| 19 | ID Card screen | `id-card/page.tsx` | `employee_id_card_screen.dart` | COMPLETE (+Share PDF extra) |
| 20 | Activate/Deactivate switch on profile | list page only | profile card | EXTRA on mobile (kept; `employees.edit` + confirm) |

## 6. Other items found
- Web/backend defects (not copied, reported): HO-59 / `20_BACKEND_DEVELOPER_ACTION_ITEMS.md` rows 8–9 and WEB-2…4.
- Header tap-to-call: implemented in Task 95 (doc 22 §6); needs a device check.

## 7. Files changed (mobile only)
`lib/core/constants/api_constants.dart`; `features/contacts/` (model, datasource, provider, `contact_approvers_section.dart`, `contact_matrix_screen.dart`); `features/attendance/` (datasource, repository + impl, `attendance_entity.dart`, `attendance_export.dart`, `attendance_export_sheet.dart`); `features/dashboard/presentation/screens/hr_dashboard_view.dart`, `admin_dashboard_view.dart`; `features/employees/` (`employees_remote_datasource.dart`, `employee_providers.dart`, `employee_profile_sections.dart`, `employee_profile_screen.dart`, `employee_attendance_tab.dart`, `promotion_tab.dart`, `approval_override_sheet.dart`, `employee_id_card_screen.dart`).

## 8. Tests
New: `contact_approvers_test.dart` (7), `attendance_export_single_employee_test.dart` (11), `admin_branch_action_queue_test.dart` (4), `employee_profile_parity_test.dart` (9), plus additions to `employee_approval_matrix_test.dart` (+3) and `employee_documents_view_test.dart` (+1). Updated for web copy: `employee_detail_notice_reset_test.dart`, `employee_approval_matrix_test.dart`, `promotion_history_test.dart`, `employee_documents_view_test.dart`.
**Full suite: 2,855 passed (was 2,820). `flutter analyze`: 8 infos, all pre-existing (baseline 13); 0 errors/warnings.** Writes in tests use stand-in servers only; no production call was made.

## 9. Backend dependencies
None new for mobile. HO-59a/b requested in doc 20 (current_address persistence; return UAN/Aadhaar-name/ESI).

## 10. Still required on device / staging (not done)
- HO-54: confirm the Assets tab with the module enabled (read-only).
- HO-42: approvers for a user with L1/L2 and for a branch user (team list); expense workflow.
- HO-43: one real single-employee export for an in-scope and an out-of-scope ID (read-only download).
- HO-44: log in as a Branch Admin.
- HO-55/57: one upload and one relationship save on a **test** employee (writes — need approval and a non-production target).
A new debug build would be needed to see any of this on the phone; none was installed.

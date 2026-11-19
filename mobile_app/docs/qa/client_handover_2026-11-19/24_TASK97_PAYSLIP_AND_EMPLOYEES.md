# 24 — Task 97: Payslip final parity + Employee Management P2 (19 Nov 2026)

**Scope:** (1) close the remaining Flutter-only My Payslip differences from Task 96 (logo, sidebar card, stamp in PDF); (2) implement the confirmed Task 95 Employee Management P2 gaps (Add Employee for Branch Admin roles, employee-list statistics, Add Branch "Other city").
**Rules kept:** mobile-only; backend/web read-only; no git change, no production write, no phone install, release AAB untouched. Phase 2 was implemented by two helper agents in disjoint files; I read their reports and re-checked the riskiest claims against the web source.
**Evidence:** *mocked* = stand-in-server tests (**not** production verification). **Nothing here has been run on a device or against staging.**

## 1. My Payslip — final parity matrix (changes from Task 96's open items)
| # | Web element (ref) | Before | After | Status | Evidence |
|---|---|---|---|---|---|
| 1 | Company logo in the standard letterhead: live `logo_url`, max 48 high × 160 wide, `contain`, 8 below (`PayslipDocument.tsx`) | none | `Image.memory`, same limits, above the company line; wage slip has none (as web); absent/unfetchable → nothing drawn | COMPLETE | mocked |
| 2 | Logo in print/share | none | embedded in the PDF letterhead (same limits) | COMPLETE | mocked (real PDF bytes) |
| 3 | Sidebar employee card (`my-payslip/page.tsx:291-316`): initials, name, designation, employee ID, Department, Date of Join; "—" when missing | none | `_PayslipEmployeeCard` from the employee's own record (`/employees/me/`): same fields, web's `designation ?? "—"` rule, "Date of Join" as `dd Mon yyyy`, "—" while unavailable | COMPLETE | mocked |
| 4 | Month list: "Select Month" heading, pay date under each month | month + status only | heading + pay date line | COMPLETE | mocked |
| 5 | Wage-slip stamp on screen (`.ws-stamp`, max 80 × 140) | loaded by `Image.network` | fetched through the same secure loader, max 80 × 140, above "Authorized Signature" | COMPLETE | mocked |
| 6 | Wage-slip stamp in print/share | omitted | **actual image bytes embedded** above "Authorized Signature" | COMPLETE | mocked (real PDF bytes) |
| 7 | Everything from Task 96 (adjustments, Additions panel, wage-slip, UAN/ESIC, labels…) | done | unchanged — the 41 reconciliation tests still pass | COMPLETE | mocked |

**How the images are fetched (secure by construction).** Web puts both in `<img src>`, so the browser fetches the link directly with no login. The logo is the company's absolute media URL (`CompanySerializer.logo_url`); the stamp is a short-lived **signed** link (`stamp_url`, `signed_file_url`). Mobile uses the existing **login-free** file client (`employeeDocumentExternalDioProvider`), so the app token is never sent to the file host — the ID card's loader, by contrast, goes through the authenticated client; this one deliberately does not. Rules enforced and tested: https only (other schemes refused without a request); response must be non-empty, ≤ 3 MB and a decodable image; any failure → `null` (the image is simply not drawn, as a broken `<img>`); bytes live in memory only (never written to disk); the link is never logged, shown, put in an error message or written into the PDF (test greps the PDF bytes for the link and its signature). No new endpoint was invented. **No blocker** to embedding was found.

## 2. Employee Management parity matrix (details: `evidence/t95/T97_AB_employee_mgmt.md`, `T97_C_branch_other_city.md`)
| Area | Web ref | Mobile | Status |
|---|---|---|---|
| **A. Add Employee — role list**: roles holding `settings.edit` are never offered | `AddEmployeeModal.tsx:152-159` | `assignableEmployeeRoles` (by permission, not the `system_admin` name) | COMPLETE (mocked) |
| A. Branch locked unless superuser or `settings.edit` holder (a Branch Admin caller stays locked) | `AddEmployeeModal.tsx:114-115,166-172` | `isUnrestrictedEmployeeUser`; branch set from the caller | COMPLETE (mocked) |
| A. Role with `can_manage_branch`: Department "Not applicable — Branch Admin" and not required; Designation free text defaulting "Branch Manager" | `:138-139,221-230,394-413` | `EmployeeFormData.applyRole/isBranchAdmin`, sheet UI | COMPLETE (mocked) |
| A. Validation messages ("Required", name/email/phone texts) and typing sanitizers | `:31-41,236-253,354-363` | `EmployeeFormData.validate`, input formatters | COMPLETE (mocked) |
| A. Payload keys | `:260-268` | unchanged keys; `department: ""` for Branch Admin (web sends the same) | COMPLETE (mocked) |
| A. Field order (Role/Branch/Department/Designation) | layout | kept as before | PARTIAL (layout only) |
| A. Edit-sheet role dropdown still filters by name; the screen's add/edit gate still treats `settings.edit` as a wildcard (web uses superuser-or-codename) | `usePermission` | `permissionProvider` | PARTIAL — contract-dependent (doc 22 §3, HO-68) |
| **B. Stats from `GET /employees/stats/`** (cards Total Employees / Active / Onboarding / Departments; `branch` param only when a branch filter is set) | `employees/page.tsx:118-121,152-166,185-196` | `fetchEmployeeStats`, `employeeStatsProvider` (no counts from the paginated list) | COMPLETE (mocked) |
| B. Branch/department filter options come from the stats response; branch filter locked and department hidden unless superuser; branch change resets department | `page.tsx:288-314` | `_showFiltersSheet` | COMPLETE (mocked) |
| B. Failure/permission/empty: stats errors silent, previous cards kept, no spinner/error card (web has none) | `page.tsx` | screen reads `valueOrNull` | COMPLETE (mocked) |
| **C. Add Branch — "Other (type city name)"**: last option once a state is chosen; "Enter new city name" (max 100, letters/space/apostrophe/hyphen); web `CITY_NAME_RE` + messages | `BranchManagement.tsx:225-227,378-392,955-1010` | `branch_location_selector.dart`, `branch_form_rules.dart` | COMPLETE (mocked) |
| C. Payload: `new_city_name` (trimmed) and no `city` for Other; `city` for a listed city; same on Edit | `:547` | `branch_repository_impl.dart` | COMPLETE (mocked) |
| C. Code preview for a typed city (`city_name`, 400 ms debounce, invalid name clears) and **preview only on Add** (verified against web:  `modalMode === "add"`) | `:322-356` | selector `_schedulePreview` | COMPLETE (mocked) — note: Edit no longer re-previews/clears the code, matching web |
| C. City-list failure → empty list with Other still usable (was a blocking error); copy 'Please select a state.' / 'Please select a city.' / 'Address is required.' / 'Branch Address *' | `:311,378-392` | selector, dialog | COMPLETE (mocked) |
| C. Hints 'Select state'/'Select city' and label 'State / Region *' | web: 'Select State', 'Select City', 'State/Region *' | not changed (existing tests) | PARTIAL (copy only) |
| C. Edit of a branch whose city is not in the master list | `:955-1010` | keeps the city id; dropdown shows hint | COMPLETE (mocked) |

## 3. Files changed (mobile only)
**Payslip:** NEW `lib/features/payroll/presentation/payslip_images.dart`; `payslip_pdf.dart` (logo/stamp bytes, `withImages`); `screens/my_payslip_screen.dart` (logo, employee card, month heading/pay date, stamp via loader).
**Employees (A+B):** `core/constants/api_constants.dart`; `features/employees/` — `employee_model.dart`, `employees_remote_datasource.dart`, `employee_providers.dart`, `employees_screen.dart`, `add_employee_sheet.dart`.
**Branches (C):** `features/branches/` — `branch_form_rules.dart`, `branch_remote_datasource.dart`, `branch_repository_impl.dart`, `branch_repository.dart`, `branch_providers.dart`, `branch_location_selector.dart`, `branch_form_dialog.dart`.
**Tests:** NEW `payroll/payslip_task97_test.dart` (15), `employees/add_employee_branch_admin_test.dart` (22), `employees/employee_stats_test.dart` (15), `branches/branch_other_city_test.dart` (20). Updated to web copy: `add_employee_reporting_pickers_test.dart` ('Required'), `add_branch_admin_test.dart` and `branch_hq_name_test.dart` ('Branch Address *').

## 4. Tests and results
- **Previous reconciliation tests:** all 41 still pass (payroll folder now 91 tests).
- **Mutation checks on the new payslip behaviour** (broken then restored byte-for-byte): accept any URL scheme, drop the stamp from the PDF, enlarge the logo limit, show the joining date unformatted — **all four caught**.
- Payslip logo/sidebar/stamp: logo size and position, absent/unfetchable image, wage slip never requests the logo, link never shown; sidebar fields and "—" when the record fails; month pay dates; stamp on screen and in the PDF (real PDF bytes: image objects present, none when unavailable, standard slip never carries the stamp and wage slip never the logo, link/signature absent from the file); the loader refuses non-https/malformed/empty/non-image/oversize/failing links, sends no Authorization or cookie.
- Employee/branch tests cover role selection per persona, Branch Admin submit without a department, stats (counts, branch refetch, loading, empty, 403, error keeps previous), and Other-city behaviour (see the evidence reports). Permission-denied and error states are covered in each.
- **Full suite: 2,979 passed (was 2,907). `flutter analyze`: 7 infos, all pre-existing; 0 errors/warnings.**

## 5. Remaining backend dependencies
None new. Endpoints used all exist (`GET /employees/stats/`, `GET /roles/` with `permissions` and `can_manage_branch`, branch create/update with `new_city_name`, `preview-code` with `city_name`, company `logo_url`, payslip `stamp_url`). Unchanged from before: `payslip_pdf` is never filled (Download PDF stays disabled, same on web); the `settings.edit` wildcard questions (HO-18/HO-50/HO-68).

## 6. Staging / device checklist (nothing below has been run)
1. A company with a logo: the standard payslip shows it above the company name; Print/Share PDF include it.
2. A wage-slip company with a stamp: on-screen and in the shared PDF; also with the stamp link expired (PDF must still build).
3. Employee sidebar fields for a real employee; an employee with no designation/joining date.
4. Add Employee as: superuser, HR, and a **real Branch Admin** — role list (no `settings.edit` roles), locked branch, Branch-Admin role without department, the created record (a **test** tenant — this writes).
5. Employees list: counts versus web for the same login and branch filter; branch filter locked for a non-superuser.
6. Add Branch with "Other (type city name)" on a **test** tenant (creates a city and a branch): code preview, duplicate/invalid names, edit of a branch whose city is not in the master list.
7. Everything in doc 23 §10 still applies.

## 7. Notes to review
- **Formatting churn:** during this work `dart format` was run on whole folders — by me with the project's 120-column width (Tasks 95–97), and once by a helper at the default 80 columns before it re-ran at 120. Files should match the project style, but because git is off-limits to me, **please review the diff for unrelated whitespace changes** (notably under `lib/features/employees`, `payroll`, `dashboard`).
- I also ran one read-only `git status` by mistake in Task 96 (reported there); no git command was run in this task.

# Web ↔ Mobile Parity — Royal HRMS

*Audit date: 2026-10-28. The reference is `web_frontend_backend/` at `production` HEAD `d92cfac`. Mobile is the `mobile_app/` working tree, **including uncommitted work**.*

## Status legend
- **Complete:** a real backend integration covering the web module's scope, and contract spot-checks pass. No module is device- or test-verified (there are no automated tests), so "Complete" means verified *by code reading and contract check*.
- **Partial:** works, but required web behaviour is missing.
- **Outdated:** an existing implementation conflicts with the current web or backend behaviour.
- **Missing:** not implemented on mobile.
- **Blocked:** cannot be completed without a decision or a backend change.
- **Needs verification:** the evidence is insufficient.
- **Excluded:** deliberately removed or web-only. Confirm the scope with the product owner.

Mobile paths are relative to `mobile_app/lib/`, web paths to `web_frontend_backend/frontend/`, and backend paths to `web_frontend_backend/backend/`.

## 1. Summary matrix

| # | Module / feature | Latest web | Mobile status | API compatibility | Gap / required action |
|---|---|---|---|---|---|
| 1 | Login (company code) | `app/login/page.tsx` | **Complete** | OK | Optional: persist and pre-fill Company ID |
| 2 | Forgot password (3 steps) | `components/auth/ForgotPasswordForm.tsx` | **Outdated (broken)** | 400: `company_code` missing | Add Company ID to all 3 steps (P0-01) |
| 3 | Forced password change | `app/change-password/page.tsx` | **Missing** | Server does not enforce it | Gate on `mustChangePassword` in the router redirect (P0-05) |
| 4 | Session refresh / logout | `lib/api` axios interceptor | **Partial (defect)** | Cookie-only; Bearer code dead | Fix the refresh deadlock (P0-02); remove dead token code (P1-08) |
| 5 | Onboarding wizard | `app/onboarding/page.tsx` + `DynamicStepFields.tsx` | **Outdated** | Ignores `/onboarding/field-config/`, `/document-type-config/`, `/custom-file-fields/` | Render configurable fields and document types (P1-05) |
| 6 | Pre-joining assessment gate and portal | `app/onboarding/assessments/page.tsx` | **Missing** | `/assessments/my/`, `/respond/`, `/complete/`, `/retry/` never called | Gate on `assessmentStatus`; build the portal (P1-06) |
| 7 | Dashboard selection | `app/dashboard/page.tsx:13-26` (flags) | **Outdated** | Branch Admin hits `/dashboard/system-admin/*`, which returns 403 | Select by `isSuperuser` → `canManageTeam` → `employees.view` (P1-01) |
| 8 | Admin dashboard | `_components/AdminDashboard.tsx` | Complete | OK | none |
| 9 | HR dashboard | `_components/HRDashboard.tsx` | Complete | OK | none |
| 10 | Employee dashboard | `_components/EmployeeDashboard.tsx` | **Partial** | `/dashboard/employee/notice-period/` and `/dashboard/birthdays/mine/` unused | Add the notice-period countdown card and the "my birthday" card (P2-01) |
| 11 | Manager dashboard | `_components/ManagerDashboard.tsx` → `/dashboard/manager/` | **Missing** (generic fallback) | Endpoint exists (`apps/dashboard/urls.py:32`) | Port it (P2-02). Confirm the web widget is not a mock. |
| 12 | Announcements | `app/dashboard/announcements/page.tsx` (open to all since 10-27) | **Outdated (minor)** | OK | Menu gated by `announcements.view` (`nav_config.dart:45`); web shows it to everyone (P2-03) |
| 13 | Interview list | `app/dashboard/interview-list` | Complete | OK (paths) | Paginate (list capped at 100) (P3) |
| 14 | Candidate review and onboarding approvals | `app/dashboard/candidate-review` | **Partial** | `/recruitment/candidates/<id>/hr-decision/` and `/review/` unused | Document "View" is a no-op (`candidate_review_screen.dart:1032`); add HR decision (P2-04) |
| 15 | Email logs | `app/dashboard/email-logs` | Complete (untracked) | OK | Commit |
| 16 | Assessments (admin) | `app/dashboard/assessments` | **Partial** | Sections endpoints unused; `page_size` 100 with no paging | Sections CRUD and results (P2-05) |
| 17 | Face ID registrations (HR) | `app/dashboard/face-id-registrations` | Complete | OK | Cross-platform embeddings: see #22 |
| 18 | Referrals | `app/dashboard/referrals` | Complete | OK | Referral bonuses are admin-only (P3) |
| 19 | Employees list | `app/dashboard/employees` | Complete | OK | `/employees/stats/` unused (P3) |
| 20 | Employee detail | `app/dashboard/employees/[id]` (9 tabs) | **Partial / Outdated** | `/promotions/`, `/reset-password/`, `/id-card/`, `/leave/credits/*`, `/assets/employees/<id>/`, `/payroll/employee-salary/` unused | Promotion history is session-only on mobile, but `/employees/<id>/promotions/` now exists (Outdated). Missing tabs: Leave credits adjust/reverse, Assets, Salary/Payroll (payroll Excluded?), reset password (P2-06) |
| 21 | Org chart | `app/dashboard/org-chart` | Complete | OK | none |
| 22 | **My Attendance: clock in/out** | `hooks/useClockWidget.ts` | **Outdated / Blocked** | (a) `day_completed` not parsed. (b) Server skips face verification for `source='mobile'` (`services_face_matching.py:207`). (c) 192-d vs 128-d embeddings. | (a) P1-03. (b)+(c) need a decision (P0-04). |
| 23 | Attendance (HR) | `app/dashboard/attendance` (6 tabs) | **Partial** | Weekly-off assignments, shift assignments, employee calendar and import `dry_run`/single-employee mode unused | Add shift and weekly-off assignment views and import preview (P2-07); GPS-accuracy warning display is *Needs verification* |
| 24 | Attendance corrections | My Attendance + Approvals | Complete | OK | none |
| 25 | Leave (apply, balances, calendar, analytics) | `app/dashboard/leave` | **Complete / Needs verification** | OK; types are dynamic, `l2_pending` handled | Verify the monthly-leave apply UX (multi-month entitlement messages) on device |
| 26 | Work From Home | `app/dashboard/work-from-home` | Complete (untracked) | OK | Commit |
| 27 | Expenses | `app/dashboard/expenses` | Complete | OK | none |
| 28 | My Payslip | `app/dashboard/my-payslip` | **Partial** | List capped at 20; `/payroll/queries/` and payslip detail unused | Paginate; raise a payslip query; view detail (P1-04, P2-08) |
| 29 | Payroll admin (run, CTC, adjustments, reports) | `app/dashboard/payroll` | **Excluded** (removed in `e558822`, 2026-07-27) | n/a | Confirm it stays web-only |
| 30 | Approvals: team | `app/dashboard/approvals` (Leave, WFH, Expense, Correction, Separation, Payslip; bulk) | **Partial** | `UnifiedApprovalKind {leave, expense, attendanceCorrection, wfh}` (`approvals_providers.dart:29`) | Add Separation and Payslip-query kinds and bulk approve/reject (P2-09) |
| 31 | Approvals: attendance sign-off | `AttendanceApprovalTab` | Complete | OK; 403 when the payroll module is disabled | Handle the module-disabled message (P1-07) |
| 32 | Approvals: face registration | `FaceRegistrationApprovalsTab` | Complete | OK | none |
| 33 | Separation (self-service and detail) | `app/dashboard/separation`, `[id]` | Complete (untracked) | OK | Commit; verify detail access for non-approver owners (*Needs verification*) |
| 34 | Documents | `app/dashboard/documents` | Complete | OK | none |
| 35 | My Requests | `app/dashboard/my-requests` | Complete (untracked) | OK | Commit |
| 36 | Profile | `app/dashboard/profile` (7 tabs) | **Partial** | Configurable document types and custom file fields unused | Add the Work Info tab (Reporting Manager, Approver, Branch HR) and configurable documents (P2-10) |
| 37 | Notifications | Bell + WebSocket `/ws/notifications/` + 60 s poll | **Partial** | REST only; no WebSocket or poll | Add a periodic unread-count refresh, and optionally WebSocket with the cookie (P3) |
| 38 | Voice assistant | `VoiceCommandButton` | Complete (not device-tested) | OK | Device test; the Sarvam credit outage risk is in web team notes (08-31) |
| 39 | Reports | ComingSoon on both | Placeholder (parity) | n/a | none |
| 40 | Global search | `DashboardShell` GlobalSearch | **Missing** | `/employees/?search=` | Optional (P3) |
| 41 | Module gating (per company) | Server 403 per module | **Missing** | `feature_gate.py` | Map "not enabled" 403s and hide menu entries (P1-07) |
| 42 | Settings: company and FY, departments, employee code, holidays, approval rules, assessment config, referral rules, email templates, SMTP, notifications, audit | `app/dashboard/settings/*` | Complete | OK | Verify employee-code settings show the new prefix+DDMM+initials format (*Needs verification*) |
| 43 | Settings: roles and permissions | `settings/permissions` | **Outdated** | `can_manage_branch` not modelled (`roles_model.dart` handles only `can_manage_team`) | Add the flag. Check whether a role PUT from mobile resets it (*Needs verification*, P1-09). |
| 44 | Settings: onboarding fields and document types | `settings/onboarding-fields` | Complete (untracked) | OK | Commit |
| 45 | Settings: leave policy | `settings/leave-policy` (5 tabs) | **Partial** | `/leave/monthly-credits/*` unused; Credit Rules is local mock | Monthly Leave tab (P2-11); remove or label the mock Credit Rules (P3) |
| 46 | Settings: attendance config | `settings/attendance-config` | **Partial** | `working-hours`, `weekly-days`, shift master not called | P2-07 |
| 47 | Settings: ID card | `settings/id-card` + employee ID-card print | **Missing** | `/settings/id-card/`, `/employees/<id>/id-card/` | Low mobile value (print-oriented) (P3) |
| 48 | Settings: assets | `settings/assets` | **Missing** | `/assets/*` (15 endpoints) | P2-12 (admin); there is no self-service "my assets" endpoint |
| 49 | Settings: payroll config | `settings/payroll-config` | **Excluded** | n/a | Follows #29 |
| 50 | Branches | `app/dashboard/branches` | **Partial** | `/branch/branches/<id>/reassign-admin/` and `/geofencing/` unused | Branch Admin assignment and reassignment, geofence editing (P2-13) |
| 51 | Platform Admin | `app/platform-admin/*` | **Excluded** (web-only, separate auth) | n/a | none |

**Totals across the 51 rows:**

| Status | Rows |
|---|---|
| Complete | 21, including leave (*Needs verification*). 5 of them exist only as uncommitted or untracked code. |
| Partial | 13, including employee detail, which is also Outdated |
| Outdated | 6: forgot password, onboarding, dashboard selection, announcements nav, My Attendance (also Blocked), roles |
| Missing | 7 |
| Excluded | 3 |
| Placeholder (both platforms) | 1 |

Counts use each row's first status.

## 2. Important discrepancies in detail

### D1. Forgot password is broken (P0)
1. **Workflow:** password reset from the login screen.
2. **Web:** `components/auth/ForgotPasswordForm.tsx` sends `company_code` at every step.
3. **Backend:** `apps/accounts/serializers.py:150-178`; `views.py:714-848`.
4. **Mobile:** `features/auth/data/models/forgot_password_models.dart`, the use cases in `features/auth/domain/usecases/`, and the forgot-password screen.
5. **Difference:** `company_code` is never sent, so every step returns 400.
6. **Fix:** add a Company ID field and pass it through the three use cases, the repository and the models.
7. **Risk:** low. Mobile-only change.

### D2. Mobile clock-in bypasses mandatory face verification (P0, decision needed)
1. **Workflow:** clock-in with face attendance enforced by the company.
2. **Web:** `hooks/useClockWidget.ts` sends `source: 'web'` with a face-api.js 128-d descriptor.
3. **Backend:** `apps/attendance/services_face_matching.py:207` returns "not required" for any source other than `web` or `voice`. `:159-162` raises "Face descriptor length mismatch" when the lengths differ.
4. **Mobile:** `features/attendance/data/datasources/attendance_remote_datasource.dart:47` defaults to `source = 'mobile'` and sends a 192-d MobileFaceNet embedding. The voice clock-in path sends `source='voice'` and **is** verified.
5. **Difference:**
   - Ordinary mobile punches are never face-verified.
   - Voice punches are verified, but they fail for web-registered faces.
   - Mobile-registered faces fail on web.
6. **Fix options (pick one, all need approval):**
   - (a) **Backend:** add `mobile` to the verified sources *and* store per-platform reference embeddings (or a model tag) so 192-d and 128-d are matched only against their own kind.
   - (b) **Mobile:** adopt the same model as web (face-api.js `faceRecognitionNet`, 128-d) through a TFLite conversion, then have the backend verify `mobile`.
   - (c) **Accept the risk:** document that face attendance is web-only, and have mobile skip face capture for ordinary punches.
7. **Risk:** security and compliance (proxy attendance). This affects every company that enforces face attendance.

### D3. Dashboard chosen by role-name substring (P1)
1. **Workflow:** home dashboard selection after login.
2. **Web:** `app/dashboard/page.tsx:13-26` uses `is_superuser` → Admin, `can_manage_team` → Manager, `employees.view` → HR, otherwise Employee.
3. **Backend:** `apps/dashboard/views/overview.py:24-29`: system-admin views need `settings.edit`; HR views need `employees.view`.
4. **Mobile:** `features/dashboard/presentation/widgets/quick_access.dart:17-23` (`resolveRoleCategory`) and `screens/home_screen.dart:35`.
5. **Difference:** `branch_admin` → "admin" → 403s. Custom role names are mis-routed.
6. **Fix:** derive the category from the `UserEntity` flags and permissions, mirroring web.
7. **Risk:** low. Keep `resolveRoleCategory` for quick-access labels if needed.

### D4. Attendance `day_completed` ignored (P1)
1. **Workflow:** second punch after a completed day.
2. **Web:** the clock widget disables after completion.
3. **Backend:** `services_attendance.py:~305` (daily limit; added 2026-10-07); `serializers_my_attendance.py:179`.
4. **Mobile:** `features/attendance/data/models/attendance_models.dart:56-67`, `my_attendance_screen.dart`, `dashboard/.../attendance_ring_card.dart`.
5. **Difference:** mobile offers "Clock In" again after clock-out.
6. **Fix:** parse `day_completed` and show a "Day completed" state.
7. **Risk:** low.

### D5. Onboarding wizard ignores per-company configuration (P1)
1. **Workflow:** new-hire onboarding.
2. **Web:** `app/onboarding/page.tsx`, `_components/DynamicStepFields.tsx`.
3. **Backend:** `/onboarding/field-config/`, `/onboarding/document-type-config/`, `/onboarding/custom-file-fields/` (added 2026-08-19 and 08-20).
4. **Mobile:** `features/onboarding/data/datasources/onboarding_datasource.dart` and the hard-coded fields in `presentation/widgets/onboarding_steps.dart` (1,684 lines).
5. **Difference:** mobile shows a fixed field set and fixed document types.
6. **Fix:** fetch the configuration and render fields and document types dynamically. Reuse `features/settings/data/models/onboarding_field_config_model.dart`.
7. **Risk:** medium. This is a large file, so refactor it into step widgets while doing the work.

### D6. Pre-joining assessment gate missing (P1)
- **Web:** redirects to `/onboarding/assessments` when an assessment is pending (`app/onboarding/assessments/page.tsx`).
- **Backend:** blocks `/dashboard/employee/*` until assessments are complete.
- **Mobile:** parses `assessmentStatus` (`user_model.dart:44`) and never uses it.
- **Fix:** add a router redirect plus a portal screen (list, respond, complete, retry).

### D7. My Payslip (P1/P2)
- The list is capped at 20 (`payroll_remote_datasource.dart:20-32`, backend `payroll/views/payslips.py:405`).
- There is no "raise query" (`/payroll/queries/`) and no detail view.

### D8. Approvals inbox (P2)
- Mobile kinds are leave, expense, attendance correction and WFH (`features/approvals/presentation/providers/approvals_providers.dart:29`).
- Web also has Separation and Payslip queries, plus bulk approve/reject (`app/dashboard/approvals/*`).

### D9. Employee profile (HR view) (P2)
- Promotion history is "session-only" on mobile, but the backend now has `employees/<id>/promotions/`.
- Missing: leave credit adjust/reverse, assets, reset password, ID card.

### D10. Roles: `can_manage_branch` (P1, needs verification)
- `features/settings/data/models/roles_model.dart` models only `can_manage_team`.
- If the role-save call sends a full object without `can_manage_branch`, saving a Branch Admin role from mobile could clear the flag. Verify the PUT/PATCH semantics in `apps/accounts` roles views before changing anything.

## 3. Mobile-specific adaptations to keep
- **Dedicated full-screen routes instead of web tabs:**
  - My Requests aggregator
  - single-page Approvals inbox
  - bottom-sheet forms
- **Global voice overlay**, with server TTS and Hindi fallback.
- **Back-button behaviour:** `PopScope` plus `enableOnBackInvokedCallback="false"`.
- **Geofence pre-check** before punching.

Do not port these desktop-oriented web features unless they are requested:
- print layouts (ID card, payslip print);
- XLSX bulk imports for assets and monthly leave;
- the Platform Admin panel;
- payroll run and configuration (excluded by the 2026-07-27 decision).

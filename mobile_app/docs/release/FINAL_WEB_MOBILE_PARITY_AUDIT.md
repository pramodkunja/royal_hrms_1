# Royal HRMS — Final Web-to-Mobile Parity Audit

*Audit date: 2026-11-09. Submission deadline: 2026-11-11 (Google Play).*

## About this audit

**Read-only.** The only file created or changed is this report.

**Web reference.**
- Production branch `origin/production` = `95fc10a` (2026-10-30), read only with `git show` / `git ls-tree` / `git grep`. Not fetched.
- The web clone's working tree (branch `fix/p0-04a-face-enforcement`) is **not** production and was not used.

**Mobile.** The `mobile_app/` working tree, including all uncommitted work up to the Attendance Import dry-run change. Mobile HEAD is `0e44635c`.

**How the audit was done.**
- Every one of the 67 production web page routes was assigned to one of six review areas.
- Each area was reviewed line by line against the mobile code and the Django `urls.py` / views on the same production commit.
- Every P0/P1 finding was then checked again directly against the code before inclusion (see *Verification notes*).

**What "COMPLETE" means.** It means **code-level parity**: the mobile UI exposes the action, calls the same endpoint with the same parameters and handles the response.
- It does **not** mean verified on a device or against the live server; nothing in this audit was run on an emulator or device.
- It does not mean automated tests exist; the *Tests* column says whether they do.
- No feature was marked COMPLETE just because a Dart file exists.

**Status vocabulary.**

| Status | Meaning |
|---|---|
| COMPLETE | Code-level parity confirmed (see above) |
| PARTIAL | Some web behaviour is missing, wrong or weaker on mobile |
| MISSING | No mobile implementation |
| BLOCKED | Cannot be ported as-is: web is a mock/orphan, or a backend/product decision is required |

**Priority.**

| Priority | Meaning |
|---|---|
| P0 | Data correctness, security, a core flow, or an outward-facing defect. Fix before the build. |
| P1 | Visible functional gap for a primary role (Employee / Manager / HR / Branch Admin / Company Admin) |
| P2 | Admin-only, rare, cosmetic, or test-only |

**Effort.** Effort estimates are engineering hours for one developer familiar with the codebase. They include unit/widget tests. They exclude device QA.

---

## 1. Summary

### 1.1 Routes and screens discovered

| | Count | Notes |
|---|---|---|
| Web page routes (`frontend/app/**/page.tsx`) | **67** | 54 under `/dashboard`, 9 under `/platform-admin`, plus `/`, `/login`, `/change-password`, `/onboarding`, `/onboarding/assessments` (overlap: `/dashboard` root) |
| Web routes with a mobile equivalent | **49** | Includes `/dashboard/onboarding-approvals` (a web redirect alias to candidate-review) and `/settings/leave-credit-rules` (a web redirect to leave-policy) |
| Web routes with **no** mobile equivalent | **16** | 9 × `/platform-admin/*`; `/dashboard/payroll`, `/payroll/runs/[id]`, `/payroll/payslips/[id]`; `/employees/[id]/id-card`; `/settings/id-card`, `/settings/assets`, `/settings/payroll-config` |
| Web routes not applicable | **2** | `/dashboard/employees/new` (orphan wizard, nothing links to it); `/dashboard/reports` (static "Coming soon", no backend) |
| Mobile go_router routes | **55** | 53 `AppRoutes` constants plus 2 child routes (`/dashboard/employees/:employeeId`, `/dashboard/separation/:requestId`) |
| Mobile `*_screen.dart` files | **58** | Some web tabs and modals are pushed sheets or dialogs on mobile |

### 1.2 Feature-level results (245 feature rows)

| Area | Rows | COMPLETE | PARTIAL | MISSING | BLOCKED |
|---|---|---|---|---|---|
| A. Auth, onboarding, recruitment, assessments, referrals, Platform Admin | 29 | 16 | 9 | 4 | 0 |
| B. Dashboards, shell/navigation, announcements, contacts, org chart, profile, documents, email logs, reports, voice | 53 | 38 | 11 | 3 | 1 |
| C. Employees, branches, separation, Face ID registrations, org settings | 49 | 22 | 16 | 10 | 1 |
| D. Attendance, my attendance, approvals, my requests, leave, WFH, leave/attendance settings | 54 | 45 | 9 | 0 | 0 |
| E. Payroll (admin), my payslip, expenses, assets | 33 | 6 | 4 | 23 | 0 |
| F. Settings hub, email templates, SMTP, audit, notifications, onboarding fields, assessment config, referral rules | 27 | 18 | 9 | 0 | 0 |
| **Total** | **245** | **145 (59%)** | **58 (24%)** | **40 (16%)** | **2 (1%)** |

**Where the 40 MISSING rows come from.**
- 18 are admin payroll. Those screens were removed from mobile in `e558822` (2026-07-27) because they were mock screens with hard-coded data.
- 4 are Platform Admin, documented as web-only in `docs/audit/WEB_MOBILE_PARITY.md`.
- 6 are Assets management (inventory plus the employee Assets tab).
- Excluding those three product-scope groups, **12 MISSING rows** remain.

**Parity is not 100%.** It cannot reach 100% by 2026-11-11 (see §4).

### 1.3 P0 findings (fix before the release build)

| ID | Finding | Mobile-only fix? | Effort |
|---|---|---|---|
| A-I4 | **Duplicate candidate email.** "Mark Selected / Rejected" PATCHes the status and then POSTs `/send-email/`. The backend status endpoint already sends the selected/rejected email (`recruitment/views.py` ~L715–725), so real candidates receive it twice. | Yes | 1 |
| A-I3 | **Duplicate interview invitation.** On first scheduling, mobile PUTs the candidate and then calls `send-email` `interview_scheduled_candidate`. The backend already sends it from PUT/PATCH (`_fire_interview_date_emails_if_needed`, views.py L560/L600). | Yes | 0.5 |
| A-A2 | **Login rejects passwords shorter than 8 characters.** Mobile login uses `FormValidators.password` (minimum length check), but the backend `LoginSerializer.password` allows `min_length=1` and web has no length check. Any account with a shorter password (e.g. HR-set or legacy) cannot sign in on mobile. | Yes | 0.5 |
| C-F01 | **Face embedding mismatch.** Mobile registers 192-d MobileFaceNet embeddings; web uses 128-d descriptors. The backend accepts any length, but matching raises "Face descriptor length mismatch" (`services_face_matching.py:159-161`). An HR registration done on mobile breaks that employee's web face clock-in, and vice versa. | **No.** Needs a backend/product decision (one model, or per-source storage) | 8+ (backend) |

---

## 2. Detailed findings by area

Column key:
- **Web**: route and key files under `frontend/` at `origin/production`.
- **Mobile**: path under `mobile_app/lib/`.
- **Tests**: mobile tests under `mobile_app/test/`.
- **Pri**: priority.
- **h**: effort in hours.

The mobile-only boundary applies. Where a backend change is required, it is listed as a blocker, not as mobile work.

### Area A — Auth, onboarding, recruitment, assessments, referrals, Platform Admin

**Roles.** All roles use the auth flows.
- Recruitment screens are HR / Branch Admin / Company Admin (`recruitment.view`).
- The assessments admin screens need `assessments.*`.
- Platform Admin is a separate web-only auth stack.

| ID | Web | Mobile | Web functionality | Mobile functionality | Status | Exact missing work | Endpoints | Tests | Pri | h |
|---|---|---|---|---|---|---|---|---|---|---|
| A-A1 | `/` `app/page.tsx` | `/` `features/auth/presentation/screens/splash_screen.dart` | Redirects to dashboard or login | Restores the session, then redirects | COMPLETE | — | — | `core/router/auth_redirect_test.dart` | — | 0 |
| A-A2 | `/login` `app/login/page.tsx` | `/login` `auth/presentation/widgets/login_form.dart` | Company code, email, password; prefill after a forced change | Same fields, payload and prefill. **Password checked against the minimum length.** | PARTIAL | Use a required-only validator on login | POST `/login/` | Redirect tests only | **P0** | 0.5 |
| A-A3 | Post-login gate (login `page.tsx`, `proxy.ts`) | `core/router/app_router.dart` `resolveAuthRedirect` | must_change_password → onboarding → assessments, with exemptions | Same order and exemptions | COMPLETE | — | — | `auth_redirect_test`, `access_control_test`, `assessment_gate_test` | — | 0 |
| A-A4 | `components/auth/ForgotPasswordForm.tsx` | `/forgot-password` `auth/.../forgot_password_form.dart` | 3-step OTP reset with company code | Same, including resend | COMPLETE | — | POST `/forgot-password/`, `/verify-otp/`, `/reset-password/` | `forgot_password_form_test`, `forgot_password_flow_test` | — | 0 |
| A-A5 | `/change-password` | `/change-password` `force_change_password_screen.dart` | Old/new/confirm; re-login with prefill | Same, plus a logout escape | COMPLETE | — | POST `/change-password/` | `force_change_password_flow_test` | — | 0 |
| A-A6 | `components/SessionExpiredOverlay.tsx` | `core/network/auth_interceptor.dart` | "Session expired" overlay, then login | Single-flight refresh, then a **silent** logout | PARTIAL | Show a session-expired message | POST `/token/refresh/` | `auth_interceptor_test` | P2 | 1 |
| A-A7 | Multi-tenant company code | Login, forgot password, prefill | Company code required everywhere | Same | COMPLETE | — | — | Forgot-password tests | — | 0 |
| A-O1 | `/onboarding` `app/onboarding/page.tsx`, `DynamicStepFields.tsx` | `/onboarding` `onboarding/.../onboarding_screen.dart`, `onboarding_steps.dart` | 5 steps plus Face ID; dynamic fields and documents; custom file fields; submit | Same | COMPLETE | — | `/onboarding/`, `/onboarding/step/{n}/`, `/field-config/`, `/document-type-config/`, `/documents/`, `/custom-file-fields/` | `onboarding_config_test`, `onboarding_hardening_test` | — | 0 |
| A-O2 | Awaiting-approval view (in `onboarding/page.tsx`) | `/onboarding/awaiting-approval` | Polls, then redirects | Manual refresh, then redirects | COMPLETE | Optional auto-poll | GET `/onboarding/`, `/assessments/my/` | Partial | P2 | 0.5 |
| A-O3 | `/onboarding/assessments` | `/onboarding/assessments`, `/assessments/:id` | Video plus quiz; countdown with auto-submit; retake | Same; video opens in an external app | COMPLETE | Optional in-app video embed | `/assessments/my/`, `/{a}/respond/{i}/`, `/complete/`, `/retry/` | `assessment_take_test`, `assessment_gate_test` | P2 | 3 |
| A-C1 | `/dashboard/candidate-review` | `candidate_review/.../candidate_review_screen.dart` | Stats and list; "Review" only with `employees.approve` / `onboarding.approve` | Stats and list; Review shown to every `recruitment.view` user (server enforces) | PARTIAL | Gate Review on `employees.approve` / `onboarding.approve` | GET `/onboarding/approvals/` | `candidate_review_approval_test` | P2 | 0.5 |
| A-C2 | `candidate-review/_components/OnboardingDrawer.tsx` | Review sheet (same screen) | Approve (dept/desig, UAN, Aadhaar name, PAN, assessment) or send back | Same contract (`assessment_ids`) | COMPLETE | — | POST `/onboarding/approvals/{userId}/` | Same test | — | 0 |
| A-I1 | `/dashboard/interview-list` `page.tsx`, `_data.ts` | `interview_list/.../interview_list_screen.dart`, `interview_providers.dart` | Stats, debounced search, status, **branch filter** (locked when restricted), numbered pages | Stats, search, status, infinite paging. Branch supported in the datasource but not exposed. | PARTIAL | Branch filter UI (locked for restricted users) | GET `/recruitment/candidates/?search&status&branch&page`, `/stats/` | `interview_list_paging_test` | P2 | 2 |
| A-I2 | `_components/AddCandidateModal.tsx` | `widgets/add_candidate_sheet.dart`, `add_candidate_form.dart` | Includes **interview time, meeting link (video), interviewer picker** | All other fields | PARTIAL | Add `interview_time`, `meeting_link`, `interviewer` (picker over `/employees/`) | POST `/recruitment/candidates/` | No | P1 | 3 |
| A-I3 | `_components/EditCandidateModal.tsx` | `add_candidate_sheet.dart` (edit mode), `candidate_card.dart` | PATCH; hidden for converted; `recruitment.edit`; backend sends the interview email | PUT; same field gaps as A-I2. **Sends the interview email a second time.** Edit shown with no permission check. | PARTIAL | Remove `_sendScheduleEmail`; gate Edit on `recruitment.edit` and not converted (fields covered in A-I2) | PUT/PATCH `/recruitment/candidates/{id}/` | No | **P0** (email) / P2 (gate) | 0.5 + 0.5 |
| A-I4 | `page.tsx`, `MarkCandidateModal.tsx` | `mark_candidate_sheet.dart`, `interview_providers.dart` `sendStatusEmail` | Status PATCH only (backend emails); menu hidden for selected/offer_sent and without `recruitment.edit` | Status PATCH **plus** POST `send-email`, so a duplicate email; menu hidden only for converted | PARTIAL | Remove the `sendStatusEmail` call; align menu visibility | PATCH `/recruitment/candidates/{id}/status/` | No | **P0** | 1 |
| A-I5 | `page.tsx` send-login | `candidate_card.dart` `_PortalActionButton` | Send portal login (`recruitment.edit`) | Send plus resend (extra) | COMPLETE | Add the permission gate | POST `/send-portal-login/`, `/resend-portal-login/` | No | P2 | 0.3 |
| A-I6 | `LogsModal.tsx` | `activity_log_dialog.dart` | Activity logs | Same | COMPLETE | — | GET `/recruitment/candidates/{id}/` | No | — | 0 |
| A-I7 | `CandidateBulkImportModal.tsx` | `/interview-list/bulk-import` | Upload, results, **sample CSV/XLSX download**; `recruitment.create` | Upload and results; no sample; route and FAB need only `recruitment.view` | PARTIAL | Sample download (verify the format query param first); gate on `recruitment.create` | POST `/recruitment/candidates/bulk-import/`, GET `/bulk-import/sample/` | No | P2 | 2 |
| A-AS1 | `/dashboard/assessments` | `assessments/.../assessments_screen.dart`, `assessment_form_dialog.dart` | CRUD, with each action gated by create/edit/delete | CRUD; FAB/Edit/Delete/Items not gated per action | PARTIAL | Per-action permission gates | GET/POST `/assessments/`, PUT/DELETE `/assessments/{id}/` | `items_manager_sections_test` | P2 | 1 |
| A-AS3 | Assign modal in `assessments/page.tsx` | `assign_dialog.dart` | Template picker; multi-select employees | Same | COMPLETE | — | POST `/assessments/assign/`, GET `/email-template-options/` | No | — | 0 |
| A-AS4 | `_components/EmployeeMyAssessments.tsx` | `/dashboard/my-assessments` | Own assignments | Same (different path) | COMPLETE | — | GET `/assessments/my/` | `my_assessments_test` | — | 0 |
| A-R1 | `/dashboard/referrals` | `referrals/.../referrals_screen.dart` | My/All tabs (All with `recruitment.view`), stats, search | Same | COMPLETE | Add tests | GET `/recruitment/referrals/`, `/all/` | **No** | P2 | 1.5 |
| A-R2 | Refer modal | `refer_candidate_dialog.dart` | Name, email, phone, position, branch, relationship, notes | Same | COMPLETE | — | POST `/recruitment/referrals/` | No | — | 0 |
| A-R3 | Referral rules tab | `referral_rule_card.dart` | Read-only rules | Same | COMPLETE | — | GET `/recruitment/referral-rules/` | No | — | 0 |
| A-P1 | `/platform-admin/login`, `/forgot-password` | — | Separate platform-admin auth and OTP reset | Absent | MISSING | Only if product wants it: separate auth stack and Dio client | `/platform-admin/login/`, `logout/`, `token/refresh/`, `me/`, `forgot-password/`… | No | P2 (excluded) | 8 |
| A-P2 | `/platform-admin`, `/companies` | — | Dashboard stats; company CRUD; enable/disable; reveal initial password; system-admin email and reset | Absent | MISSING | As above | `/platform-admin/dashboard-stats/`, `companies/…` | No | P2 (excluded) | 16 |
| A-P3 | `/platform-admin/admins` | — | Invite and enable/disable platform admins | Absent | MISSING | As above | `/platform-admin/admins/…` | No | P2 (excluded) | 4 |
| A-P4 | `/platform-admin/audit-log`, `/email-settings`, `/account`, `/settings` | — | Audit log, platform SMTP, own password, settings hub | Absent | MISSING | As above | `/platform-admin/audit-logs/`, `smtp-settings/…`, `change-password/` | No | P2 (excluded) | 6 |

Not counted in Area A:
- `/dashboard/onboarding-approvals` is a web redirect alias.
- The assessment items manager is covered in F-AC2.

### Area B — Dashboards, shell, announcements, contacts, org chart, profile, documents, email logs, reports, voice

**Roles.**
- The dashboard is chosen in this order: superuser/`settings.edit` → Admin; `can_manage_team` → Manager; `employees.view` → HR; otherwise Employee.
- Branch Admin is a role-based scope that uses the HR or Manager view, depending on capability flags.

| ID | Web | Mobile | Web functionality | Mobile functionality | Status | Exact missing work | Endpoints | Tests | Pri | h |
|---|---|---|---|---|---|---|---|---|---|---|
| B-D01 | `/dashboard` `app/dashboard/page.tsx` | `dashboard/.../home_screen.dart` | Role resolution | Same | COMPLETE | — | — | `dashboard_category_test` | — | 0 |
| B-D02 | `KpiConsole.tsx`, `AdminDashboard.tsx` | `dashboard/presentation/screens/admin_dashboard_view.dart` | KPIs, system health, clock-in | Same | COMPLETE | — | GET `/dashboard/system-admin/kpis/` | Category only | — | 0 |
| B-D03 | `PendingApprovalsWidget.tsx` | `admin_dashboard_view.dart` | 4 counters; Leave → `/dashboard/approvals` | Same counters; Leave → Leave screen | PARTIAL | Point the Leave row to Approvals | GET `/dashboard/system-admin/pending-approvals/` | No | P2 | 0.25 |
| B-D04 | `DeptHeadcountChart.tsx` (admin) | `admin_dashboard_view.dart` | Headcount chart | Bar list | COMPLETE | — | GET `/dashboard/system-admin/department-headcount/` | No | — | 0 |
| B-D05 | `AnnouncementCard.tsx` | Admin, HR and Manager views | Latest announcement | Same | COMPLETE | — | `/dashboard/system-admin/announcement/`, `/dashboard/announcement/` | No | — | 0 |
| B-D06 | `EmployeeLifecycleTabs.tsx`, `NoticePeriodRow.tsx` (admin) | `admin_dashboard_view.dart`, `data/models/admin_dashboard_models.dart` | Notice tab shows approval date, last working day, days left | Generic row; model drops `approved_at`, `last_working_day`, `days_remaining` (stale "always 0" comment) | PARTIAL | Parse the fields; reuse `HrNoticePeriodRow` | GET `/dashboard/system-admin/employee-lifecycle/` | HR equivalent only | P1 | 1.5 |
| B-D07 | `BirthdayWidget.tsx`, `SendWishModal.tsx`, `SendAllBirthdayModal.tsx` (admin) | `admin_dashboard_view.dart` | Today/upcoming; **Send Wish / Resend per row; Send All** | Read-only lists | MISSING | Per-row wish (reuse `send_wish_sheet.dart`); Send-All sheet with progress; gate as `canSendBirthdayWishes` | GET `/birthdays/`; POST `/recruitment/candidates/{emp}/send-email/` | Wish sheet only (`celebration_cards_test`) | P1 | 4 |
| B-D08 | `AuditLogsWidget.tsx` | `admin_dashboard_view.dart` | Module filter, paging, View all | Same | COMPLETE | — | GET `/dashboard/system-admin/audit-logs/` | No | — | 0 |
| B-D09 | `ClockInButton.tsx`, `HrAttendanceCard.tsx` | `widgets/attendance_ring_card.dart` | Punch card; day-complete state | Same | COMPLETE | — | `/attendance/today/`, punch | Indirect | — | 0 |
| B-D10 | `hr/HrConsole.tsx` | `hr_dashboard_view.dart` | KPIs, punch pill | Same | COMPLETE | — | GET `/dashboard/hr/kpis/` | Category | — | 0 |
| B-D11 | `hr/HrAttendanceSummary.tsx` | `hr_dashboard_view.dart` | Summary | Same | COMPLETE | — | GET `/dashboard/hr/attendance-summary/` | No | — | 0 |
| B-D12 | `hr/HrActionQueue.tsx` | `hr_dashboard_view.dart`, `hr_dashboard_models.dart` | Counts; separation fetched separately (the backend hard-codes 0); live WebSocket updates | Separation always 0; no live updates | PARTIAL | Fetch `/separation/requests/?scope=team&page_size=1` (gated); WebSocket optional (P2, 3h) | GET `/dashboard/hr/action-queue/` | No | P1 | 1 |
| B-D13 | `hr/HrRecruitmentFunnel.tsx` | `hr_dashboard_view.dart` | Funnel | Same | COMPLETE | — | GET `/dashboard/hr/recruitment-funnel/` | No | — | 0 |
| B-D14 | `hr/HrEmployeeLifecycleTabs.tsx` | `hr_dashboard_view.dart`, `hr_notice_period_row.dart` | 3 tabs with notice details | Same | COMPLETE | — | GET `/dashboard/hr/employee-lifecycle/` | `hr_notice_period_lifecycle_test` | — | 0 |
| B-D15 | DeptHeadcountChart (HR) | `hr_dashboard_view.dart` | Headcount | Same | COMPLETE | — | GET `/dashboard/department-headcount/` | No | — | 0 |
| B-D16 | `hr/HrBirthdaysWidget.tsx` | `hr_dashboard_view.dart` | Read-only birthdays | Same | COMPLETE | — | `/dashboard/hr/birthdays/today/`, `/upcoming/` | `employee_birthdays_test` | — | 0 |
| B-D17 | `_components/ManagerDashboard.tsx` | `manager_dashboard_view.dart` | Team stats, approvals, activity, birthdays, leaves | Same | COMPLETE | — | GET `/dashboard/manager/` | `manager_dashboard_test` | — | 0 |
| B-D18 | `employee/EmpConsole.tsx` | `employee_dashboard_view.dart` | KPIs, status, clock-in | Same | COMPLETE | — | `/dashboard/employee/kpis/`, `/attendance-status/` | Category | — | 0 |
| B-D19 | `employee/EmpLeaveBalances.tsx` | `employee_dashboard_view.dart`, `leave_monthly_breakdown.dart` | Balances by year; monthly statement | Same | COMPLETE | — | `/dashboard/employee/leave-balances/?year=` | `leave_monthly_breakdown_test` | — | 0 |
| B-D20 | `employee/EmpActionItems.tsx` | `employee_dashboard_view.dart` | Paged (5) with Prev/Next | First page only, no pager | PARTIAL | `page`/`page_size` plus a pager | `/dashboard/employee/action-items/` | No | P2 | 1 |
| B-D21 | `employee/EmpRecentRequests.tsx` | `employee_dashboard_view.dart` | First 5 requests | Same | COMPLETE | — | `/dashboard/employee/recent-requests/` | No | — | 0 |
| B-D22 | `employee/EmpUpcomingHolidays.tsx` | `emp_upcoming_holidays_card.dart` | Holidays | Same | COMPLETE | — | `/leave/holidays/` | `upcoming_holidays_test` | — | 0 |
| B-D23 | `employee/EmpNoticePeriodCard.tsx` | `emp_notice_period_card.dart` | Serving-notice card | Same | COMPLETE | — | `/dashboard/employee/notice-period/` | `employee_notice_period_test` | — | 0 |
| B-D24 | `policy/PendingAcknowledgementsBanner.tsx` | `documents/.../pending_acknowledgements.dart` | Banner linking to documents | Banner and in-place acknowledge sheet (works where web's link is blocked without `documents.view`) | COMPLETE | — | `/documents/pending-acknowledgements/`, POST `/documents/{id}/acknowledge/` | `policy_ack_test` | — | 0 |
| B-D25 | `employee/EmpUpdatesCard.tsx` | `employee_dashboard_view.dart` | In-place announcement modal | Navigates to Announcements | PARTIAL | Optional in-place sheet | `/dashboard/announcement/` | No | P2 | 1 |
| B-D26 | `EmpBirthdayAnnouncement.tsx`, `BirthdayCelebrationModal.tsx` | `employee_dashboard_view.dart` | Celebration modal | List only | PARTIAL | Celebration sheet | `/dashboard/employee/birthdays/today/` | `employee_birthdays_test` | P2 | 2 |
| B-D27 | `TeamBirthdayCard.tsx`, `ManagerBirthdayCard.tsx` | `emp_celebration_cards.dart` | Cards with Send Wishes | Same; button gated so no 403 (deliberate) | COMPLETE | — | `/dashboard/birthdays/mine/`, POST send-email | `celebration_cards_test` | — | 0 |
| B-D28 | `EmpPromotionCelebration.tsx` | `emp_celebration_cards.dart` | Unread promotion notification | Same | COMPLETE | — | `/notifications/?notification_type=promotion…`, PATCH `/read/` | `celebration_cards_test` | — | 0 |
| B-D29 | `AssessmentLockedNotice.tsx` | Router assessment gate | Per-widget notice | App-wide redirect (equivalent) | COMPLETE | — | — | Gate tests | — | 0 |
| B-D30 | `GlobalSearch.tsx` | `presentation/search/global_search_*.dart` | Nav and employee search | Same rules | COMPLETE | — | `/employees/?search&page_size=5` | `global_search_test` | — | 0 |
| B-D31 | `NotificationBell.tsx`, `useNotifications.ts` | `notifications/.../notification_bell_button.dart`, `notification_panel.dart` | List, unread polling, mark read/all, module routing (promotion → profile) | Same; **no `promotion` route** (falls back to the dashboard) | PARTIAL | Add the `promotion` → profile route; tests | `/notifications/`, `/unread-count/`, `/{id}/read/`, `/read-all/` | **No** | P2 | 0.5 |
| B-D32 | `DashboardShell.tsx` header | `dashboard_shell.dart`, `app_top_bar.dart`, `app_sidebar.dart` | Avatar photo, title, logout | Initials avatar only | PARTIAL | Show `profile_photo_url` | `/employees/me/` | No | P2 | 0.5 |
| B-D33 | `lib/navConfig.ts`, `proxy.ts` | `navigation/nav_config.dart`, `core/router/access_control.dart` | Permission-filtered navigation | Same algorithm (see §2.B matrix) | COMPLETE | Optional strict gate alignment | — | `access_control_test` | P2 | 0.5 |
| B-D34 | `/dashboard/announcements` | `announcements/.../announcements_screen.dart` | Categories, paging, stats, view tracking, react, pin | Same (load-more) | COMPLETE | — | `/announcements/`, `/{id}/view/`, `/{id}/react/` | `announcements_pagination_test`, `permission_visibility_test` | — | 0 |
| B-D35 | Announcement form (announcements page) | `post_announcement_sheet.dart`, `announcement_permissions.dart` | CRUD, pin, email; **posters without org-wide rights locked to their own branch**; departments filtered by branch | CRUD, pin, email; **no own-branch lock**; departments unscoped (backend does not enforce) | PARTIAL | Lock non-org-wide posters to their own branch; fetch departments with `?branch=` | POST/PUT/DELETE `/announcements/` | Visibility only | P1 | 2 |
| B-D36 | Announcements → Celebration birthday cards | — | Birthday cards in the All/Celebration tabs | Absent | MISSING | Add the cards | `/dashboard/employee/birthdays/today/` | No | P2 | 1.5 |
| B-D37 | `/dashboard/contacts` | `contacts/.../contact_matrix_screen.dart`, `contact_form_sheet.dart` | List; CRUD with `can_manage` | Same, plus tel:/mailto: links | COMPLETE | — | `/company-contacts/` | `contact_matrix_test` | — | 0 |
| B-D38 | `/dashboard/org-chart` `OrgChartClient.tsx` | `org_chart/.../org_chart_screen.dart` | Branch filter, zoom, profile links | Branch chips, gated profile tap (no zoom; vertical layout) | COMPLETE | — | `/org-chart/?branch=` | `org_chart_profile_access_test` | — | 0 |
| B-D39 | `/dashboard/profile` `ProfileClient.tsx` | `profile/.../profile_screen.dart`, `profile_sections.dart` | All sections; edit phone, addresses, emergency; **admin-configured custom fields** (`custom_field_values`) | Fixed fields only; no field-config or custom values | PARTIAL | Fetch field-config; render and edit custom fields | GET `/onboarding/field-config/`, PATCH `/employees/me/` | `profile_work_info_test` | P1 | 4 |
| B-D40 | `CustomFieldFileUpload.tsx` (profile) | — | Upload/delete custom file fields | Absent (constants exist, unused) | MISSING | List/upload/delete UI | `/onboarding/custom-file-fields/` | No | P1 | 3 |
| B-D41 | Profile Documents tab | `profile_documents_section.dart`, `profile_document_viewer.dart` | Upload, replace, view | Same, plus an in-app viewer | COMPLETE | — | `/onboarding/documents/`, `/document-type-config/`, POST `/employees/{id}/documents/` | 5 profile document tests | — | 0 |
| B-D42 | `ProfilePhotoModal.tsx` | `profile_sections.dart` | Photo 100–200 KB; remove | Same | COMPLETE | Tests | POST/DELETE `/employees/me/photo/` | No | P2 | 0.5 |
| B-D43 | `FaceRegistrationModal.tsx`, `FaceConsentPanel.tsx`, `FaceStatusPanel.tsx` | `profile_face_id_section.dart`, `face_consent_panel.dart` | Status states plus consent; hidden when disabled | Same; shows a "disabled" card instead of hiding | COMPLETE | Optionally hide when disabled | `/attendance/face-registration/me/` | No | P2 | 0.25 |
| B-D44 | `profile/ChangePasswordForm.tsx` | `profile_sections.dart` | Change password | Same | COMPLETE | — | POST change-password | Auth tests | — | 0 |
| B-D45 | SeparationCard on profile | `ProfileSeparationSection` | Status card | Same | COMPLETE | — | separation | separation tests | — | 0 |
| B-D46 | `/dashboard/documents` | `documents/.../documents_screen.dart` | Stats, filter, search | Same | COMPLETE | — | `/documents/stats/`, `/documents/` | `permission_visibility_test` | — | 0 |
| B-D47 | Document upload | `document_upload_dialog.dart` | Multipart upload with acknowledgement flag | Same | COMPLETE | — | POST `/documents/` | No | — | 0 |
| B-D48 | Document delete | `document_detail_dialog.dart` | Confirm, then delete | Same | COMPLETE | — | DELETE `/documents/{id}/` | `permission_visibility_test` | — | 0 |
| B-D49 | `DocPreviewModal.tsx`, `DocPreviewBody.tsx` | `document_detail_dialog.dart` | In-app image/PDF/text preview | Opens in an external app | PARTIAL | In-app viewer (reuse `profile_document_viewer`) | `file_url` | No | P2 | 3 |
| B-D50 | `policy/AcknowledgementPanel.tsx` | `acknowledgement_panel.dart` | Acknowledge; toggle; report | Same | COMPLETE | — | `/documents/{id}/acknowledge/`, `/acknowledgements/` | `policy_ack_test` | — | 0 |
| B-D51 | `/dashboard/email-logs` | `email_log/.../email_log_screen.dart` | Search, paging, read-only | Same | COMPLETE | Tests | GET `/recruitment/emails/` | **No** | P2 | 1 |
| B-D52 | `/dashboard/reports` (static ComingSoon) | Placeholder, blocked by `kUnavailablePaths` | Web mock; no backend | Hidden | BLOCKED | None (fix the stale comment in `access_control.dart`) | none | `access_control_test` | — | 0 |
| B-D53 | `VoiceCommandButton.tsx`, `VoiceConversationPanel.tsx`, `QuickActionChips.tsx`; backend `apps/voice_commands` | `voice_commands/**`, `app/app.dart` overlay | Voice/typed commands, TTS, fallback STT, face-proof turn | Same payloads and flows (stricter gating) | COMPLETE (code) | **Never device-tested.** Device end-to-end check plus more tests. | POST `/voice/parse/`, `/transcribe-fallback/`, `/speak/` | `voice_access_test` only | P1 (verification) | 3 |

#### §2.B Navigation and permission matrix

| Web nav item | Web gate (nav / proxy) | Mobile entry | Mobile gate | Match |
|---|---|---|---|---|
| Dashboard, Announcements, Separation, My Attendance, My Requests, Contact Matrix, My Payslips, My Referrals, My Profile | none | Same | none | Yes |
| Interview List, Review & Onboarding, Email Logs | `recruitment.view` | Same | `recruitment.view` | Yes |
| Assessments | `assessments.view` | Same | `assessments.view` | Yes |
| My Assessments | none (`/dashboard/assessments`) | `/dashboard/my-assessments` | none | Yes (different path) |
| Face ID Registrations | `facial_recognition.approve` | Same | Same | Yes |
| Employees | `employees.view` | Same | Same | Yes |
| Org Chart | `org_chart.view` | Same | Same | Yes |
| Branches | `branches.view` / proxy `settings.view` | Same | `branches.view` | Partial (mobile follows the API) |
| Attendance | `attendance.create` / proxy `attendance.view` | Same | Same | Yes |
| **Payroll** | `payroll.view` | **none** | — | **No** (removed in `e558822`) |
| Leave Management | `leave.view` | Same | Same | Yes |
| Work From Home | `wfh.view` | `/dashboard/wfh` | nav `wfh.view`; **no route guard** | Partial |
| Expenses | `expenses.view` | Same | Same | Yes |
| Approvals | any of `leave.approve`, `expenses.approve` | Same | also accepts `wfh.approve`, `separation.approve` | Partial (mobile wider; matches the tabs shown) |
| Document Center | `documents.view` | Same | Same | Yes |
| Audit Log | `audit.view` (proxy resolves to `settings.view`) | `/settings/audit` | `audit.view` | Partial (mobile matches the API) |
| Settings | `settings.view` | Same | Same | Yes |
| Reports | not in nav; ComingSoon | hidden (`kUnavailablePaths`) | — | Yes |
| Header: search / bell / logout / voice | authenticated | Same | authenticated (voice stricter) | Yes |

**Superuser bypass.** Mobile applies the superuser/`settings.edit` bypass on the client (`userHasPermission`). Login also sets `is_superuser` from `settings.edit` (`accounts/views.py:607`).

**Sidebar gaps.** Payroll is the only web sidebar section with no mobile entry. Missing in-page entries: ID Card (employee header), Assets (settings and the employee tab), and three settings tiles (ID Card, Assets, Payroll Rules).

### Area C — Employees, branches, separation, Face ID registrations, organisation settings

**Roles.** HR / Branch Admin / Company Admin, via `employees.*`, `branches.view`, `settings.*`, `facial_recognition.approve`. Separation is open to all (self-service) plus approvers.

| ID | Web | Mobile | Web functionality | Mobile functionality | Status | Exact missing work | Endpoints | Tests | Pri | h |
|---|---|---|---|---|---|---|---|---|---|---|
| C-E01 | `/dashboard/employees` nav | `/dashboard/employees` | `employees.view` | Same | COMPLETE | — | — | `access_control_test`, `permission_visibility_test` | — | 0 |
| C-E02 | `employees/page.tsx` | `employees/presentation/employees_screen.dart`, `employees_remote_datasource.dart` | Search, filters, pages; branch locked for Branch Admin | Same params; infinite scroll; branch filter not locked (server scopes) | PARTIAL | Lock the branch filter | GET `/employees/` | No | P2 | 2 |
| C-E03 | Stats cards | `employee_providers.dart` | `/employees/stats/?branch=` | Separate count calls; no department count; ignores the branch filter | PARTIAL | Use `/employees/stats/` | GET `/employees/stats/` | No | P2 | 2 |
| C-E04 | Row activate/deactivate | Profile card toggle | Confirm modal; PATCH `is_active` | Toggle without confirmation | PARTIAL | Confirmation dialog | PATCH `/employees/{code}/` | No | P2 | 1.5 |
| C-E05 | `AddEmployeeModal.tsx` | `add_employee_sheet.dart`, `employee_model.dart` | Includes **Assign HR** and **Reporting Manager** | No `hr_id` / `reporting_manager_id` | PARTIAL | Add both pickers (datasource methods already exist) | POST `/employees/` | No | P1 | 3 |
| C-E06 | `/dashboard/employees/new` | — | Orphan 7-step wizard; nothing links to it | — | BLOCKED (web orphan) | Do not port | POST `/employees/` | — | — | 0 |
| C-E07 | `BulkImportModal.tsx` | `employee_bulk_import_screen.dart` | Upload; **sample CSV/XLSX**; **error-report CSV** | Upload and results | PARTIAL | Sample download plus error-report export | POST `/employees/bulk-import/`, GET `/bulk-import/sample/` | No | P2 | 3 |
| C-E09 | `[id]/_components/ProfileHeader.tsx` | `employee_profile_screen.dart` | ID Card link, Reset Password | No ID Card entry | PARTIAL | Add the entry (with C-E27) | — | Partial | P1 | 0.5 |
| C-E10 | `ResetPasswordModal.tsx` | `reset_password_dialog.dart` | Reset with `email_sent` warning | Same | COMPLETE | — | POST `/employees/{code}/reset-password/` | `employee_detail_notice_reset_test` | — | 0 |
| C-E11 | `[id]/page.tsx` pending-onboarding gate | `employee_profile_screen.dart` | Hides tabs and shows "Onboarding form not submitted" | Tabs and edit always shown | MISSING | Gate on `onboarding_status` | GET `/employees/{code}/` | No | P1 | 2 |
| C-E12 | Tab set `employees/_data.ts` | `employee_profile_screen.dart` | Profile, Salary, Payroll, Leave, Attendance, Approval Matrix, Promotion, Assets, Wishes | Has a "Benefit" placeholder; no Salary/Payroll/Assets | PARTIAL | Remove Benefit (the others are C-E19/E20/E21) | — | No | P2 | 0.5 |
| C-E13 | Profile → Personal edit | `add_employee_sheet.dart` (editing) | Includes **login email** and **Reporting Approver** | Neither | PARTIAL | Add both to the form and payload | PUT `/employees/{code}/` | No | P1 | 3 |
| C-E14 | Education, Bank, Emergency sections | `employee_profile_screen.dart` | HR can view **and edit** | Read-only (stale comment `employee_model.dart:470-475` says PUT persists only 8 keys) | PARTIAL | Edit for all three sections, with validation; fix the comment | PUT `/employees/{code}/` | No | P1 | 6 |
| C-E15 | EPF / Statutory | — | `uan_number`, `name_as_per_aadhar`, `esi_number` | Absent | MISSING | Model, view and edit | PUT `/employees/{code}/` | No | P1 | 2 |
| C-E16 | Profile custom fields | — | Custom values plus custom file fields | Absent | MISSING | Config-driven rendering, edit, file upload/delete | `/onboarding/field-config/`, `/employees/{id}/custom-file-fields/` | No | P2 | 6 |
| C-E17 | Profile → Documents | `employee_profile_screen.dart` | Type list from config; upload/replace | Server list; upload/replace | COMPLETE | Optional: config-driven "Not uploaded" rows | POST `/employees/{code}/documents/` | No | P2 | 1.5 |
| C-E18 | Notice period (read-only) | `employee_profile_screen.dart` | Read-only | Same | COMPLETE | — | GET `/employees/{code}/` | `employee_detail_notice_reset_test` | — | 0 |
| C-E19 | `SalaryTab.tsx` | — | CTC history; assign salary | Absent | MISSING | Product decision (admin payroll scope) | `/payroll/employee-salary/history/{pk}/`, `/payroll/structures/` | No | P2 (decision) | 6 |
| C-E20 | `PayrollTab.tsx` | — | Payslip history | Absent | MISSING | Product decision | `/payroll/employees/{pk}/payslips/` | No | P2 (decision) | 3 |
| C-E21 | `AssetsTab.tsx` | — | Assigned assets; assign; return | Absent; no asset endpoints | MISSING | Tab plus assign/return dialogs (Assets scope decision) | `/assets/employees/{uuid}/`, `/assign/`, `/assets/assignments/{id}/return/` | No | P1 (decision) | 6 |
| C-E22 | `LeaveTab.tsx`, `LeaveCreditsSection.tsx` | `employee_leave_tab.dart`, `leave_credits_section.dart` | Stats, requests, credits adjust/reverse | Same | COMPLETE | Device check of the detail modal | `/leave/credits/{code}/…` | `employee_leave_credits_test` | — | 0.5 |
| C-E23 | `AttendanceTab.tsx` | `employee_attendance_tab.dart` | Calendar and history | Same | COMPLETE | Parameter spot-check | `/attendance/…` | No | P2 | 1 |
| C-E24 | `ApprovalMatrixTab.tsx`, `ReportingManagerCard.tsx` | `employee_profile_screen.dart`, `approval_override_sheet.dart` | Overrides; manager/HR quick edit | Same | COMPLETE | Tests | `/employees/{code}/approval-matrix/`, `/reporting-manager/`, `/hr/` | No | P2 | 1 |
| C-E25 | `PromotionTab.tsx` | `promotion_tab.dart` | **History from `/employees/{id}/promotions/`**; promote | Promote works; history is session-local only (endpoint never called) | PARTIAL | Fetch and render history; refetch after promote | GET `/employees/{code}/promotions/` | No | P1 | 3 |
| C-E26 | `WishesTab.tsx` | `wishes_tab.dart`, `send_wish_sheet.dart` | Send a wish email | Same | COMPLETE | — | POST `/recruitment/candidates/{code}/send-email/` | Partial | P2 | 0.5 |
| C-E27 | `/employees/[id]/id-card`, `components/idcard/IdCardFaces.tsx` | — | Front/back card; A4 or card layout; print/PDF | Absent | MISSING | Card widgets plus PDF/print (needs a dependency, e.g. `pdf`/`printing`: **decision**) | GET `/employees/{code}/id-card/` | No | P1 (decision) | 10 |
| C-B01 | `/dashboard/branches` | `branches/.../branches_screen.dart` | List, stats, distribution | Same, plus search and filters | COMPLETE | — | `/branch/branches/`, `/stats/`, `/distribution/` | No | — | 0 |
| C-B02 | `BranchManagement.tsx` form | `branch_form_dialog.dart` | Create/edit core fields | Same (PUT; the backend applies it as `partial=True`, `branch/views.py:290`) | COMPLETE | — | `/branch/branches/[id/]`, `/preview-code/` | No | P2 | 0.5 |
| C-B03 | Geofencing in the branch form | `branch_card.dart`, `branch_details_sheet.dart` (display) | Toggle, latitude/longitude, radius 10–5000 m | **Display only** | PARTIAL | Edit with validation (optional "use current location") | PATCH `/branch/branches/{id}/` or PUT `/{pk}/geofencing/` | No | P1 | 4 |
| C-B04 | LeaderForm on create | — | Assign an existing or new Branch Admin while creating | Absent | MISSING | Add the step to Add Branch | PUT `/employees/{code}/`, POST `/employees/` | No | P2 | 5 |
| C-B05 | Change Branch Admin | `branch_admin_reassign.dart` | Reassign | Same | COMPLETE | — | POST `/branch/branches/{id}/reassign-admin/` | `branch_admin_reassign_test`, `edit_branch_admin_test` | — | 0 |
| C-B06 | Delete branch | `branches_screen.dart` | Confirm, then delete | Same | COMPLETE | — | DELETE `/branch/branches/{id}/` | No | P2 | 0.5 |
| C-B07 | Admin team counts in branch details | `branch_details_sheet.dart` | Counts | Absent | MISSING | Two count calls | GET `/employees/?reporting_manager_id=&hr_id=` | No | P2 | 1.5 |
| C-S01 | `/dashboard/separation` | `separation/.../separation_screen.dart` | My/Team; **employee-code filter**; row actions | My/Team, status chips; no code filter | PARTIAL | Employee-code filter | GET `/separation/requests/` | `separation_*` tests | P2 | 1.5 |
| C-S02 | `SeparationFormModal.tsx` | `separation_form_sheet.dart` | Create/edit with document | Same | COMPLETE | — | POST/PATCH `/separation/requests/` | Yes | — | 0 |
| C-S03 | Detail: cancel/delete | `separation_detail_screen.dart` | Gated by `can_*` | Same | COMPLETE | — | PATCH/DELETE `/separation/requests/{id}/` | Partial | — | 0 |
| C-S04 | `ApprovalSection.tsx`, `DecisionModal.tsx` | `separation_approval_section.dart` | Stage approve/reject | Same | COMPLETE | — | POST `/stages/{sid}/action/` | `separation_approvals_test` | — | 0 |
| C-S05 | `KtHandoverSection.tsx` | `separation_handover_section.dart` | Task CRUD | Same | COMPLETE | Tests | `/tasks/` | No | P2 | 0.5 |
| C-S06 | `ClearanceSection.tsx` | `separation_clearance_section.dart` | Approve/reject | Same | COMPLETE | Tests | `/clearances/` | No | P2 | 0.5 |
| C-S07 | `DocumentsSection.tsx` | `separation_documents_section.dart` | Attach/delete | Same | COMPLETE | Tests | `/documents/` | No | P2 | 0.5 |
| C-S08 | `ActivitySection.tsx` | `separation_activity_section.dart` | Grouped activity | Same | COMPLETE | — | `/activities/` | No | — | 0 |
| C-F01 | `/dashboard/face-id-registrations`, `HRFaceCaptureModal.tsx` | `facial_recognition/.../face_id_registrations_screen.dart` | Picker, status, consent, liveness, register (**128-d**) | Same flow; registers a **192-d** embedding | PARTIAL | **Blocked on backend/product** (see §1.3) | POST `/attendance/face-registration/register/` | No | **P0** (blocked) | 8+ |
| C-ST01 | `/settings/company` | `settings/presentation/company/company_screen.dart` | All fields; logo upload; **remove logo (`remove_logo=true`)** | Fields and upload; **remove is local-only** (never sent) | PARTIAL | Send `remove_logo` | PUT `/settings/company/` | No | P1 | 1 |
| C-ST02 | `FinancialYearSection.tsx` | `financial_year_section.dart` | Start month | Same | COMPLETE | — | `/settings/company/financial-year/` | No | — | 0 |
| C-ST03 | `/settings/departments` | `settings/presentation/departments/*` | Department and designation CRUD | Same | COMPLETE | Tests | `/departments/`, `/designations/` | No | P2 | 0.5 |
| C-ST04 | `/settings/employee-code` | `employee_code_screen.dart`, `employee_code_model.dart` | **Prefix + DDMM + initials format**; prefix only editable (letters); `settings.edit` | **Outdated**: padding and next-sequence editable; wrong preview; no gate | PARTIAL | Match the new format, validation and gate | GET/PUT `/settings/employee-code/` | No | P1 | 2 |
| C-ST05 | `/settings/id-card` | — | Signatory, terms, toggles, reference PDF | Absent | MISSING | New screen | GET/PUT `/settings/id-card/`, `/reference-pdf/` | No | P2 | 5 |
| C-ST07 | `/settings/permissions` roles list | `/settings/roles` `roles_screen.dart` | List and active toggle | Same | COMPLETE | — | `/roles/` | No | — | 0 |
| C-ST08 | `AddRoleModal.tsx`, `EditRoleModal.tsx`, `RoleFormFields.tsx` | `role_form_sheet.dart`, `roles_model.dart` | **`can_manage_team` / `can_manage_branch` toggles**; 4 presets | Payload omits both flags (preserved on PUT because they are optional model booleans, but they **cannot be set** from mobile); 2 presets | PARTIAL | Add both toggles and the Full Admin / View Only presets | POST `/roles/`, PUT `/roles/{id}/` | No | P1 | 2.5 |

Not counted in Area C:
- Employee list export: web has no export.
- The mobile-only separation section on the employee profile.
- Settings → Assets: counted in Area E.
- The settings-hub tiles: counted in F-ST01.

### Area D — Attendance, approvals, my requests, leave, WFH, leave/attendance settings

**Roles.**
- Employees use My Attendance, Leave, WFH and My Requests.
- Managers and HR use Approvals.
- HR uses Attendance (`attendance.create` / `attendance.view`).
- Admins use the settings screens.

| ID | Web | Mobile | Web functionality | Mobile functionality | Status | Exact missing work | Endpoints | Tests | Pri | h |
|---|---|---|---|---|---|---|---|---|---|---|
| D-A01 | `/dashboard/attendance` | `attendance/.../attendance_screen.dart` | 6 tabs; branch banner | 6 tabs | COMPLETE | (banner: see D-A04) | — | `access_control_test`, `p0_permission_parity_test` | — | 0 |
| D-A02 | Stat cards | `_StatsBar` | 4 cards plus badges | Same | COMPLETE | — | `/attendance/dashboard/` | No | — | 0 |
| D-A03 | `AttendanceTab.tsx` | `_TeamDayView` | Filters, chips, 20 per page | Same, plus search/status/sort | COMPLETE | — | `/attendance/records/` | No | — | 0 |
| D-A04 | Branch lock | `attendance_screen.dart` | Restricted HR sees a locked branch | Dropdown shown to all (server scopes) | PARTIAL | Lock or hide on the 4 tabs; show the banner | — | No | P2 | 2 |
| D-A05 | Export `lib/attendanceExport.ts` | `attendance_export_sheet.dart` | Day/month/range | Same | COMPLETE | — | GET `/attendance/export/` | `attendance_export_test` | — | 0 |
| D-A06 | `ImportModal.tsx` | `_ImportAttendanceDialog` | Dry-run preview, then confirm | Same | COMPLETE | — | POST `/attendance/import/` (dry_run), `/import/sample/` | `attendance_import_modes_test` (30) | — | 0 |
| D-A07 | `AttendanceEditForm.tsx` | `_AttendanceRecordFormDialog` | Create/PATCH | Same | COMPLETE | Tests | `/attendance/records/create/`, `/{id}/` | No | P2 | 2 |
| D-A08 | `AttendanceDetailDrawer.tsx` | Detail dialog in `attendance_screen.dart` | **Approve/Reject corrections inline** | Corrections shown read-only (review exists only in the Un-punches inbox) | PARTIAL | Inline review (reuse `reviewCorrection`); refresh | PATCH `/attendance/corrections/{id}/review/` | Partial | P1 | 3 |
| D-A09 | `EmployeeMonthView.tsx` | `_EmployeeMonthView` | Month grid with flagged outline | Stats/summary/calendar (different but valid API) | COMPLETE | Optional flagged outline | `/attendance/calendar/?employee_id=` | `attendance_month_navigation_test` | P2 | 2 |
| D-A11 | `OtEntryTab.tsx` | `_OtEntryTab` | **Approver picker** | Free-text approver (silently dropped if unmatched) | PARTIAL | HR-user picker | POST `/attendance/overtime/create/` | No | P2 | 1.5 |
| D-A12 | `InvalidPunchesTab.tsx` + modals | `_InvalidPunchesTab` | Paged list; assign/convert/discard | Actions match; single page of 100 | COMPLETE | Paging | `/attendance/invalid-punches/…` | No | P2 | 1.5 |
| D-A13 | `UnpunchesTab.tsx` | `_UnpunchesTab`, `hr_correction_card.dart` | Read-only list | List plus corrections inbox | COMPLETE | Paging | `/attendance/un-punches/`, `/corrections/` | No | P2 | 1 |
| D-A15 | `WeeklyOffAssignmentTab.tsx` | `weekly_off_assignment_tab.dart` | Assign single or bulk | Same | COMPLETE | — | `/attendance/weekly-off-assignments/` | `weekly_off_assignment_test` | — | 0 |
| D-A16 | `ShiftAssignmentTab.tsx`, `ShiftMasterCard.tsx` | `shift_assignment_tab.dart`, `shift_master_card.dart` | Shift master and assignment | Same | COMPLETE | — | `/attendance/working-hours/`, `/shift-assignments/` | `shift_assignment_test`, `shift_master_test` | — | 0 |
| D-B01 | `/dashboard/my-attendance` | `my_attendance_screen.dart` | 2 tabs | Same | COMPLETE | — | — | — | — | 0 |
| D-B02 | `ClockWidget.tsx`, `useClockWidget.ts` | `clock/clock_punch_flow.dart` | GPS → WFH mode → geofence → face → punch | Same order | COMPLETE | (face: see C-F01) | `/attendance/punch/`, `/geofence-check/`, `/today/` | `clock_punch_flow_test` | — | 0 |
| D-B03 | Face lockout countdown | — | `blocked` + `retry_after_seconds` countdown | Error text only | PARTIAL | Parse and show the countdown | POST `/attendance/punch/` | No | P2 | 2 |
| D-B04 | Day-completed guard | `clock_punch_flow.dart` | Disable after In and Out | Same | COMPLETE | — | `/attendance/today/` | `day_completed_test` | — | 0 |
| D-B05 | Stats/summary | `my_attendance_screen.dart` | Cards and month navigation | Same | COMPLETE | — | `/attendance/stats/`, `/summary/` | `attendance_month_navigation_test` | — | 0 |
| D-B06 | `CalendarAndHistory.tsx` | `my_attendance_screen.dart` | Calendar, history, regularize | Same | COMPLETE | — | `/attendance/calendar/` | Partial | — | 0 |
| D-B07 | `CorrectionModal.tsx`, `RegularizationModal.tsx` | `_CorrectionDialog` | Request a correction | Same | COMPLETE | Tests | POST `/attendance/correction/` | No | P2 | 1.5 |
| D-B08 | `AttendanceCorrectionsTab.tsx` | `_MyCorrectionsSection` | Counts, list, approval trail | Same | COMPLETE | — | `/attendance/corrections/my/` | No | — | 0 |
| D-C01 | `/dashboard/approvals` gating | `approvals/.../approvals_screen.dart` | Team/Attendance/Face tabs by permission | Same, plus WFH | COMPLETE | — | — | `access_control_test` | — | 0 |
| D-C02 | `TeamApprovalsSection.tsx`, `ApprovalsToolbar.tsx`, `SummaryCards.tsx` | `approvals_providers.dart`, `approvals_list.dart` | Merged inbox, filters, counts | Same sources and parameters | COMPLETE | **Tests** | `/leave/requests/?scope=team`, `/wfh/…`, `/expenses/`, `/attendance/corrections/`, `/separation/…` | **No** | P1 (tests) | 4 |
| D-C03 | `ApprovalModal.tsx` | `approve_reject_dialog.dart` | Remarks; **email template picker** (leave and expense) | Remarks; no picker | PARTIAL | Picker for **expense only**. The backend ignores `template_name` for leave (web mock); merged with E-EXP05. | PUT `/expenses/{n}/`, `/settings/email-templates/resolve-context/` | No | P2 | 4 |
| D-C04 | `BulkConfirmModal.tsx` | `approvals_providers.dart` | Bulk with exclusions | Same | COMPLETE | Tests | as D-C03 | No | P2 | 1 |
| D-C05 | `RequestDetailDrawer.tsx` | `approval_detail_sheet.dart` | Detail; separation routes out | Same | COMPLETE | — | — | `separation_approvals_test` | — | 0 |
| D-C06 | Payslip queries (Team tab) | `resolve_payslip_query_dialog.dart` | Resolve with a note | Same | COMPLETE | — | `/payroll/queries/`, `/{id}/resolve/` | `payslip_query_resolution_test` | — | 0 |
| D-C07 | `AttendanceApprovalTab.tsx` | `attendance_approval_tab.dart`, `attendance_approval_remote_datasource.dart` | Payroll-cycle L1/L2 approval | Same payload | COMPLETE | **Tests** | `/payroll/cycles/pending-approval/`, `/{id}/approve-attendance/` … | **No** | P1 (tests) | 3 |
| D-C08 | `FaceRegistrationApprovalsTab.tsx` | `face_registration_approvals_tab.dart` | Approve/reject pending registrations | Same | COMPLETE | Tests | `/attendance/face-registration/pending/`, `/{id}/review/` | No | P2 | 1.5 |
| D-D01 | `/dashboard/my-requests` | `my_requests/.../my_requests_screen.dart` | Merged list, filters, **column sort**, cancel | Same; fixed sort (plus WFH cancel) | PARTIAL | Sort control; tests | `/leave/requests/`, `/expenses/`, `/attendance/corrections/my/`, `/wfh/requests/` | **No** | P2 | 3 |
| D-E01 | `/dashboard/leave` | `leave/.../leave_screen.dart` | 4 tabs | Same, plus a duplicate Approvals tab | COMPLETE | Decide on the duplicate tab | — | No | P2 | 0.5 |
| D-E02 | `LeaveDashboard.tsx`, `LopBadge.tsx` | `leave_dashboard_tab.dart` | LOP badge on rows | LOP only in the detail view | PARTIAL | Row badge | `/leave/balance/`, `/leave/requests/` | No | P2 | 1.5 |
| D-E03 | `ApplyLeaveForm.tsx` | `apply_leave_tab.dart` | Preview, document rules, multipart | Same | COMPLETE | **Tests** | GET `?action=preview`, POST `/leave/requests/` | **No** | P1 (tests) | 3 |
| D-E04 | `LeaveRequestDetailModal.tsx` | `leave_request_detail_sheet.dart` | Detail, cancel | Same | COMPLETE | — | `/leave/requests/{id}/` | No | — | 0 |
| D-E05 | `TeamCalendar.tsx` | `team_calendar_tab.dart` | Month calendar | Same | COMPLETE | — | `/leave/calendar/` | No | — | 0 |
| D-E06 | `LeaveAnalytics.tsx` | `leave_analytics_tab.dart` | Stats | Same (backend defaults) | COMPLETE | — | `/leave/stats/` | No | — | 0 |
| D-E07 | `components/leave/MonthlyLeaveStatement.tsx` (HR profile) | `employee_leave_tab.dart` | Monthly statement cards plus table | Absent in the HR profile (the employee dashboard has it) | PARTIAL | Render the statement in the profile Leave tab | `/leave/balance/` statement | Dashboard only | P2 | 5 |
| D-E08 | `OpeningBalanceImportModal.tsx` | `leave_balance_import_screen.dart` | Sample, validate, import | Same | COMPLETE | Tests | `/leave/balance/import/…` | **No** | P2 | 2 |
| D-F01 | `/dashboard/work-from-home` | `wfh/.../wfh_screen.dart` | 3 tabs | Same | COMPLETE | (add the route guard: §2.B) | — | — | — | 0 |
| D-F02 | `RequestWfhForm.tsx` | `request_wfh_tab.dart`, `wfh_saved_location_picker.dart` | Medical proof, saved locations | Same | COMPLETE | — | `/wfh/requests/`, `/wfh/saved-locations/` | `wfh_medical_request_test` | — | 0 |
| D-F03 | `MyWfhRequestsList.tsx` | `my_wfh_requests_tab.dart` | List, cancel | Same | COMPLETE | — | `/wfh/requests/` | Partial | — | 0 |
| D-F04 | `WfhDailyReports.tsx` | `wfh_daily_reports_tab.dart`, `wfh_report_review_panel.dart` | Submit and review | Same | COMPLETE | — | `/wfh/reports/` | `wfh_daily_reports_tab_test`, `wfh_report_data_test` | — | 0 |
| D-G01 | `/settings/attendance-config`, `AttendanceSettings.tsx` | `/settings/attendance-rules` | All sections; PATCH or PUT | Same | COMPLETE | — | `/attendance/settings/` | `attendance_policy_rules_test`, `attendance_rules_weekly_off_grid_test` | — | 0 |
| D-G02 | `WeeklyOffPatternsCard.tsx` | `weekly_off_patterns_card.dart` | Pattern CRUD | Same | COMPLETE | — | `/attendance/weekly-days/` | `weekly_off_pattern_test` | — | 0 |
| D-H01 | `/settings/leave-policy` tabs | `leave_policy_screen.dart` | 5 tabs plus import | Same | COMPLETE | — | — | Partial | — | 0 |
| D-H02 | `PolicyTab.tsx` | `add_leave_type_dialog.dart`, `leave_policy_form_sheet.dart` | Leave type CRUD | Same | COMPLETE | — | `/leave/policy/` | `leave_policy_long_leave_test` | — | 0 |
| D-H03 | `LeavePoliciesTab.tsx` and sections | `leave_policy_rules_tab.dart`, `monthly_credit_settings_section.dart` | Rules, carry-forward, eligibility, monthly | Same | COMPLETE | Device check of the carry-forward save path | `/leave/policy/{type}/` | `monthly_credit_settings_test` | — | 0 |
| D-H04 | `CreditTab.tsx` | `leave_credit_rules_screen.dart` | Annual credit | Real annual credit, **plus a fake local "Accrual Rules" list** (no backend) | PARTIAL | Remove or hide the fake accrual UI | POST `/leave/balance/credit/` | No | P2 | 1 |
| D-H05 | `CarryForwardTab.tsx` | `leave_carry_forward_tab.dart` | Preview, run, history | Same (stale comment at `api_constants.dart:338`) | COMPLETE | Tests; fix the comment | `/leave/carry-forward/…` | **No** | P2 | 2 |
| D-H06 | `MonthlyLeaveTab.tsx` | `leave_policy/monthly_leave/*` | Import, bulk, assignments | Same | COMPLETE | — | `/leave/monthly-credits/…` | `monthly_leave_management_test` | — | 0 |
| D-H07 | `/settings/holiday-calendar` | `holiday_calendar_screen.dart` | CRUD, views, filters | CRUD, branch filter, year | COMPLETE | Tests; confirm search/month filter | `/leave/holidays/` | **No** | P2 | 3 |
| D-H08 | `/settings/notice-period` | `settings/presentation/notice_period/*` | Edit and import | Same | COMPLETE | — | `/employees/notice-period/import/` | `notice_period_settings_test` | — | 0 |
| D-H09 | `/settings/approval-rules` | `approval_rules_screen.dart` | L1/L2 roles per workflow | Same | COMPLETE | Tests | `/settings/approval-rules/` | **No** | P2 | 1.5 |

Not counted in Area D:
- Mobile-only Reprocess Day.
- Web's orphaned `CorrectionsTab.tsx`.
- Geofence configuration (counted as C-B03).

### Area E — Payroll (admin), My Payslip, Expenses, Assets

**Admin payroll context.**
- Commit `e558822` (2026-07-27) deleted the mobile payroll screens. Per `teamcontextfile.md`, they were mock screens with hard-coded data and zero API calls.
- **No document records a product decision to keep admin payroll web-only.** `docs/audit/WEB_MOBILE_PARITY.md:48` still says "Confirm it stays web-only".
- All 18 PAY rows below are MISSING pending that decision.
- Roles: `payroll.view` / `.create` / `.edit` (HR/Admin); `assets.*` (Admin).

| ID | Web | Mobile | Web functionality | Mobile functionality | Status | Exact missing work | Endpoints | Tests | Pri | h |
|---|---|---|---|---|---|---|---|---|---|---|
| E-PAY01 | `/dashboard/payroll` `payroll/page.tsx` | — | 6 tabs, Run Payroll, branch lock | — | MISSING | Shell, nav and tab scaffold | — | No | P1 (decision) | 6 |
| E-PAY02 | `PayrollDashboard.tsx`, `BranchStatusOverview.tsx` | — | Cycles, branch status, resume | — | MISSING | Port | `/payroll/cycles/`, `/settings/`, `/branch-status/` | No | P1 (decision) | 10 |
| E-PAY03 | `RunPayrollWizard.tsx`, `PayrollPeriodStep.tsx` | — | Create cycle | — | MISSING | Port | POST `/payroll/cycles/` | No | P1 (decision) | 8 |
| E-PAY04 | `ApprovalStep.tsx` | — | Attendance approval status in the wizard | — | MISSING | Port | `/payroll/cycles/{id}/manager-approvals/` | No | P1 (decision) | 4 |
| E-PAY05 | `EarningsDeductionsStep.tsx` | — | Eligible employees; process | — | MISSING | Port | `/eligible-employees/`, POST `/process/` | No | P1 (decision) | 6 |
| E-PAY06 | `ReimbBonusesStep.tsx`, `ReimbEditModal.tsx`, `BonusEditModal.tsx` | — | Expense and bonus summaries; edit | — | MISSING | Port | `/expense-summary/`, `/referral-bonus-summary/`, `/payslips/{id}/reimb-bonus/` | No | P1 (decision) | 8 |
| E-PAY07 | `CalculationStep.tsx`, `ValidationStep.tsx` | — | Calculated table; validation | — | MISSING | Port | `/payroll/cycles/{id}/payslips/` | No | P1 (decision) | 6 |
| E-PAY08 | `PayslipsStep.tsx` | — | Dispatch payslips | — | MISSING | Port | POST `/payslips/dispatch/` | No | P1 (decision) | 3 |
| E-PAY09 | `BankTransferStep.tsx` | — | Transfer confirmation; mark paid | — | MISSING | Port | `/salary-transfer/status/`, `/confirm/`, `/mark-paid/` | No | P1 (decision) | 5 |
| E-PAY10 | `CancelCycleModal.tsx` | — | Cancel cycle | — | MISSING | Port | POST `/cancel/` | No | P2 | 2 |
| E-PAY11 | `SalarySetupTab.tsx`, `SalaryComponentsEditor.tsx` | — | CTC assign/revise | — | MISSING | Port | `/payroll/employee-salary/`, `/structures/` | No | P1 (decision) | 14 |
| E-PAY12 | `PayrollAdjustments.tsx` | — | Adjustments CRUD and import | — | MISSING | Port | `/payroll/adjustments/…` | No | P2 | 8 |
| E-PAY14 | `PayrollReports.tsx` | — | ECR XLSX/PDF/TXT | — | MISSING | Port | `/ecr/`, `/ecr/pdf/`, `/ecr-text/` | No | P2 | 5 |
| E-PAY15 | `PayrollAnalytics.tsx` | — | KPIs and charts | — | MISSING | Port | `/payroll/cycles/` | No | P2 | 5 |
| E-PAY16 | `/payroll/runs/[id]` | — | Run detail plus downloads | — | MISSING | Port | `/payroll/cycles/{id}/…`, `/esic/` | No | P2 | 6 |
| E-PAY17 | `/payroll/payslips/[id]` | — (`ApiConstants.payslipDetail` unused) | HR payslip view and print | — | MISSING | Port (reuse the My Payslip card) | `/payroll/payslips/{id}/` | No | P2 | 4 |
| E-PAY18 | `/settings/payroll-config` (Run Settings) | — | Cycle, statutory rates, toggles | — | MISSING | Port | `/payroll/settings/` | No | P2 | 5 |
| E-PAY19 | `SalaryStructuresTab.tsx`, `StatutoryConfigTab.tsx`, `BranchConfigTab.tsx` | — | Structures, statutory, branch config | — | MISSING | Port | `/payroll/structures/…`, `/statutory/…`, `/branch-config/…` | No | P2 | 16 |
| E-PAY21 | `/dashboard/my-payslip`, `PayslipDocument.tsx` | `/dashboard/my-payslip` `my_payslip_screen.dart`, `payslip_model.dart` | Month list; full payslip document | Same data and lines (logo display not confirmed) | COMPLETE | Commit the uncommitted work; device check | `/payroll/my-payslips/`, `/settings/company/` | `payslip_document_parity_test` | — | 1 |
| E-PAY22 | Acknowledge | `my_payslip_screen.dart` | Acknowledge when `sent` | Same | COMPLETE | — | POST `/my-payslips/{id}/acknowledge/` | Partial | — | 0 |
| E-PAY23 | Raise query and my queries | `payslip_queries_section.dart` | Eligibility, deadline, list | Same | COMPLETE | — | `/payroll/queries/` | `payslip_queries_test` | — | 0 |
| E-PAY24 | `PayslipPrint.tsx` (`window.print`) | — | Print / save as PDF (the server `payslip_pdf` is never written) | None | PARTIAL | **Deferred by user decision** ("Defer PDF; screen only") | client-side | No | P2 (deferred) | 8 |
| E-EXP01 | `/dashboard/expenses` `ExpenseClaims.tsx` stats | `expenses/.../expense_screen.dart` | Stats | Same | COMPLETE | Tests | `/expenses/stats/` | **No** | P1 (tests) | 2 |
| E-EXP02 | Claims list | `expense_list_item.dart`, `expense_remote_datasource.dart` | Latest 5 plus "View all" link to My Requests | Default page (20), no paging, no "View all" | PARTIAL | Paging or `page_size`; View-all link | `/expenses/` | No | P2 | 2 |
| E-EXP03 | `ExpenseFormModal.tsx` | `expense_form_sheet.dart` | Create with receipts | Same (plus a 365-day date limit) | COMPLETE | Tests; confirm the 365-day limit | POST `/expenses/` | **No** | P1 (tests) | 2 |
| E-EXP04 | `ExpenseDetailModal.tsx` | `expense_detail_dialog.dart` | Detail and receipts | Same | COMPLETE | — | `/expenses/{n}/` | No | — | 0 |
| E-EXP05 | Expense approve with template (TeamApprovalsSection) | `approvals_providers.dart` | `template_name` / `extra_context` | Status only | PARTIAL | Template picker (same work as D-C03) | PUT `/expenses/{n}/` | No | P2 | (in D-C03) |
| E-EXP07 | Reimbursement into payroll | Payslip reimbursements line | HR side is in the payroll wizard | Employee view matches | PARTIAL | Covered by E-PAY06 | — | No | P2 | (in PAY06) |
| E-AST01 | `/settings/assets` list | — | Search, filters, pagination | — | MISSING | List screen and settings tile | `/assets/` | No | P1 (decision) | 8 |
| E-AST02 | Asset form | — | CRUD; inline category/type | — | MISSING | Form and delete | `/assets/`, `/categories/`, `/types/` | No | P1 (decision) | 10 |
| E-AST03 | Maintenance | — | Send and complete | — | MISSING | 2 dialogs | `/send-to-maintenance/`, `/maintenance/{id}/complete/` | No | P2 | 3 |
| E-AST04 | `AssignmentDetails.tsx` | — | Holder and history | — | MISSING | Detail view | `/assets/{id}/` | No | P2 | 2 |
| E-AST05 | `BulkImportAssetsModal.tsx`, `BulkAssignAssetsModal.tsx` | — | Imports with samples | — | MISSING | Port | `/assets/import/`, `/assets/assignments/import/` | No | P2 | 6 |

Not counted in Area E:
- Payslip-query resolution: counted as D-C06.
- Attendance approval: counted as D-C07.
- The employee Assets tab: counted as C-E21.
- Expense edit/delete: backend-only, not in web.

### Area F — Settings hub, email templates, SMTP, audit, notifications, onboarding fields, assessment config, referral rules

**Roles.**
- HR and Branch Admin have `settings.view`, but no `settings.edit`.
- Company Admin has `settings.edit`, which mobile treats as superuser.
- SMTP GET needs `settings.edit`, so HR sees an error state on both platforms (backend design).

| ID | Web | Mobile | Web functionality | Mobile functionality | Status | Exact missing work | Endpoints | Tests | Pri | h |
|---|---|---|---|---|---|---|---|---|---|---|
| F-ST01 | `/dashboard/settings` `settings/page.tsx` | `settings/presentation/settings_hub/settings_screen.dart` | 19 cards | 16 tiles: no **ID Card**, **Assets**, **Payroll Rules** | PARTIAL | Add the tiles once the screens exist | — | Partial | P1 (with C-ST05/E-AST) | 0.5 |
| F-ST02 | `proxy.ts` gates | `access_control.dart` | `settings.view` on all pages (the audit page inherits it) | Audit gated on `audit.view` (more correct) | COMPLETE | Optional: hide tiles the user cannot open | — | `access_control_test` | P2 | 1 |
| F-ET01 | `/settings/email-templates` | `email_templates_screen.dart`, `settings_remote_datasource.dart:151` | Grouped list | Same. **No `page_size`**, but the backend pages at 20, so templates after the 20th are hidden (web has the same bug) | PARTIAL | Send `page_size` or loop pages | GET `/settings/email-templates/` | No | P1 | 1 |
| F-ET02 | `EditTemplateModal.tsx` (create) | `template_editor_sheet.dart` | Create with category and attachments | Same | COMPLETE | — | POST `/settings/email-templates/` | No | — | 0 |
| F-ET03 | Edit | `template_editor_sheet.dart` | PATCH | Same | COMPLETE | — | PATCH `/settings/email-templates/{id}/` | No | — | 0 |
| F-ET04 | WYSIWYG editor | `template_editor_sheet.dart` | WYSIWYG, inline images, live preview | HTML editor with toolbar and a preview tab | PARTIAL | Inline image insert | — | No | P2 | 6 |
| F-ET05 | Attachments | `template_editor_sheet.dart` | Add/remove (web remove 404s) | Add/remove via the real contract | COMPLETE | — | POST/DELETE `/settings/email-templates/{id}/` | No | — | 0 |
| F-ET06 | Active toggle | `template_card.dart` | PATCH `is_active` | Same | COMPLETE | — | PATCH | No | — | 0 |
| F-ET07 | Preview modal | `template_preview_sheet.dart` | HTML with branding (web uses GET; the backend is POST-only) | Text with HTML stripped | PARTIAL | Render HTML with branding; Edit shortcut | — | No | P2 | 3 |
| F-ET08 | (no web delete) | `email_templates_screen.dart` | — | Delete custom templates | COMPLETE (extra) | — | DELETE | No | — | 0 |
| F-ET09 | Email branding card | `email_branding_card.dart` | Branding fields and logo | Same | COMPLETE | — | `/settings/company/` | No | — | 0 |
| F-ET10 | Birthday wishes card | `birthday_settings_card.dart` | 5 fields plus a link to the birthday audit log | 5 fields; no link | PARTIAL | Audit deep link with `module=birthday` | `/api/birthdays/settings/` | `birthday_settings_test` | P2 | 1 |
| F-ET11 | Write gating | Templates screens | Actions shown to `settings.view` users (403 on use) | Same | COMPLETE | Optional gate | — | No | P2 | 1 |
| F-SM01 | `/settings/smtp` | `smtp/smtp_screen.dart` | List | Same | COMPLETE | — | GET `/settings/smtp/` | No | — | 0 |
| F-SM02 | `SmtpModal.tsx`, `ProviderSelectModal.tsx` | `smtp_form_sheet.dart` | **Provider picker** and `provider` field | No picker or `provider` | PARTIAL | Picker with presets | POST/PUT `/settings/smtp/` | No | P2 | 3 |
| F-SM03 | Activate / delete | `smtp_screen.dart` | Activate, delete | Same | COMPLETE | — | `/activate/`, DELETE | No | — | 0 |
| F-SM04 | Test email | `smtp_screen.dart` | Send a test | Same | COMPLETE | — | POST `/settings/smtp/test/` | No | — | 0 |
| F-AU01 | `/settings/audit` | `audit/audit_screen.dart` | Filters; numbered pager; 30-day default | "Load more" **replaces** the list with the next page; no way back | PARTIAL | Accumulate pages or add Prev/Next; fix the search hint | GET `/settings/audit/` | Routing only | P1 | 2 |
| F-AU02 | Module filter | `audit_screen.dart` | Module list | Mobile list misses `accounts`, `branch`, `birthday`, etc. and includes the never-written `auth` | PARTIAL | Use the modules the backend writes | same | No | P1 | 0.5 |
| F-AU03 | Row fields | `_AuditCard` | Actor, IP, module, action | Same | COMPLETE | — | same | No | — | 0 |
| F-AU04 | Dashboard widget link | `admin_dashboard_view.dart` | View all | Same | COMPLETE | — | — | No | — | 0 |
| F-NT01 | `/settings/notifications` | `notification_settings_screen.dart` | 8 toggles, auto-save | 8 toggles, batch save | COMPLETE | Gate also on `isSuperuser` | `/api/notifications/settings/` | No | P2 | 0.5 |
| F-OF01 | `/settings/onboarding-fields` | `onboarding_fields_screen.dart`, `onboarding_field_form_sheet.dart` | Field config CRUD and reorder | Same | COMPLETE | — | `/settings/onboarding-fields/` | Model only | — | 0 |
| F-OF02 | Document types | `onboarding_fields_screen.dart`, `document_type_form_sheet.dart` | Document type CRUD | Same | COMPLETE | — | `/settings/document-types/` | No | — | 0 |
| F-AC01 | `/settings/assessment-config` | `assessment_config_screen.dart` | 3 settings | Same (edit gated on `assessments.edit`) | COMPLETE | — | `/api/assessments/settings/` | Routing only | — | 0 |
| F-AC02 | `assessments/_components/ItemsModal.tsx` | `items_manager_dialog.dart` | Sections and items; **MCQ / True-False toggle**; video preview | Sections and items CRUD | PARTIAL | True/False helper; video preview | `/assessments/{id}/sections/`, `/items/` | `items_manager_sections_test` | P2 | 2 |
| F-RR01 | `/settings/referral-rules` | `referral_rules_settings_screen.dart` | Rule CRUD | Same | COMPLETE | — | `/api/recruitment/referral-rules/` | No | — | 0 |

---

## 3. Prioritized implementation checklist

All items are inside `mobile_app/`. Items marked **(decision)** need a product answer before work starts. Items marked **(backend)** cannot be completed by mobile alone.

### P0: before the release build (≈ 2 h mobile, plus 1 backend/product blocker)

- [ ] **P0-1** Remove the duplicate candidate emails: drop `sendStatusEmail` after Mark Selected/Rejected (A-I4) and `_sendScheduleEmail` after first scheduling (A-I3). Add tests asserting no `send-email` POST follows. **1.5 h**
- [ ] **P0-2** Login form: replace the minimum-length password validator with a required-only check (A-A2). Add a test. **0.5 h**
- [ ] **P0-3 (backend/product)** Face embedding dimension mismatch, 192-d mobile vs 128-d web (C-F01). Decide one model or per-source storage; the backend should reject mismatched lengths. **Not mobile-fixable.** Until it is resolved, HR should not register faces from mobile for employees who clock in on web.

### P1: primary-role gaps that can be fixed in mobile alone (≈ 53.5 h)

| # | Item (IDs) | h |
|---|---|---|
| 1 | HR attendance detail: inline Approve/Reject of corrections (D-A08) | 3 |
| 2 | Audit log paging fix plus correct module list (F-AU01, F-AU02) | 2.5 |
| 3 | Email templates: load all pages (F-ET01) | 1 |
| 4 | Company settings: send `remove_logo` (C-ST01) | 1 |
| 5 | Employee-code settings: new prefix + DDMM + initials format, validation, `settings.edit` gate (C-ST04) | 2 |
| 6 | Roles: `can_manage_team` / `can_manage_branch` toggles and presets (C-ST08) | 2.5 |
| 7 | Add Employee: HR and Reporting Manager pickers (C-E05) | 3 |
| 8 | Employee edit: login email plus Reporting Approver (C-E13) | 3 |
| 9 | Employee edit: Education / Bank / Emergency sections (C-E14) | 6 |
| 10 | Employee EPF / statutory fields (C-E15) | 2 |
| 11 | Employee pending-onboarding gate (C-E11) | 2 |
| 12 | Promotion history from the server (C-E25) | 3 |
| 13 | Branch geofence editing (C-B03) | 4 |
| 14 | Interview scheduling fields: time, meeting link, interviewer (A-I2/I3) | 3 |
| 15 | Admin dashboard notice-period rows (B-D06) | 1.5 |
| 16 | Admin dashboard Send Wish / Send All (B-D07) | 4 |
| 17 | HR action-queue separation count (B-D12) | 1 |
| 18 | Announcements own-branch lock for non-org-wide posters (B-D35) | 2 |
| 19 | Profile custom fields and custom file fields (B-D39, B-D40) | 7 |

### P1: tests and verification (≈ 17 h)

| # | Item | h |
|---|---|---|
| 20 | Team Approvals inbox tests (D-C02) | 4 |
| 21 | Attendance Approval (payroll cycle) tests (D-C07) | 3 |
| 22 | Apply Leave tests (D-E03) | 3 |
| 23 | Expenses stats and create tests (E-EXP01, E-EXP03) | 4 |
| 24 | Voice commands: device end-to-end verification (B-D53) | 3 |

### P1: needs a product decision first

| # | Item | h | Decision needed |
|---|---|---|---|
| 25 | ID Card page with print/PDF plus header entry (C-E27, C-E09) | 10.5 | Approve a PDF/print dependency (`pdf`/`printing`) and the layout |
| 26 | Assets: core list and form, employee Assets tab, settings tile (E-AST01/02, C-E21, F-ST01) | 24.5 | Is asset management in mobile scope? |
| 27 | Admin payroll: dashboard, run wizard, salary setup (E-PAY01–09, PAY11) | ≈ 78 | Confirm web-only (recommended) or port |

### P2 (≈ 150 h in total; schedule after release)

- **Platform Admin** (A-P1–P4, 34 h): documented as excluded.
- **Remaining payroll admin** (E-PAY10/12/14–19, ≈ 51 h): decision.
- **Assets maintenance and imports** (E-AST03–05, 11 h).
- **Employee screens**:
  - Custom fields and file fields (C-E16, 6 h)
  - Salary and Payroll tabs (C-E19/E20, 9 h, decision)
  - Branch Admin on create (C-B04, 5 h)
  - ID card settings (C-ST05, 5 h)
  - Employee list stats, filters, confirm dialog and bulk-import samples (C-E02/E03/E04/E07, 8.5 h)
- **Attendance**:
  - Branch lock (D-A04)
  - OT approver picker (D-A11)
  - Invalid and un-punch paging (D-A12/A13)
  - Face lockout countdown (D-B03)
  - Monthly leave statement in the HR profile (D-E07)
  - Fake accrual UI removal (D-H04)
  - My Requests sort (D-D01)
  - LOP row badge (D-E02)
  - Expense approval template picker (D-C03/E-EXP05)
- **Settings**: email editor images and preview (F-ET04/07), SMTP provider picker (F-SM02), birthday audit link (F-ET10), assessment True/False helper (F-AC02).
- **Small UI parity**:
  - Session-expired message (A-A6)
  - Branch filter and bulk-import sample on Interview List (A-I1/I7)
  - Permission gates on Candidate Review, Interview List and Assessments (A-C1/I3/I5/AS1)
  - Notification promotion route (B-D31)
  - Sidebar avatar (B-D32)
  - Action-item paging (B-D20)
  - Celebration modal and cards (B-D26/D36)
  - In-app document preview (B-D49)
  - Expense list paging (E-EXP02)
  - WFH route guard (§2.B)
- **Test backlog**: no tests for My Requests, Holiday Calendar, Approval Rules, Carry Forward, Opening Balance Import, Referrals, Email Logs, Notifications, Employees list/create/edit, Branches CRUD, Face ID registration, Company, Departments, Employee Code, Roles, Email Templates, SMTP or Audit.
- **Deferred by the user**: payslip PDF/print (E-PAY24, 8 h).

---

## 4. Time required

| Scope | Hours | Approx. 1-dev working days (7 h/day) |
|---|---|---|
| P0 (mobile) | 2 | 0.3 |
| P1: mobile-only code | 53.5 | 7.6 |
| P1: tests and verification | 17 | 2.4 |
| P1: decision-gated (ID Card, Assets) | 35 | 5 |
| P1: admin payroll (if ported) | ≈ 78 | ≈ 11 |
| P2 total | ≈ 150 | ≈ 21 |
| **Full parity (all of the above, excluding device QA)** | **≈ 335** | **≈ 48** |

**Against the 2026-11-11 deadline (builds through 2026-11-10).**
- About 1.5 working days remain.
- Realistically that covers P0-1, P0-2 and a subset of the mobile-only P1 list. Suggested order: items 1–6 (≈ 12 h of small, high-value fixes), then 7–12 as time allows.
- **Full parity is not achievable by 11-11.**
- Report the release as "core employee, manager and HR flows at parity; admin payroll, assets, ID card and Platform Admin web-only for this release", pending product sign-off.

---

## 5. Backend and product blockers

1. **Face embeddings (P0, backend/product).**
   - Mobile uses 192-d embeddings and web uses 128-d; the backend has no length validation, and mixed registrations break matching.
   - Production also skips the server face check for `source='mobile'`.
2. **Admin payroll scope (product).**
   - Removed from mobile on 2026-07-27 because the screens were mocks; never formally declared web-only.
   - About 130 h to port all of it.
3. **Assets and ID Card scope (product).** No mobile code exists. ID Card printing needs a new dependency.
4. **Platform Admin (product).** Documented as web-only (separate auth). Confirm it stays out of the Play release.
5. **Dashboard separation counters (backend).** `/dashboard/system-admin/pending-approvals/` and `/dashboard/hr/action-queue/` hard-code `separation_requests: 0`. HR can work around it in mobile (B-D12); the admin counter cannot.
6. **Announcement branch scoping (backend).** Enforced only by the web client. Mobile can mirror it (B-D35), but the backend does not enforce it.
7. **Leave approval email templates (web mock).** `LeaveApprovalView` ignores `template_name` / `extra_context`. Do not port the leave template picker.
8. **Accrual / credit rules (backend).** No model or endpoints exist. Mobile's local preview must not be presented as real.
9. **Payslip PDF (backend).** `EmployeePayslip.payslip_pdf` is never written, so server-side "Download PDF" is dead on both platforms. Mobile PDF generation is deferred by the user.
10. **Reports (web mock).** A static "Coming soon" page; no backend.
11. **Unverified contracts (check before porting).**
    - Candidate bulk-import sample format parameter.
    - `EmailTemplatePreviewView` POST payload (web calls it incorrectly with GET).
    - Payroll salary-preview parameter.
12. **Web-side bugs found (report only; the web repo is read-only).**
    - Email-template attachment removal calls a non-existent route.
    - Template preview uses GET against a POST-only view.
    - The audit module filter uses `announcements` instead of `announcement`.
    - An `audit.view`-only user is redirected away from the audit page by `proxy.ts`.
    - The web policy-acknowledgement banner links to a page blocked without `documents.view`.
    - Web email-template lists are also capped at 20.

---

## 6. Verification notes and limitations

**Re-checked directly against code before inclusion.** Each P0 finding, and the P1 findings listed below, was re-checked against the source after the area review:

| Finding | Evidence |
|---|---|
| Candidate status email | `mark_candidate_sheet.dart:111` sends after the PATCH; backend status view sends selected/rejected |
| Interview email | `add_candidate_sheet.dart:152-159`, `_fire_interview_date_emails_if_needed` at views.py L560/L600 |
| Login validator | `login_form.dart` uses `FormValidators.password` (min length); `LoginSerializer` `min_length=1` |
| Email template paging | `settings_remote_datasource.dart:151` has no `page_size`; `EmailTemplateListCreateView` `default_page_size=20` |
| Audit paging | `audit_screen.dart:299` replaces the page |
| Company logo removal | No `remove_logo` in mobile |
| Employee code screen | Padding and sequence still editable |
| Role payload | `roles_model.dart:120-125` omits `can_manage_*` |
| Promotion history | No `promotions` endpoint call |
| HR attendance corrections | `reviewCorrection` used only in the Un-punches inbox |
| Admin birthday widget | No wish actions in `admin_dashboard_view.dart` |
| Profile custom fields | No field-config usage in `features/profile` |
| HR separation counter | `hr_dashboard_models.dart:76` reads the hard-coded 0 |
| Leave template | `template_name` absent from `hrms/views/leave.py` |

**Corrections made during verification.**
- **Branch edit.** A suspected geofence wipe on branch edit was ruled out: the backend applies branch PUT with `partial=True` (`branch/views.py:290`).
- **Role edit.** Mobile role PUT is non-partial, but `can_manage_*` are optional model booleans, so leaving them out keeps the existing values. This conclusion comes from DRF semantics and was **not run against a server**.

**Limitations.**
- No emulator, device or live-server testing was done for this audit. COMPLETE is code-level only.
- The `origin/production` ref was not fetched. Production commits after `95fc10a` (2026-10-30) are not covered. This is the same reference as the 2026-11-02 audit, so no new web functionality was found since then; the change since that audit is on the mobile side.
- Role-to-permission mappings are taken from the seeded permissions and `test/core/router/access_control_test.dart`. Tenant-customised roles may differ.
- Effort figures are estimates, not commitments.
- PII: no personal data, credentials or salary figures appear in this report.

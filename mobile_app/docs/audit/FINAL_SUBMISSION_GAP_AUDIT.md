# Royal HRMS Mobile — Final Web-to-Mobile Gap Audit (submission deadline 2026-11-14)

*Audit date: 2026-11-02. Read-only: no application, web or backend file was modified. The web reference is production `origin/production` = `95fc10a` (2026-10-30), read through `git show`. The web clone's working tree (local branch `fix/p0-04a-face-enforcement`, uncommitted P0-04A face work) is **not** production and was not used as reference. Mobile = the `mobile_app/` working tree, including uncommitted work.*

Status vocabulary:

| Status | Meaning |
|---|---|
| **Complete & verified** | Code-reviewed and covered by automated tests (no device test) |
| **Implemented, not device-verified** | Wired to real endpoints and reachable; never run on a phone |
| **Partial** | Some of the web behaviour |
| **Outdated** | Conflicts with the current backend or web |
| **Missing** | Not in mobile |
| **Blocked** | Needs a backend or product decision |
| **Excluded** | Intentionally web-only |

---

## Answers in brief

1. **What new functionality was added to web?** 221 production commits since 2026-08-13 (`18fad08..95fc10a`).
   - Multi-tenant company login.
   - Platform Admin.
   - Branch Admin role.
   - Work From Home, including medical proof and daily reports.
   - Self-service separation with notice-period countdown.
   - Org chart.
   - Assets and ID cards.
   - Monthly and custom leave.
   - One clock-in/one clock-out rule, shift assignments, GPS address labels, face-capture liveness and telemetry.
   - Payroll CTC components, payslip queries and salary-transfer confirmation.
   - Configurable onboarding.
   - Notification settings.
   - Announcements for everyone.
   - Policy acknowledgement and contact matrix (10-29).
   - Notice-period settings and import (10-29/30).
   - Document-center preview (10-30).

   Details: §2.
2. **What was already developed in mobile?** 27 feature modules wired to real endpoints, covering the core employee, HR and admin journeys. That work was committed on 2026-10-28 as `9ab90d65`. See §3.
3. **What has been completed since October 28?**
   - **Pushed:** P0-01 (forgot password sends `company_code`) and P0-02 (token-refresh deadlock), commit `b1825b48`.
   - **Uncommitted:** P1-01 (dashboard chosen by flags), P0-05 (forced password change) and P1-03 (`day_completed`).
   - **Tests:** 1 placeholder became **74 passing tests**.
   - See §1 and §5.
4. **What remains missing or outdated?** See §4. The ones that matter for a mobile user:
   - config-driven onboarding;
   - assessment gate and portal;
   - WFH daily report and medical proof;
   - payslip pagination;
   - mandatory-face handling for mobile punches;
   - the voice mic showing during a forced password change (new);
   - unfiltered quick-access tiles (new);
   - module-disabled messaging.

   Admin and configuration features (assets, ID card, monthly-leave admin, shift assignment, payroll run) are missing but deferrable.
5. **Where did mobile development stop?**
   - The two-month pause began after face-capture quality gating for voice clock-in, last edited **2026-08-27 11:57**.
   - Since resuming, the last code change was **2026-10-30 12:01** (P1-03, `attendance_models.dart`).
6. **What must be done before November 14?** The P0 list in §7:
   - commit and push the current work;
   - hide the voice mic during a forced password change;
   - decide how mobile behaves when face attendance is mandatory;
   - rebuild a signed release with a bumped version;
   - run a role-by-role device smoke test;
   - complete the Play Console data-safety, privacy-policy and reviewer-access setup.

   **Scope confirmed 2026-11-02: this submission is Google Play (Android) only; iOS is deferred.**
7. **What can safely be deferred?** The P2/P3 list in §7. Mostly admin screens and secondary features: manager dashboard, assets, ID card, global search, contact matrix, policy acknowledgement, monthly-leave admin, shift assignment, approvals for separation and payslip queries, and code-quality work.

---

## 1. Current git and project state (Task 1)

### 1.1 Repositories

| | Mobile (repository root `Royal-HRMS/`) | Web/backend (`web_frontend_backend/`, separate clone) |
|---|---|---|
| Branch | `mobile/p0-auth-fixes`, tracking `mobile/mobile/p0-auth-fixes` | `fix/p0-04a-face-enforcement` (local only) |
| HEAD | `b1825b48` (2026-10-28) P0-01 + P0-02 | `bf288fc` (2026-10-29) |
| Remote | personal repository `pramodkunja/royal_hrms_1`: `demo` = `9ab90d65`, `mobile/p0-auth-fixes` = `b1825b48`, **already pushed** | production upstream `95fc10a` (2026-10-30), 3 commits ahead of the local base |
| Staged | none | none |

### 1.2 Uncommitted mobile work (everything since `b1825b48`)

| Change | Modified (tracked) | New (untracked) | Last edit |
|---|---|---|---|
| P1-01 dashboard selection | `lib/features/dashboard/presentation/screens/home_screen.dart`, `lib/features/dashboard/presentation/widgets/quick_access.dart` | `test/features/dashboard/dashboard_category_test.dart` | 10-29 16:37 |
| P0-05 forced password change | `lib/core/router/app_router.dart`, `lib/features/auth/presentation/providers/auth_providers.dart`, `lib/features/auth/presentation/widgets/login_form.dart` | `lib/features/auth/presentation/screens/force_change_password_screen.dart`, `test/core/router/auth_redirect_test.dart`, `test/features/auth/force_change_password_flow_test.dart` | 10-30 11:44 |
| P1-03 day_completed | `lib/features/attendance/data/models/attendance_models.dart`, `lib/features/attendance/domain/entities/attendance_entity.dart`, `lib/features/attendance/presentation/providers/attendance_providers.dart`, `lib/features/attendance/presentation/screens/my_attendance_screen.dart`, `lib/features/dashboard/presentation/widgets/attendance_ring_card.dart` | `test/features/attendance/day_completed_test.dart` | 10-30 12:01 |

That's 10 modified files (+245/−78) and 5 untracked files. None of it is committed.

### 1.3 Other changes (left untouched)
- **Root repository, outside `mobile_app/`:**
  - 384 deletions of the old root `backend/`, `frontend/` and related files;
  - modified `.vscode/settings.json`;
  - untracked `.DS_Store`;
  - `web_frontend_backend/` showing as untracked.
- **Web clone:** uncommitted P0-04A backend face-enforcement work (9 attendance files, +180/−32). It isn't in production and is outside the mobile scope.

### 1.4 Quality gates (run 2026-11-02)

| Check | Result |
|---|---|
| `flutter test` | **74/74 pass** |
| `flutter analyze` | **13 issues**, all `curly_braces_in_flow_control_structures` infos, at exactly the 13 locations recorded on 10-28. **0 new.** |
| Last implementation date | Before the pause: 2026-08-27. Since resuming: **2026-10-30 12:01**. |

### 1.5 What differs from the October 28 audit

| Item | 2026-10-28 | Now |
|---|---|---|
| Mobile work since 08-13 | Uncommitted (169 paths) | Committed (`9ab90d65`) and pushed |
| Tests | 1 placeholder | 74 real tests |
| Forgot password | Broken (no `company_code`) | Fixed (P0-01, pushed) |
| Token-refresh deadlock | Present | Fixed (P0-02, pushed) |
| Branch Admin dashboard | Admin view with 403s | HR view by flags (P1-01, uncommitted) |
| Forced password change | Not enforced | Enforced (P0-05, uncommitted) |
| `day_completed` | Ignored | Handled (P1-03, uncommitted) |
| Web production | `d92cfac` | `95fc10a`, with 6 more commits: policy compliance, attendance export, notice period ×3, document center |
| New gaps found this round | — | Voice mic during forced change; unfiltered quick tiles; leave preview key rename; no route permission guards |

---

## 2. Web changes since August 13, grouped (Task 2)

**Audience key:** **S** = employee self-service, **M** = manager, **HR** = HR/Branch Admin, **A** = admin/configuration, **P** = platform admin only.

**Mobile key:** ✅ implemented · ◐ partial · ✗ missing · — not applicable to mobile.

### Authentication and company login

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Company code required at login; tenant resolved from the access-token cookie (08-17/19) | `POST /api/login/` `{company_code,email,password}`; response adds `company_code`, `company_name` | S | ✅ |
| Forgot password, OTP and reset require `company_code`; unknown code returns 404 | `POST /api/forgot-password/`, `/verify-otp/`, `/reset-password/` | S | ✅ (P0-01) |
| Forced password change enforced in the client; server ends the session after the change | `POST /api/change-password/`; login field `must_change_password` | S | ✅ (P0-05, uncommitted) |
| Login and OTP rate limits keyed by IP + company | — | S | ✅ (server messages shown) |
| Platform Admin login and panel; System Admin email change and password reset | `/api/platform-admin/*` | P | — Excluded |

### Dashboards and roles

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Dashboard chosen by flags: `is_superuser` (includes `settings.edit`) → Admin, `can_manage_team` → Manager, `employees.view` → HR | login flags | all | ✅ (P1-01, uncommitted) |
| HR and Branch Admin roles lost `settings.edit` (so they're no longer treated as admin); managers lost `recruitment.*` and `payroll.view` and gained `can_manage_team` | role data | — | ✅ compatible with P1-01 |
| Branch Admin role (`can_manage_branch`): branch-scoped, skips assessments, can edit the approval matrix | flags | HR | ◐ flag parsed, no Branch Admin-specific behaviour |
| Manager dashboard | `GET /api/dashboard/manager/` | M | ✗ generic fallback |
| Employee notice-period countdown card | `GET /api/dashboard/employee/notice-period/` | S | ✗ (shown in separation detail only) |
| Dashboards blocked until onboarding and assigned assessments are complete | `/api/dashboard/employee/*` | S | ✗ no assessment gate |

### Attendance and face verification

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| One clock-in and one clock-out per day; `day_completed` in today/punch responses | `POST /api/attendance/punch/`, `GET /today/` | S | ✅ (P1-03, uncommitted) |
| WFH-mode punch requires an approved WFH request and GPS within about 200 m of its location | punch | S | ✅ server message shown |
| Readable punch addresses; GPS accuracy warnings | `punches[].location` | S/HR | ✅ shown as text |
| Face clock-in: liveness, attempt limit, replay detection, telemetry | `face-registration/*`, `face-capture-telemetry/` | S/HR | ◐ capture exists; **production skips the face check for `source='mobile'`**, and the 192-value mobile scan can't be compared with web's 128-value one |
| Shift assignments (SGT/ICT, UK shift skips the distance check) | `/api/attendance/shift-assignments/*` | HR | ✗ |
| Weekly-off assignments | `/api/attendance/weekly-off-assignments/*` | HR | ✗ (company-level policy only) |
| Attendance import (single employee, dry run) and export by date range | `/api/attendance/import/`, `/export/` | HR | ◐ older import/export |
| Policy rules (10-29): missing clock-out → half day or absent; early-leave allowance; late-mark allowance; WFH report affects status | server-side | S sees results | ✅ display only (statuses come from the server) |

### Leave and approvals

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Custom leave types usable on apply (e.g. menstrual leave) | `/api/leave/policy/`, apply | S | ✅ types loaded dynamically |
| Monthly leave: entitlement checks, month-end expiry, monthly statements | `/api/leave/monthly-credits/*`, balance | S/HR | ◐ server checks apply; **monthly admin missing** |
| Long-leave notice, WFH overlap and monthly-entitlement errors on apply; approval can return 409 | apply / approve | S/M | ✅ server message shown |
| **Leave preview renamed `earned_leave_used` → `leave_days_used`** (08-23) | `?action=preview` | S | **Outdated**: mobile reads the old key (`leave_models.dart:409`) but never displays it, so low impact |
| Leave credit adjust/reverse (manager for direct reports, HR) | `/api/leave/credits/<id>/…` | M/HR | ✗ |
| Approvals hub adds WFH, Payslip Requests and Separation tabs; bulk actions | various | M/HR | ◐ leave, expense, correction and WFH only |

### Payroll and payslips

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| My payslips list (paged, 20 per page by default) and acknowledge | `/api/payroll/my-payslips/` | S | **Outdated**: no paging, so only 20 show |
| Raise or view a payslip query | `GET/POST /api/payroll/queries/?mine=1` | S | ✗ |
| Payroll run, CTC components, salary transfer, ECR/ESIC, analytics, ₹0 block | `/api/payroll/*` | A | — Excluded (removed from mobile 07-27) |

### Work From Home

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Request with GPS location, saved locations, cancel | `/api/wfh/requests/`, `/saved-locations/` | S | ✅ |
| **Medical proof** (`is_medical` + PDF/JPG/PNG up to 5 MB, required when medical) | `POST /api/wfh/requests/` (multipart) | S | ✗ (optional field, defaults to false, so not breaking) |
| **Daily work report**, reviewed by the manager as full day, half day or not accepted; **a missing or rejected report changes attendance** | `/api/wfh/reports/` | S/M | ✗ |
| Approve/reject at L1/L2 (`wfh.approve`) | `/api/wfh/requests/<id>/approve/` | M | ✅ (Approvals) |

### Separation

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Self-service resignation, workflow stages, KT tasks, clearances, documents, activity | `/api/separation/*` | S/M/HR | ✅ |
| Notice period assigned by HR replaces the employee's input; response adds `expected_last_working_day`, `days_remaining`, `notice_status` | create/detail | S | ✅ shown in detail (`separation_detail_screen.dart:207`) |
| Notice-period settings and import | `/api/accounts/…notice-period…` | A | ✗ (admin) |

### Employee management and onboarding

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| **Configurable onboarding fields, document types and custom file fields** | `/api/onboarding/field-config/`, `/document-type-config/`, `/custom-file-fields/` | S (new hires) | **✗ Missing**: the wizard is hardcoded |
| Onboarding requires a face registration when face attendance is mandatory | `accounts/views.py` onboarding submit | S | ◐ wizard has a Face ID step, but the 192-value scan is incompatible with web |
| My Profile shows reporting manager, approver, branch HR and `notice_period_days` | `GET /api/employees/me/` | S | ✗ not shown on My Profile |
| New employee-ID format (prefix + DDMM + initials); existing IDs can be rewritten | — | all | ✅ display only |
| Employee detail tabs: promotions, reset password, ID card, assets, salary | `/api/employees/<id>/…` | HR | ◐ promotions are session-only; others missing |
| HR edits refuse name/phone/joining-date changes after onboarding (409) | employee PATCH | HR | ✅ message shown |

### Recruitment

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Permission and scope fixes; onboarding email on bulk import | `/api/recruitment/*` | HR | ✅ interview list and candidate review (document "View" button does nothing) |
| HR decision on a candidate | `/api/recruitment/candidates/<id>/hr-decision/` | HR | ✗ |
| Candidate assessment portal | `/api/assessments/my/`, `/respond/`, `/complete/`, `/retry/` | S (candidates/new hires) | **✗ Missing** |

### Assets and ID cards

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Asset CRUD, bulk assign, current holder | `/api/assets/*` (`assets.*`) | A/HR | ✗ |
| My assets | `GET /api/assets/employees/<uuid>/` | S | ✗ |
| ID card settings and print preview | `/api/settings/id-card/`, `/api/employees/<id>/id-card/` | A/HR | ✗ (print-oriented) |

### Settings and configuration

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Onboarding fields and document types | `/api/settings/onboarding-fields/` | A | ✅ |
| Notification settings | `/api/notifications/settings/` | S | ✅ |
| Attendance policy rules (10-29) | attendance settings | A | ◐ older Attendance Rules screen |
| Monthly leave, carry forward, credit rules | leave policy | A | ◐ Credit Rules screen is local mock data |
| Branch Admin assignment/reassignment and geofence editing | `/api/branch/branches/<id>/reassign-admin/`, `/geofencing/` | A | ✗ |
| Module switches per company (403 "<Module> is not enabled for your company") | `apps/tenants/feature_gate.py` | all | ◐ generic error shown |

### Notifications and announcements

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Announcements page for all users; targeting by branch and department; full view | `/api/announcements/` | S | **Outdated**: mobile menu requires `announcements.view` (`nav_config.dart:45`) |
| Announcement emails as HTML | server | — | — |
| Notification bell plus WebSocket | `/api/notifications/*`, `ws/notifications/` | S | ◐ REST only, no live updates |

### Organisation chart, Voice and Other

| Change | Endpoints / permission | Audience | Mobile |
|---|---|---|---|
| Org chart grouped by branch (own branch unless `settings.edit`) | `GET /api/org-chart/` | S | ✅ |
| Voice: chat view, quick chips, Hindi speech, server TTS, face-proof clock-in, approve/reject corrections by voice | `/api/voice/parse/`, `/speak/`, `/transcribe-fallback/` | S/M | ✅ not device-verified. The web team noted a speech-provider (Sarvam) credit outage on 08-31. |
| Policy acknowledgement (10-29) | `GET /api/documents/pending-acknowledgements/`, `POST /api/documents/<id>/acknowledge/` `{version}` (409 when out of date) | S | ✗ |
| Contact matrix (10-29) | `GET /api/company-contacts/` | S | ✗ |
| Document-center preview with company context (10-30); signed, short-lived document links | `/api/documents/…` | S/HR | ◐ opens externally; links aren't cached, so expiry is fine |
| Reports | — | — | Placeholder on both web and mobile |

---

## 3. What mobile users can actually reach (Task 3)

These are reachable and wired to real endpoints, but **none has been device-verified**:
- auth (login, forgot password, forced change);
- employee, HR and admin dashboards;
- My Attendance and HR attendance;
- leave;
- WFH requests;
- expenses;
- approvals (4 kinds);
- separation;
- My Requests;
- profile (including photo and Face ID);
- notifications and notification settings;
- announcements (permission-gated);
- documents;
- org chart;
- employees and employee detail;
- branches;
- interview list;
- candidate review;
- email log;
- referrals;
- assessments (HR management);
- Face ID registrations (HR);
- settings (16 screens);
- voice assistant.

**Problems that cut across the app:**

| Problem | Evidence | Impact |
|---|---|---|
| **No permission guards on routes.** Any `/dashboard/*` or `/settings/*` path opens for any signed-in user, and the screen then gets a 403 from the server. | `lib/core/router/app_router.dart` `resolveAuthRedirect` only handles signed-out, forced-change and onboarding states | Low for a menu-driven app; deep links show error screens |
| **Quick-access tiles ignore `permission`.** Every tile in a category shows. | `QuickItem.permission` declared at `lib/features/dashboard/presentation/widgets/quick_access.dart:74` and never read | Employees see tiles (e.g. Expenses, Documents) that end in 403 |
| **Menu still uses role names in two places** | `nav_config.dart:59` (Attendance hidden for `employee`), `:72` (Approvals hidden for `hr`/`hr_admin`, and `payroll.view` missing, so HR can't reach the Attendance Approval tab from the menu) | Some roles can't reach features they're allowed |
| **Role-name checks inside screens** | `leave_screen.dart:84,89`; leave analytics, approvals and dashboard tabs; `financial_year_section.dart:31`; `add_candidate_sheet.dart:88`; `add_employee_sheet.dart:64` | Branch-filter and approval behaviour differ for custom or renamed roles |
| **Create buttons not gated** | Announcements, Documents, Branches, Assessments | 403 on submit |
| **Reachable placeholders** | Reports (`PlaceholderScreen`, `reports.view`); Employee Benefit tab (`employee_profile_screen.dart:224`) | Cosmetic |
| **Orphaned code** | `dashboard_screen.dart`; Leave Credit Rules mock (`leave_credit_rules_screen.dart:337`) | None |
| **Face ID search hides errors** | `face_id_registrations_screen.dart:57-67` (a 403 or network error shows "No employees match") | Misleading for HR |
| **Debug features in release** | None. The LAN IP is debug-only (`api_config.dart:29,58`); logging is debug-only; cleartext only in the debug manifest; debug banner off (`app.dart:31`). | — |

---

## 4. Parity matrix (Task 4)

Effort: S is under half a day, M is 1–2 days, L is 3 or more days. All "mobile files" paths are under `mobile_app/lib/`.

| Feature | Web behaviour | Mobile implementation | Status | Evidence / files | User impact | Priority | Effort |
|---|---|---|---|---|---|---|---|
| Company login | Company code + email + password | Same | Implemented, not device-verified | `features/auth/data/models/login_request_model.dart` | Everyone | — | — |
| Forgot password and refresh | Company code at all 3 steps; refresh in a queue | Same; deadlock fixed | **Complete & verified** (tests) | `forgot_password_models.dart:12,26,43`; `core/network/auth_interceptor.dart`; 26 tests | Everyone | — | — |
| Forced password change | Client redirect; session ends after change | Router gate, screen, login pre-fill | **Complete & verified** (uncommitted) | `core/router/app_router.dart` `resolveAuthRedirect`; `force_change_password_screen.dart`; 23 tests | New and reset accounts | P0 commit | — |
| **Voice mic during forced change (new)** | Web blocks the whole UI | Mic overlay still visible and usable | **Outdated (new gap)** | `features/voice_commands/presentation/widgets/voice_mic_overlay.dart:61-66` (only checks onboarding) | Can clock in by voice before changing a temporary password; the backend doesn't block it | **P0** | S |
| Role and permission handling | Flags and permissions | Dashboard by flags; menu mostly by permission; tiles unfiltered; role names in places | Partial | §3 | Wrong tiles, 403s | P1 (tiles) / P2 (rest) | S / M |
| Branch Admin | HR dashboard, branch-scoped, approval matrix | HR dashboard via P1-01; `canManageBranch` unused | Partial | `quick_access.dart` resolver; `user_entity.dart:16` | Works for daily use | P2 | M |
| Dashboard selection | Flags in order | Same | **Complete & verified** (uncommitted) | 9 tests | All roles | P0 commit | — |
| Manager dashboard | `/dashboard/manager/` | Generic fallback | Missing | `home_screen.dart:28-47` | Managers see a basic dashboard | P2 | M |
| Attendance completion | `day_completed` disables punch | Same on both widgets | **Complete & verified** (uncommitted) | 15 tests | All | P0 commit | — |
| Clock in/out, geofence, WFH punch | Server rules | Pre-checks; server messages shown | Implemented, not device-verified | `attendance_ring_card.dart`, `my_attendance_screen.dart` | All | P0 device test | — |
| Face registration and mandatory face verification | Verified for web and voice; 128-value scans | 192-value scan; plain mobile punches **not face-checked by production** | **Blocked** (product or backend decision; P0-04A backend is uncommitted and not deployed) | `attendance_remote_datasource.dart:47`; `face_embedding_model_io.dart` | Companies with mandatory face: mobile clock-in skips verification | **P0 decision** | S (mobile-only fallback) |
| Voice attendance | Voice clock-in with face proof | Implemented | Implemented, not device-verified | `voice_command_controller.dart` | Optional | P1 device test | — |
| Leave apply, balances, cancel | Custom/monthly types, new 400s | Dynamic types; server messages | Implemented, not device-verified | `features/leave/**` | All | — | — |
| Leave preview `leave_days_used` | Renamed key | Reads old key; not displayed | Outdated (low impact) | `leave_models.dart:409` | None visible | P3 | S |
| Monthly leave admin, credit adjust | HR tools | — | Missing | — | HR uses web | P2 | M |
| Approvals | 6 kinds plus bulk | 4 kinds | Partial | `approvals_providers.dart:29` | Separation and payslip queries handled on web | P2 | M |
| WFH request | GPS, saved locations, medical proof | Without medical proof | Partial | `features/wfh/**` | Medical WFH needs web | P1 | S–M |
| **WFH daily report** | Employee submits; manager reviews; affects attendance | — | **Missing** | — | **A WFH employee without a report gets marked absent or half day** where the policy is on | **P1** | M |
| Separation and notice period | Self-service, countdown | Full workflow; countdown in detail | Implemented, not device-verified | `separation_detail_screen.dart:207` | — | P2 (dashboard card) | S |
| My Payslips | Paged, acknowledge, queries | First page only; acknowledge | **Outdated** | `payroll_remote_datasource.dart:16-25` | Over 20 payslips → older ones hidden | **P1** | S |
| Payslip queries | Raise and history | — | Missing | — | Web only | P2 | M |
| Config-driven onboarding | Fields and document types per company | Hardcoded 5 steps, `kDocTypes` | **Outdated** | `onboarding_datasource.dart:12-76`; `onboarding_steps.dart:958` | New hires at companies with custom required fields may not be able to submit | **P1** (verify or fallback) / P2 (full port) | S fallback / L full |
| Assessment gate and candidate portal | Redirect to the portal while pending | `assessmentStatus` unused; no portal | **Missing** | `user_entity.dart` | Pending-assessment users get 403s on the employee dashboard | **P1** (gate + "use web" screen) / P2 (portal) | S / L |
| My Profile work info and notice period | Manager, approver, HR, notice days | Not on My Profile (HR view has them) | Partial | `features/profile/**` | Informational | P2 | S |
| Announcements permissions | Everyone reads | Menu needs `announcements.view` | Outdated | `nav_config.dart:45` | Some employees can't see announcements | P1 | S |
| Module-disabled handling | 403 per module | Generic `ForbiddenException` with the server message | Partial | `core/network/api_client.dart:147-160` | Message understandable; menu still shows the module | P1 | S–M |
| Assets and ID card | Admin + my assets + print | — | Missing | — | Web only | P2 | M–L |
| Global search | Employee search in the top bar | — | Missing | `dashboard/presentation/widgets/app_top_bar.dart` | Convenience | P3 | S |
| Policy acknowledgement | Pending docs, acknowledge | — | Missing | — | Compliance; companies may expect it | P2 | M |
| Contact matrix | Everyone sees contacts | — | Missing | — | Informational | P2 | S |
| Document preview | In-app preview | Opens externally | Partial | `document_detail_dialog.dart:259` | Acceptable on mobile | P3 | — |
| Org chart | Branch-scoped | Implemented | Implemented, not device-verified | `features/org_chart/**` | — | — | — |
| Notifications | Bell + WebSocket + settings | REST + settings | Partial | `features/notifications/**` | No live updates | P3 | M |
| Shift and weekly-off assignment | HR | — | Missing | — | Web only | P2 | M |
| Branch Admin reassignment and geofence editing | Admin | — | Missing | — | Web only | P3 | M |
| Payroll admin, Platform Admin | Admin | — | Excluded | commit `e558822` | Web only | — | — |
| Reports | Coming soon | Placeholder | Parity | `placeholder_screen.dart` | — | — | — |
| iOS app | — | Template bundle ID, no camera description | Excluded for this submission (Android only) | §6 | iOS only | Deferred | S + Apple account |

---

## 5. Review of the latest mobile fixes (Task 5)

| Fix | State | Code | Tests (run 11-02) |
|---|---|---|---|
| P0-01 forgot password | Committed and pushed (`b1825b48`) | `company_code` in all 3 request models; screen pre-filled from login | 12 flow + 3 form, pass |
| P0-02 token refresh | Committed and pushed | Shared refresh future; tagged retry; a 401 on retry ends the session | 11, pass |
| P1-01 dashboard selection | Uncommitted | `resolveDashboardCategory` in `quick_access.dart:29`; 2 call sites | 9, pass |
| P0-05 forced password change | Uncommitted | `resolveAuthRedirect`; `/change-password`; screen; `loginPrefillProvider` | 12 router + 11 flow, pass |
| P1-03 day_completed | Uncommitted | Model/entity field; notifier guard; both clock widgets | 15, pass |

**How the fixes interact**
- **Regression found: P0-05 × voice.** `VoiceMicOverlay` is mounted globally (`app/app.dart:50`) and hides only for onboarding states (`voice_mic_overlay.dart:61-66`). So it **shows on the forced change-password screen**, and the backend doesn't enforce the flag, which means voice commands, including clock in/out, still work. Fix: also hide it when `mustChangePassword` (and for consistency `onboardingRejected`) is set. That's a P0, around an hour including a test.
- **P0-05 × P0-02, no issue.** After a successful change the server blacklists the refresh token. The app logs out straight away; the 401 from `/logout/` is excluded from refresh and ignored.
- **P0-05 × P0-01, consistent.** A successful password reset also clears `must_change_password` on the server (`accounts/views.py:865`).
- **P1-01 × backend role changes, consistent.** HR and Branch Admin no longer hold `settings.edit`, so both land on the HR dashboard, as on web.
- **P1-03 × voice, acceptable.** Voice clock-in doesn't read `dayCompleted`; on a completed day the server rejects it with its message.
- **Overlapping files:** P1-01 and P1-03 both touch the dashboard folder, but different files (`quick_access.dart`/`home_screen.dart` vs `attendance_ring_card.dart`). P0-05 is the only change to `app_router.dart`.

---

## 6. Submission readiness (Task 6)

### Confirmed facts

| Item | Finding | Evidence |
|---|---|---|
| Android application ID | `com.royalhrms.app` | `android/app/build.gradle.kts:36` |
| Version | `1.0.0+5`; a release bundle with versionCode 5 was built 10-27. **If it was uploaded to Play, the next upload needs versionCode ≥ 6.** | `pubspec.yaml`, `android/local.properties` |
| SDK levels | Flutter 3.44.8 defaults: compileSdk 36, **targetSdk 36**, minSdk 24 | Flutter Gradle plugin |
| 16 KB page size | **All 8 native libraries in the 10-27 bundle have 16 KB-aligned LOAD segments** (0x4000 or 0x10000) | `llvm-readelf` on `app-release.aab` |
| Release signing | `key.properties` is present on this machine (not read). **If it's missing, the release build silently falls back to debug signing.** | `build.gradle.kts:45-62` |
| Android permissions | INTERNET, fine/coarse location, RECORD_AUDIO; CAMERA comes from the camera plugin | `AndroidManifest.xml:4-9` |
| Android backup | `allowBackup` not set (defaults to on), so the cookie files are backed up | manifest |
| Icon and splash | Android launcher icon (Royal emblem, adaptive) and native splash generated | `assets/icon/`, `pubspec.yaml` |
| API base URL | Release builds always use `https://royalhrms.com/api/`; the LAN IP is debug-only | `lib/core/config/api_config.dart:20-29,58-59` |
| Debug-only features in release | None found | §3 |
| Session restoration | Cookie jar plus the cached user; the forced-change gate is enforced on restore | `main.dart`, P0-05 tests |
| Network errors | Typed errors; "No internet" overlay; refresh doesn't log out on network failure | `core/network/api_client.dart`, `app.dart` |
| iOS | **Bundle ID `com.example.mobileApp` (template), no development team, no `NSCameraUsageDescription`, icon generator set to `ios: false`** | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `pubspec.yaml` |

### Confirmed blockers
1. **Uncommitted work:** P1-01, P0-05 and P1-03 aren't committed or pushed.
2. **Stale release bundle:** the 10-27 bundle predates every fix since; it must be rebuilt.
3. **Voice mic during forced password change:** see §5.
4. ~~iOS~~: **out of scope for this submission (Android only, confirmed 2026-11-02).** It still has the template bundle ID, no camera usage description (the app crashes on first camera use) and no development team; fix all three before any later App Store release.

### Unverified risks
- **No device testing yet:** nothing since 08-13 has been tested on a phone. That includes camera, ML Kit, TFLite face capture, speech-to-text and Hindi fallback, server TTS, geofence and GPS, the cookie session across app restarts, and the double-slash base URL against the real production server.
- **Play Console requirements (not checkable from code):**
  - privacy policy URL;
  - Data safety form: location, camera with face-biometric embeddings sent to the server, microphone with voice audio sent to a third-party speech service, contact info, employee data;
  - **App access instructions with a demo company code and test account**, without which review can be rejected;
  - content rating;
  - target audience.
- **Companies with mandatory face attendance:** mobile punches aren't face-verified by production. That's a compliance risk if those companies rely on face attendance.
- **The release key** must be available on whichever machine builds the release.
- **Speech provider (Sarvam) credits outage** (web team notes, 08-31) may affect voice features.

---

## 7. Deadline roadmap (Task 7): 2026-11-03 → 2026-11-14

That's about 9 working days. The plan prioritises the journeys real users take daily on a phone (clock in/out, leave, WFH, approvals, payslips, profile, separation) over porting all 81 new endpoints.

### P0: must do before submission

| # | Task | Web reference | Mobile files | Backend dependency | Estimate | Verification | Deferrable? |
|---|---|---|---|---|---|---|---|
| P0-1 | Commit and push P1-01, P0-05 and P1-03, staging the 15 files by explicit path | — | §1.2 list | none | 0.5 h | `git status` clean for `mobile_app/`; remote branch updated | No |
| P0-2 | Hide the voice mic while `mustChangePassword` (and `onboardingRejected`) is set; add a test | web blocks all UI on `/change-password` | `features/voice_commands/presentation/widgets/voice_mic_overlay.dart` | none | 1–2 h | Widget test: overlay absent for a flagged user; full suite | No |
| P0-3 | **Decide mandatory-face behaviour for mobile.** Recommended mobile-only fallback: when `faceVerificationStatus.isMandatory`, don't show a face scan the server ignores; show "Face ID clock-in is available on the web app", or accept the current unverified behaviour knowingly | `hooks/useClockWidget.ts`; backend `services_face_matching.py:207` (production) | `attendance_ring_card.dart`, `my_attendance_screen.dart`, voice face-proof path | Long-term fix needs a backend change (P0-04A, not deployed) | 0.5 day + decision | Tests for the mandatory and optional cases | Decision: no. Fix: yes, if face attendance is off for all target companies |
| P0-4 | Release build hygiene: bump versionCode to 6 (if 5 was uploaded); make Gradle fail when `key.properties` is missing; rebuild the signed bundle; re-check 16 KB alignment | — | `pubspec.yaml`, `android/app/build.gradle.kts` | none | 2–3 h | `flutter build appbundle --release` succeeds; signature check; `llvm-readelf` alignment | No |
| P0-5 | **Device smoke test by role** (employee, manager, HR, Branch Admin, system admin) on at least two Android devices. Cover: company login, forgot password, forced change, clock in/out (office and WFH, geofence pass and fail), day completed, leave apply/cancel, WFH request, approvals, payslips, profile and photo, separation, notifications, logout, restart with session restore, airplane mode. Write results to `docs/audit/DEVICE_TEST_LOG.md` | all | — | Test company and accounts on production or staging | 1.5–2 days | Pass/fail log; issues triaged into P0/P1 | No |
| P0-6 | Play Console setup: privacy policy, data safety (location, camera/biometrics, microphone and voice to a third party), reviewer access (demo company code and account), content rating, store listing | — | none (console) | Company decision; reviewer account | 0.5 day | Console has no warnings | No |
| P0-7 | **Deferred: Android-only submission (confirmed 2026-11-02).** For a later App Store release: iOS bundle ID, development team, `NSCameraUsageDescription`, iOS icons (`flutter_launcher_icons ios: true`), archive and TestFlight | — | `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `pubspec.yaml` | Apple developer account | 0.5–1 day | Archive validates; camera opens on device | Yes, if Android-only |

### P1: core functionality, strongly recommended

| # | Task | Web reference | Mobile files | Backend dependency | Estimate | Verification | Deferrable? |
|---|---|---|---|---|---|---|---|
| P1-1 | My Payslips paging (`page_size=100` or loop over `total_pages`) | `my-payslip/page.tsx` | `features/payroll/data/datasources/payroll_remote_datasource.dart` | none | 1–2 h | Test with a two-page fake | Risky: users with more than 20 payslips |
| P1-2 | Filter quick-access tiles by `QuickItem.permission` | — | `features/dashboard/presentation/widgets/quick_access.dart` | none | 1–2 h | Widget test per role | Yes, but users hit 403s |
| P1-3 | Announcements open to everyone; Approvals menu: drop the role-name exclusion and add `payroll.view` as web does | `lib/navConfig.ts` | `features/dashboard/presentation/navigation/nav_config.dart` | none | 1–2 h | buildNav unit tests per role | Yes |
| P1-4 | **WFH daily report**: submit and history (employee); manager review if time allows | `work-from-home/_components/WfhDailyReports.tsx` | `features/wfh/**` | none (`/api/wfh/reports/` exists) | 1–1.5 days | Datasource + widget tests; device test | Only if no target company uses the WFH-report policy |
| P1-5 | WFH medical proof (`is_medical` + file up to 5 MB, multipart) | `RequestWfhForm.tsx` | `features/wfh/**` | none | 0.5 day | Request body test | Yes (optional field) |
| P1-6 | Assessment gate: route users with a pending `assessmentStatus` (excluding managers, Branch Admins and superusers) to a "Complete your assessment on the web" screen | `app/onboarding/assessments`, `proxy.ts` | `core/router/app_router.dart` `resolveAuthRedirect`, new screen | none | 0.5 day | Redirect matrix tests | Not if candidates use mobile |
| P1-7 | Onboarding config check: fetch `/onboarding/field-config/` and `/document-type-config/`. If the company requires fields or documents the hardcoded wizard can't collect, show "Complete onboarding on the web" instead of failing at submit | `app/onboarding/page.tsx` | `features/onboarding/**` | none | 0.5–1 day | Tests with default and custom configs | Not if new hires onboard on mobile |
| P1-8 | Module-disabled handling: recognise "is not enabled for your company" 403s and show a friendly empty state (a menu-hiding API doesn't exist) | `apps/tenants/feature_gate.py` | `core/network/api_client.dart`, shared error widget | none | 0.5 day | `parseDioException` tests | Yes (the message already shows) |
| P1-9 | Device-test voice clock-in and face capture; fix device-specific issues | — | `features/voice_commands/**`, `features/facial_recognition/**` | Speech provider credits | 0.5–1 day | Device log | Yes, if voice and face are hidden |

### P2: important, can wait until after submission

- Manager dashboard (`/dashboard/manager/`).
- Approvals for separation and payslip queries, plus bulk actions.
- Payslip query raise and history.
- My Profile work info and notice period; dashboard notice-period card.
- Policy acknowledgement.
- Contact matrix.
- My assets.
- Full config-driven onboarding wizard.
- Full candidate assessment portal.
- Remove role-name checks inside leave, financial-year and add-candidate/employee screens.
- Gate create buttons by permission.
- Route-level permission guards.
- Monthly-leave admin; credit adjust/reverse.
- Shift and weekly-off assignment.
- Branch Admin-specific behaviour.
- Candidate HR decision and the document "View" button.
- `allowBackup=false` and moving the cookie jar out of backed-up storage.

### P3: optional polish

- Fix the leave preview key (`leave_days_used`).
- Global search.
- Notifications over WebSocket.
- In-app document preview.
- The 13 analyzer infos.
- Splitting large files (`attendance_screen.dart`, 3,525 lines).
- Bundling fonts.
- Moving the environment setting to `--dart-define`.
- Removing dead code (`dashboard_screen.dart`, the Credit Rules mock, unused constants).
- Making the Face ID search show errors.

### Suggested schedule

| Dates | Work |
|---|---|
| Nov 3 | P0-1, P0-2, P0-3 decision and implementation, P1-1, P1-2, P1-3 |
| Nov 4–5 | P1-4, P1-5 (WFH), P1-6 (assessment gate), P1-7 (onboarding config check) |
| Nov 6 | P1-8; P0-4 release build #1; internal testing track upload |
| Nov 7–10 | P0-5 device smoke test by role; P1-9; fix found issues |
| Nov 11 | P0-6 Play Console |
| Nov 12 | Release build #2 (final); regression run; sign-off |
| Nov 13–14 | Buffer for review feedback and last fixes |

---

## Appendix: sources

- Web production: `git show origin/production:<path>` at `95fc10a`; range `18fad08..95fc10a` (221 commits).
- Verified directly this round:
  - leave preview key (`hrms/views/leave.py:873` vs `leave_models.dart:409`);
  - WFH `is_medical` default (`hrms/models.py:782`) and medical-proof validation (`hrms/serializers.py:579`);
  - unfiltered quick tiles (`quick_access.dart:74`);
  - voice overlay eligibility (`voice_mic_overlay.dart:61-66`, `app.dart:50`);
  - native-library alignment (`app-release.aab`);
  - Flutter SDK defaults;
  - Android and iOS configuration;
  - git state;
  - tests and analyzer.
- Earlier audit documents in this folder (`AUDIT_SUMMARY.md`, `WEB_MOBILE_PARITY.md`, `API_COMPATIBILITY.md`, `IMPLEMENTATION_ROADMAP.md`, 2026-10-28) are now partly superseded by this report, as described in §1.5.

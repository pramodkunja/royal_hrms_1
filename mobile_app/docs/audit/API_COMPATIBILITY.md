# API Compatibility — Mobile ↔ Django Backend

*Audit date: 2026-10-28. Paths below are relative to `/api`. Backend paths are relative to `web_frontend_backend/backend/`, mobile paths to `mobile_app/lib/`. Secrets and `.env` values are deliberately omitted.*

## 1. Backend facts that govern every mobile call

| Topic | Verified behaviour | Evidence |
|---|---|---|
| Stack | Django 5.1.15, DRF 3.15, django-tenants 3.7 (schema-per-company, PostgreSQL), simplejwt 5.3, Channels/Daphne (WebSocket notifications), Celery + Redis, Cloudinary storage | `requirements.txt`, `config/settings.py` |
| URLconf | Single `ROOT_URLCONF='config.urls'` with no separate public URLconf. The tenant is resolved by middleware, not by host or subdomain. | `config/urls.py`, `apps/tenants/middleware.py` |
| Login | `POST /login/` `{company_code, email, password}` → `{success, message, data: {user: {...}}}`. The user object includes `permissions[]`, `must_change_password`, `onboarding_status`, `assessment_status`, `can_manage_team`, `can_manage_branch`, `is_superuser`, `company_code`, `company_name`. | `apps/accounts/serializers.py:144`, `apps/accounts/views.py:584-604` |
| Token transport | **Cookies only**: `royal_access_token` (900 s) and `royal_refresh_token` (7 d), httpOnly, `SameSite=Lax`, `Secure` when `DEBUG=False`. **No tokens in the response body.** | `apps/accounts/views.py:606-613` |
| Refresh | `POST /token/refresh/` reads the refresh cookie first, then the `refresh` field in the body. It rotates the refresh token and blacklists the old one, returns `data={}`, and sets new cookies. | `apps/accounts/views.py:~650-689` |
| Tenant resolution | Read from the `company_schema` claim of the **access-token cookie only**. A Bearer-only request stays on the `public` schema and gets a 401. | `apps/tenants/middleware.py:56-66` |
| Module gating | Returns 403 `"<Module> is not enabled for your company"` for attendance, face attendance, leave, expenses, separation, payroll, voice, assessments, recruitment and announcements when the tenant lacks that module | `apps/tenants/feature_gate.py` |
| CSRF | Not enforced for API views, because the cookie-JWT auth class is not SessionAuthentication | `apps/accounts/authentication.py` |
| Throttles | login 20/h, forgot-password 5/h, OTP 10/h, user 3000/h | `config/settings.py` |
| Pagination | Default `page_size` 20 with an override of up to 100 on most list views. Responses are `{count, total_pages, results, ...}` inside the `data` envelope or at the top level, depending on the view. | `core/pagination.py` |

## 2. Summary of the mobile contract check (281 call sites)

| Classification | Count |
|---|---|
| OK: path, method, and the spot-checked payload/response all compatible | 278 |
| Path missing (404) | 0 |
| Method not allowed (405) | 0 |
| **Payload mismatch (breaking)** | **3**: the forgot-password flow |
| Response-shape mismatch (soft, non-breaking today) | 2: token-in-body expectation, payslip pagination |

How the check was done:
- **Paths and methods:** all 281 calls (every one built from `ApiConstants`) were resolved automatically against backend URL patterns, path converters, and each view's allowed HTTP methods.
- **Payloads and responses:** request and response keys were compared by hand for the high-traffic flows listed in §4. Lower-traffic calls were checked for **path and method only**, so they should be treated as *Needs verification* for payload details.

## 3. Discrepancies

### 3.1 BROKEN: forgot-password flow returns 400 at every step (P0)
- **Mobile:** `features/auth/data/models/forgot_password_models.dart:7,16,30` sends `{email}`, then `{email, otp}`, then `{reset_token, new_password, confirm_password}`.
- **Backend:** `apps/accounts/serializers.py:150-178`. `ForgotPasswordSerializer`, `VerifyOTPSerializer` and `ResetPasswordSerializer` each require `company_code`, because the tenant is looked up before the email (`apps/accounts/views.py:714-848`).
- **Web reference:** `frontend/components/auth/ForgotPasswordForm.tsx` sends `company_code` at all three steps.
- **Result:** `400 company_code: This field is required.` No user can reset a password from the app.
- **Fix:**
  - Add a Company ID field to the forgot-password screen, pre-filled from the login form if entered.
  - Pass it through `forgot_password_usecase.dart`, `verify_otp_usecase.dart`, `reset_password_usecase.dart`, `AuthRepository` and the 3 request models.
  - This is mobile-only; no backend change.

### 3.2 SOFT: dead Bearer/body-token code (P1 cleanup)
- **Mobile:**
  - `features/auth/data/models/login_response_model.dart:20-23` reads `data.access` and `data.refresh`.
  - `core/network/auth_interceptor.dart:40-56` attaches `Authorization: Bearer`.
  - `auth_interceptor.dart:101-120` sends the stored refresh token in the body and reads new tokens from the response.
- **Backend:** never returns tokens in the body, and the tenant middleware ignores the Bearer header.
- **Effect:** native auth works **only** through `dio_cookie_manager` + `PersistCookieJar` (`core/network/api_client.dart:37-42`, `main.dart:31-39`). The secure-storage token code is dead.
- **Fix:** delete the dead code paths (mobile-only), *or*, with backend approval, return tokens in the body and resolve the tenant from Bearer too. Flutter web works only same-origin.

### 3.3 SOFT: My Payslips silently shows at most 20 (P1)
- **Mobile:** `features/payroll/data/datasources/payroll_remote_datasource.dart:20-32` makes one call with no paging.
- **Backend:** `MyPayslipsView` pages at 20 by default, up to 100 (`apps/payroll/views/payslips.py:405-409`).
- **Fix:** pass `page_size=100` or loop over `total_pages`.

### 3.4 Gating and permission risks (not broken today)
- **Module gates:** a tenant without the payroll module gets 403 on My Payslips **and** the Approvals → Attendance Approval tab, which reuses `/payroll/cycles/*`. Mobile shows a generic "forbidden" message instead of "module not enabled". Fix: map the 403 message from the server and hide nav items for disabled modules, if the backend exposes the module list (*Needs verification*).
- **Dashboard role:** mobile chooses the dashboard by role-name substring (`features/dashboard/presentation/widgets/quick_access.dart:17`).
  - A `branch_admin` lands on `/dashboard/system-admin/*`, which requires `settings.edit` (`apps/dashboard/views/overview.py:24`), so it shows 403s.
  - Web uses flags: `frontend/app/dashboard/page.tsx:13-26`.
- **`fetchPayrollSettings`:** `features/approvals/data/datasources/attendance_approval_remote_datasource.dart:26` needs `payroll.view`. Its provider has no consumers (dead code).
- **`fetchRecordDetail(isEmployeeId:true)`:** would 404, because the route only accepts a UUID (`apps/attendance/urls.py:108`). This is latent; it is not called that way today.
- **Logout:** with an expired access cookie, `POST /logout/` returns 401 (`IsAuthenticated`, `apps/accounts/views.py:692`). Mobile swallows the error, so the refresh token is not blacklisted server-side. Low risk.

### 3.5 Configuration-driven contracts mobile ignores (Outdated)
- **Onboarding wizard:** calls only `/onboarding/`, `/onboarding/step/<n>/` and `/onboarding/documents/` (`features/onboarding/data/datasources/onboarding_datasource.dart`).
  - Since 2026-08-19 web renders per-company fields from `/onboarding/field-config/`, `/onboarding/document-type-config/` and `/onboarding/custom-file-fields/`.
  - Risk: a company that adds required custom fields or document types gets an incomplete or failing submission from mobile. *Needs verification* of server-side enforcement.
- **Face embeddings:** mobile posts a 192-d MobileFaceNet vector; web posts a 128-d face-api.js vector.
  - The backend stores whichever is posted (`apps/attendance/views/face_registration.py:124`).
  - An employee who registers on web and clocks in on mobile, or the reverse, cannot be matched. Product decision required.

### 3.6 Stale comments and unused constants (P3)
- The `api_constants.dart` carry-forward comment says the routes 404. They exist at `apps/hrms/urls.py:110-113`.
- `ApiConstants.payslipDetail` and `ApiConstants.settingsEmailTemplatePreview` are never called.
- The `face_capture_state.dart:3` header says "server-computed embedding". That is stale; computation is on-device.

## 4. Contracts hand-verified as compatible

| Flow | Mobile → backend evidence |
|---|---|
| Login | `{company_code,email,password}` matches `LoginSerializer` (serializers.py:144). User keys match `UserModel.fromJson` (user_model.dart:27-53). |
| Change password | `{old_password,new_password,confirm_password}` matches `ChangePasswordSerializer` (serializers.py:195). The server clears cookies, so the app must re-login. |
| Punch | `IN/OUT`, mode, `source: mobile`, GPS, `face_embedding` match `PunchWriteSerializer` (attendance/serializers_my_attendance.py:30-73). The response matches `TodayAttendanceModel` except `day_completed`, which is not parsed (§5a). |
| Attendance correction | Keys and reason codes match `CorrectionWriteSerializer` and `AttendanceCorrection.REASON_CHOICES` (attendance/models.py:1378-1389). |
| Leave apply / approve / cancel / preview / balances | Match `LeaveRequestCreateSerializer` (hrms/serializers.py:586), `LeaveApprovalView`, `LeaveRequestDetailView.patch` and `?action=preview` (hrms/views/leave.py:882) |
| WFH | Create, approve and saved-locations keys match (hrms/serializers.py:526, views/workfromhome.py:308) |
| Notifications | List, unread-count, read, read-all and settings match (notifications/views.py, serializers.py:9-22) |
| Separation | Create, update, cancel, stage action, tasks, clearances and documents match (hrms/serializers.py:937-993, views/separation*.py) |
| Facial recognition | Submit, HR register and review match serializers_face_registration.py:51-92 |
| Voice | parse, transcribe-fallback and speak keys match (voice_commands/views.py:89-118, views_transcribe.py:167, views_speak.py:108) |
| Attendance approval | `{level,comment,self_approve}` matches `AttendanceApprovalView` (payroll/views/cycles.py:742-765) |
| Employees | `reporting_manager_id` and `hr_id` match `EmployeeDetailView.patch` |
| Onboarding | GET/POST `/onboarding/` and PATCH `/onboarding/step/<n>/` match `OnboardingView` (accounts/views.py:4426-4530) |

## 5. Backend endpoints relevant to tenant users that mobile never calls

These feed the parity gaps in `WEB_MOBILE_PARITY.md`:

- **Dashboard:** `dashboard/manager/`, `dashboard/employee/notice-period/`, `dashboard/birthdays/mine/`, `dashboard/employee/birthdays/today/`
- **Employees:** `employees/stats/`, `employees/<id>/id-card/`, `employees/<id>/promotions/`, `employees/<id>/reset-password/`, `employees/<id>/custom-file-fields/`, `employees/bulk-import/sample/`
- **Onboarding config:** `onboarding/field-config/`, `onboarding/document-type-config/`, `onboarding/custom-file-fields/`
- **Leave:**
  - `leave/credits/<code>/` (with `adjust/` and transaction `reverse/`)
  - `leave/monthly-credits/*` (import, assignments, bulk)
  - `leave/balance/<id>/` adjust
- **Attendance:**
  - `attendance/employee-calendar/`, `attendance/weekly-off-assignments/*`, `attendance/shift-assignments/*`, `attendance/import/<id>/status/`, `attendance/face-capture-telemetry/`
  - attendance policy CRUD: `working-hours`, `weekly-days`, `punch-rules`, `overtime-rules`, `late-mark-lop`, `absence-alert`
- **Payroll:** `payroll/payslips/<id>/`, `payroll/queries/` (payslip queries: raise and resolve), `payroll/employees/<id>/payslips/`, `payroll/cycles/<id>/manager-approvals/`, and the whole admin payroll surface (removed from mobile deliberately in commit `e558822`)
- **Assets:** `assets/employees/<id>/` (my assets) and the full assets admin
- **Assessments (candidate portal):** `assessments/my/`, `assessments/<id>/respond/<item>/`, `/complete/`, `/retry/`
- **Recruitment:** `recruitment/candidates/review/`, `/hr-decision/`, `/status-choices/`, `recruitment/referral-bonuses/*`
- **Other:** `birthdays/settings/`, `branch/employee-access/*`, `branch/branches/<id>/geofencing/`, `branch/branches/<id>/reassign-admin/`, `settings/id-card/`, `settings/email-templates/resolve-context/`

## 5a. Backend changes since the mobile pause (baseline `18fad08`, 2026-08-12 → HEAD `d92cfac`, 2026-10-28)

- **344 URL patterns now, 263 at baseline: 81 new, 0 removed, no HTTP-method changes on existing paths.** This is why no mobile call 404s.
- **New areas:**
  - Assets (15 endpoints) and WFH (5)
  - Monthly leave and leave credits (8), and shift assignments (3)
  - Platform admin (19, web-only)
  - ID card, onboarding field and document-type config, notification settings, `/org-chart/`
  - Payroll analytics, ESIC, ECR text and salary-transfer confirmation
  - `/voice/speak/`, `/voice/transcribe-fallback/`, the notice-period card, face-capture telemetry
- **Envelope:** success is `{status, message, data}`. Errors are `{status:'error', message:"<field>: <msg>", data}` (`config/exceptions.py`). Attendance and voice return **422** for validation errors; most other views return **400**.
- **Permissions:** 288 views declare only `IsAuthenticated` and check `core.permissions.has_perm(user,'x.y')` inside the view. Superusers and any role holding `settings.edit` pass every check.

### Business rules that changed and affect mobile

| Rule | Backend evidence | Mobile impact |
|---|---|---|
| **Face verification is skipped for `source='mobile'`.** It runs only for `web` or `voice`, and only when the company makes face attendance mandatory. | `apps/attendance/services_face_matching.py:207`, `services_attendance.py:147-160` | **Mobile always sends `source:'mobile'`** (`features/attendance/data/datasources/attendance_remote_datasource.dart:47`). It computes and sends an embedding that the server ignores, so **mobile clock-in bypasses mandatory face verification.** Business-rule and security gap; needs a decision (see Roadmap P0-04). |
| **Face embedding length must match the registration.** | `services_face_matching.py:159-162` (`'Face descriptor length mismatch.'`) | Mobile is 192-d (MobileFaceNet) and web is 128-d (face-api.js), so registrations can't be used across platforms. The voice punch path (`source='voice'`) **is** verified, so a web-registered user doing a mobile voice clock-in gets a mismatch error. |
| One clock-in and one clock-out per day; repeats return 400. The response has `day_completed`. | `services_attendance.py:~305` | **Outdated:** `TodayAttendanceModel.fromJson` (`features/attendance/data/models/attendance_models.dart:56-67`) does **not** parse `day_completed` (backend `serializers_my_attendance.py:179`). After clock-out the UI offers Clock In again, and the user goes through GPS and face capture before getting a 400. Roadmap P1-03. |
| Office punches must be within the branch radius plus up to 100 m of GPS accuracy, else 403. WFH punches need an approved WFH request and must be within 200 m of its saved location. UK-shift employees skip the distance check. | `services_attendance.py:130-145` | Mobile has a geofence pre-check (`/attendance/geofence-check/`) and the WFH module. The server message should be surfaced verbatim. |
| Repeated failed face attempts or a replayed capture return 403 with `{blocked, retry_after_seconds}`. | `services_face_matching.py:165-171` | Mobile should show a countdown or disable retry. *Needs verification* of current handling. |
| Leave: `leave_type` is free text up to 50 characters (custom types). `credit_schedule` is annual or monthly; monthly credit expires at month end. Statuses are `pending`, `l2_pending`, `approved`, `rejected`, `cancelled`. Delete needs `leave.approve` and returns 409 if the leave is approved. | `apps/hrms/` leave views and serializers | Mostly compatible: mobile loads types from `leaveTypesProvider` and treats `l2_pending` as pending (`leave_entity.dart:195`). Monthly-entitlement and month-end messages arrive as server validation text. |
| Employee IDs are now prefix + DDMM + initials (e.g. `RSS0308TG`), and existing IDs were converted. | commit `6a08efa`, the 2026-10-01 employee-ID commits | Any cached or hard-coded `EMP…` format assumption is stale. |
| `/dashboard/employee/*` and `/dashboard/birthdays/mine/` are blocked until onboarding **and assigned assessments** are complete. | `apps/dashboard/views/` | Mobile has no assessment gate (`assessmentStatus` unused), so these users would see 403s on the Employee dashboard. |
| `must_change_password` is **not** enforced server-side; the client must gate it. | backend report | Mobile parses it but never enforces it. |
| The HR employee edit returns 409 when name, phone or joining date change after onboarding is complete. | `apps/accounts/views.py` | Show the server message. |
| Separation detail needs `separation.approve`; payroll config GETs need `payroll.view`. | backend report | Check mobile separation detail for non-approver owners. *Needs verification.* |
| Announcements are targeted to all, a department or a branch. A user with no department or branch never sees targeted posts. | commit `9a4734d` | Server-side, so no mobile change is needed. |
| ID card (`employees.view`) and assets (`assets.view`) need HR-level permissions; there is no self-service endpoint. | backend report | A mobile "My ID card" or "My assets" screen would need a backend change. |

## 6. Full call-site matrix

Below is every mobile call site with its classification, mobile file:line, backend route (urls.py line) and view (file:line). The method was resolved by script; contracts were not hand-checked unless listed in §4.

|---|---|---|---|---|---|
| GET | /api/announcements/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:16` | `api/announcements/ apps/announcements/urls.py:11` | `AnnouncementListCreateView apps/announcements/views.py:107` |
| POST | /api/announcements/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:40` | `api/announcements/ apps/announcements/urls.py:11` | `AnnouncementListCreateView apps/announcements/views.py:107` |
| DELETE | /api/announcements/PARAM/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:50` | `api/announcements/<int:pk>/ apps/announcements/urls.py:12` | `AnnouncementDetailView apps/announcements/views.py:213` |
| PUT | /api/announcements/PARAM/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:45` | `api/announcements/<int:pk>/ apps/announcements/urls.py:12` | `AnnouncementDetailView apps/announcements/views.py:213` |
| POST | /api/announcements/PARAM/react/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:56` | `api/announcements/<int:pk>/react/ apps/announcements/urls.py:13` | `AnnouncementReactView apps/announcements/views.py:314` |
| POST | /api/announcements/PARAM/view/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:68` | `api/announcements/<int:pk>/view/ apps/announcements/urls.py:14` | `AnnouncementViewTrackView apps/announcements/views.py:348` |
| POST | /api/assessments/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:21` | `api/assessments/ apps/assessments/urls.py:21` | `AssessmentListCreateView apps/assessments/views/admin.py:73` |
| DELETE | /api/assessments/PARAM/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:33` | `api/assessments/<uuid:assessment_id>/ apps/assessments/urls.py:22` | `AssessmentDetailView apps/assessments/views/admin.py:107` |
| PUT | /api/assessments/PARAM/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:28` | `api/assessments/<uuid:assessment_id>/ apps/assessments/urls.py:22` | `AssessmentDetailView apps/assessments/views/admin.py:107` |
| GET | /api/assessments/PARAM/items/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:39` | `api/assessments/<uuid:assessment_id>/items/ apps/assessments/urls.py:23` | `AssessmentItemListCreateView apps/assessments/views/admin.py:157` |
| POST | /api/assessments/PARAM/items/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:48` | `api/assessments/<uuid:assessment_id>/items/ apps/assessments/urls.py:23` | `AssessmentItemListCreateView apps/assessments/views/admin.py:157` |
| POST | /api/assessments/assign/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:73` | `api/assessments/assign/ apps/assessments/urls.py:31` | `AssignAssessmentView apps/assessments/views/admin.py:221` |
| GET | /api/assessments/email-template-options/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:94` | `api/assessments/email-template-options/ apps/assessments/urls.py:32` | `EmailTemplateOptionsView apps/assessments/views/admin.py:433` |
| DELETE | /api/assessments/items/PARAM/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:63` | `api/assessments/items/<uuid:item_id>/ apps/assessments/urls.py:24` | `AssessmentItemDetailView apps/assessments/views/admin.py:188` |
| PUT | /api/assessments/items/PARAM/ | OK | `features/assessments/data/datasources/assessments_remote_datasource.dart:56` | `api/assessments/items/<uuid:item_id>/ apps/assessments/urls.py:24` | `AssessmentItemDetailView apps/assessments/views/admin.py:188` |
| GET | /api/assessments/settings/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:539` | `api/assessments/settings/ apps/assessments/urls.py:18` | `AssessmentSettingsView apps/assessments/views/settings.py:15` |
| PUT | /api/assessments/settings/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:546` | `api/assessments/settings/ apps/assessments/urls.py:18` | `AssessmentSettingsView apps/assessments/views/settings.py:15` |
| GET | /api/attendance/calendar/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:102` | `api/attendance/calendar/ apps/attendance/urls.py:100` | `AttendanceCalendarView apps/attendance/views/my_attendance.py:253` |
| POST | /api/attendance/correction/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:118` | `api/attendance/correction/ apps/attendance/urls.py:101` | `AttendanceCorrectionView apps/attendance/views/my_attendance.py:291` |
| GET | /api/attendance/corrections/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:313` | `api/attendance/corrections/ apps/attendance/urls.py:118` | `HRCorrectionListView apps/attendance/views/hr_attendance.py:715` |
| PATCH | /api/attendance/corrections/PARAM/review/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:333` | `api/attendance/corrections/<uuid:pk>/review/ apps/attendance/urls.py:119` | `HRCorrectionReviewView apps/attendance/views/hr_attendance.py:748` |
| GET | /api/attendance/corrections/my/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:326` | `api/attendance/corrections/my/ apps/attendance/urls.py:102` | `MyCorrectionsListView apps/attendance/views/my_attendance.py:364` |
| GET | /api/attendance/dashboard/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:136` | `api/attendance/dashboard/ apps/attendance/urls.py:105` | `HRAttendanceDashboardView apps/attendance/views/hr_attendance.py:122` |
| GET | /api/attendance/export/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:379` | `api/attendance/export/ apps/attendance/urls.py:116` | `HRAttendanceExportView apps/attendance/views/hr_attendance.py:794` |
| POST | /api/attendance/face-registration/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:51` | `api/attendance/face-registration/ apps/attendance/urls.py:137` | `FaceRegistrationSubmitView apps/attendance/views/face_registration.py:63` |
| PATCH | /api/attendance/face-registration/PARAM/review/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:107` | `api/attendance/face-registration/<uuid:pk>/review/ apps/attendance/urls.py:140` | `FaceRegistrationReviewView apps/attendance/views/face_registration.py:196` |
| GET | /api/attendance/face-registration/employees/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:115` | `api/attendance/face-registration/employees/ apps/attendance/urls.py:150` | `FaceRegistrationEmployeePickerView apps/attendance/views/face_registration_hr.py:54` |
| GET | /api/attendance/face-registration/employees/PARAM/status/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:123` | `api/attendance/face-registration/employees/<uuid:employee_uuid>/status/ apps/attendance/urls.py:151` | `FaceRegistrationEmployeeStatusView apps/attendance/views/face_registration_hr.py:88` |
| GET | /api/attendance/face-registration/me/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:39` | `api/attendance/face-registration/me/ apps/attendance/urls.py:138` | `FaceRegistrationMyStatusView apps/attendance/views/face_registration.py:142` |
| GET | /api/attendance/face-registration/pending/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:73` | `api/attendance/face-registration/pending/ apps/attendance/urls.py:139` | `FaceRegistrationPendingListView apps/attendance/views/face_registration.py:168` |
| POST | /api/attendance/face-registration/register/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:136` | `api/attendance/face-registration/register/ apps/attendance/urls.py:149` | `FaceRegistrationHRRegisterView apps/attendance/views/face_registration_hr.py:117` |
| GET | /api/attendance/face-verification/status/ | OK | `features/facial_recognition/data/datasources/facial_recognition_remote_datasource.dart:34` | `api/attendance/face-verification/status/ apps/attendance/urls.py:143` | `FaceVerificationStatusView apps/attendance/views/face_registration.py:271` |
| POST | /api/attendance/geofence-check/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:36` | `api/attendance/geofence-check/ apps/attendance/urls.py:96` | `AttendanceGeofenceCheckView apps/attendance/views/geofence_check.py:28` |
| POST | /api/attendance/import/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:395` | `api/attendance/import/ apps/attendance/urls.py:113` | `HRAttendanceImportView apps/attendance/views/hr_attendance.py:488` |
| GET | /api/attendance/import/sample/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:404` | `api/attendance/import/sample/ apps/attendance/urls.py:114` | `HRAttendanceImportSampleView apps/attendance/views/hr_attendance.py:607` |
| GET | /api/attendance/invalid-punches/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:285` | `api/attendance/invalid-punches/ apps/attendance/urls.py:111` | `HRInvalidPunchesView apps/attendance/views/hr_attendance.py:428` |
| POST | /api/attendance/invalid-punches/PARAM/assign/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:352` | `api/attendance/invalid-punches/<uuid:pk>/assign/ apps/attendance/urls.py:132` | `HRInvalidPunchAssignView apps/attendance/views/hr_audit_actions.py:58` |
| POST | /api/attendance/invalid-punches/PARAM/convert/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:370` | `api/attendance/invalid-punches/<uuid:pk>/convert/ apps/attendance/urls.py:134` | `HRInvalidPunchConvertView apps/attendance/views/hr_audit_actions.py:108` |
| POST | /api/attendance/invalid-punches/PARAM/discard/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:359` | `api/attendance/invalid-punches/<uuid:pk>/discard/ apps/attendance/urls.py:133` | `HRInvalidPunchDiscardView apps/attendance/views/hr_audit_actions.py:83` |
| GET | /api/attendance/overtime/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:248` | `api/attendance/overtime/ apps/attendance/urls.py:109` | `HROvertimeListView apps/attendance/views/hr_attendance.py:373` |
| POST | /api/attendance/overtime/create/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:267` | `api/attendance/overtime/create/ apps/attendance/urls.py:110` | `HROvertimeCreateView apps/attendance/views/hr_attendance.py:403` |
| POST | /api/attendance/punch/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:59` | `api/attendance/punch/ apps/attendance/urls.py:95` | `AttendancePunchView apps/attendance/views/my_attendance.py:104` |
| GET | /api/attendance/records/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:155` | `api/attendance/records/ apps/attendance/urls.py:106` | `HRAttendanceListView apps/attendance/views/hr_attendance.py:146` |
| GET | /api/attendance/records/PARAM/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:231` | `api/attendance/records/<uuid:pk>/ apps/attendance/urls.py:108` | `HRAttendanceDetailView apps/attendance/views/hr_attendance.py:170` |
| PATCH | /api/attendance/records/PARAM/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:202` | `api/attendance/records/<uuid:pk>/ apps/attendance/urls.py:108` | `HRAttendanceDetailView apps/attendance/views/hr_attendance.py:170` |
| GET | /api/attendance/records/PARAM/audit/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:415` | `api/attendance/records/<uuid:pk>/audit/ apps/attendance/urls.py:129` | `HRAttendanceAuditView apps/attendance/views/hr_audit_actions.py:31` |
| POST | /api/attendance/records/create/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:180` | `api/attendance/records/create/ apps/attendance/urls.py:107` | `HRAttendanceCreateView apps/attendance/views/hr_attendance.py:277` |
| POST | /api/attendance/reprocess/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:219` | `api/attendance/reprocess/ apps/attendance/urls.py:117` | `HRAttendanceReprocessView apps/attendance/views/hr_attendance.py:653` |
| GET | /api/attendance/settings/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:515` | `api/attendance/settings/ apps/attendance/urls.py:92` | `AttendanceSettingsAPIView apps/attendance/views/settings_view.py:34` |
| PATCH | /api/attendance/settings/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:530` | `api/attendance/settings/ apps/attendance/urls.py:92` | `AttendanceSettingsAPIView apps/attendance/views/settings_view.py:34` |
| PUT | /api/attendance/settings/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:523` | `api/attendance/settings/ apps/attendance/urls.py:92` | `AttendanceSettingsAPIView apps/attendance/views/settings_view.py:34` |
| GET | /api/attendance/stats/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:84` | `api/attendance/stats/ apps/attendance/urls.py:98` | `AttendanceStatsView apps/attendance/views/my_attendance.py:192` |
| GET | /api/attendance/summary/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:93` | `api/attendance/summary/ apps/attendance/urls.py:99` | `AttendanceSummaryView apps/attendance/views/my_attendance.py:221` |
| GET | /api/attendance/today/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:79` | `api/attendance/today/ apps/attendance/urls.py:97` | `TodayAttendanceView apps/attendance/views/my_attendance.py:172` |
| GET | /api/attendance/un-punches/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:299` | `api/attendance/un-punches/ apps/attendance/urls.py:112` | `HRUnpunchesView apps/attendance/views/hr_attendance.py:458` |
| GET | /api/birthdays/ | OK | `features/hrms/data/datasources/hrms_remote_datasource.dart:19` | `api/birthdays/ apps/hrms/urls.py:57` | `BirthdayView apps/hrms/views/birthdays.py:18` |
| GET | /api/branch/branches/ | OK | `features/announcements/data/datasources/announcements_remote_datasource.dart:75` | `api/branch/branches/ apps/branch/urls.py:30` | `BranchListCreateView apps/branch/views.py:149` |
| GET | /api/branch/branches/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:67` | `api/branch/branches/ apps/branch/urls.py:30` | `BranchListCreateView apps/branch/views.py:149` |
| GET | /api/branch/branches/ | OK | `features/interview_list/presentation/widgets/add_candidate_sheet.dart:70` | `api/branch/branches/ apps/branch/urls.py:30` | `BranchListCreateView apps/branch/views.py:149` |
| GET | /api/branch/branches/ | OK | `features/org_chart/data/datasources/org_chart_remote_datasource.dart:26` | `api/branch/branches/ apps/branch/urls.py:30` | `BranchListCreateView apps/branch/views.py:149` |
| POST | /api/branch/branches/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:87` | `api/branch/branches/ apps/branch/urls.py:30` | `BranchListCreateView apps/branch/views.py:149` |
| DELETE | /api/branch/branches/PARAM/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:99` | `api/branch/branches/<int:pk>/ apps/branch/urls.py:31` | `BranchDetailView apps/branch/views.py:233` |
| PUT | /api/branch/branches/PARAM/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:94` | `api/branch/branches/<int:pk>/ apps/branch/urls.py:31` | `BranchDetailView apps/branch/views.py:233` |
| GET | /api/branch/branches/distribution/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:52` | `api/branch/branches/distribution/ apps/branch/urls.py:27` | `BranchDistributionView apps/branch/views.py:660` |
| GET | /api/branch/branches/preview-code/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:30` | `api/branch/branches/preview-code/ apps/branch/urls.py:25` | `BranchPreviewCodeView apps/branch/views.py:108` |
| GET | /api/branch/branches/stats/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:44` | `api/branch/branches/stats/ apps/branch/urls.py:26` | `BranchStatsView apps/branch/views.py:634` |
| GET | /api/branch/states/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:12` | `api/branch/states/ apps/branch/urls.py:21` | `StateListView apps/branch/views.py:86` |
| GET | /api/branch/states/PARAM/cities/ | OK | `features/branches/data/datasources/branch_remote_datasource.dart:21` | `api/branch/states/<int:state_id>/cities/ apps/branch/urls.py:22` | `CityListView apps/branch/views.py:94` |
| POST | /api/change-password/ | OK | `features/profile/data/datasources/profile_remote_datasource.dart:53` | `api/change-password/ apps/accounts/urls.py:71` | `ChangePasswordView apps/accounts/views.py:892` |
| GET | /api/dashboard/announcement/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:189` | `api/dashboard/announcement/ apps/dashboard/urls.py:18` | `SharedAnnouncementView apps/dashboard/views/overview.py:495` |
| GET | /api/dashboard/department-headcount/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:137` | `api/dashboard/department-headcount/ apps/dashboard/urls.py:17` | `HRDepartmentHeadcountView apps/dashboard/views/overview.py:222` |
| GET | /api/dashboard/employee/action-items/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:158` | `api/dashboard/employee/action-items/ apps/dashboard/urls.py:37` | `EmployeeActionItemsView apps/dashboard/views/people.py:358` |
| GET | /api/dashboard/employee/attendance-status/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:182` | `api/dashboard/employee/attendance-status/ apps/dashboard/urls.py:40` | `EmployeeAttendanceStatusView apps/dashboard/views/overview.py:706` |
| GET | /api/dashboard/employee/attendance-summary/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:171` | `api/dashboard/employee/attendance-summary/ apps/dashboard/urls.py:39` | `EmployeeAttendanceSummaryView apps/dashboard/views/overview.py:671` |
| GET | /api/dashboard/employee/kpis/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:144` | `api/dashboard/employee/kpis/ apps/dashboard/urls.py:35` | `EmployeeKPIView apps/dashboard/views/overview.py:523` |
| GET | /api/dashboard/employee/leave-balances/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:150` | `api/dashboard/employee/leave-balances/ apps/dashboard/urls.py:36` | `EmployeeLeaveBalanceView apps/dashboard/views/overview.py:607` |
| GET | /api/dashboard/employee/recent-requests/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:163` | `api/dashboard/employee/recent-requests/ apps/dashboard/urls.py:38` | `EmployeeRecentRequestsView apps/dashboard/views/people.py:460` |
| GET | /api/dashboard/hr/action-queue/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:112` | `api/dashboard/hr/action-queue/ apps/dashboard/urls.py:23` | `HRActionQueueView apps/dashboard/views/overview.py:300` |
| GET | /api/dashboard/hr/attendance-summary/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:107` | `api/dashboard/hr/attendance-summary/ apps/dashboard/urls.py:29` | `HRAttendanceSummaryView apps/dashboard/views/overview.py:457` |
| GET | /api/dashboard/hr/birthdays/today/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:127` | `api/dashboard/hr/birthdays/today/ apps/dashboard/urls.py:27` | `HRBirthdayTodayView apps/dashboard/views/people.py:313` |
| GET | /api/dashboard/hr/birthdays/upcoming/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:132` | `api/dashboard/hr/birthdays/upcoming/ apps/dashboard/urls.py:28` | `HRBirthdayUpcomingView apps/dashboard/views/people.py:322` |
| GET | /api/dashboard/hr/employee-lifecycle/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:122` | `api/dashboard/hr/employee-lifecycle/ apps/dashboard/urls.py:26` | `HREmployeeLifecycleView apps/dashboard/views/people.py:255` |
| GET | /api/dashboard/hr/kpis/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:102` | `api/dashboard/hr/kpis/ apps/dashboard/urls.py:22` | `HRKPIView apps/dashboard/views/overview.py:234` |
| GET | /api/dashboard/hr/recruitment-funnel/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:117` | `api/dashboard/hr/recruitment-funnel/ apps/dashboard/urls.py:24` | `HRRecruitmentFunnelView apps/dashboard/views/overview.py:431` |
| GET | /api/dashboard/system-admin/announcement/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:44` | `api/dashboard/system-admin/announcement/ apps/dashboard/urls.py:8` | `SystemAdminAnnouncementView apps/dashboard/views/overview.py:158` |
| GET | /api/dashboard/system-admin/audit-logs/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:88` | `api/dashboard/system-admin/audit-logs/ apps/dashboard/urls.py:14` | `SystemAdminAuditLogsView apps/dashboard/views/people.py:213` |
| GET | /api/dashboard/system-admin/birthdays/today/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:72` | `api/dashboard/system-admin/birthdays/today/ apps/dashboard/urls.py:12` | `SystemAdminBirthdayTodayView apps/dashboard/views/people.py:193` |
| GET | /api/dashboard/system-admin/birthdays/upcoming/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:79` | `api/dashboard/system-admin/birthdays/upcoming/ apps/dashboard/urls.py:13` | `SystemAdminBirthdayUpcomingView apps/dashboard/views/people.py:202` |
| GET | /api/dashboard/system-admin/department-headcount/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:59` | `api/dashboard/system-admin/department-headcount/ apps/dashboard/urls.py:10` | `SystemAdminDepartmentHeadcountView apps/dashboard/views/overview.py:213` |
| GET | /api/dashboard/system-admin/employee-lifecycle/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:65` | `api/dashboard/system-admin/employee-lifecycle/ apps/dashboard/urls.py:11` | `SystemAdminEmployeeLifecycleView apps/dashboard/views/people.py:150` |
| GET | /api/dashboard/system-admin/kpis/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:39` | `api/dashboard/system-admin/kpis/ apps/dashboard/urls.py:7` | `SystemAdminKPIView apps/dashboard/views/overview.py:86` |
| GET | /api/dashboard/system-admin/pending-approvals/ | OK | `features/dashboard/data/datasources/dashboard_remote_datasource.dart:53` | `api/dashboard/system-admin/pending-approvals/ apps/dashboard/urls.py:9` | `SystemAdminPendingApprovalsView apps/dashboard/views/overview.py:185` |
| GET | /api/departments/ | OK | `features/candidate_review/data/datasources/approval_datasource.dart:53` | `api/departments/ apps/accounts/urls.py:111` | `DepartmentListCreateView apps/accounts/views.py:1275` |
| POST | /api/departments/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:233` | `api/departments/ apps/accounts/urls.py:111` | `DepartmentListCreateView apps/accounts/views.py:1275` |
| DELETE | /api/departments/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:244` | `api/departments/<int:pk>/ apps/accounts/urls.py:112` | `DepartmentDetailView apps/accounts/views.py:1353` |
| PUT | /api/departments/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:239` | `api/departments/<int:pk>/ apps/accounts/urls.py:112` | `DepartmentDetailView apps/accounts/views.py:1353` |
| GET | /api/designations/ | OK | `features/candidate_review/data/datasources/approval_datasource.dart:76` | `api/designations/ apps/accounts/urls.py:113` | `DesignationListCreateView apps/accounts/views.py:1618` |
| GET | /api/designations/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:350` | `api/designations/ apps/accounts/urls.py:113` | `DesignationListCreateView apps/accounts/views.py:1618` |
| POST | /api/designations/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:397` | `api/designations/ apps/accounts/urls.py:113` | `DesignationListCreateView apps/accounts/views.py:1618` |
| DELETE | /api/designations/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:409` | `api/designations/<int:pk>/ apps/accounts/urls.py:115` | `DesignationDetailView apps/accounts/views.py:1670` |
| PUT | /api/designations/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:404` | `api/designations/<int:pk>/ apps/accounts/urls.py:115` | `DesignationDetailView apps/accounts/views.py:1670` |
| GET | /api/documents/ | OK | `features/documents/data/datasources/document_remote_datasource.dart:28` | `api/documents/ apps/accounts/urls.py:153` | `DocumentListCreateView apps/accounts/views.py:2488` |
| POST | /api/documents/ | OK | `features/documents/data/datasources/document_remote_datasource.dart:59` | `api/documents/ apps/accounts/urls.py:153` | `DocumentListCreateView apps/accounts/views.py:2488` |
| DELETE | /api/documents/PARAM/ | OK | `features/documents/data/datasources/document_remote_datasource.dart:70` | `api/documents/<str:pk>/ apps/accounts/urls.py:155` | `DocumentDetailView apps/accounts/views.py:2586` |
| GET | /api/documents/stats/ | OK | `features/documents/data/datasources/document_remote_datasource.dart:10` | `api/documents/stats/ apps/accounts/urls.py:154` | `DocumentStatsView apps/accounts/views.py:2795` |
| GET | /api/employees/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:138` | `api/employees/ apps/accounts/urls.py:74` | `EmployeeListCreateView apps/accounts/views.py:2977` |
| GET | /api/employees/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:177` | `api/employees/ apps/accounts/urls.py:74` | `EmployeeListCreateView apps/accounts/views.py:2977` |
| GET | /api/employees/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:99` | `api/employees/ apps/accounts/urls.py:74` | `EmployeeListCreateView apps/accounts/views.py:2977` |
| GET | /api/employees/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:293` | `api/employees/ apps/accounts/urls.py:74` | `EmployeeListCreateView apps/accounts/views.py:2977` |
| POST | /api/employees/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:204` | `api/employees/ apps/accounts/urls.py:74` | `EmployeeListCreateView apps/accounts/views.py:2977` |
| GET | /api/employees/PARAM/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:197` | `api/employees/<str:employee_id>/ apps/accounts/urls.py:90` | `EmployeeDetailView apps/accounts/views.py:3518` |
| PATCH | /api/employees/PARAM/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:227` | `api/employees/<str:employee_id>/ apps/accounts/urls.py:90` | `EmployeeDetailView apps/accounts/views.py:3518` |
| PUT | /api/employees/PARAM/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:217` | `api/employees/<str:employee_id>/ apps/accounts/urls.py:90` | `EmployeeDetailView apps/accounts/views.py:3518` |
| GET | /api/employees/PARAM/approval-matrix/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:296` | `api/employees/<str:employee_id>/approval-matrix/ apps/accounts/urls.py:84` | `EmployeeApprovalMatrixView apps/accounts/views.py:6392` |
| PATCH | /api/employees/PARAM/approval-matrix/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:312` | `api/employees/<str:employee_id>/approval-matrix/ apps/accounts/urls.py:84` | `EmployeeApprovalMatrixView apps/accounts/views.py:6392` |
| POST | /api/employees/PARAM/documents/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:401` | `api/employees/<str:employee_id>/documents/ apps/accounts/urls.py:85` | `EmployeeProfileDocumentView apps/accounts/views.py:5239` |
| PATCH | /api/employees/PARAM/hr/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:378` | `api/employees/<str:employee_id>/hr/ apps/accounts/urls.py:89` | `EmployeeDetailView apps/accounts/views.py:3518` |
| PATCH | /api/employees/PARAM/reporting-manager/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:371` | `api/employees/<str:employee_id>/reporting-manager/ apps/accounts/urls.py:83` | `EmployeeReportingManagerView apps/accounts/views.py:6208` |
| POST | /api/employees/bulk-import/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:422` | `api/employees/bulk-import/ apps/accounts/urls.py:76` | `EmployeeBulkImportView apps/accounts/views.py:6621` |
| GET | /api/employees/hrs/ | OK | `features/attendance/data/datasources/attendance_remote_datasource.dart:345` | `api/employees/hrs/ apps/accounts/urls.py:80` | `HRListView apps/accounts/views.py:6102` |
| GET | /api/employees/hrs/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:261` | `api/employees/hrs/ apps/accounts/urls.py:80` | `HRListView apps/accounts/views.py:6102` |
| GET | /api/employees/managers/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:269` | `api/employees/managers/ apps/accounts/urls.py:81` | `ManagerListView apps/accounts/views.py:6140` |
| GET | /api/employees/me/ | OK | `features/onboarding/presentation/screens/awaiting_approval_screen.dart:39` | `api/employees/me/ apps/accounts/urls.py:78` | `MyProfileView apps/accounts/views.py:6024` |
| GET | /api/employees/me/ | OK | `features/profile/data/datasources/profile_remote_datasource.dart:14` | `api/employees/me/ apps/accounts/urls.py:78` | `MyProfileView apps/accounts/views.py:6024` |
| PATCH | /api/employees/me/ | OK | `features/profile/data/datasources/profile_remote_datasource.dart:19` | `api/employees/me/ apps/accounts/urls.py:78` | `MyProfileView apps/accounts/views.py:6024` |
| DELETE | /api/employees/me/photo/ | OK | `features/profile/data/datasources/profile_remote_datasource.dart:39` | `api/employees/me/photo/ apps/accounts/urls.py:79` | `ProfilePhotoView apps/accounts/views_profile_photo.py:35` |
| POST | /api/employees/me/photo/ | OK | `features/profile/data/datasources/profile_remote_datasource.dart:33` | `api/employees/me/photo/ apps/accounts/urls.py:79` | `ProfilePhotoView apps/accounts/views_profile_photo.py:35` |
| GET | /api/expenses/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:27` | `api/expenses/ apps/hrms/urls.py:61` | `ExpenseListCreateView apps/hrms/views/expenses.py:72` |
| POST | /api/expenses/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:133` | `api/expenses/ apps/hrms/urls.py:61` | `ExpenseListCreateView apps/hrms/views/expenses.py:72` |
| GET | /api/expenses/PARAM/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:50` | `api/expenses/<int:expense_number>/ apps/hrms/urls.py:65` | `ExpenseDetailView apps/hrms/views/expenses.py:159` |
| PUT | /api/expenses/PARAM/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:59` | `api/expenses/<int:expense_number>/ apps/hrms/urls.py:65` | `ExpenseDetailView apps/hrms/views/expenses.py:159` |
| GET | /api/expenses/categories/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:72` | `api/expenses/categories/ apps/hrms/urls.py:62` | `ExpenseCategoryListView apps/hrms/views/expenses.py:344` |
| GET | /api/expenses/stats/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:101` | `api/expenses/stats/ apps/hrms/urls.py:64` | `ExpenseStatsView apps/hrms/views/expenses.py:366` |
| GET | /api/expenses/status/ | OK | `features/expenses/data/datasources/expense_remote_datasource.dart:85` | `api/expenses/status/ apps/hrms/urls.py:63` | `ExpenseStatusListView apps/hrms/views/expenses.py:355` |
| POST | /api/forgot-password/ | PAYLOAD MISMATCH | `features/auth/data/datasources/auth_remote_datasource.dart:39` | `api/forgot-password/ apps/accounts/urls.py:68` | `ForgotPasswordView apps/accounts/views.py:714` |
| GET | /api/leave/balance/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:25` | `api/leave/balance/ apps/hrms/urls.py:72` | `LeaveBalanceView apps/hrms/views/leave.py:659` |
| POST | /api/leave/balance/credit/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:346` | `api/leave/balance/credit/ apps/hrms/urls.py:73` | `LeaveBalanceView apps/hrms/views/leave.py:659` |
| POST | /api/leave/balance/import/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:576` | `api/leave/balance/import/ apps/hrms/urls.py:74` | `LeaveOpeningBalanceImportView apps/hrms/views/leave.py:2206` |
| GET | /api/leave/balance/import/sample/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:555` | `api/leave/balance/import/sample/ apps/hrms/urls.py:76` | `LeaveOpeningBalanceSampleView apps/hrms/views/leave.py:2289` |
| POST | /api/leave/balance/import/validate/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:568` | `api/leave/balance/import/validate/ apps/hrms/urls.py:75` | `LeaveOpeningBalanceValidateView apps/hrms/views/leave.py:2319` |
| GET | /api/leave/calendar/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:212` | `api/leave/calendar/ apps/hrms/urls.py:107` | `LeaveCalendarView apps/hrms/views/leave.py:1473` |
| GET | /api/leave/carry-forward/history/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:381` | `api/leave/carry-forward/history/ apps/hrms/urls.py:113` | `CarryForwardHistoryView apps/hrms/views/leave.py:1786` |
| POST | /api/leave/carry-forward/preview/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:365` | `api/leave/carry-forward/preview/ apps/hrms/urls.py:111` | `CarryForwardPreviewView apps/hrms/views/leave.py:1643` |
| POST | /api/leave/carry-forward/run/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:373` | `api/leave/carry-forward/run/ apps/hrms/urls.py:112` | `CarryForwardRunView apps/hrms/views/leave.py:1679` |
| GET | /api/leave/carry-forward/years/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:358` | `api/leave/carry-forward/years/ apps/hrms/urls.py:110` | `CarryForwardYearsView apps/hrms/views/leave.py:1616` |
| GET | /api/leave/holidays/ | OK | `features/settings/data/datasources/holiday_remote_datasource.dart:21` | `api/leave/holidays/ apps/hrms/urls.py:116` | `HolidayListCreateView apps/hrms/views/holidays.py:27` |
| POST | /api/leave/holidays/ | OK | `features/settings/data/datasources/holiday_remote_datasource.dart:31` | `api/leave/holidays/ apps/hrms/urls.py:116` | `HolidayListCreateView apps/hrms/views/holidays.py:27` |
| DELETE | /api/leave/holidays/PARAM/ | OK | `features/settings/data/datasources/holiday_remote_datasource.dart:46` | `api/leave/holidays/<str:holiday_id>/ apps/hrms/urls.py:117` | `HolidayDetailView apps/hrms/views/holidays.py:93` |
| PATCH | /api/leave/holidays/PARAM/ | OK | `features/settings/data/datasources/holiday_remote_datasource.dart:36` | `api/leave/holidays/<str:holiday_id>/ apps/hrms/urls.py:117` | `HolidayDetailView apps/hrms/views/holidays.py:93` |
| PATCH | /api/leave/holidays/PARAM/ | OK | `features/settings/data/datasources/holiday_remote_datasource.dart:41` | `api/leave/holidays/<str:holiday_id>/ apps/hrms/urls.py:117` | `HolidayDetailView apps/hrms/views/holidays.py:93` |
| GET | /api/leave/policy/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:15` | `api/leave/policy/ apps/hrms/urls.py:68` | `LeavePolicyView apps/hrms/views/leave.py:557` |
| GET | /api/leave/policy/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:309` | `api/leave/policy/ apps/hrms/urls.py:68` | `LeavePolicyView apps/hrms/views/leave.py:557` |
| POST | /api/leave/policy/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:328` | `api/leave/policy/ apps/hrms/urls.py:68` | `LeavePolicyView apps/hrms/views/leave.py:557` |
| DELETE | /api/leave/policy/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:338` | `api/leave/policy/<str:leave_type>/ apps/hrms/urls.py:69` | `LeavePolicyView apps/hrms/views/leave.py:557` |
| PUT | /api/leave/policy/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:318` | `api/leave/policy/<str:leave_type>/ apps/hrms/urls.py:69` | `LeavePolicyView apps/hrms/views/leave.py:557` |
| GET | /api/leave/requests/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:170` | `api/leave/requests/ apps/hrms/urls.py:94` | `LeaveRequestListCreateView apps/hrms/views/leave.py:877` |
| GET | /api/leave/requests/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:195` | `api/leave/requests/ apps/hrms/urls.py:94` | `LeaveRequestListCreateView apps/hrms/views/leave.py:877` |
| GET | /api/leave/requests/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:55` | `api/leave/requests/ apps/hrms/urls.py:94` | `LeaveRequestListCreateView apps/hrms/views/leave.py:877` |
| GET | /api/leave/requests/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:89` | `api/leave/requests/ apps/hrms/urls.py:94` | `LeaveRequestListCreateView apps/hrms/views/leave.py:877` |
| POST | /api/leave/requests/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:123` | `api/leave/requests/ apps/hrms/urls.py:94` | `LeaveRequestListCreateView apps/hrms/views/leave.py:877` |
| GET | /api/leave/requests/PARAM/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:131` | `api/leave/requests/<str:request_id>/ apps/hrms/urls.py:95` | `LeaveRequestDetailView apps/hrms/views/leave.py:1081` |
| PATCH | /api/leave/requests/PARAM/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:138` | `api/leave/requests/<str:request_id>/ apps/hrms/urls.py:95` | `LeaveRequestDetailView apps/hrms/views/leave.py:1081` |
| POST | /api/leave/requests/PARAM/approve/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:142` | `api/leave/requests/<str:request_id>/approve/ apps/hrms/urls.py:96` | `LeaveApprovalView apps/hrms/views/leave.py:1158` |
| POST | /api/leave/requests/PARAM/approve/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:149` | `api/leave/requests/<str:request_id>/approve/ apps/hrms/urls.py:96` | `LeaveApprovalView apps/hrms/views/leave.py:1158` |
| GET | /api/leave/stats/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:178` | `api/leave/stats/ apps/hrms/urls.py:106` | `LeaveStatsView apps/hrms/views/leave.py:1387` |
| GET | /api/leave/stats/ | OK | `features/leave/data/datasources/leave_remote_datasource.dart:35` | `api/leave/stats/ apps/hrms/urls.py:106` | `LeaveStatsView apps/hrms/views/leave.py:1387` |
| POST | /api/login/ | OK | `features/auth/data/datasources/auth_remote_datasource.dart:21` | `api/login/ apps/accounts/urls.py:65` | `LoginView apps/accounts/views.py:503` |
| POST | /api/logout/ | OK | `features/auth/data/datasources/auth_remote_datasource.dart:30` | `api/logout/ apps/accounts/urls.py:66` | `LogoutView apps/accounts/views.py:692` |
| GET | /api/notifications/ | OK | `features/notifications/data/datasources/notifications_remote_datasource.dart:11` | `api/notifications/ apps/notifications/urls.py:12` | `NotificationListView apps/notifications/views.py:16` |
| PATCH | /api/notifications/PARAM/read/ | OK | `features/notifications/data/datasources/notifications_remote_datasource.dart:25` | `api/notifications/<str:notification_id>/read/ apps/notifications/urls.py:16` | `NotificationMarkReadView apps/notifications/views.py:52` |
| PATCH | /api/notifications/read-all/ | OK | `features/notifications/data/datasources/notifications_remote_datasource.dart:29` | `api/notifications/read-all/ apps/notifications/urls.py:14` | `NotificationMarkAllReadView apps/notifications/views.py:66` |
| GET | /api/notifications/settings/ | OK | `features/notifications/data/datasources/notifications_remote_datasource.dart:33` | `api/notifications/settings/ apps/notifications/urls.py:15` | `NotificationSettingsView apps/notifications/views.py:75` |
| PATCH | /api/notifications/settings/ | OK | `features/notifications/data/datasources/notifications_remote_datasource.dart:38` | `api/notifications/settings/ apps/notifications/urls.py:15` | `NotificationSettingsView apps/notifications/views.py:75` |
| GET | /api/notifications/unread-count/ | OK | `features/notifications/data/datasources/notifications_remote_datasource.dart:19` | `api/notifications/unread-count/ apps/notifications/urls.py:13` | `NotificationUnreadCountView apps/notifications/views.py:44` |
| GET | /api/onboarding/ | OK | `features/onboarding/data/datasources/onboarding_datasource.dart:12` | `api/onboarding/ apps/accounts/urls.py:93` | `OnboardingView apps/accounts/views.py:4426` |
| POST | /api/onboarding/ | OK | `features/onboarding/data/datasources/onboarding_datasource.dart:76` | `api/onboarding/ apps/accounts/urls.py:93` | `OnboardingView apps/accounts/views.py:4426` |
| GET | /api/onboarding/approvals/ | OK | `features/candidate_review/data/datasources/approval_datasource.dart:10` | `api/onboarding/approvals/ apps/accounts/urls.py:99` | `OnboardingApprovalView apps/accounts/views.py:5551` |
| POST | /api/onboarding/approvals/PARAM/ | OK | `features/candidate_review/data/datasources/approval_datasource.dart:41` | `api/onboarding/approvals/<str:user_id>/ apps/accounts/urls.py:100` | `OnboardingApprovalView apps/accounts/views.py:5551` |
| GET | /api/onboarding/documents/ | OK | `features/onboarding/data/datasources/onboarding_datasource.dart:37` | `api/onboarding/documents/ apps/accounts/urls.py:95` | `EmployeeDocumentView apps/accounts/views.py:5087` |
| GET | /api/onboarding/documents/ | OK | `features/profile/data/datasources/profile_remote_datasource.dart:63` | `api/onboarding/documents/ apps/accounts/urls.py:95` | `EmployeeDocumentView apps/accounts/views.py:5087` |
| POST | /api/onboarding/documents/ | OK | `features/onboarding/data/datasources/onboarding_datasource.dart:52` | `api/onboarding/documents/ apps/accounts/urls.py:95` | `EmployeeDocumentView apps/accounts/views.py:5087` |
| DELETE | /api/onboarding/documents/PARAM/ | OK | `features/onboarding/data/datasources/onboarding_datasource.dart:71` | `api/onboarding/documents/<str:doc_id>/ apps/accounts/urls.py:96` | `EmployeeDocumentView apps/accounts/views.py:5087` |
| PATCH | /api/onboarding/step/PARAM/ | OK | `features/onboarding/data/datasources/onboarding_datasource.dart:26` | `api/onboarding/step/<int:step>/ apps/accounts/urls.py:94` | `OnboardingView apps/accounts/views.py:4426` |
| GET | /api/org-chart/ | OK | `features/org_chart/data/datasources/org_chart_remote_datasource.dart:13` | `api/org-chart/ apps/accounts/urls.py:114` | `OrgChartView apps/accounts/views.py:1540` |
| POST | /api/payroll/cycles/PARAM/approve-attendance/ | OK | `features/approvals/data/datasources/attendance_approval_remote_datasource.dart:81` | `api/payroll/cycles/<uuid:pk>/approve-attendance/ apps/payroll/urls.py:109` | `AttendanceApprovalView apps/payroll/views/cycles.py:739` |
| GET | /api/payroll/cycles/PARAM/attendance-daily/PARAM/ | OK | `features/approvals/data/datasources/attendance_approval_remote_datasource.dart:90` | `api/payroll/cycles/<uuid:pk>/attendance-daily/<str:employee_pk>/ apps/payroll/urls.py:97` | `CycleEmployeeDailyView apps/payroll/views/attendance_approval.py:196` |
| GET | /api/payroll/cycles/PARAM/attendance-summary/ | OK | `features/approvals/data/datasources/attendance_approval_remote_datasource.dart:40` | `api/payroll/cycles/<uuid:pk>/attendance-summary/ apps/payroll/urls.py:96` | `CycleAttendanceSummaryView apps/payroll/views/attendance_approval.py:92` |
| GET | /api/payroll/cycles/pending-approval/ | OK | `features/approvals/data/datasources/attendance_approval_remote_datasource.dart:32` | `api/payroll/cycles/pending-approval/ apps/payroll/urls.py:95` | `AttendancePendingCyclesView apps/payroll/views/attendance_approval.py:43` |
| GET | /api/payroll/my-payslips/ | OK | `features/payroll/data/datasources/payroll_remote_datasource.dart:21` | `api/payroll/my-payslips/ apps/payroll/urls.py:136` | `MyPayslipsView apps/payroll/views/payslips.py:392` |
| POST | /api/payroll/my-payslips/PARAM/acknowledge/ | OK | `features/payroll/data/datasources/payroll_remote_datasource.dart:37` | `api/payroll/my-payslips/<uuid:pk>/acknowledge/ apps/payroll/urls.py:137` | `AcknowledgePayslipView apps/payroll/views/payslips.py:413` |
| GET | /api/payroll/settings/ | OK | `features/approvals/data/datasources/attendance_approval_remote_datasource.dart:27` | `api/payroll/settings/ apps/payroll/urls.py:71` | `PayrollSettingsView apps/payroll/views/settings.py:13` |
| GET | /api/permissions/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:415` | `api/permissions/ apps/accounts/urls.py:122` | `PermissionListView apps/accounts/views.py:1132` |
| GET | /api/recruitment/candidates/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:32` | `api/recruitment/candidates/ apps/recruitment/urls.py:28` | `CandidateListCreateView apps/recruitment/views.py:353` |
| POST | /api/recruitment/candidates/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:51` | `api/recruitment/candidates/ apps/recruitment/urls.py:28` | `CandidateListCreateView apps/recruitment/views.py:353` |
| GET | /api/recruitment/candidates/PARAM/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:44` | `api/recruitment/candidates/<int:pk>/ apps/recruitment/urls.py:34` | `CandidateDetailView apps/recruitment/views.py:503` |
| PUT | /api/recruitment/candidates/PARAM/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:58` | `api/recruitment/candidates/<int:pk>/ apps/recruitment/urls.py:34` | `CandidateDetailView apps/recruitment/views.py:503` |
| POST | /api/recruitment/candidates/PARAM/resend-portal-login/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:100` | `api/recruitment/candidates/<int:pk>/resend-portal-login/ apps/recruitment/urls.py:39` | `ResendPortalLoginView apps/recruitment/views.py:1488` |
| POST | /api/recruitment/candidates/PARAM/send-email/ | OK | `features/employees/data/datasources/employees_remote_datasource.dart:338` | `api/recruitment/candidates/<str:pk>/send-email/ apps/recruitment/urls.py:37` | `SendCandidateEmailView apps/recruitment/views.py:1106` |
| POST | /api/recruitment/candidates/PARAM/send-email/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:86` | `api/recruitment/candidates/<str:pk>/send-email/ apps/recruitment/urls.py:37` | `SendCandidateEmailView apps/recruitment/views.py:1106` |
| POST | /api/recruitment/candidates/PARAM/send-portal-login/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:96` | `api/recruitment/candidates/<int:pk>/send-portal-login/ apps/recruitment/urls.py:38` | `SendPortalLoginView apps/recruitment/views.py:1349` |
| PATCH | /api/recruitment/candidates/PARAM/status/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:65` | `api/recruitment/candidates/<int:pk>/status/ apps/recruitment/urls.py:35` | `CandidateStatusView apps/recruitment/views.py:665` |
| POST | /api/recruitment/candidates/bulk-import/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:116` | `api/recruitment/candidates/bulk-import/ apps/recruitment/urls.py:29` | `CandidateBulkImportView apps/recruitment/views.py:2019` |
| GET | /api/recruitment/candidates/stats/ | OK | `features/interview_list/data/datasources/interview_datasource.dart:19` | `api/recruitment/candidates/stats/ apps/recruitment/urls.py:32` | `CandidateStatsView apps/recruitment/views.py:1253` |
| GET | /api/recruitment/emails/ | OK | `features/email_log/data/datasources/email_log_remote_datasource.dart:27` | `api/recruitment/emails/ apps/recruitment/urls.py:40` | `CandidateEmailLogView apps/recruitment/views.py:1052` |
| GET | /api/recruitment/referral-rules/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:80` | `api/recruitment/referral-rules/ apps/recruitment/urls.py:47` | `ReferralRuleListCreateView apps/recruitment/views.py:1699` |
| POST | /api/recruitment/referral-rules/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:96` | `api/recruitment/referral-rules/ apps/recruitment/urls.py:47` | `ReferralRuleListCreateView apps/recruitment/views.py:1699` |
| DELETE | /api/recruitment/referral-rules/PARAM/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:125` | `api/recruitment/referral-rules/<int:pk>/ apps/recruitment/urls.py:48` | `ReferralRuleDetailView apps/recruitment/views.py:1729` |
| PATCH | /api/recruitment/referral-rules/PARAM/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:114` | `api/recruitment/referral-rules/<int:pk>/ apps/recruitment/urls.py:48` | `ReferralRuleDetailView apps/recruitment/views.py:1729` |
| GET | /api/recruitment/referrals/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:33` | `api/recruitment/referrals/ apps/recruitment/urls.py:43` | `ReferralListCreateView apps/recruitment/views.py:1600` |
| POST | /api/recruitment/referrals/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:75` | `api/recruitment/referrals/ apps/recruitment/urls.py:43` | `ReferralListCreateView apps/recruitment/views.py:1600` |
| GET | /api/recruitment/referrals/all/ | OK | `features/referrals/data/datasources/referral_remote_datasource.dart:42` | `api/recruitment/referrals/all/ apps/recruitment/urls.py:44` | `ReferralAllView apps/recruitment/views.py:1659` |
| POST | /api/reset-password/ | PAYLOAD MISMATCH | `features/auth/data/datasources/auth_remote_datasource.dart:59` | `api/reset-password/ apps/accounts/urls.py:70` | `ResetPasswordView apps/accounts/views.py:828` |
| GET | /api/roles/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:450` | `api/roles/ apps/accounts/urls.py:118` | `RoleListCreateView apps/accounts/views.py:932` |
| POST | /api/roles/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:471` | `api/roles/ apps/accounts/urls.py:118` | `RoleListCreateView apps/accounts/views.py:932` |
| PUT | /api/roles/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:477` | `api/roles/<int:pk>/ apps/accounts/urls.py:119` | `RoleDetailView apps/accounts/views.py:982` |
| GET | /api/separation/reasons/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:29` | `api/separation/reasons/ apps/hrms/urls.py:121` | `SeparationReasonListView apps/hrms/views/separation.py:35` |
| GET | /api/separation/requests/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:56` | `api/separation/requests/ apps/hrms/urls.py:124` | `SeparationRequestListCreateView apps/hrms/views/separation.py:133` |
| POST | /api/separation/requests/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:92` | `api/separation/requests/ apps/hrms/urls.py:124` | `SeparationRequestListCreateView apps/hrms/views/separation.py:133` |
| DELETE | /api/separation/requests/PARAM/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:132` | `api/separation/requests/<str:request_id>/ apps/hrms/urls.py:125` | `SeparationRequestDetailView apps/hrms/views/separation.py:222` |
| GET | /api/separation/requests/PARAM/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:62` | `api/separation/requests/<str:request_id>/ apps/hrms/urls.py:125` | `SeparationRequestDetailView apps/hrms/views/separation.py:222` |
| PATCH | /api/separation/requests/PARAM/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:117` | `api/separation/requests/<str:request_id>/ apps/hrms/urls.py:125` | `SeparationRequestDetailView apps/hrms/views/separation.py:222` |
| PATCH | /api/separation/requests/PARAM/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:124` | `api/separation/requests/<str:request_id>/ apps/hrms/urls.py:125` | `SeparationRequestDetailView apps/hrms/views/separation.py:222` |
| GET | /api/separation/requests/PARAM/activities/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:273` | `api/separation/requests/<str:request_id>/activities/ apps/hrms/urls.py:146` | `SeparationActivityListView apps/hrms/views/separation_workflow.py:331` |
| GET | /api/separation/requests/PARAM/clearances/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:211` | `api/separation/requests/<str:request_id>/clearances/ apps/hrms/urls.py:138` | `SeparationClearanceListView apps/hrms/views/separation_workflow.py:220` |
| POST | /api/separation/requests/PARAM/clearances/PARAM/action/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:223` | `api/separation/requests/<str:request_id>/clearances/<str:clearance_id>/action/ apps/hrms/urls.py:139` | `SeparationClearanceActionView apps/hrms/views/separation_workflow.py:231` |
| GET | /api/separation/requests/PARAM/documents/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:238` | `api/separation/requests/<str:request_id>/documents/ apps/hrms/urls.py:142` | `SeparationDocumentListCreateView apps/hrms/views/separation_workflow.py:276` |
| POST | /api/separation/requests/PARAM/documents/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:253` | `api/separation/requests/<str:request_id>/documents/ apps/hrms/urls.py:142` | `SeparationDocumentListCreateView apps/hrms/views/separation_workflow.py:276` |
| POST | /api/separation/requests/PARAM/stages/PARAM/action/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:143` | `api/separation/requests/<str:request_id>/stages/<str:stage_id>/action/ apps/hrms/urls.py:128` | `SeparationApprovalStageActionView apps/hrms/views/separation_workflow.py:64` |
| GET | /api/separation/requests/PARAM/tasks/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:158` | `api/separation/requests/<str:request_id>/tasks/ apps/hrms/urls.py:134` | `SeparationHandoverTaskListCreateView apps/hrms/views/separation_workflow.py:115` |
| POST | /api/separation/requests/PARAM/tasks/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:174` | `api/separation/requests/<str:request_id>/tasks/ apps/hrms/urls.py:134` | `SeparationHandoverTaskListCreateView apps/hrms/views/separation_workflow.py:115` |
| DELETE | /api/separation/requests/PARAM/tasks/PARAM/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:204` | `api/separation/requests/<str:request_id>/tasks/<str:task_id>/ apps/hrms/urls.py:135` | `SeparationHandoverTaskDetailView apps/hrms/views/separation_workflow.py:158` |
| PATCH | /api/separation/requests/PARAM/tasks/PARAM/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:194` | `api/separation/requests/<str:request_id>/tasks/<str:task_id>/ apps/hrms/urls.py:135` | `SeparationHandoverTaskDetailView apps/hrms/views/separation_workflow.py:158` |
| GET | /api/separation/types/ | OK | `features/separation/data/datasources/separation_remote_datasource.dart:22` | `api/separation/types/ apps/hrms/urls.py:120` | `SeparationTypeListView apps/hrms/views/separation.py:27` |
| GET | /api/settings/approval-rules/ | OK | `features/settings/data/datasources/approval_rules_remote_datasource.dart:10` | `api/settings/approval-rules/ apps/accounts/urls.py:131` | `ApprovalWorkflowRuleView apps/accounts/views.py:6291` |
| PATCH | /api/settings/approval-rules/ | OK | `features/settings/data/datasources/approval_rules_remote_datasource.dart:21` | `api/settings/approval-rules/ apps/accounts/urls.py:131` | `ApprovalWorkflowRuleView apps/accounts/views.py:6291` |
| GET | /api/settings/audit/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:489` | `api/settings/audit/ apps/accounts/urls.py:134` | `AuditLogListView apps/accounts/views.py:4096` |
| GET | /api/settings/company/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:24` | `api/settings/company/ apps/accounts/urls.py:126` | `CompanyRetrieveUpdateView apps/accounts/views.py:2821` |
| PUT | /api/settings/company/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:39` | `api/settings/company/ apps/accounts/urls.py:126` | `CompanyRetrieveUpdateView apps/accounts/views.py:2821` |
| PUT | /api/settings/company/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:41` | `api/settings/company/ apps/accounts/urls.py:126` | `CompanyRetrieveUpdateView apps/accounts/views.py:2821` |
| GET | /api/settings/company/financial-year/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:49` | `api/settings/company/financial-year/ apps/accounts/urls.py:127` | `CompanyFinancialYearView apps/accounts/views.py:2899` |
| PUT | /api/settings/company/financial-year/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:57` | `api/settings/company/financial-year/ apps/accounts/urls.py:127` | `CompanyFinancialYearView apps/accounts/views.py:2899` |
| GET | /api/settings/document-types/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:278` | `api/settings/document-types/ apps/accounts/urls.py:107` | `DocumentTypeConfigView apps/accounts/views.py:4970` |
| POST | /api/settings/document-types/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:285` | `api/settings/document-types/ apps/accounts/urls.py:107` | `DocumentTypeConfigView apps/accounts/views.py:4970` |
| DELETE | /api/settings/document-types/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:299` | `api/settings/document-types/<str:type_key>/ apps/accounts/urls.py:108` | `DocumentTypeConfigView apps/accounts/views.py:4970` |
| PATCH | /api/settings/document-types/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:291` | `api/settings/document-types/<str:type_key>/ apps/accounts/urls.py:108` | `DocumentTypeConfigView apps/accounts/views.py:4970` |
| GET | /api/settings/email-template-categories/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:132` | `api/settings/email-template-categories/ apps/accounts/urls.py:143` | `EmailTemplateCategoryListCreateView apps/accounts/views.py:1956` |
| POST | /api/settings/email-template-categories/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:142` | `api/settings/email-template-categories/ apps/accounts/urls.py:143` | `EmailTemplateCategoryListCreateView apps/accounts/views.py:1956` |
| GET | /api/settings/email-templates/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:151` | `api/settings/email-templates/ apps/accounts/urls.py:147` | `EmailTemplateListCreateView apps/accounts/views.py:2052` |
| POST | /api/settings/email-templates/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:172` | `api/settings/email-templates/ apps/accounts/urls.py:147` | `EmailTemplateListCreateView apps/accounts/views.py:2052` |
| DELETE | /api/settings/email-templates/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:192` | `api/settings/email-templates/<int:pk>/ apps/accounts/urls.py:148` | `EmailTemplateDetailView apps/accounts/views.py:2119` |
| DELETE | /api/settings/email-templates/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:215` | `api/settings/email-templates/<int:pk>/ apps/accounts/urls.py:148` | `EmailTemplateDetailView apps/accounts/views.py:2119` |
| PATCH | /api/settings/email-templates/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:180` | `api/settings/email-templates/<int:pk>/ apps/accounts/urls.py:148` | `EmailTemplateDetailView apps/accounts/views.py:2119` |
| PATCH | /api/settings/email-templates/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:187` | `api/settings/email-templates/<int:pk>/ apps/accounts/urls.py:148` | `EmailTemplateDetailView apps/accounts/views.py:2119` |
| POST | /api/settings/email-templates/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:206` | `api/settings/email-templates/<int:pk>/ apps/accounts/urls.py:148` | `EmailTemplateDetailView apps/accounts/views.py:2119` |
| GET | /api/settings/employee-code/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:68` | `api/settings/employee-code/ apps/accounts/urls.py:130` | `EmployeeCodeSettingsView apps/accounts/views.py:4167` |
| PUT | /api/settings/employee-code/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:74` | `api/settings/employee-code/ apps/accounts/urls.py:130` | `EmployeeCodeSettingsView apps/accounts/views.py:4167` |
| GET | /api/settings/onboarding-fields/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:250` | `api/settings/onboarding-fields/ apps/accounts/urls.py:105` | `OnboardingFieldConfigView apps/accounts/views.py:4835` |
| POST | /api/settings/onboarding-fields/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:258` | `api/settings/onboarding-fields/ apps/accounts/urls.py:105` | `OnboardingFieldConfigView apps/accounts/views.py:4835` |
| DELETE | /api/settings/onboarding-fields/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:272` | `api/settings/onboarding-fields/<str:field_key>/ apps/accounts/urls.py:106` | `OnboardingFieldConfigView apps/accounts/views.py:4835` |
| PATCH | /api/settings/onboarding-fields/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:264` | `api/settings/onboarding-fields/<str:field_key>/ apps/accounts/urls.py:106` | `OnboardingFieldConfigView apps/accounts/views.py:4835` |
| GET | /api/settings/smtp/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:85` | `api/settings/smtp/ apps/accounts/urls.py:137` | `SMTPSettingsListCreateView apps/accounts/views.py:1775` |
| POST | /api/settings/smtp/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:93` | `api/settings/smtp/ apps/accounts/urls.py:137` | `SMTPSettingsListCreateView apps/accounts/views.py:1775` |
| DELETE | /api/settings/smtp/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:111` | `api/settings/smtp/<int:pk>/ apps/accounts/urls.py:138` | `SMTPSettingsDetailView apps/accounts/views.py:1819` |
| PUT | /api/settings/smtp/PARAM/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:99` | `api/settings/smtp/<int:pk>/ apps/accounts/urls.py:138` | `SMTPSettingsDetailView apps/accounts/views.py:1819` |
| POST | /api/settings/smtp/PARAM/activate/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:107` | `api/settings/smtp/<int:pk>/activate/ apps/accounts/urls.py:139` | `SMTPActivateView apps/accounts/views.py:1903` |
| POST | /api/settings/smtp/test/ | OK | `features/settings/data/datasources/settings_remote_datasource.dart:116` | `api/settings/smtp/test/ apps/accounts/urls.py:140` | `SMTPTestEmailView apps/accounts/views.py:1930` |
| POST | /api/token/refresh/ | OK | `core/network/auth_interceptor.dart:103` | `api/token/refresh/ apps/accounts/urls.py:67` | `TokenRefreshAPIView apps/accounts/views.py:628` |
| POST | /api/verify-otp/ | PAYLOAD MISMATCH | `features/auth/data/datasources/auth_remote_datasource.dart:47` | `api/verify-otp/ apps/accounts/urls.py:69` | `VerifyOTPView apps/accounts/views.py:768` |
| POST | /api/voice/parse/ | OK | `features/voice_commands/data/datasources/voice_remote_datasource.dart:40` | `api/voice/parse/ apps/voice_commands/urls.py:8` | `VoiceParseView apps/voice_commands/views.py:22` |
| POST | /api/voice/speak/ | OK | `features/voice_commands/data/datasources/voice_remote_datasource.dart:105` | `api/voice/speak/ apps/voice_commands/urls.py:10` | `VoiceSpeakView apps/voice_commands/views_speak.py:57` |
| POST | /api/voice/transcribe-fallback/ | OK | `features/voice_commands/data/datasources/voice_remote_datasource.dart:82` | `api/voice/transcribe-fallback/ apps/voice_commands/urls.py:9` | `VoiceTranscribeFallbackView apps/voice_commands/views_transcribe.py:96` |
| GET | /api/wfh/requests/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:20` | `api/wfh/requests/ apps/hrms/urls.py:99` | `WorkFromHomeRequestListCreateView apps/hrms/views/workfromhome.py:110` |
| GET | /api/wfh/requests/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:51` | `api/wfh/requests/ apps/hrms/urls.py:99` | `WorkFromHomeRequestListCreateView apps/hrms/views/workfromhome.py:110` |
| POST | /api/wfh/requests/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:83` | `api/wfh/requests/ apps/hrms/urls.py:99` | `WorkFromHomeRequestListCreateView apps/hrms/views/workfromhome.py:110` |
| GET | /api/wfh/requests/PARAM/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:57` | `api/wfh/requests/<str:request_id>/ apps/hrms/urls.py:100` | `WorkFromHomeRequestDetailView apps/hrms/views/workfromhome.py:215` |
| PATCH | /api/wfh/requests/PARAM/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:91` | `api/wfh/requests/<str:request_id>/ apps/hrms/urls.py:100` | `WorkFromHomeRequestDetailView apps/hrms/views/workfromhome.py:215` |
| POST | /api/wfh/requests/PARAM/approve/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:104` | `api/wfh/requests/<str:request_id>/approve/ apps/hrms/urls.py:101` | `WorkFromHomeApprovalView apps/hrms/views/workfromhome.py:265` |
| POST | /api/wfh/requests/PARAM/approve/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:97` | `api/wfh/requests/<str:request_id>/approve/ apps/hrms/urls.py:101` | `WorkFromHomeApprovalView apps/hrms/views/workfromhome.py:265` |
| GET | /api/wfh/saved-locations/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:111` | `api/wfh/saved-locations/ apps/hrms/urls.py:102` | `WFHSavedLocationListCreateView apps/hrms/views/wfh_saved_locations.py:11` |
| POST | /api/wfh/saved-locations/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:127` | `api/wfh/saved-locations/ apps/hrms/urls.py:102` | `WFHSavedLocationListCreateView apps/hrms/views/wfh_saved_locations.py:11` |
| DELETE | /api/wfh/saved-locations/PARAM/ | OK | `features/wfh/data/datasources/wfh_remote_datasource.dart:137` | `api/wfh/saved-locations/<uuid:location_id>/ apps/hrms/urls.py:103` | `WFHSavedLocationDetailView apps/hrms/views/wfh_saved_locations.py:41` |

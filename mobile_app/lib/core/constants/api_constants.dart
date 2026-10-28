import '../config/api_config.dart';

class ApiConstants {
  ApiConstants._();

  // The base URL itself is centralized in ApiConfig (core/config/api_config.dart)
  // — change ApiConfig.current there to switch environments; nothing here or
  // at any call site needs to change. Kept as a getter (not reassigned) so
  // every existing `ApiConstants.baseUrl` call site keeps working unchanged.
  //
  // nginx proxies /api/ to Django on the production host (see the server's
  // nginx config), so this must keep the /api suffix or requests fall
  // through to the Next.js frontend block instead of the Django API and
  // come back as HTML, not JSON.
  static String get baseUrl => ApiConfig.baseUrl;

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  // Was previously unset (Dio defaults to no send timeout at all), which let
  // an upload (documents, bulk import, facial-recognition capture) hang
  // indefinitely on a dead connection instead of failing recoverably.
  static const Duration sendTimeout = Duration(seconds: 30);

  // Auth endpoints
  static const String login = '/login/';
  static const String logout = '/logout/';
  static const String tokenRefresh = '/token/refresh/';
  static const String forgotPassword = '/forgot-password/';
  static const String verifyOtp = '/verify-otp/';
  static const String resetPassword = '/reset-password/';
  static const String changePassword = '/change-password/';

  // Settings — Company
  static const String settingsCompany = '/settings/company/';
  static const String settingsCompanyFinancialYear =
      '/settings/company/financial-year/';

  // Settings — Employee Code
  static const String settingsEmployeeCode = '/settings/employee-code/';

  // Settings — Approval Rules (GET/PATCH require hr_admin/system_admin —
  // CanManageRoles on backend, not a settings.view/edit permission codename).
  // PATCH targets this same collection URL; the row to update is identified
  // by `workflow_type` in the request body, not a path segment.
  static const String settingsApprovalRules = '/settings/approval-rules/';

  // Settings — SMTP
  static const String settingsSmtp = '/settings/smtp/';
  static String settingsSmtpDetail(int id) => '/settings/smtp/$id/';
  static String settingsSmtpActivate(int id) => '/settings/smtp/$id/activate/';
  static const String settingsSmtpTest = '/settings/smtp/test/';

  // Settings — Email Templates
  static const String settingsEmailTemplates = '/settings/email-templates/';
  static String settingsEmailTemplateDetail(int id) =>
      '/settings/email-templates/$id/';
  static String settingsEmailTemplatePreview(int id) =>
      '/settings/email-templates/$id/preview/';
  static const String settingsEmailTemplateCategories =
      '/settings/email-template-categories/';

  // Settings — Departments / Designations
  static const String departments = '/departments/';
  static String departmentDetail(int id) => '/departments/$id/';
  static const String designations = '/designations/';
  static String designationDetail(int id) => '/designations/$id/';

  // Settings — Roles & Permissions
  static const String roles = '/roles/';
  static String roleDetail(dynamic id) => '/roles/$id/';
  static const String permissions = '/permissions/';

  // Settings — Audit Log
  static const String settingsAudit = '/settings/audit/';

  // Settings — Onboarding Fields (steps 0-3) & Document Types (step 4) —
  // matches backend OnboardingFieldConfigView / DocumentTypeConfigView.
  static const String settingsOnboardingFields = '/settings/onboarding-fields/';
  static String settingsOnboardingFieldDetail(String fieldKey) =>
      '/settings/onboarding-fields/$fieldKey/';
  static const String settingsDocumentTypes = '/settings/document-types/';
  static String settingsDocumentTypeDetail(String typeKey) =>
      '/settings/document-types/$typeKey/';

  // Organisation Chart
  static const String orgChart = '/org-chart/';

  // Employees
  static const String employees = '/employees/';
  static const String employeeBulkImport = '/employees/bulk-import/';
  static String employeeDetail(String employeeId) => '/employees/$employeeId/';

  // Employees — per-employee Approval Matrix (GET list of workflow rows /
  // PATCH a single row's L1/L2 override). Matches backend
  // EmployeeApprovalMatrixView.
  static String employeeApprovalMatrix(String employeeId) =>
      '/employees/$employeeId/approval-matrix/';

  // Employees — Approval Matrix tab's "Reporting Relationships" quick-edit
  // (Reporting Manager + Branch HR), distinct from the full Edit Employee
  // sheet's REPORTING & HR section.
  static String employeeReportingManager(String employeeId) =>
      '/employees/$employeeId/reporting-manager/';
  static String employeeHrAssign(String employeeId) =>
      '/employees/$employeeId/hr/';

  // Employees — HR/admin document upload (matches backend
  // EmployeeDocumentAdminView, distinct from the self-service onboarding
  // upload endpoint since it isn't restricted to the onboarding window).
  static String employeeDocuments(String employeeId) =>
      '/employees/$employeeId/documents/';

  // My Profile (self-service) — matches backend MyProfileView
  static const String myProfile = '/employees/me/';

  // My Profile photo (self-service) — matches backend ProfilePhotoView
  static const String myProfilePhoto = '/employees/me/photo/';

  // Announcements
  static const String announcements = '/announcements/';
  static String announcementDetail(String id) => '/announcements/$id/';
  static String announcementReact(String id) => '/announcements/$id/react/';
  static String announcementView(String id) => '/announcements/$id/view/';

  // Document Center
  static const String documentStats = '/documents/stats/';
  static const String documents = '/documents/';
  static String documentDetail(int id) => '/documents/$id/';

  // Candidates / Interview List
  static const String candidateStats = '/recruitment/candidates/stats/';
  static const String candidates = '/recruitment/candidates/';
  static String candidateDetail(int id) => '/recruitment/candidates/$id/';
  static String candidateStatus(int id) =>
      '/recruitment/candidates/$id/status/';
  static String candidateSendLogin(int id) =>
      '/recruitment/candidates/$id/send-portal-login/';
  static String candidateResendLogin(int id) =>
      '/recruitment/candidates/$id/resend-portal-login/';
  static const String candidateBulkImport = '/recruitment/candidates/bulk-import/';
  // Accepts either the numeric candidate pk or the human-readable employee
  // code (e.g. "EMP0001") — SendCandidateEmailView falls back to
  // `portal_user__employee_id` when the path segment isn't purely digits.
  static String candidateSendEmail(String id) =>
      '/recruitment/candidates/$id/send-email/';

  // Email Log — matches backend /api/recruitment/emails/ (apps/recruitment/
  // urls.py). This is the ONLY email-logging feature in the backend; it is
  // Recruitment-scoped (candidate emails only) and gated on recruitment.view
  // — there is no general HRMS-wide email log.
  static const String emailLogs = '/recruitment/emails/';

  // Referrals — matches backend /api/recruitment/referrals/...
  static const String referrals =
      '/recruitment/referrals/'; // GET (mine) / POST (create)
  static const String referralsAll =
      '/recruitment/referrals/all/'; // GET, requires recruitment.view
  static const String referralRules =
      '/recruitment/referral-rules/'; // GET (any user) / POST (requires settings.view)
  static String referralRuleDetail(int id) =>
      '/recruitment/referral-rules/$id/'; // PATCH / DELETE, requires settings.view

  // Assessments (HR admin management) — matches backend /api/assessments/...
  static const String assessments = '/assessments/';
  static String assessmentDetail(String id) => '/assessments/$id/';
  static String assessmentItems(String assessmentId) =>
      '/assessments/$assessmentId/items/';
  static String assessmentItemDetail(String itemId) =>
      '/assessments/items/$itemId/';
  static const String assessmentAssign = '/assessments/assign/';
  static const String assessmentEmailTemplateOptions =
      '/assessments/email-template-options/';

  // Settings — Assessment Config (singleton) — matches backend /api/assessments/settings/
  static const String settingsAssessmentConfig =
      '/assessments/settings/'; // GET (assessments.view) / PUT (assessments.edit)

  // Payroll cycle endpoints (apps/payroll) — the admin-facing Payroll module
  // (run payroll, payroll rules) was removed from mobile, but the Attendance
  // Approval tab still gates its L1/L2 sign-off flow on the backend's
  // payroll cycles, so these stay.
  static const String payrollSettings = '/payroll/settings/';
  static String payrollApproveAttendance(String id) => '/payroll/cycles/$id/approve-attendance/';
  static const String payrollPendingApproval = '/payroll/cycles/pending-approval/';
  static String payrollAttendanceSummary(String cycleId) => '/payroll/cycles/$cycleId/attendance-summary/';
  static String payrollEmployeeDailyAttendance(String cycleId, String employeeId) =>
      '/payroll/cycles/$cycleId/attendance-daily/$employeeId/';

  // Payroll — My Payslips (employee-facing only). Gated server-side on the
  // 'payroll.view_own' permission (seeded for every role — see
  // apps/accounts/migrations/0043_seed_payroll_view_own_permission.py), not
  // on anything checked client-side. There is no PDF-generation endpoint
  // anywhere in apps/payroll — EmployeePayslip.payslip_pdf is a FileField
  // nothing ever populates, on web or here, so there's no "download" call to
  // wire up; don't add one without new backend work first.
  static const String myPayslips = '/payroll/my-payslips/';
  static String acknowledgePayslip(String id) => '/payroll/my-payslips/$id/acknowledge/';
  static String payslipDetail(String id) => '/payroll/payslips/$id/';

  // Holiday Calendar — matches backend /api/leave/holidays/
  static const String holidays = '/leave/holidays/';
  static String holidayDetail(String id) => '/leave/holidays/$id/';

  // Branch management
  static const String branchStates = '/branch/states/';
  static String branchCities(int stateId) => '/branch/states/$stateId/cities/';
  static const String branchPreviewCode = '/branch/branches/preview-code/';
  static const String branchStats = '/branch/branches/stats/';
  static const String branchDistribution = '/branch/branches/distribution/';
  static const String branches = '/branch/branches/';
  static String branchDetail(int id) => '/branch/branches/$id/';

  // Employee Onboarding
  static const String onboardingProfile = '/onboarding/';
  static String onboardingStep(int step) => '/onboarding/step/$step/';
  static const String onboardingDocuments = '/onboarding/documents/';
  static String onboardingDocumentDetail(int id) =>
      '/onboarding/documents/$id/';

  // Onboarding Approvals (HR)
  static const String onboardingApprovals = '/onboarding/approvals/';
  static String onboardingApprove(String userId) =>
      '/onboarding/approvals/$userId/';

  // Leave management — paths match backend /api/leave/...
  static const String leaveTypes = '/leave/policy/';
  static const String leaveBalances = '/leave/balance/';
  static const String leaveStats = '/leave/stats/';
  static const String leaves = '/leave/requests/';
  static const String leaveCalendar = '/leave/calendar/';
  static String leaveDetail(dynamic id) => '/leave/requests/$id/';
  static String leaveAction(dynamic id) => '/leave/requests/$id/approve/';
  static String leavePolicyDetail(String leaveType) =>
      '/leave/policy/$leaveType/';
  static const String leaveBalanceCredit = '/leave/balance/credit/';

  // Separation & Exit — matches backend /api/separation/... (apps/hrms/urls.py).
  // The mobile/web user-facing name is "Separation & Exit"; the backend model
  // and these paths keep their original "separation" naming (there never was
  // an "fnf" URL prefix — see apps/hrms/models.py SeparationRequest) so no
  // renaming is needed here for backend compatibility.
  static const String separationTypes = '/separation/types/';
  static const String separationReasons = '/separation/reasons/';
  static const String separationRequests = '/separation/requests/';
  static String separationRequestDetail(String id) =>
      '/separation/requests/$id/';
  static String separationStageAction(String requestId, String stageId) =>
      '/separation/requests/$requestId/stages/$stageId/action/';
  static String separationTasks(String requestId) =>
      '/separation/requests/$requestId/tasks/';
  static String separationTaskDetail(String requestId, String taskId) =>
      '/separation/requests/$requestId/tasks/$taskId/';
  static String separationClearances(String requestId) =>
      '/separation/requests/$requestId/clearances/';
  static String separationClearanceAction(
          String requestId, String clearanceId) =>
      '/separation/requests/$requestId/clearances/$clearanceId/action/';
  static String separationDocuments(String requestId) =>
      '/separation/requests/$requestId/documents/';
  static String separationDocumentDetail(
          String requestId, String documentId) =>
      '/separation/requests/$requestId/documents/$documentId/';
  static String separationActivities(String requestId) =>
      '/separation/requests/$requestId/activities/';

  // Work From Home — matches backend /api/wfh/... (apps/hrms/urls.py).
  static const String wfhRequests = '/wfh/requests/';
  static String wfhRequestDetail(dynamic id) => '/wfh/requests/$id/';
  static String wfhRequestAction(dynamic id) => '/wfh/requests/$id/approve/';
  static const String wfhSavedLocations = '/wfh/saved-locations/';
  static String wfhSavedLocationDetail(dynamic id) =>
      '/wfh/saved-locations/$id/';

  // Opening Balance & History bulk import (one-time historical migration
  // tool) — matches web's API.leave.balanceImport*.
  static const String leaveBalanceImport = '/leave/balance/import/';
  static const String leaveBalanceImportValidate = '/leave/balance/import/validate/';
  static const String leaveBalanceImportSample = '/leave/balance/import/sample/';

  // Carry Forward execution (year-range batch job) — matches web's
  // API.leave.carryForward.*. NOTE: as of this writing these routes do not
  // exist in the backend (apps/hrms/urls.py has no carry-forward paths at
  // all), so calls here 404 on the real server exactly as they do on web —
  // this mirrors web's own (currently non-functional) feature, not a mobile
  // gap. See LeaveCarryForwardTab's doc comment.
  static const String carryForwardYears = '/leave/carry-forward/years/';
  static const String carryForwardPreview = '/leave/carry-forward/preview/';
  static const String carryForwardRun = '/leave/carry-forward/run/';
  static const String carryForwardHistory = '/leave/carry-forward/history/';

  // Expenses
  static const String expenses = '/expenses/';
  static const String expenseStats = '/expenses/stats/';
  static const String expenseCategories = '/expenses/categories/';
  static const String expenseStatusList = '/expenses/status/';
  static String expenseDetail(dynamic expenseNumber) =>
      '/expenses/$expenseNumber/';

  // Attendance — My Attendance (employee self-service), matches backend /api/attendance/...
  // geofence-check is a read-only pre-punch validation (views/geofence_check.py)
  // — the SAME GeofencingService.validate() the punch itself re-runs
  // authoritatively; this lets the clock-in UI reject an out-of-geofence
  // attempt before ever opening face capture, without writing anything.
  static const String attendanceGeofenceCheck = '/attendance/geofence-check/';
  static const String attendancePunch = '/attendance/punch/';
  static const String attendanceToday = '/attendance/today/';
  static const String attendanceStats = '/attendance/stats/';
  static const String attendanceSummary = '/attendance/summary/';
  static const String attendanceCalendar = '/attendance/calendar/';
  static const String attendanceCorrection = '/attendance/correction/';

  // Notifications — matches backend /api/notifications/...
  static const String notifications = '/notifications/';
  static const String notificationsUnreadCount = '/notifications/unread-count/';
  static const String notificationsReadAll = '/notifications/read-all/';
  static String notificationRead(String id) => '/notifications/$id/read/';
  static const String notificationSettings = '/notifications/settings/';

  // HRMS — Birthdays widget (hrms app is mounted at the API root, not
  // under a '/hrms/' prefix — see config/urls.py: path('api/', include('apps.hrms.urls')))
  static const String hrmsBirthdays = '/birthdays/';

  // Attendance — HR admin management
  static const String attendanceDashboard = '/attendance/dashboard/';
  static const String attendanceRecords = '/attendance/records/';
  static const String attendanceRecordCreate = '/attendance/records/create/';
  static String attendanceRecordDetail(String id) => '/attendance/records/$id/';
  static const String attendanceReprocess = '/attendance/reprocess/';
  static const String attendanceOvertimeList = '/attendance/overtime/';
  static const String attendanceOvertimeCreate = '/attendance/overtime/create/';
  static const String attendanceInvalidPunches = '/attendance/invalid-punches/';
  static const String attendanceUnpunches = '/attendance/un-punches/';
  static const String attendanceHrCorrections = '/attendance/corrections/';
  static String attendanceHrCorrectionReview(String id) =>
      '/attendance/corrections/$id/review/';

  // Attendance — employee's own correction-request history (status +
  // L1/L2 approver breakdown), distinct from the HR inbox above.
  static const String attendanceMyCorrections = '/attendance/corrections/my/';

  // Attendance — Invalid Punch actions (assign/discard/convert)
  static String attendanceInvalidPunchAssign(String id) =>
      '/attendance/invalid-punches/$id/assign/';
  static String attendanceInvalidPunchDiscard(String id) =>
      '/attendance/invalid-punches/$id/discard/';
  static String attendanceInvalidPunchConvert(String id) =>
      '/attendance/invalid-punches/$id/convert/';

  // Attendance — Export / Import
  static const String attendanceExport = '/attendance/export/';
  static const String attendanceImport = '/attendance/import/';
  static const String attendanceImportSample = '/attendance/import/sample/';

  // Attendance — Record audit history
  static String attendanceRecordAudit(String id) =>
      '/attendance/records/$id/audit/';

  // Employees — HR users list (for the Invalid Punch "Assign" picker, and the
  // Edit Employee sheet's HR contact picker)
  static const String employeesHrList = '/employees/hrs/';

  // Employees — Manager users list (for the Edit Employee sheet's reporting
  // manager picker). Backend REQUIRES the `branch` query param.
  static const String employeesManagerList = '/employees/managers/';

  // Settings — Attendance Rules (singleton org-wide settings, 6 sections) —
  // matches backend GET/PUT/PATCH /api/attendance/settings/. Requires
  // settings.view for all three verbs (a backend inconsistency — PUT/PATCH
  // should require settings.edit but don't; not something to fix client-side).
  static const String attendanceSettings = '/attendance/settings/';

  // Dashboard app — role-specific widgets, matches backend apps/dashboard.
  // All views require IsAuthenticated; the system-admin/hr ones additionally
  // role-gate inside the view (role.name == 'system_admin', or in
  // ('hr','system_admin')) rather than via a permission codename — a 403
  // there means the account's role doesn't match, not a missing permission.
  // Employee-scoped ones (employee/*) have no extra role gate — any
  // authenticated user gets their own data.
  static const String dashboardSystemAdminKpis = '/dashboard/system-admin/kpis/';
  static const String dashboardSystemAdminAnnouncement =
      '/dashboard/system-admin/announcement/';
  static const String dashboardSystemAdminPendingApprovals =
      '/dashboard/system-admin/pending-approvals/';
  static const String dashboardSystemAdminDepartmentHeadcount =
      '/dashboard/system-admin/department-headcount/';
  static const String dashboardSystemAdminEmployeeLifecycle =
      '/dashboard/system-admin/employee-lifecycle/';
  static const String dashboardSystemAdminBirthdaysToday =
      '/dashboard/system-admin/birthdays/today/';
  static const String dashboardSystemAdminBirthdaysUpcoming =
      '/dashboard/system-admin/birthdays/upcoming/';
  static const String dashboardSystemAdminAuditLogs =
      '/dashboard/system-admin/audit-logs/';

  static const String dashboardHrKpis = '/dashboard/hr/kpis/';
  static const String dashboardHrAttendanceSummary =
      '/dashboard/hr/attendance-summary/';
  static const String dashboardHrActionQueue = '/dashboard/hr/action-queue/';
  static const String dashboardHrRecruitmentFunnel =
      '/dashboard/hr/recruitment-funnel/';
  static const String dashboardHrEmployeeLifecycle =
      '/dashboard/hr/employee-lifecycle/';
  static const String dashboardHrBirthdaysToday =
      '/dashboard/hr/birthdays/today/';
  static const String dashboardHrBirthdaysUpcoming =
      '/dashboard/hr/birthdays/upcoming/';
  static const String dashboardHrDepartmentHeadcount =
      '/dashboard/department-headcount/';

  static const String dashboardEmployeeKpis = '/dashboard/employee/kpis/';
  static const String dashboardEmployeeLeaveBalances =
      '/dashboard/employee/leave-balances/';
  static const String dashboardEmployeeActionItems =
      '/dashboard/employee/action-items/';
  static const String dashboardEmployeeRecentRequests =
      '/dashboard/employee/recent-requests/';
  static const String dashboardEmployeeAttendanceSummary =
      '/dashboard/employee/attendance-summary/';
  static const String dashboardEmployeeAttendanceStatus =
      '/dashboard/employee/attendance-status/';

  // Shared announcement (no role gate) — matches web's EmpAnnouncement.
  static const String dashboardAnnouncement = '/dashboard/announcement/';

  // Voice Commands — matches backend apps/voice_commands (single endpoint,
  // dispatches every intent server-side; see registry/intents_en.yaml for
  // the full intent list).
  static const String voiceParse = '/voice/parse/';
  // Backend TTS reply (apps/voice_commands/views_speak.py) — JSON in
  // ({text, language_code}), raw audio/wav bytes out on success.
  static const String voiceSpeak = '/voice/speak/';
  // Hindi-STT retry (apps/voice_commands/views_transcribe.py) — multipart
  // {audio: <clip>} in, {transcript, language_probability,
  // was_language_hinted, detected_language} out.
  static const String voiceTranscribeFallback = '/voice/transcribe-fallback/';

  // Facial Recognition — matches apps/attendance's real face-registration/
  // face-verification endpoints exactly (there is no image-upload or
  // embedding-extraction endpoint on the backend at all — it only ever
  // accepts an already-computed embedding, same as the browser's
  // face-api.js output; mobile computes its embedding entirely on-device,
  // see features/facial_recognition/presentation/capture/).
  static const String faceVerificationStatus = '/attendance/face-verification/status/';
  static const String faceRegistrationMe = '/attendance/face-registration/me/';
  static const String faceRegistrationSubmit = '/attendance/face-registration/';
  static const String faceRegistrationPending = '/attendance/face-registration/pending/';
  static String faceRegistrationReview(String id) =>
      '/attendance/face-registration/$id/review/';
  static const String faceRegistrationHrRegister = '/attendance/face-registration/register/';
  static const String faceRegistrationEmployees = '/attendance/face-registration/employees/';
  static String faceRegistrationEmployeeStatus(String employeeUuid) =>
      '/attendance/face-registration/employees/$employeeUuid/status/';
}

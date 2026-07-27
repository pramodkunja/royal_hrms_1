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

  // Employees
  static const String employees = '/employees/';
  static const String employeeBulkImport = '/employees/bulk-import/';
  static String employeeDetail(String employeeId) => '/employees/$employeeId/';

  // Employees — per-employee Approval Matrix (GET list of workflow rows /
  // PATCH a single row's L1/L2 override). Matches backend
  // EmployeeApprovalMatrixView.
  static String employeeApprovalMatrix(String employeeId) =>
      '/employees/$employeeId/approval-matrix/';

  // My Profile (self-service) — matches backend MyProfileView
  static const String myProfile = '/employees/me/';

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
  static const String candidatesReview = '/recruitment/candidates/review/';
  static const String candidateBulkImport = '/recruitment/candidates/bulk-import/';
  // Accepts either the numeric candidate pk or the human-readable employee
  // code (e.g. "EMP0001") — SendCandidateEmailView falls back to
  // `portal_user__employee_id` when the path segment isn't purely digits.
  static String candidateSendEmail(String id) =>
      '/recruitment/candidates/$id/send-email/';

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

  // Settings — Assessment Config (singleton) — matches backend /api/assessments/settings/
  static const String settingsAssessmentConfig =
      '/assessments/settings/'; // GET (assessments.view) / PUT (assessments.edit)

  // Payroll cycle endpoints (apps/payroll) — the mobile Payroll module itself
  // was removed, but the Attendance Approval tab still gates its L1/L2
  // sign-off flow on the backend's payroll cycles, so these stay.
  static const String payrollSettings = '/payroll/settings/';
  static String payrollApproveAttendance(String id) => '/payroll/cycles/$id/approve-attendance/';
  static const String payrollPendingApproval = '/payroll/cycles/pending-approval/';
  static String payrollAttendanceSummary(String cycleId) => '/payroll/cycles/$cycleId/attendance-summary/';
  static String payrollEmployeeDailyAttendance(String cycleId, String employeeId) =>
      '/payroll/cycles/$cycleId/attendance-daily/$employeeId/';

  // Holiday Calendar — matches backend /api/leave/holidays/
  static const String holidays = '/leave/holidays/';
  static String holidayDetail(String id) => '/leave/holidays/$id/';

  // Branch management
  static const String branchStates = '/branch/states/';
  static String branchCities(int stateId) => '/branch/states/$stateId/cities/';
  static const String branchPreviewCode = '/branch/branches/preview-code/';
  static const String branchStats = '/branch/branches/stats/';
  static const String branches = '/branch/branches/';
  static String branchDetail(int id) => '/branch/branches/$id/';

  // Employee Onboarding
  static const String onboardingProfile = '/onboarding/profile/';
  static String onboardingStep(int step) => '/onboarding/profile/step/$step/';
  static const String onboardingDocuments = '/onboarding/documents/';
  static String onboardingDocumentDetail(int id) =>
      '/onboarding/documents/$id/';
  static const String onboardingSubmit = '/onboarding/submit/';

  // Onboarding Approvals (HR)
  static const String onboardingApprovals = '/onboarding/approvals/';
  static String onboardingApprove(String userId) =>
      '/onboarding/approvals/$userId/approve/';

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
}

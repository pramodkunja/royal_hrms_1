class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    // Always hits the hosted backend — nginx proxies /api/ to Django on
    // royalhrms.nxsys.in (see the server's nginx config), so this must keep
    // the /api suffix or requests fall through to the Next.js frontend block
    // instead of the Django API and come back as HTML, not JSON.
    return 'https://royalhrms.nxsys.in/api';
  }

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
  static String attendanceRecordDetail(String id) => '/attendance/records/$id/';
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
}

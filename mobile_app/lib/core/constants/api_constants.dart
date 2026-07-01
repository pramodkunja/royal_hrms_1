import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    if (kDebugMode) {
      // Platform.isAndroid must be guarded by !kIsWeb — dart:io's Platform
      // class throws on the web platform ("Unsupported operation: _operatingSystem").
      // Django root config mounts all accounts URLs at /api/, so include it here.
      //if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000/api';
      return 'http://localhost:8000/api';
    }
    return 'https://api.royalhrms.com/api';
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
  static const String leaveTypes    = '/leave/policy/';
  static const String leaveBalances = '/leave/balance/';
  static const String leaveStats    = '/leave/stats/';
  static const String leaves        = '/leave/requests/';
  static const String leaveCalendar = '/leave/calendar/';
  static String leaveDetail(dynamic id)  => '/leave/requests/$id/';
  static String leaveAction(dynamic id)  => '/leave/requests/$id/approve/';
  static String leavePolicyDetail(String leaveType) => '/leave/policy/$leaveType/';
  static const String leaveBalanceCredit = '/leave/balance/credit/';

  // Expenses
  static const String expenses     = '/expenses/';
  static const String expenseStats = '/expenses/stats/';
}

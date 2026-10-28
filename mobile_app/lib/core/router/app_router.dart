import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/not_found_view.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/dashboard/presentation/screens/placeholder_screen.dart';
import '../../features/settings/presentation/settings_hub/settings_screen.dart';
import '../../features/settings/presentation/company/company_screen.dart';
import '../../features/settings/presentation/smtp/smtp_screen.dart';
import '../../features/settings/presentation/email_templates/email_templates_screen.dart';
import '../../features/settings/presentation/departments/departments_screen.dart';
import '../../features/settings/presentation/employee_code/employee_code_screen.dart';
import '../../features/settings/presentation/roles/roles_screen.dart';
import '../../features/settings/presentation/audit/audit_screen.dart';
import '../../features/settings/presentation/leave_policy/leave_policy_screen.dart';
import '../../features/settings/presentation/holiday_calendar/holiday_calendar_screen.dart';
import '../../features/settings/presentation/attendance_rules/attendance_rules_screen.dart';
import '../../features/settings/presentation/approval_rules/approval_rules_screen.dart';
import '../../features/settings/presentation/leave_policy/leave_balance_import_screen.dart';
import '../../features/settings/presentation/referral_rules/referral_rules_settings_screen.dart';
import '../../features/settings/presentation/assessment_config/assessment_config_screen.dart';
import '../../features/settings/presentation/notification_settings/notification_settings_screen.dart';
import '../../features/settings/presentation/onboarding_fields/onboarding_fields_screen.dart';
import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/employees/presentation/employees_screen.dart';
import '../../features/employees/presentation/screens/employee_bulk_import_screen.dart';
import '../../features/employees/presentation/screens/employee_profile_screen.dart';
import '../../features/employees/data/models/employee_model.dart';
import '../../features/branches/presentation/screens/branches_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/facial_recognition/presentation/screens/face_id_registrations_screen.dart';
import '../../features/org_chart/presentation/screens/org_chart_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/interview_list/presentation/screens/candidate_bulk_import_screen.dart';
import '../../features/interview_list/presentation/screens/interview_list_screen.dart';
import '../../features/candidate_review/presentation/screens/candidate_review_screen.dart';
import '../../features/assessments/presentation/screens/assessments_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/awaiting_approval_screen.dart';
import '../../features/leave/presentation/screens/leave_screen.dart';
import '../../features/separation/domain/entities/separation_entity.dart';
import '../../features/separation/presentation/screens/separation_detail_screen.dart';
import '../../features/separation/presentation/screens/separation_screen.dart';
import '../../features/wfh/presentation/screens/wfh_screen.dart';
import '../../features/expenses/presentation/screens/expense_screen.dart';
import '../../features/approvals/presentation/screens/approvals_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/attendance/presentation/screens/my_attendance_screen.dart';
import '../../features/payroll/presentation/screens/my_payslip_screen.dart';
import '../../features/referrals/presentation/screens/referrals_screen.dart';
import '../../features/email_log/presentation/screens/email_log_screen.dart';
import '../../features/my_requests/presentation/screens/my_requests_screen.dart';

// ─── Route path constants ─────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // Dashboard shell + sub-routes (mirror navConfig.ts paths)
  static const String dashboard = '/dashboard';
  static const String announcements = '/dashboard/announcements';
  static const String interviewList = '/dashboard/interview-list';
  static const String candidateReview = '/dashboard/candidate-review';
  static const String assessments = '/dashboard/assessments';
  static const String emailLogs = '/dashboard/email-logs';
  static const String employees = '/dashboard/employees';
  static String employeeProfilePath(String employeeId) =>
      '/dashboard/employees/$employeeId';
  static const String employeeBulkImport = '/employees/bulk-import';
  static const String candidateBulkImport = '/interview-list/bulk-import';
  static const String orgChart = '/dashboard/org-chart';
  static const String branches = '/dashboard/branches';
  static const String attendance = '/dashboard/attendance';
  static const String leave = '/dashboard/leave';
  static const String wfh = '/dashboard/wfh';
  static const String expenses = '/dashboard/expenses';
  static const String approvals = '/dashboard/approvals';
  static const String separation = '/dashboard/separation';
  static String separationDetailPath(String requestId) =>
      '/dashboard/separation/$requestId';
  static const String documents = '/dashboard/documents';
  static const String faceIdRegistrations = '/dashboard/face-id-registrations';
  static const String myAttendance = '/dashboard/my-attendance';
  static const String myPayslips = '/dashboard/my-payslip';
  static const String referrals = '/dashboard/referrals';
  static const String myRequests = '/dashboard/my-requests';
  static const String profile = '/dashboard/profile';
  static const String reports = '/dashboard/reports';
  static const String settings = '/dashboard/settings';

  // Onboarding
  static const String onboarding = '/onboarding';
  static const String onboardingAwaiting = '/onboarding/awaiting-approval';

  // Settings sub-screens — pushed on top of the shell (full-screen with back arrow)
  static const String settingsCompany = '/settings/company';
  static const String settingsDepartments = '/settings/departments';
  static const String settingsRoles = '/settings/roles';
  static const String settingsEmployeeCode = '/settings/employee-code';
  static const String settingsEmailTemplates = '/settings/email-templates';
  static const String settingsSmtp = '/settings/smtp';
  static const String settingsAuditLog = '/settings/audit';
  static const String settingsLeavePolicy = '/settings/leave-policy';
  static const String settingsHolidayCalendar = '/settings/holiday-calendar';
  static const String settingsAttendanceRules = '/settings/attendance-rules';
  static const String settingsReferralRules = '/settings/referral-rules';
  static const String settingsAssessmentConfig = '/settings/assessment-config';
  static const String settingsApprovalRules = '/settings/approval-rules';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsOnboardingFields = '/settings/onboarding-fields';
  static const String settingsLeaveBalanceImport =
      '/settings/leave-policy/import-balances';

  // Routes whose screen renders its own bottom-right floatingActionButton.
  // Used by VoiceMicOverlay (mounted globally, above every route) to decide
  // whether its default (never-dragged) position should sit in the standard
  // bottom-right corner, or bumped up above one — keep in sync with each
  // screen's own `floatingActionButton:`. A few of these (leave,
  // settingsLeavePolicy, settingsReferralRules) only show their FAB
  // conditionally (a tab index, a permission check) — they're still listed
  // here since the unconditional "bumped up" position is harmless empty
  // space on the rare screen-state where their FAB happens to be hidden, and
  // not worth a second per-screen signal on top of this route-based one.
  static const Set<String> screensWithFab = {
    employees,
    interviewList,
    attendance,
    leave,
    announcements,
    assessments,
    branches,
    documents,
    expenses,
    referrals,
    settingsDepartments,
    settingsEmailTemplates,
    settingsHolidayCalendar,
    settingsLeavePolicy,
    settingsOnboardingFields,
    settingsReferralRules,
    settingsRoles,
    settingsSmtp,
  };
}

// ─── Navigation helpers ───────────────────────────────────────────────────────

/// Navigates to a top-level dashboard section (sidebar item, quick-access
/// tile, dashboard card, notification tap). Collapses any existing back
/// stack down to the Dashboard root first, then pushes the destination —
/// so repeatedly jumping between sections from these fixed entry points
/// never piles up unboundedly, while still leaving a normal "back returns
/// to Dashboard" history entry instead of erasing it (the previous
/// `context.go()` behavior, which is what let the Android back button
/// close the app straight from any dashboard section).
void goToDashboardSection(BuildContext context, String path) {
  while (context.canPop()) {
    context.pop();
  }
  if (path != AppRoutes.dashboard) {
    context.push(path);
  }
}

// ─── Current visible path (for overlays that live outside the Navigator) ──────

/// The path of whatever route is actually on screen right now.
///
/// GoRouter's own `currentConfiguration.uri` can't be used for this: it
/// deliberately excludes any route reached via `context.push()` (go_router's
/// `RouteMatchList.uri` docs: "This uri only reflects RouteMatches that are
/// not ImperativeRouteMatch"), and a `NavigatorObserver` attached via
/// `GoRouter(observers:)` was tried and found not to reliably observe pushes
/// happening inside a ShellRoute's own nested Navigator either. Since
/// [goToDashboardSection] and every settings sub-screen navigate via push,
/// both of those left this stuck on whatever path was last reached via
/// `context.go()` — which is exactly why VoiceMicOverlay's FAB-avoidance
/// (keyed off this path) needs a source that updates on push too.
///
/// Instead, this is published directly by widgets *inside* the routed tree,
/// where `GoRouterState.of(context).uri.path` is always correct for
/// whatever route it's called from regardless of how it was reached — see
/// DashboardShell (every /dashboard/* route) and SettingsAppBar (every
/// settings sub-screen, pushed outside the shell).
final currentVisiblePathProvider = StateProvider<String>(
  (ref) => AppRoutes.dashboard,
);

/// Bumped by DashboardShell every time navigation lands back on
/// [AppRoutes.dashboard] after having been on a different route.
///
/// HomeScreen (and every per-role dashboard view under it) is reached via
/// [goToDashboardSection]'s `context.push()`, so returning to it is a
/// `pop()` back to the *same still-mounted* widget, not a fresh build —
/// its `autoDispose` providers never lost their last listener, so they
/// never naturally re-fetch. Each dashboard view listens to this counter
/// and re-invalidates its own data (the same providers its pull-to-refresh
/// already invalidates) whenever it changes.
final dashboardRevisitProvider = StateProvider<int>((ref) => 0);

// ─── Router provider ──────────────────────────────────────────────────────────

// A thin ChangeNotifier that lets GoRouter react to Riverpod auth-state changes.
// GoRouter's `refreshListenable` re-runs `redirect` whenever this notifies.
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier();

  // Re-evaluate all active routes whenever auth state changes (login / logout).
  ref.listen(authStateProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final authState = authAsync.valueOrNull;
      final isAuthenticated = authState?.isAuthenticated ?? false;
      final user = authState?.user;
      final path = state.uri.path;

      // Not logged in — send to login
      if (!isAuthenticated) {
        if (path.startsWith('/dashboard') ||
            path.startsWith('/settings') ||
            path.startsWith('/onboarding')) {
          return AppRoutes.login;
        }
        return null;
      }

      // Logged in — check onboarding status
      if (user != null) {
        if (user.needsOnboarding || user.onboardingRejected) {
          // pending/draft/rejected: must complete (or revise) the onboarding wizard
          if (!path.startsWith('/onboarding') ||
              path == AppRoutes.onboardingAwaiting) {
            return AppRoutes.onboarding;
          }
          return null;
        }
        if (user.awaitingApproval) {
          // submitted: waiting for HR approval
          if (path != AppRoutes.onboardingAwaiting) {
            return AppRoutes.onboardingAwaiting;
          }
          return null;
        }
        // complete / no onboarding: normal dashboard access
        // Redirect away from onboarding routes if already done
        if (path.startsWith('/onboarding')) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
    routes: [
      // ── Auth routes ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, state) =>
            NoTransitionPage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) =>
            NoTransitionPage(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ── Onboarding (outside dashboard shell) ───────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, state) =>
            NoTransitionPage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboardingAwaiting,
        pageBuilder: (_, state) => NoTransitionPage(
            key: state.pageKey, child: const AwaitingApprovalScreen()),
      ),

      // ── Settings sub-screens (outside shell — own AppBar + back button) ──
      GoRoute(
        path: AppRoutes.settingsCompany,
        builder: (_, __) => const CompanyScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsDepartments,
        builder: (_, __) => const DepartmentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsRoles,
        builder: (_, __) => const RolesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsEmployeeCode,
        builder: (_, __) => const EmployeeCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsEmailTemplates,
        builder: (_, __) => const EmailTemplatesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsSmtp,
        builder: (_, __) => const SmtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAuditLog,
        builder: (_, __) => const AuditScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsLeavePolicy,
        builder: (_, __) => const LeavePolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsHolidayCalendar,
        builder: (_, __) => const HolidayCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAttendanceRules,
        builder: (_, __) => const AttendanceRulesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsReferralRules,
        builder: (_, __) => const ReferralRulesSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsNotifications,
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsOnboardingFields,
        builder: (_, __) => const OnboardingFieldsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAssessmentConfig,
        builder: (_, __) => const AssessmentConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsApprovalRules,
        builder: (_, __) => const ApprovalRulesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsLeaveBalanceImport,
        builder: (_, __) => const LeaveBalanceImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.employeeBulkImport,
        builder: (_, __) => const EmployeeBulkImportScreen(),
      ),
      GoRoute(
        path: AppRoutes.candidateBulkImport,
        builder: (_, __) => const CandidateBulkImportScreen(),
      ),

      // ── Dashboard shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
          ),

          // Announcements
          GoRoute(
            path: AppRoutes.announcements,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const AnnouncementsScreen()),
          ),

          // Recruitment
          GoRoute(
            path: AppRoutes.interviewList,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const InterviewListScreen()),
          ),
          GoRoute(
            path: AppRoutes.candidateReview,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const CandidateReviewScreen()),
          ),
          GoRoute(
            path: AppRoutes.assessments,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const AssessmentsScreen()),
          ),
          GoRoute(
            path: AppRoutes.emailLogs,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const EmailLogScreen()),
          ),

          // Workforce
          GoRoute(
            path: AppRoutes.employees,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const EmployeesScreen()),
            routes: [
              GoRoute(
                path: ':employeeId',
                builder: (context, state) => EmployeeProfileScreen(
                  employeeId: state.pathParameters['employeeId']!,
                  initialEmployee: state.extra as EmployeeModel?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.orgChart,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const OrgChartScreen()),
          ),
          GoRoute(
            path: AppRoutes.branches,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const BranchesScreen()),
          ),

          // Time & Pay
          GoRoute(
            path: AppRoutes.attendance,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const AttendanceScreen()),
          ),
          GoRoute(
            path: AppRoutes.leave,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const LeaveScreen()),
          ),
          GoRoute(
            path: AppRoutes.wfh,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const WfhScreen()),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ExpenseScreen()),
          ),

          // HR Ops
          GoRoute(
            path: AppRoutes.approvals,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ApprovalsScreen()),
          ),
          GoRoute(
            path: AppRoutes.separation,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const SeparationScreen()),
            routes: [
              GoRoute(
                path: ':requestId',
                builder: (context, state) => SeparationDetailScreen(
                  requestId: state.pathParameters['requestId']!,
                  initial: state.extra as SeparationRequestEntity?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.documents,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const DocumentsScreen()),
          ),
          GoRoute(
            path: AppRoutes.faceIdRegistrations,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const FaceIdRegistrationsScreen()),
          ),

          // My
          GoRoute(
            path: AppRoutes.myAttendance,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const MyAttendanceScreen()),
          ),
          GoRoute(
            path: AppRoutes.myPayslips,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const MyPayslipScreen()),
          ),
          GoRoute(
            path: AppRoutes.referrals,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ReferralsScreen()),
          ),
          GoRoute(
            path: AppRoutes.myRequests,
            pageBuilder: (_, state) => NoTransitionPage(
                key: state.pageKey, child: const MyRequestsScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ProfileScreen()),
          ),

          // System
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PlaceholderScreen(
                  title: 'Reports', icon: Icons.bar_chart_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const SettingsScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: NotFoundView(),
    ),
  );
});

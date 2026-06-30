import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/employees/presentation/employees_screen.dart';
import '../../features/employees/presentation/screens/employee_profile_screen.dart';
import '../../features/employees/data/models/employee_model.dart';
import '../../features/branches/presentation/screens/branches_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/org_chart/presentation/screens/org_chart_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/interview_list/presentation/screens/interview_list_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/awaiting_approval_screen.dart';

// ─── Route path constants ─────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash          = '/';
  static const String login           = '/login';
  static const String forgotPassword  = '/forgot-password';

  // Dashboard shell + sub-routes (mirror navConfig.ts paths)
  static const String dashboard       = '/dashboard';
  static const String announcements   = '/dashboard/announcements';
  static const String interviewList   = '/dashboard/interview-list';
  static const String candidateReview = '/dashboard/candidate-review';
  static const String emailLogs       = '/dashboard/email-logs';
  static const String employees       = '/dashboard/employees';
  static String employeeProfilePath(String employeeId) =>
      '/dashboard/employees/$employeeId';
  static const String orgChart        = '/dashboard/org-chart';
  static const String branches        = '/dashboard/branches';
  static const String attendance      = '/dashboard/attendance';
  static const String payroll         = '/dashboard/payroll';
  static const String myPayslip       = '/dashboard/my-payslip';
  static const String leave           = '/dashboard/leave';
  static const String expenses        = '/dashboard/expenses';
  static const String approvals       = '/dashboard/approvals';
  static const String separation      = '/dashboard/separation';
  static const String documents       = '/dashboard/documents';
  static const String myRequests      = '/dashboard/my-requests';
  static const String profile         = '/dashboard/profile';
  static const String reports         = '/dashboard/reports';
  static const String audit           = '/dashboard/audit';
  static const String settings        = '/dashboard/settings';

  // Onboarding
  static const String onboarding        = '/onboarding';
  static const String onboardingAwaiting = '/onboarding/awaiting-approval';

  // Settings sub-screens — pushed on top of the shell (full-screen with back arrow)
  static const String settingsCompany        = '/settings/company';
  static const String settingsDepartments    = '/settings/departments';
  static const String settingsRoles          = '/settings/roles';
  static const String settingsEmployeeCode   = '/settings/employee-code';
  static const String settingsEmailTemplates = '/settings/email-templates';
  static const String settingsSmtp           = '/settings/smtp';
  static const String settingsAuditLog       = '/settings/audit';
}

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
        if (user.needsOnboarding) {
          // pending/draft: must complete onboarding wizard
          if (!path.startsWith('/onboarding')) {
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
        pageBuilder: (_, __) => const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, __) => const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ── Onboarding (outside dashboard shell) ───────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, __) =>
            const NoTransitionPage(child: OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboardingAwaiting,
        pageBuilder: (_, __) =>
            const NoTransitionPage(child: AwaitingApprovalScreen()),
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

      // ── Dashboard shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),

          // Announcements
          GoRoute(
            path: AppRoutes.announcements,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AnnouncementsScreen()),
          ),

          // Recruitment
          GoRoute(
            path: AppRoutes.interviewList,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: InterviewListScreen()),
          ),
          GoRoute(
            path: AppRoutes.candidateReview,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Candidate Review', icon: Icons.how_to_reg_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.emailLogs,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Email Logs', icon: Icons.mail_outline),
            ),
          ),

          // Workforce
          GoRoute(
            path: AppRoutes.employees,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: EmployeesScreen()),
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
            pageBuilder: (_, __) => const NoTransitionPage(child: OrgChartScreen()),
          ),
          GoRoute(
            path: AppRoutes.branches,
            pageBuilder: (_, __) => const NoTransitionPage(child: BranchesScreen()),
          ),

          // Time & Pay
          GoRoute(
            path: AppRoutes.attendance,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Attendance & Time', icon: Icons.access_time_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.payroll,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Payroll Management', icon: Icons.payments_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.myPayslip,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'My Payslips', icon: Icons.receipt_long_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.leave,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Leave Management', icon: Icons.beach_access_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Expenses', icon: Icons.account_balance_wallet_outlined),
            ),
          ),

          // HR Ops
          GoRoute(
            path: AppRoutes.approvals,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Team Approvals', icon: Icons.checklist_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.separation,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Separation & FnF', icon: Icons.exit_to_app_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.documents,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DocumentsScreen()),
          ),

          // My
          GoRoute(
            path: AppRoutes.myRequests,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'My Requests', icon: Icons.inbox_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),

          // System
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Reports', icon: Icons.bar_chart_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.audit,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: PlaceholderScreen(title: 'Audit Log', icon: Icons.security_outlined),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, __) => const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

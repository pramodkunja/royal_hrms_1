import '../../features/auth/domain/entities/user_entity.dart';

/// Client-side mirror of the backend's authorization rule, shared by the
/// router guard, the sidebar menu (buildNav) and the dashboard quick-access
/// tiles so all three always agree.
///
/// Backend rule (backend/core/permissions.py `has_perm`): a Django superuser,
/// or any role holding `settings.edit`, passes every permission check;
/// otherwise the role must hold the exact codename. The login response's
/// `is_superuser` is already true for both cases (apps/accounts/views.py
/// LoginView), and `settings.edit` is checked too so a user cached before
/// that flag existed still resolves the way the server does.
///
/// Never decides anything from the role *name* — roles are per company and
/// renameable; only the permissions the server granted count. No user (signed
/// out / still loading) holds nothing.
bool userHasPermission(UserEntity? user, String codename) {
  if (user == null) return false;
  if (user.isSuperuser || user.permissions.contains('settings.edit')) return true;
  return user.permissions.contains(codename);
}

/// True when [user] holds at least one of [codenames] (see userHasPermission).
bool userHasAnyPermission(UserEntity? user, Iterable<String> codenames) =>
    codenames.any((c) => userHasPermission(user, c));

/// Backend apps/attendance/access.py is_attendance_staff: superuser /
/// settings.edit, a team or branch manager, or attendance.edit.
bool isAttendanceStaff(UserEntity? user) =>
    user != null && (userHasPermission(user, 'attendance.edit') || user.canManageTeam || user.canManageBranch);

/// Who may delegate their approvals — backend apps/approvals/services.py
/// can_approve_workflow for the two delegable workflows: leave
/// (has_perm leave.approve) or attendance (can_manage_attendance =
/// attendance.create held by attendance staff). Web approvals/page.tsx
/// canDelegate is the same rule with usePermission; like every other mobile
/// check, settings.edit counts as the backend's has_perm does.
bool canDelegateApprovals(UserEntity? user) =>
    userHasPermission(user, 'leave.approve') ||
    (userHasPermission(user, 'attendance.create') && isAttendanceStaff(user));

/// Permission needed to open a route directly (deep link, `go()`, typed
/// path) — any one listed codename grants access. Mirrors web's
/// frontend/proxy.ts ROUTE_PERMISSIONS, mapped onto this app's paths, with
/// the backend endpoint's own check deciding where web's route gate and menu
/// disagree:
///  - branches: `branches.view` (apps/branch/views.py list view; web's route
///    gate says settings.view but its menu and the API say branches.view);
///  - audit log: `audit.view` (apps/accounts/views.py AuditLogListView);
///  - face ID registrations: `facial_recognition.approve` (every endpoint in
///    apps/attendance/views/face_registration_hr.py);
///  - assessments: `assessments.view` (this app's screen is the HR management
///    view only; apps/assessments/views/admin.py). The employee's own list,
///    /dashboard/my-assessments, is deliberately absent: like web's
///    "My Assessments" it is self-service for every signed-in user, and its
///    API (GET /assessments/my/) returns only the caller's own assignments;
///  - approvals: also `wfh.approve` — this app's Approvals screen includes
///    WFH requests, which the backend authorises with wfh.approve.
/// Paths not listed (dashboard home, announcements, separation, WFH, my
/// attendance, my payslips, my requests, referrals, profile) are
/// self-service for every signed-in user, as on web; the backend scopes what
/// each of those returns.
const Map<String, List<String>> kRoutePermissions = {
  '/dashboard/interview-list': ['recruitment.view'],
  // Web: the Bulk Import entry needs recruitment.create (canCreate).
  '/interview-list/bulk-import': ['recruitment.create'],
  '/dashboard/candidate-review': ['recruitment.view'],
  '/dashboard/email-logs': ['recruitment.view'],
  // Web isAdminView: any assessments.* codename opens the management view.
  '/dashboard/assessments': ['assessments.view', 'assessments.create', 'assessments.edit', 'assessments.delete'],
  '/dashboard/face-id-registrations': ['facial_recognition.approve'],
  '/dashboard/employees': ['employees.view'],
  // Bulk import creates employees: employees.create (EmployeeBulkImportView).
  '/employees/bulk-import': ['employees.create'],
  '/dashboard/org-chart': ['org_chart.view'],
  '/dashboard/branches': ['branches.view'],
  // HR attendance management — web proxy.ts / navConfig.ts: attendance.edit
  // or settings.edit. attendance.view (and .create) alone are what ordinary
  // employees may hold for My Attendance (backend apps/attendance/access.py).
  '/dashboard/attendance': ['attendance.edit', 'settings.edit'],
  '/dashboard/leave': ['leave.view'],
  '/dashboard/expenses': ['expenses.view'],
  // separation.approve as on web (approvals/page.tsx): separation requests
  // are part of the Team Approvals inbox.
  '/dashboard/approvals': ['leave.approve', 'expenses.approve', 'wfh.approve', 'separation.approve'],
  '/dashboard/documents': ['documents.view'],
  // Training & Learning admin (web navConfig/proxy: training.view).
  '/dashboard/training': ['training.view'],
  '/dashboard/reports': ['reports.view'],
  '/dashboard/settings': ['settings.view'],
  '/settings': ['settings.view'],
  '/settings/audit': ['audit.view'],
};

/// Routes a user may also open when a rule other than a codename list
/// authorises them (Task 71g, audit L6). Approvals: delegators — attendance
/// staff with attendance.create may delegate (and approve attendance
/// corrections) without holding any of the codenames above, and the
/// Delegation tab lives only on this screen. Opening the screen grants no
/// queue: every tab and queue keeps its own permission check.
const Map<String, bool Function(UserEntity?)> kRouteAlternativeAccess = {
  '/dashboard/approvals': canDelegateApprovals,
};

/// Whether a kRouteAlternativeAccess rule (longest matching prefix) lets
/// [user] open [path].
bool alternativeRouteAccess(UserEntity? user, String path) {
  String? best;
  for (final route in kRouteAlternativeAccess.keys) {
    if ((path == route || path.startsWith('$route/')) && (best == null || route.length > best.length)) {
      best = route;
    }
  }
  return best != null && kRouteAlternativeAccess[best]!(user);
}

/// The permissions [path] requires, or null when it is open to every
/// signed-in user. The longest matching prefix wins (exact path or a
/// sub-path), as in web's proxy.ts — so /settings/audit uses its own entry,
/// and /dashboard/employees/<id> inherits /dashboard/employees.
List<String>? requiredPermissionsFor(String path) {
  String? best;
  for (final route in kRoutePermissions.keys) {
    if ((path == route || path.startsWith('$route/')) && (best == null || route.length > best.length)) {
      best = route;
    }
  }
  return best == null ? null : kRoutePermissions[best];
}

/// Sub-screens that need a permission IN ADDITION to the one their parent
/// route already requires (kRoutePermissions above, longest prefix) — web
/// shows these as an action inside a gated page, so both gates apply. Any one
/// listed codename satisfies the extra check (userHasAnyPermission).
///  - Leave balance import: web leave-policy/page.tsx shows "Import Opening
///    Balances" only for usePermission("leave.edit"), on a page whose route
///    needs settings.view (proxy.ts). The backend endpoints
///    (LeaveOpeningBalance{Import,Validate,Sample}View) check leave.approve;
///    a leave.approve-only user is still kept out here, as on web.
const Map<String, List<String>> kRouteExtraPermissions = {
  '/settings/leave-policy/import-balances': ['leave.edit'],
};

/// The extra permissions [path] requires beyond requiredPermissionsFor, or
/// null. Longest matching prefix wins, as for kRoutePermissions.
List<String>? extraPermissionsFor(String path) {
  String? best;
  for (final route in kRouteExtraPermissions.keys) {
    if ((path == route || path.startsWith('$route/')) && (best == null || route.length > best.length)) {
      best = route;
    }
  }
  return best == null ? null : kRouteExtraPermissions[best];
}

/// Screens that are not built for mobile yet (they would only show a
/// placeholder). Hidden from the menu and refused by the router for every
/// user, whatever their permissions. Their nav entry, route and permission
/// above stay in place; remove the path from this set once the real screen
/// ships. Reports: web has a real module (frontend/app/dashboard/reports);
/// mobile only has PlaceholderScreen.
const Set<String> kUnavailablePaths = {'/dashboard/reports'};

/// Whether [path] is, or is under, one of [kUnavailablePaths].
bool isUnavailablePath(String path) =>
    kUnavailablePaths.any((p) => path == p || path.startsWith('$p/'));

// ── Company modules (subscription) ──────────────────────────────────────────
//
// Web frontend/lib/modules.ts ROUTE_MODULES, mapped onto this app's paths.
// Hiding is a convenience: the API enforces every module itself. Module
// availability is separate from permission — a visible module grants no
// permission (canAccessPath checks both).

/// Module keys (backend apps/tenants/models.py MODULE_*).
abstract final class AppModules {
  static const announcements = 'announcements';
  static const recruitment = 'recruitment';
  static const faceAttendance = 'face_attendance';
  static const attendance = 'attendance';
  static const leave = 'leave';
  static const payroll = 'payroll';
  static const expenses = 'expenses';
  static const separation = 'separation';
  static const voiceCommands = 'voice_commands';
  static const assessments = 'assessments';
  static const documents = 'documents';
  static const assets = 'assets';
  static const wfh = 'wfh';
  static const training = 'training';
}

/// Route prefix → module. Longest matching prefix wins (web moduleForPath).
/// Paths not listed are core (always available).
const Map<String, String> kRouteModules = {
  '/dashboard/attendance': AppModules.attendance,
  '/dashboard/my-attendance': AppModules.attendance,
  '/dashboard/face-id-registrations': AppModules.faceAttendance,
  '/dashboard/leave': AppModules.leave,
  '/dashboard/wfh': AppModules.wfh, // web /dashboard/work-from-home
  '/dashboard/my-payslip': AppModules.payroll,
  '/dashboard/expenses': AppModules.expenses,
  '/dashboard/interview-list': AppModules.recruitment,
  '/interview-list/bulk-import': AppModules.recruitment, // web /dashboard/interview-list/…
  '/dashboard/candidate-review': AppModules.recruitment,
  '/dashboard/email-logs': AppModules.recruitment,
  '/dashboard/referrals': AppModules.recruitment,
  '/dashboard/assessments': AppModules.assessments,
  '/dashboard/my-assessments': AppModules.assessments, // web "My Assessments" is /dashboard/assessments
  '/dashboard/separation': AppModules.separation,
  '/dashboard/announcements': AppModules.announcements,
  '/dashboard/documents': AppModules.documents,
  '/dashboard/training': AppModules.training,
  // Self-service (no permission, as web proxy.ts), module only.
  '/dashboard/my-learning': AppModules.training,
  '/dashboard/contacts': AppModules.documents,
  '/settings/attendance-rules': AppModules.attendance, // web settings/attendance-config
  '/settings/leave-policy': AppModules.leave, // includes import-balances
  '/settings/holiday-calendar': AppModules.leave,
  '/settings/referral-rules': AppModules.recruitment,
  '/settings/assessment-config': AppModules.assessments,
  '/settings/assets': AppModules.assets, // web settings/assets
};

/// The module [path] belongs to, or null for core screens.
String? moduleForPath(String path) {
  final clean = path.split(RegExp('[?#]')).first;
  String? best;
  for (final route in kRouteModules.keys) {
    if ((clean == route || clean.startsWith('$route/')) && (best == null || route.length > best.length)) {
      best = route;
    }
  }
  return best == null ? null : kRouteModules[best];
}

/// Web hasModule(modules, key): no key → available; the company's module
/// list unknown (older session, or no user yet) → available; otherwise only
/// when the subscription includes it.
bool userHasModule(UserEntity? user, String? key) => key == null || user == null || user.hasModule(key);

/// Whether [user] may open [path] directly: the module (when the list is
/// known) and the permission.
bool canAccessPath(UserEntity? user, String path) {
  if (isUnavailablePath(path)) return false;
  if (!userHasModule(user, moduleForPath(path))) return false;
  final required = requiredPermissionsFor(path);
  if (required != null && !userHasAnyPermission(user, required) && !alternativeRouteAccess(user, path)) return false;
  final extra = extraPermissionsFor(path);
  return extra == null || userHasAnyPermission(user, extra);
}

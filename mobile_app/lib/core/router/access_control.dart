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
  '/dashboard/attendance': ['attendance.view'],
  '/dashboard/leave': ['leave.view'],
  '/dashboard/expenses': ['expenses.view'],
  // separation.approve as on web (approvals/page.tsx): separation requests
  // are part of the Team Approvals inbox.
  '/dashboard/approvals': ['leave.approve', 'expenses.approve', 'wfh.approve', 'separation.approve'],
  '/dashboard/documents': ['documents.view'],
  '/dashboard/reports': ['reports.view'],
  '/dashboard/settings': ['settings.view'],
  '/settings': ['settings.view'],
  '/settings/audit': ['audit.view'],
};

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

/// Whether [user] may open [path] directly.
bool canAccessPath(UserEntity? user, String path) {
  if (isUnavailablePath(path)) return false;
  final required = requiredPermissionsFor(path);
  return required == null || userHasAnyPermission(user, required);
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'dashboard_section.dart';

/// Role category resolution + the "Quick Access" grid, shared by every
/// per-role dashboard view. Extracted out of `home_screen.dart` so
/// `EmployeeDashboardView`/`AdminDashboardView`/`HrDashboardView` (separate
/// files) can all reuse the exact same role-detection logic and tile look.
///
/// Mirrors web's `resolveRole()` in `app/dashboard/page.tsx` exactly — each
/// of the 4 role categories gets its own distinct Quick Actions set (see
/// `EmployeeDashboard.tsx`/`ManagerDashboard.tsx`/`HRDashboard.tsx`/
/// `AdminDashboard.tsx`'s "Quick actions" arrays).
String resolveRoleCategory(String rawRole) {
  final r = rawRole.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  if (r.contains('hradmin') || r == 'hr') return 'hr';
  if (r.contains('admin')) return 'admin'; // system_admin
  if (r.contains('manager')) return 'manager';
  return 'employee'; // default, matches web's fallback
}

// Uploaded module icon artwork (assets/images/), keyed by the module's own
// path rather than its per-role label text — a module can show up as
// "Employees" under HR/Admin but "Team Members" under Manager, and it's
// still the same module/image either way.
const _kQuickItemImageByPath = <String, String>{
  '/dashboard/employees': 'assets/images/Employees.png',
  '/dashboard/attendance': 'assets/images/Attendance.png',
  '/dashboard/my-attendance': 'assets/images/Attendance.png',
  '/dashboard/branches': 'assets/images/Branches.png',
  '/settings/roles': 'assets/images/Roles&Permissions.png',
  '/dashboard/settings': 'assets/images/Settings.png',
  '/dashboard/interview-list': 'assets/images/Interview list.png',
  '/dashboard/candidate-review': 'assets/images/Review Candidate.png',
};

// Overrides keyed by "path|label" for the rare case where the SAME path is
// shared by tiles that mean genuinely different things depending on role —
// unlike the cases above, "Apply Leave" (an employee submitting their own
// request) and "Leave Approvals" (HR reviewing others') both live at
// /dashboard/leave but are not the same action, so only the HR-facing tile
// gets the "Leave Approval" artwork; Apply Leave keeps its plain icon.
const _kQuickItemImageByPathAndLabel = <String, String>{
  '/dashboard/leave|Leave Approvals': 'assets/images/Leave Approval.png',
};

class QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final String path;
  final String? permission;

  const QuickItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.path,
    this.permission,
  });

  /// Uploaded module artwork to show instead of [icon], resolved from
  /// [path] (and, for the few tiles where the same path means different
  /// things per role, [label] too) — falls back to the plain Material icon
  /// (null) for every module without a provided image.
  String? get imageAsset =>
      _kQuickItemImageByPathAndLabel['$path|$label'] ?? _kQuickItemImageByPath[path];
}

// Mirrors each web dashboard's own "Quick actions" array exactly (icons
// translated to their nearest Material equivalent, colors mapped to this
// app's matching semantic AppColors token) — see
// frontend/app/dashboard/_components/{Employee,Manager,HR,Admin}Dashboard.tsx.
// Web hardcodes a different 6-tile set per role rather than one shared,
// permission-filtered list, so this app does the same.

final kQuickItemsEmployee = <QuickItem>[
  QuickItem(
      label: 'Apply Leave',
      icon: Icons.beach_access_outlined,
      color: AppColors.success,
      path: '/dashboard/leave',
      permission: 'leave.view'),
  QuickItem(
      label: 'My Payslips',
      icon: Icons.receipt_long_outlined,
      color: AppColors.primary,
      path: '/dashboard/my-payslip',
      // Gated server-side on 'payroll.view_own', seeded for every role — not
      // the HR-only 'payroll.view' the removed tile used to declare here.
      permission: 'payroll.view_own'),
  QuickItem(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      color: AppColors.info,
      path: '/dashboard/my-attendance',
      permission: null),
  QuickItem(
      label: 'My Expenses',
      icon: Icons.account_balance_wallet_outlined,
      color: AppColors.warning,
      path: '/dashboard/expenses',
      permission: 'expenses.view'),
  QuickItem(
      label: 'Documents',
      icon: Icons.folder_outlined,
      color: AppColors.primary,
      path: '/dashboard/documents',
      permission: 'documents.view'),
  QuickItem(
      label: 'My Profile',
      icon: Icons.account_circle_outlined,
      color: AppColors.info,
      path: '/dashboard/profile',
      permission: null),
];

final kQuickItemsManager = <QuickItem>[
  QuickItem(
      label: 'Review Approvals',
      icon: Icons.checklist_outlined,
      color: AppColors.warning,
      path: '/dashboard/approvals',
      permission: 'leave.view'),
  QuickItem(
      label: 'Apply Leave',
      icon: Icons.beach_access_outlined,
      color: AppColors.success,
      path: '/dashboard/leave',
      permission: 'leave.view'),
  QuickItem(
      label: 'My Payslip',
      icon: Icons.receipt_long_outlined,
      color: AppColors.primary,
      path: '/dashboard/my-payslip',
      permission: 'payroll.view_own'),
  QuickItem(
      label: 'Team Members',
      icon: Icons.groups_outlined,
      color: AppColors.info,
      path: '/dashboard/employees',
      permission: 'employees.view'),
  QuickItem(
      label: 'Interviews',
      icon: Icons.person_search_outlined,
      color: AppColors.primary,
      path: '/dashboard/interview-list',
      permission: 'recruitment.view'),
  QuickItem(
      label: 'My Requests',
      icon: Icons.inbox_outlined,
      color: AppColors.warning,
      path: '/dashboard/my-requests',
      permission: null),
];

final kQuickItemsHr = <QuickItem>[
  QuickItem(
      label: 'Interview List',
      icon: Icons.people_outline,
      color: AppColors.primary,
      path: '/dashboard/interview-list',
      permission: 'recruitment.view'),
  QuickItem(
      label: 'Leave Approvals',
      icon: Icons.beach_access_outlined,
      color: AppColors.success,
      path: '/dashboard/leave',
      permission: 'leave.view'),
  QuickItem(
      label: 'Employees',
      icon: Icons.badge_outlined,
      color: AppColors.info,
      path: '/dashboard/employees',
      permission: 'employees.view'),
  QuickItem(
      label: 'Review Candidates',
      icon: Icons.how_to_reg_outlined,
      color: AppColors.warning,
      path: '/dashboard/candidate-review',
      permission: 'recruitment.view'),
  QuickItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      color: AppColors.primary,
      path: '/dashboard/settings',
      permission: 'settings.view'),
];

final kQuickItemsAdmin = <QuickItem>[
  QuickItem(
      label: 'Employees',
      icon: Icons.badge_outlined,
      color: AppColors.primary,
      path: '/dashboard/employees',
      permission: 'employees.view'),
  QuickItem(
      label: 'Roles & Perms',
      icon: Icons.verified_user_outlined,
      color: AppColors.success,
      path: '/settings/roles',
      permission: 'settings.view'),
  QuickItem(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      color: AppColors.info,
      path: '/dashboard/attendance',
      permission: 'attendance.view'),
  QuickItem(
      label: 'Branches',
      icon: Icons.business_outlined,
      color: AppColors.primary,
      path: '/dashboard/branches',
      permission: 'branches.view'),
  QuickItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      color: AppColors.warning,
      path: '/dashboard/settings',
      permission: 'settings.view'),
];

final kQuickItemsByRole = <String, List<QuickItem>>{
  'employee': kQuickItemsEmployee,
  'manager': kQuickItemsManager,
  'hr': kQuickItemsHr,
  'admin': kQuickItemsAdmin,
};

// Wraps the grid in the same highlighted-header card chrome as the other
// dashboard sections below it, instead of a plain heading floating above it.
class QuickAccessCard extends StatelessWidget {
  final List<QuickItem> items;

  const QuickAccessCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick Access',
      icon: Icons.apps_rounded,
      accentColor: AppColors.primary,
      child: QuickAccessGrid(items: items),
    );
  }
}

class QuickAccessGrid extends StatelessWidget {
  final List<QuickItem> items;

  const QuickAccessGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      // A fixed mainAxisExtent (rather than childAspectRatio) keeps tile
      // height constant regardless of available width — childAspectRatio
      // made height shrink along with width once this grid got nested one
      // level deeper inside SectionCard's own padding, which left too
      // little room for the icon + two-line label and overflowed.
      // 3 columns (not 4) — every role's array is exactly 6 items, so this
      // lays out as a clean 3×2 grid matching the reference design.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 92,
      ),
      itemBuilder: (context, index) => QuickTile(item: items[index]),
    );
  }
}

class QuickTile extends StatelessWidget {
  final QuickItem item;

  const QuickTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Settings sub-screens (e.g. Roles & Perms) live outside the dashboard
      // shell and use their own AppBar with a back button that calls
      // context.pop() — they must be pushed, not go()'d to, or there's
      // nothing on the stack for that back button to pop.
      onTap: () => item.path.startsWith('/settings/')
          ? context.push(item.path)
          : goToDashboardSection(context, item.path),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // A proper bordered white card (not a flat tinted chip) — matches
          // the reference design's nested-card look for each tile.
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            item.imageAsset != null
                // The uploaded artwork is already a full-color icon (see
                // _kQuickItemImageByPath) — no tinted background box behind
                // it, unlike the plain glyph case below, and sized a touch
                // bigger since it's carrying real detail rather than a
                // simple line-icon shape.
                ? SizedBox(
                    width: 36,
                    height: 36,
                    child: Image.asset(item.imageAsset!, fit: BoxFit.contain),
                  )
                : Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: item.color, size: 17),
                  ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

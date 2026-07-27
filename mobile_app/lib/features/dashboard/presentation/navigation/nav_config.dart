import 'package:flutter/material.dart';

// ─── Sealed nav entry types ──────────────────────────────────────────────────
// Dart port of the TypeScript NavEntry union from frontend/lib/navConfig.ts.
// Sealed so switch statements on NavEntry are exhaustive (Dart 3+).

sealed class NavEntry {
  const NavEntry();
}

final class NavSection extends NavEntry {
  final String title;
  const NavSection(this.title);
}

final class NavItem extends NavEntry {
  final String id;
  final IconData icon;
  final String label;
  final String path;
  final String? permission; // null (with anyOfPermissions also null) = always visible
  final List<String>? anyOfPermissions; // visible if user holds ANY of these
  final List<String>? excludeRoles; // hidden for these role names regardless of permission
  final String? badge;

  const NavItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.path,
    this.permission,
    this.anyOfPermissions,
    this.excludeRoles,
    this.badge,
  });
}

// ─── Full nav definition ──────────────────────────────────────────────────────
// Mirrors the ALL_NAV array in frontend/lib/navConfig.ts exactly.
// Tabler icons are mapped to the nearest Material icon equivalents.

const kAllNav = <NavEntry>[
  NavSection('Main'),
  NavItem(id: 'dashboard',        icon: Icons.dashboard_outlined,              label: 'Dashboard',        path: '/dashboard',                  permission: null),
  NavItem(id: 'announcements',    icon: Icons.campaign_outlined,               label: 'Announcements',    path: '/dashboard/announcements',    permission: 'announcements.view'),

  NavSection('Recruitment'),
  NavItem(id: 'interview-list',   icon: Icons.people_outline,                  label: 'Interview List',   path: '/dashboard/interview-list',   permission: 'recruitment.view'),
  NavItem(id: 'candidate-review', icon: Icons.how_to_reg_outlined,             label: 'Review & Onboarding', path: '/dashboard/candidate-review', permission: 'recruitment.view'),
  NavItem(id: 'assessments',      icon: Icons.assignment_outlined,             label: 'Assessments',      path: '/dashboard/assessments',      permission: 'assessments.view'),
  NavItem(id: 'email-logs',       icon: Icons.mail_outline,                    label: 'Email Logs',       path: '/dashboard/email-logs',       permission: 'recruitment.view'),

  NavSection('Workforce'),
  NavItem(id: 'employees',        icon: Icons.badge_outlined,                  label: 'Employees',        path: '/dashboard/employees',        permission: 'employees.view'),
  NavItem(id: 'org-chart',        icon: Icons.account_tree_outlined,           label: 'Org Chart',        path: '/dashboard/org-chart',        permission: 'employees.view'),
  NavItem(id: 'branches',         icon: Icons.business_outlined,               label: 'Branches',         path: '/dashboard/branches',         permission: 'branches.view'),

  NavSection('Time & Pay'),
  NavItem(id: 'attendance',       icon: Icons.access_time_outlined,            label: 'Attendance',       path: '/dashboard/attendance',       permission: 'attendance.view', excludeRoles: ['employee']),
  NavItem(id: 'leave',            icon: Icons.beach_access_outlined,           label: 'Leave Management', path: '/dashboard/leave',            permission: 'leave.view'),
  NavItem(id: 'expenses',         icon: Icons.account_balance_wallet_outlined, label: 'Expenses',         path: '/dashboard/expenses',         permission: 'expenses.view'),

  NavSection('HR Ops'),
  // Backend's approval endpoints authorize on 'leave.approve' OR 'expenses.approve'
  // (any one grants access) and HR/HR Admin manage approvals through their own
  // dedicated workflows, not this generic link — matches web's navConfig.ts exactly.
  NavItem(id: 'approvals',        icon: Icons.checklist_outlined,              label: 'Approvals',        path: '/dashboard/approvals',        anyOfPermissions: ['leave.approve', 'expenses.approve'], excludeRoles: ['hr', 'hr_admin']),
  NavItem(id: 'separation',       icon: Icons.exit_to_app_outlined,            label: 'Separation & FnF', path: '/dashboard/separation',       permission: 'employees.view'),
  NavItem(id: 'documents',        icon: Icons.folder_outlined,                 label: 'Document Center',  path: '/dashboard/documents',        permission: 'documents.view'),

  NavSection('My'),
  NavItem(id: 'my-attendance',    icon: Icons.fingerprint,                     label: 'My Attendance',    path: '/dashboard/my-attendance',    permission: null),
  NavItem(id: 'referrals',        icon: Icons.person_add_alt_1_outlined,       label: 'My Referrals',     path: '/dashboard/referrals',        permission: null),
  NavItem(id: 'my-requests',      icon: Icons.inbox_outlined,                  label: 'My Requests',      path: '/dashboard/my-requests',      permission: null),
  NavItem(id: 'profile',          icon: Icons.account_circle_outlined,         label: 'My Profile',       path: '/dashboard/profile',          permission: null),

  NavSection('System'),
  NavItem(id: 'reports',          icon: Icons.bar_chart_outlined,              label: 'Reports',          path: '/dashboard/reports',          permission: 'reports.view'),
  // Points straight at the real, fully-wired Audit Log screen (same one
  // reachable from Settings → Audit Log) instead of the unimplemented
  // placeholder that used to sit at /dashboard/audit.
  NavItem(id: 'audit',            icon: Icons.security_outlined,               label: 'Audit Log',        path: '/settings/audit',             permission: 'audit.view'),
  NavItem(id: 'settings',         icon: Icons.settings_outlined,               label: 'Settings',         path: '/dashboard/settings',         permission: 'settings.view'),
];

// ─── Dart port of TypeScript buildNav() ──────────────────────────────────────
// Filters kAllNav to items the user can see, suppressing sections that would
// be empty. Mirrors the logic in frontend/lib/navConfig.ts exactly.

List<NavEntry> buildNav(List<String> permissions, {String? role}) {
  final permSet = <String>{...permissions};
  final result = <NavEntry>[];
  NavSection? pendingSection;
  var sectionHasItem = false;

  for (final entry in kAllNav) {
    switch (entry) {
      case NavSection():
        pendingSection = entry;
        sectionHasItem = false;
      case NavItem():
        final permVisible = entry.anyOfPermissions != null
            ? entry.anyOfPermissions!.any(permSet.contains)
            : (entry.permission == null || permSet.contains(entry.permission!));
        final roleVisible = role == null ||
            entry.excludeRoles == null ||
            !entry.excludeRoles!.contains(role);
        if (permVisible && roleVisible) {
          if (pendingSection != null && !sectionHasItem) {
            result.add(pendingSection);
          }
          result.add(entry);
          sectionHasItem = true;
        }
    }
  }
  return result;
}

// ─── Page title map ───────────────────────────────────────────────────────────
// Mirrors PAGE_TITLES from frontend/components/dashboard/DashboardShell.tsx.

const kPageTitles = <String, String>{
  '/dashboard':                 'Dashboard',
  '/dashboard/announcements':   'Announcements',
  '/dashboard/interview-list':  'Interview List',
  '/dashboard/candidate-review':'Candidate Review & Onboarding',
  '/dashboard/assessments':     'Assessment Management',
  '/dashboard/email-logs':      'Email Logs',
  '/dashboard/employees':       'Employees',
  '/dashboard/org-chart':       'Organisation Chart',
  '/dashboard/branches':        'Branch Management',
  '/dashboard/attendance':      'Attendance & Time',
  '/dashboard/leave':           'Leave Management',
  '/dashboard/expenses':        'Expense Claims',
  '/dashboard/approvals':       'Team Approvals',
  '/dashboard/separation':      'Separation & FnF',
  '/dashboard/documents':       'Document Center',
  '/dashboard/my-attendance':   'My Attendance',
  '/dashboard/referrals':       'My Referrals',
  '/dashboard/my-requests':     'My Requests',
  '/dashboard/profile':         'My Profile',
  '/dashboard/reports':         'Reports',
  '/dashboard/settings':        'Settings',
};

String pageTitle(String path) =>
    kPageTitles[path] ?? 'Royal HRMS';

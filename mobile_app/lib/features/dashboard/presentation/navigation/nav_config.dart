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
  final String? permission; // null = always visible
  final String? badge;

  const NavItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.path,
    this.permission,
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
  NavItem(id: 'candidate-review', icon: Icons.how_to_reg_outlined,             label: 'Candidate Review', path: '/dashboard/candidate-review', permission: 'recruitment.view'),
  NavItem(id: 'email-logs',       icon: Icons.mail_outline,                    label: 'Email Logs',       path: '/dashboard/email-logs',       permission: 'recruitment.view'),

  NavSection('Workforce'),
  NavItem(id: 'employees',        icon: Icons.badge_outlined,                  label: 'Employees',        path: '/dashboard/employees',        permission: 'employees.view'),
  NavItem(id: 'org-chart',        icon: Icons.account_tree_outlined,           label: 'Org Chart',        path: '/dashboard/org-chart',        permission: 'employees.view'),
  NavItem(id: 'branches',         icon: Icons.business_outlined,               label: 'Branches',         path: '/dashboard/branches',         permission: 'branches.view'),

  NavSection('Time & Pay'),
  NavItem(id: 'attendance',       icon: Icons.access_time_outlined,            label: 'Attendance',       path: '/dashboard/attendance',       permission: 'attendance.view'),
  NavItem(id: 'payroll',          icon: Icons.payments_outlined,               label: 'Payroll',          path: '/dashboard/payroll',          permission: 'payroll.view'),
  NavItem(id: 'my-payslip',       icon: Icons.receipt_long_outlined,           label: 'My Payslips',      path: '/dashboard/my-payslip',       permission: 'payroll.view'),
  NavItem(id: 'leave',            icon: Icons.beach_access_outlined,           label: 'Leave Management', path: '/dashboard/leave',            permission: 'leave.view'),
  NavItem(id: 'expenses',         icon: Icons.account_balance_wallet_outlined, label: 'Expenses',         path: '/dashboard/expenses',         permission: 'expenses.view'),

  NavSection('HR Ops'),
  NavItem(id: 'approvals',        icon: Icons.checklist_outlined,              label: 'Approvals',        path: '/dashboard/approvals',        permission: 'leave.view'),
  NavItem(id: 'separation',       icon: Icons.exit_to_app_outlined,            label: 'Separation & FnF', path: '/dashboard/separation',       permission: 'employees.view'),
  NavItem(id: 'documents',        icon: Icons.folder_outlined,                 label: 'Document Center',  path: '/dashboard/documents',        permission: 'documents.view'),

  NavSection('My'),
  NavItem(id: 'my-requests',      icon: Icons.inbox_outlined,                  label: 'My Requests',      path: '/dashboard/my-requests',      permission: null),
  NavItem(id: 'profile',          icon: Icons.account_circle_outlined,         label: 'My Profile',       path: '/dashboard/profile',          permission: null),

  NavSection('System'),
  NavItem(id: 'reports',          icon: Icons.bar_chart_outlined,              label: 'Reports',          path: '/dashboard/reports',          permission: 'reports.view'),
  NavItem(id: 'audit',            icon: Icons.security_outlined,               label: 'Audit Log',        path: '/dashboard/audit',            permission: 'audit.view'),
  NavItem(id: 'settings',         icon: Icons.settings_outlined,               label: 'Settings',         path: '/dashboard/settings',         permission: 'settings.view'),
];

// ─── Dart port of TypeScript buildNav() ──────────────────────────────────────
// Filters kAllNav to items the user can see, suppressing sections that would
// be empty. Mirrors the logic in frontend/lib/navConfig.ts exactly.

List<NavEntry> buildNav(List<String> permissions) {
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
        final visible =
            entry.permission == null || permSet.contains(entry.permission!);
        if (visible) {
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
  '/dashboard/candidate-review':'Candidate Review',
  '/dashboard/email-logs':      'Email Logs',
  '/dashboard/employees':       'Employees',
  '/dashboard/org-chart':       'Organisation Chart',
  '/dashboard/branches':        'Branch Management',
  '/dashboard/attendance':      'Attendance & Time',
  '/dashboard/payroll':         'Payroll Management',
  '/dashboard/my-payslip':      'My Payslips',
  '/dashboard/leave':           'Leave Management',
  '/dashboard/expenses':        'Expense Claims',
  '/dashboard/approvals':       'Team Approvals',
  '/dashboard/separation':      'Separation & FnF',
  '/dashboard/documents':       'Document Center',
  '/dashboard/my-requests':     'My Requests',
  '/dashboard/profile':         'My Profile',
  '/dashboard/reports':         'Reports',
  '/dashboard/audit':           'Audit Log',
  '/dashboard/settings':        'Settings',
};

String pageTitle(String path) =>
    kPageTitles[path] ?? 'Royal HRMS';

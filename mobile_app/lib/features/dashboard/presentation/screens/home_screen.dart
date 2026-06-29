import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final permissions = user?.permissions ?? const [];
    final quickAccess = _quickAccess(permissions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeCard(
            name: user?.fullName ?? '',
            roleDisplay: user?.roleDisplay ?? '',
            permissions: permissions,
          ),
          const SizedBox(height: 20),

          if (quickAccess.isNotEmpty) ...[
            Text('Quick Access', style: AppTextStyles.h4),
            const SizedBox(height: 12),
            _QuickAccessGrid(items: quickAccess),
            const SizedBox(height: 20),
          ],

          Text('Recent Activity', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          const _ComingSoonCard(
            icon: Icons.history_rounded,
            label: 'Recent activity feed will appear here.',
          ),
        ],
      ),
    );
  }

  /// Returns quick-access items filtered by the user's permissions.
  List<_QuickItem> _quickAccess(List<String> permissions) {
    final permSet = <String>{...permissions};
    return _kQuickItems.where((item) {
      return item.permission == null || permSet.contains(item.permission);
    }).toList();
  }
}

// ── Welcome card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String roleDisplay;
  final List<String> permissions;

  const _WelcomeCard({
    required this.name,
    required this.roleDisplay,
    required this.permissions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2A6ACC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day,',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Welcome' : name,
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleDisplay.isEmpty ? 'Employee' : roleDisplay,
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${permissions.length} permission${permissions.length == 1 ? '' : 's'} granted',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _LargeInitialsAvatar(name: name),
        ],
      ),
    );
  }
}

// ── Quick access grid ────────────────────────────────────────────────────────

class _QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final String path;
  final String? permission;

  const _QuickItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.path,
    this.permission,
  });
}

const _kQuickItems = <_QuickItem>[
  _QuickItem(label: 'Employees',   icon: Icons.badge_outlined,         color: Color(0xFF1E4E8C), path: '/dashboard/employees',   permission: 'employees.view'),
  _QuickItem(label: 'Attendance',  icon: Icons.access_time_outlined,   color: Color(0xFF1B8A6B), path: '/dashboard/attendance',  permission: 'attendance.view'),
  _QuickItem(label: 'Leave',       icon: Icons.beach_access_outlined,  color: Color(0xFFB5651D), path: '/dashboard/leave',       permission: 'leave.view'),
  _QuickItem(label: 'Payroll',     icon: Icons.payments_outlined,      color: Color(0xFF6B3FA0), path: '/dashboard/payroll',     permission: 'payroll.view'),
  _QuickItem(label: 'Approvals',   icon: Icons.checklist_outlined,     color: Color(0xFF0E7C86), path: '/dashboard/approvals',   permission: 'leave.view'),
  _QuickItem(label: 'Documents',   icon: Icons.folder_outlined,        color: Color(0xFFC0392B), path: '/dashboard/documents',   permission: 'documents.view'),
  _QuickItem(label: 'My Profile',  icon: Icons.account_circle_outlined,color: Color(0xFF2A6ACC), path: '/dashboard/profile',     permission: null),
  _QuickItem(label: 'My Requests', icon: Icons.inbox_outlined,         color: Color(0xFF5D4037), path: '/dashboard/my-requests', permission: null),
];

class _QuickAccessGrid extends StatelessWidget {
  final List<_QuickItem> items;

  const _QuickAccessGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) => _QuickTile(item: items[index]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final _QuickItem item;

  const _QuickTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(item.path),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coming soon placeholder ───────────────────────────────────────────────────

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoonCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textHint, size: 32),
          const SizedBox(height: 10),
          Text(label, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Large initials avatar ─────────────────────────────────────────────────────

class _LargeInitialsAvatar extends StatelessWidget {
  final String name;

  const _LargeInitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = name.isEmpty
        ? '?'
        : parts.length == 1
            ? parts[0][0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

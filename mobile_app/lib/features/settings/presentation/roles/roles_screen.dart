import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/roles_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/role_form_sheet.dart';

const _kModuleLabels = {
  'employees': 'Employees', 'recruitment': 'Recruitment',
  'attendance': 'Attendance', 'leave': 'Leave',
  'payroll': 'Payroll', 'expenses': 'Expenses',
  'referrals': 'Referrals', 'announcements': 'Announcements',
  'documents': 'Documents', 'settings': 'Settings',
  'reports': 'Reports', 'audit': 'Audit', 'branches': 'Branches',
};

String _moduleLabel(String m) =>
    _kModuleLabels[m] ?? (m.isEmpty ? m : m[0].toUpperCase() + m.substring(1));

// Banner colors — same style as email templates
const _kRolesBannerColor   = Color(0xFF1B3A6B); // navy  — All Roles
const _kMatrixBannerColor  = Color(0xFF0D6B4A); // green — Permission Matrix modules

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(rolesProvider);
    final permsAsync = ref.watch(allPermissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'Roles & Permissions',
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
          onPressed: () => _openForm(context, ref, null),
          tooltip: 'Add Role',
        ),
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (roles) => _buildBody(context, ref, roles, permsAsync),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<RoleModel> roles,
    AsyncValue<List<PermissionModel>> permsAsync,
  ) {
    if (roles.isEmpty) return _EmptyView(onAdd: () => _openForm(context, ref, null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          'Control what each role can access across all modules',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        // ── All Roles group card ──────────────────────────────────────
        _RolesGroupCard(
          roles: roles,
          onEdit:   (role) => _openForm(context, ref, role),
          onToggle: (role, v) => _toggle(context, ref, role, v),
        ),
        const SizedBox(height: 14),
        // ── Permission Matrix group cards ─────────────────────────────
        permsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (perms) => _PermissionMatrixSection(roles: roles, permissions: perms),
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, RoleModel? role) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: RoleFormSheet(role: role, ref: ref),
      ),
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, RoleModel role, bool val) async {
    final error = await ref.read(rolesProvider.notifier).toggleActive(role.id, val);
    if (!context.mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── All-Roles group card ──────────────────────────────────────────────────────

class _RolesGroupCard extends StatelessWidget {
  final List<RoleModel> roles;
  final void Function(RoleModel) onEdit;
  final void Function(RoleModel, bool) onToggle;

  const _RolesGroupCard({
    required this.roles,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner header ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _kRolesBannerColor,
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'All Roles',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${roles.length} role${roles.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // ── Role rows ────────────────────────────────────────────────
          ...List.generate(roles.length, (i) => Column(
            children: [
              const Divider(height: 1, color: AppColors.border),
              _RoleRow(
                role: roles[i],
                onEdit:   () => onEdit(roles[i]),
                onToggle: (v) => onToggle(roles[i], v),
              ),
            ],
          )),
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  final RoleModel role;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  const _RoleRow({required this.role, required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isSystem = role.isSystem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name / slug / status
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSystem
                        ? [const Color(0xFF9B51E0), const Color(0xFF7B3FBF)]
                        : [AppColors.primary, const Color(0xFF2A6ACC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSystem ? Icons.verified_user_outlined : Icons.shield_outlined,
                  color: Colors.white, size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            role.displayName.isNotEmpty ? role.displayName : role.name,
                            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSystem)
                          const _SmallBadge(label: 'System', color: Color(0xFF9B51E0)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.name,
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(isActive: role.isActive),
            ],
          ),
        ),
        // Stats + actions
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
          child: Row(
            children: [
              _StatChip(
                icon: Icons.lock_outline,
                value: '${role.permissions.length}',
                label: 'perms',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.people_outline,
                value: '${role.userCount}',
                label: role.userCount == 1 ? 'user' : 'users',
                color: AppColors.success,
              ),
              const Spacer(),
              if (!isSystem) ...[
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onTap: onEdit,
                  color: AppColors.primary,
                  filled: true,
                ),
                const SizedBox(width: 6),
              ],
              Transform.scale(
                scale: 0.8,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: role.isActive,
                  onChanged: isSystem ? null : onToggle,
                  activeTrackColor: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Permission Matrix — each module is its own group card ────────────────────

class _PermissionMatrixSection extends StatelessWidget {
  final List<RoleModel> roles;
  final List<PermissionModel> permissions;

  const _PermissionMatrixSection({required this.roles, required this.permissions});

  @override
  Widget build(BuildContext context) {
    final permsMap = <String, List<PermissionModel>>{};
    for (final p in permissions) {
      if (p.module != null) permsMap.putIfAbsent(p.module!, () => []).add(p);
    }
    final modules = permsMap.keys.toList()..sort();

    if (modules.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label above the module cards
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.grid_view_outlined, size: 16, color: _kMatrixBannerColor),
              const SizedBox(width: 6),
              Text(
                'Permission Matrix',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${modules.length} modules · ${roles.length} roles',
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
        ...List.generate(modules.length, (i) {
          final mod = modules[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModuleGroupCard(
              module: mod,
              roles: roles,
              perms: permsMap[mod] ?? [],
            ),
          );
        }),
      ],
    );
  }
}

class _ModuleGroupCard extends StatelessWidget {
  final String module;
  final List<RoleModel> roles;
  final List<PermissionModel> perms;

  const _ModuleGroupCard({required this.module, required this.roles, required this.perms});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Colored banner — clipped to card's rounded top corners ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _kMatrixBannerColor,
            child: Row(
              children: [
                const Icon(Icons.grid_on_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _moduleLabel(module),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${perms.length} permission${perms.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // ── Role access rows ─────────────────────────────────────────
          ...List.generate(roles.length, (i) => Column(
            children: [
              const Divider(height: 1, color: AppColors.border),
              _RoleMatrixRow(role: roles[i], modulePerms: perms),
            ],
          )),
        ],
      ),
    );
  }
}

class _RoleMatrixRow extends StatelessWidget {
  final RoleModel role;
  final List<PermissionModel> modulePerms;

  const _RoleMatrixRow({required this.role, required this.modulePerms});

  @override
  Widget build(BuildContext context) {
    final roleHas = role.permissions.toSet();
    final matched = modulePerms.where((p) => roleHas.contains(p.name)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              role.displayName.isNotEmpty ? role.displayName : role.name,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _PermBadge(matched: matched, total: modulePerms.length),
        ],
      ),
    );
  }
}

class _PermBadge extends StatelessWidget {
  final List<PermissionModel> matched;
  final int total;

  const _PermBadge({required this.matched, required this.total});

  @override
  Widget build(BuildContext context) {
    if (matched.isEmpty) {
      return Text('—', style: AppTextStyles.caption.copyWith(color: AppColors.textHint));
    }
    if (matched.length == total) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Full ($total)',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }
    return Wrap(
      spacing: 4, runSpacing: 4,
      children: matched.map((p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(
          p.description ?? '',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      )).toList(),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: AppTextStyles.caption.copyWith(
              color: color, fontWeight: FontWeight.w600, fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color, fontSize: 10, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final bool filled;

  const _ActionBtn({
    required this.icon, required this.tooltip, required this.onTap,
    required this.color, this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: filled ? 0 : 0.2)),
          ),
          child: Icon(icon, size: 16, color: filled ? Colors.white : color),
        ),
      ),
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shield_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No roles configured', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Create roles to manage user access and permissions.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Role'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load roles', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

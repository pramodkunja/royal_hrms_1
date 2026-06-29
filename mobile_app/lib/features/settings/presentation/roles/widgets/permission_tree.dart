import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/roles_model.dart';

const _kModuleLabels = {
  'employees': 'Employees', 'recruitment': 'Recruitment',
  'attendance': 'Attendance', 'leave': 'Leave',
  'payroll': 'Payroll', 'expenses': 'Expenses',
  'referrals': 'Referrals', 'announcements': 'Announcements',
  'documents': 'Documents', 'settings': 'Settings',
  'reports': 'Reports', 'audit': 'Audit', 'branches': 'Branches',
};

String _label(String m) =>
    _kModuleLabels[m] ?? (m.isEmpty ? m : m[0].toUpperCase() + m.substring(1));

String _actionLabel(String? action) {
  if (action == null || action.isEmpty) return '';
  return action[0].toUpperCase() + action.substring(1);
}

/// Full accordion permission tree grouped by module.
class PermissionTree extends StatelessWidget {
  final List<PermissionModel> permissions;
  final Set<String> selected;
  final ValueChanged<String> onTogglePerm;
  final void Function(String module, bool selectAll) onToggleModule;

  const PermissionTree({
    super.key,
    required this.permissions,
    required this.selected,
    required this.onTogglePerm,
    required this.onToggleModule,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<PermissionModel>>{};
    for (final p in permissions) {
      grouped.putIfAbsent(p.module ?? 'general', () => []).add(p);
    }
    final modules = grouped.keys.toList()..sort();

    if (modules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No permissions available.', style: AppTextStyles.bodySecondary),
      );
    }

    return Column(
      children: modules.map((mod) => _ModuleBlock(
        module: mod,
        perms: grouped[mod]!,
        selected: selected,
        onTogglePerm: onTogglePerm,
        onToggleModule: onToggleModule,
      )).toList(),
    );
  }
}

class _ModuleBlock extends StatefulWidget {
  final String module;
  final List<PermissionModel> perms;
  final Set<String> selected;
  final ValueChanged<String> onTogglePerm;
  final void Function(String, bool) onToggleModule;

  const _ModuleBlock({
    required this.module,
    required this.perms,
    required this.selected,
    required this.onTogglePerm,
    required this.onToggleModule,
  });

  @override
  State<_ModuleBlock> createState() => _ModuleBlockState();
}

class _ModuleBlockState extends State<_ModuleBlock> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final codenames = widget.perms.map((p) => p.name).toSet();
    final checkedCount = codenames.intersection(widget.selected).length;
    final total = codenames.length;
    final isAll = checkedCount == total;
    final isPartial = checkedCount > 0 && !isAll;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Module header row
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: isAll ? true : (isPartial ? null : false),
                    activeColor: AppColors.primary,
                    onChanged: (_) => widget.onToggleModule(widget.module, !isAll),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _label(widget.module),
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '$checkedCount/$total',
                    style: AppTextStyles.caption.copyWith(
                      color: isAll ? AppColors.success : (isPartial ? AppColors.primary : AppColors.textHint),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          // Action checkboxes
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: _ActionGrid(
                perms: widget.perms,
                selected: widget.selected,
                onToggle: widget.onTogglePerm,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final List<PermissionModel> perms;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _ActionGrid({required this.perms, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // 3-column grid of action checkboxes
    const cols = 3;
    final rows = (perms.length / cols).ceil();

    return Column(
      children: List.generate(rows, (row) {
        final rowItems = perms.skip(row * cols).take(cols).toList();
        return Row(
          children: [
            ...rowItems.map((p) => Expanded(
              child: _ActionCheckbox(
                label: _actionLabel(p.description),
                checked: selected.contains(p.name),
                onTap: () => onToggle(p.name),
              ),
            )),
            // Fill empty slots in last row
            ...List.generate(cols - rowItems.length, (_) => const Expanded(child: SizedBox())),
          ],
        );
      }),
    );
  }
}

class _ActionCheckbox extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;
  const _ActionCheckbox({required this.label, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: checked,
            onChanged: (_) => onTap(),
            activeColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: checked ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/departments_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/dept_form_sheet.dart';
import 'widgets/desig_form_sheet.dart';

class DepartmentsScreen extends ConsumerStatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  ConsumerState<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends ConsumerState<DepartmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'Depts & Designations',
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
          onPressed: _onAdd,
          tooltip: _tabs.index == 0 ? 'Add Department' : 'Add Designation',
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTextStyles.label,
          tabs: const [
            Tab(text: 'Departments'),
            Tab(text: 'Designations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DepartmentsTab(
            onAdd: _onAdd,
            onEdit: (d) => _openDeptEdit(d),
          ),
          _DesignationsTab(
            onAdd: _onAdd,
            onEdit: (d) => _openDesigEdit(d),
          ),
        ],
      ),
    );
  }

  void _onAdd() {
    if (_tabs.index == 0) {
      _openDeptEdit(null);
    } else {
      _openDesigEdit(null);
    }
  }

  Future<void> _openDeptEdit(DepartmentModel? dept) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: DeptFormSheet(department: dept, ref: ref),
      ),
    );
  }

  Future<void> _openDesigEdit(DesignationModel? desig) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: DesigFormSheet(designation: desig, ref: ref),
      ),
    );
  }
}

// ── Departments tab ───────────────────────────────────────────────────────────

class _DepartmentsTab extends ConsumerWidget {
  final VoidCallback onAdd;
  final ValueChanged<DepartmentModel> onEdit;
  const _DepartmentsTab({required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(departmentsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (depts) => depts.isEmpty
          ? _EmptyView(
              icon: Icons.account_tree_outlined,
              label: 'No departments yet',
              subtitle: 'Add departments to organise your organisation.',
              onAdd: onAdd,
            )
          : Column(
              children: [
                _TabSummary(count: depts.length, label: 'department'),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: depts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _DeptCard(
                      dept: depts[i],
                      onEdit: () => onEdit(depts[i]),
                      onDelete: () => _confirmDelete(ctx, ref, depts[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DepartmentModel dept) async {
    final ok = await _showDeleteDialog(context, dept.name);
    if (!ok || !context.mounted) return;
    final error = await ref.read(departmentsProvider.notifier).removeDept(dept.id);
    if (context.mounted) {
      _toast(context, error ?? '"${dept.name}" deleted.', error == null);
    }
  }
}

// ── Designations tab ──────────────────────────────────────────────────────────

class _DesignationsTab extends ConsumerWidget {
  final VoidCallback onAdd;
  final ValueChanged<DesignationModel> onEdit;
  const _DesignationsTab({required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(designationsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString()),
      data: (desigs) => desigs.isEmpty
          ? _EmptyView(
              icon: Icons.work_outline,
              label: 'No designations yet',
              subtitle: 'Add job designations within departments.',
              onAdd: onAdd,
            )
          : Column(
              children: [
                _TabSummary(count: desigs.length, label: 'designation'),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: desigs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _DesigCard(
                      desig: desigs[i],
                      onEdit: () => onEdit(desigs[i]),
                      onDelete: () => _confirmDelete(ctx, ref, desigs[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DesignationModel desig) async {
    final ok = await _showDeleteDialog(context, desig.name);
    if (!ok || !context.mounted) return;
    final error = await ref.read(designationsProvider.notifier).removeDesig(desig.id);
    if (context.mounted) {
      _toast(context, error ?? '"${desig.name}" deleted.', error == null);
    }
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _DeptCard extends StatelessWidget {
  final DepartmentModel dept;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DeptCard({required this.dept, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dept.name,
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dept.description != null && dept.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dept.description!,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusDot(isActive: dept.isActive),
                const SizedBox(width: 4),
                _ActionMenu(onEdit: onEdit, onDelete: onDelete),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatItem(
                  icon: Icons.work_outline,
                  value: '${dept.designationCount}',
                  label: 'designations',
                  color: const Color(0xFF219653),
                ),
                const SizedBox(width: 20),
                _StatItem(
                  icon: Icons.people_outline,
                  value: '${dept.employeeCount}',
                  label: 'employees',
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesigCard extends StatelessWidget {
  final DesignationModel desig;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DesigCard({required this.desig, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF219653).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.work_outline, color: Color(0xFF219653), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desig.name,
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        desig.departmentName ?? '—',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _StatusDot(isActive: desig.isActive),
            const SizedBox(width: 4),
            _ActionMenu(onEdit: onEdit, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _TabSummary extends StatelessWidget {
  final int count;
  final String label;
  const _TabSummary({required this.count, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      '$count $label${count == 1 ? '' : 's'}',
      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  final bool isActive;
  const _StatusDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.success : AppColors.textHint,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(
        '$value $label',
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _ActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ActionMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textHint),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onAdd;
  const _EmptyView({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(label, style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
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
            Text('Could not load', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Shared utilities ──────────────────────────────────────────────────────────

Future<bool> _showDeleteDialog(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Confirm Delete'),
      content: Text('Delete "$name"? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _toast(BuildContext context, String msg, bool ok) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: ok ? AppColors.success : AppColors.error,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

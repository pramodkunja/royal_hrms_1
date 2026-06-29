import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/departments_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/dept_form_sheet.dart';
import 'widgets/dept_list_item.dart';
import 'widgets/desig_form_sheet.dart';

class DepartmentsScreen extends ConsumerStatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  ConsumerState<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends ConsumerState<DepartmentsScreen> {
  int? _selectedDeptId;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Depts & Designations'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDeptEdit(null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Department',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: deptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (depts) => _Body(
          depts: depts,
          query: _query,
          searchCtrl: _searchCtrl,
          selectedDeptId: _selectedDeptId,
          onQueryChanged: (q) => setState(() => _query = q),
          onSelectDept: (id) => setState(
            () => _selectedDeptId = (_selectedDeptId == id) ? null : id,
          ),
          onEditDept: _openDeptEdit,
          onDeleteDept: _confirmDeleteDept,
          onAddDesig: (deptId) => _openDesigEdit(null, defaultDeptId: deptId),
          onEditDesig: (d) => _openDesigEdit(d),
          onDeleteDesig: _confirmDeleteDesig,
        ),
      ),
    );
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

  Future<void> _openDesigEdit(DesignationModel? desig, {int? defaultDeptId}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: DesigFormSheet(designation: desig, ref: ref, defaultDeptId: defaultDeptId),
      ),
    );
  }

  Future<void> _confirmDeleteDept(DepartmentModel dept) async {
    final ok = await _showDeleteDialog(context, dept.name);
    if (!ok || !mounted) return;
    final error = await ref.read(departmentsProvider.notifier).removeDept(dept.id);
    if (mounted) _toast(context, error ?? '"${dept.name}" deleted.', error == null);
    if (error == null && _selectedDeptId == dept.id) {
      setState(() => _selectedDeptId = null);
    }
  }

  Future<void> _confirmDeleteDesig(DesignationModel desig) async {
    final ok = await _showDeleteDialog(context, desig.name);
    if (!ok || !mounted) return;
    final error = await ref.read(designationsProvider.notifier).removeDesig(desig.id);
    if (mounted) _toast(context, error ?? '"${desig.name}" deleted.', error == null);
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final List<DepartmentModel> depts;
  final String query;
  final TextEditingController searchCtrl;
  final int? selectedDeptId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSelectDept;
  final ValueChanged<DepartmentModel?> onEditDept;
  final ValueChanged<DepartmentModel> onDeleteDept;
  final ValueChanged<int> onAddDesig;
  final ValueChanged<DesignationModel> onEditDesig;
  final ValueChanged<DesignationModel> onDeleteDesig;

  const _Body({
    required this.depts,
    required this.query,
    required this.searchCtrl,
    required this.selectedDeptId,
    required this.onQueryChanged,
    required this.onSelectDept,
    required this.onEditDept,
    required this.onDeleteDept,
    required this.onAddDesig,
    required this.onEditDesig,
    required this.onDeleteDesig,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDesigs = ref.watch(designationsProvider).valueOrNull ?? const [];

    final filtered = query.isEmpty
        ? depts
        : depts.where((d) => d.name.toLowerCase().contains(query.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsRow(depts: depts, desigCount: allDesigs.length),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: _SearchBar(controller: searchCtrl, onChanged: onQueryChanged),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyView(onAdd: () => onEditDept(null))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final dept = filtered[i];
                    final deptDesigs = allDesigs
                        .where((d) => d.departmentId == dept.id)
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DeptListItem(
                        dept: dept,
                        isExpanded: selectedDeptId == dept.id,
                        designations: deptDesigs,
                        onTap: () => onSelectDept(dept.id),
                        onEdit: () => onEditDept(dept),
                        onDelete: () => onDeleteDept(dept),
                        onAddDesig: () => onAddDesig(dept.id),
                        onEditDesig: onEditDesig,
                        onDeleteDesig: onDeleteDesig,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<DepartmentModel> depts;
  final int desigCount;
  const _StatsRow({required this.depts, required this.desigCount});

  @override
  Widget build(BuildContext context) {
    final activeDepts = depts.where((d) => d.isActive).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.account_tree_outlined,
              count: depts.length,
              label: 'Departments',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.work_outline,
              count: desigCount,
              label: 'Designations',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.verified_outlined,
              count: activeDepts,
              label: 'Active Depts',
              color: const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tinted icon strip
          Container(
            color: color.withValues(alpha: 0.08),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.40),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          // Count + label
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Search departments…',
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.account_tree_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No departments yet', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Add departments to organise your company.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Department'),
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
      content: Text('Delete "$name"? This cannot be undone.'),
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

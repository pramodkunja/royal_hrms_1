import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/data/models/roles_model.dart';
import '../../data/models/employee_model.dart';
import '../providers/employee_providers.dart';

const List<String> _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _displayDate(String iso) {
  if (iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${dt.day} ${_kMonthNames[dt.month - 1]} ${dt.year}';
}

class _PromotionHistoryEntry {
  final String fromDesignation;
  final String toDesignation;
  final bool roleChanged;
  final String effectiveDate; // ISO yyyy-MM-dd
  final String updatedBy;

  const _PromotionHistoryEntry({
    required this.fromDesignation,
    required this.toDesignation,
    required this.roleChanged,
    required this.effectiveDate,
    required this.updatedBy,
  });
}

/// Employee Profile "Promotion" tab — ports web's `PromotionTab.tsx`
/// (`app/dashboard/employees/[id]/_components/PromotionTab.tsx`) exactly,
/// including its real limitations rather than inventing missing backend
/// support: there is no Promotion model, endpoint, or persisted history
/// anywhere in the Django backend. Submitting a promotion just PUTs the
/// employee's `designation`/`role` through the same endpoint the Edit
/// Employee sheet already uses (`updateEmployeeAction` /
/// `PUT /employees/{id}/`), and "Promotion History" below is session-only
/// local state — never fetched from an API, same as web.
class PromotionTab extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const PromotionTab({super.key, required this.employee});

  @override
  ConsumerState<PromotionTab> createState() => _PromotionTabState();
}

class _PromotionTabState extends ConsumerState<PromotionTab> {
  final List<_PromotionHistoryEntry> _history = [];

  Future<void> _openPromoteSheet() async {
    final entry = await _PromoteEmployeeSheet.show(context, employee: widget.employee);
    if (entry != null && mounted) {
      setState(() => _history.insert(0, entry));
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final canEdit =
        ref.watch(authStateProvider).valueOrNull?.user?.hasPermission('employees.edit') ?? false;

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Designation',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      employee.designation.isNotEmpty ? employee.designation : '—',
                      style: AppTextStyles.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(employee.roleDisplay,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 12),
                AppButton(
                  // AppButton's ElevatedButton uses Material 3's default
                  // ~24px-per-side padding — icon + "Promote" needs ~140px
                  // total once that's added, so anything narrower (118 was
                  // tried and overflowed by 22px) clips the label.
                  label: 'Promote',
                  width: 150,
                  leadingIcon: Icons.trending_up_rounded,
                  onPressed: _openPromoteSheet,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Promotion History', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('No promotions recorded yet.', style: AppTextStyles.bodySecondary),
          )
        else
          ..._history.map((e) => _PromotionHistoryCard(entry: e)),
      ],
    );
  }
}

class _PromotionHistoryCard extends StatelessWidget {
  final _PromotionHistoryEntry entry;
  const _PromotionHistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${entry.fromDesignation} → ${entry.toDesignation}',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: 'Applied', color: AppColors.success),
            ],
          ),
          if (entry.roleChanged) ...[
            const SizedBox(height: 6),
            _StatusPill(label: 'Role change', color: AppColors.warning),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(_displayDate(entry.effectiveDate),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              Icon(Icons.person_outline, size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.updatedBy.isNotEmpty ? entry.updatedBy : '—',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── "Promote Employee" sheet ────────────────────────────────────────────────

class _PromoteEmployeeSheet extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const _PromoteEmployeeSheet({required this.employee});

  static Future<_PromotionHistoryEntry?> show(
    BuildContext context, {
    required EmployeeModel employee,
  }) {
    return showModalBottomSheet<_PromotionHistoryEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromoteEmployeeSheet(employee: employee),
    );
  }

  @override
  ConsumerState<_PromoteEmployeeSheet> createState() => _PromoteEmployeeSheetState();
}

class _PromoteEmployeeSheetState extends ConsumerState<_PromoteEmployeeSheet> {
  late String _designation;
  late String _roleSlug;
  late String _effectiveDate;
  final _remarksCtrl = TextEditingController();
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _designation = widget.employee.designation;
    _roleSlug = widget.employee.role;
    final now = DateTime.now();
    _effectiveDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  bool get _isElevated => _roleSlug != widget.employee.role;

  Future<void> _pickEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_effectiveDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _effectiveDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _submit() async {
    if (_designation.isEmpty) {
      setState(() => _error = 'Select a new designation.');
      return;
    }
    if (_roleSlug.isEmpty) {
      setState(() => _error = 'Select a system role.');
      return;
    }
    // Matches web's exact copy/gate: PromotionTab.tsx blocks submit with
    // this same message until the elevation checkbox is ticked.
    if (_isElevated && !_confirmed) {
      setState(() => _error = 'Confirm the role change before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final fromDesignation = widget.employee.designation;
    final form = EmployeeUpdateFormData.fromModel(widget.employee)
      ..designation = _designation
      ..role = _roleSlug;

    final err = await updateEmployeeAction(ref, widget.employee.id, form);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final updatedBy = ref.read(authStateProvider).valueOrNull?.user?.fullName ?? '';
    Navigator.of(context).pop(_PromotionHistoryEntry(
      fromDesignation: fromDesignation,
      toDesignation: _designation,
      roleChanged: _isElevated,
      effectiveDate: _effectiveDate,
      updatedBy: updatedBy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.trending_up_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Promote Employee',
                          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DesignationField(
                        employee: widget.employee,
                        selected: _designation,
                        onChanged: (v) => setState(() => _designation = v ?? ''),
                      ),
                      const SizedBox(height: 14),
                      _RoleField(
                        selected: _roleSlug,
                        onChanged: (v) => setState(() => _roleSlug = v),
                      ),
                      const SizedBox(height: 14),
                      Text('Effective Date', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickEffectiveDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.backgroundMid,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(_displayDate(_effectiveDate), style: AppTextStyles.body),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Remarks (optional)',
                        hint: 'Reason for promotion',
                        controller: _remarksCtrl,
                        maxLines: 3,
                      ),
                      if (_isElevated) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This changes the employee\'s system role and access — review carefully.',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => setState(() => _confirmed = !_confirmed),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _confirmed,
                                onChanged: (v) => setState(() => _confirmed = v ?? false),
                                activeColor: AppColors.primary,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'I confirm this role change and its access impact.',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: AppButton(
                  label: 'Submit Promotion',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignationField extends ConsumerWidget {
  final EmployeeModel employee;
  final String selected;
  final ValueChanged<String?> onChanged;

  const _DesignationField({required this.employee, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depts = ref.watch(employeeFormDepartmentsProvider).valueOrNull ?? [];
    final deptId = depts.where((d) => d.name == employee.department).firstOrNull?.id;

    final names = deptId == null
        ? const <String>[]
        : ref.watch(employeeDesignationsByDeptProvider(deptId)).valueOrNull ?? [];
    // The employee's current designation might not be in the department's
    // active designation list (e.g. a since-renamed/deactivated one) —
    // always include it so the field doesn't silently drop the selection.
    final options = {selected, ...names}.where((d) => d.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('New Designation', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selected.isEmpty ? null : selected,
          isExpanded: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundMid,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          hint: Text('— Select Designation —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: options
              .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RoleField extends ConsumerWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleField({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // system_admin is never assignable via employee edit — the backend
    // rejects it outright, and web excludes it from this dropdown too.
    final roles = (ref.watch(employeeFormRolesProvider).valueOrNull ?? [])
        .where((r) => r.name != 'system_admin')
        .toList();
    final selectedRole = roles.where((r) => r.name == selected).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Role', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<RoleModel>(
          initialValue: selectedRole,
          isExpanded: true,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.backgroundMid,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          hint: Text('— Select Role —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: roles
              .map((r) => DropdownMenuItem(value: r, child: Text(r.displayName, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (r) => onChanged(r?.name ?? ''),
        ),
      ],
    );
  }
}

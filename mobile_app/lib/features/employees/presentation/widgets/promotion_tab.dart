import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/data/models/roles_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/promotion_record_model.dart';
import '../providers/employee_providers.dart';

/// Employee Profile "Promotion" tab — web `PromotionTab.tsx`. History is
/// the persisted record list from GET /employees/<id>/promotions/ (newest
/// first, as the server orders it); records are read-only and are created by
/// the backend whenever a promotion (PUT /employees/<id>/) changes the
/// designation or role. Viewing needs employees.view, promoting employees.edit.
class PromotionTab extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const PromotionTab({super.key, required this.employee});

  @override
  ConsumerState<PromotionTab> createState() => _PromotionTabState();
}

class _PromotionTabState extends ConsumerState<PromotionTab> {
  Future<void> _openPromoteSheet() async {
    final message = await _PromoteEmployeeSheet.show(context, employee: widget.employee);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final canEdit = userHasPermission(ref.watch(authStateProvider).valueOrNull?.user, 'employees.edit');
    final historyAsync = ref.watch(employeePromotionsProvider(employee.employeeId));
    final roleLabels = {
      for (final r in ref.watch(employeeFormRolesProvider).valueOrNull ?? const <RoleModel>[]) r.name: r.displayName,
    };

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
        ...historyAsync.when(
          loading: () => [
            const _HistoryMessage(key: Key('promotion-history-loading'), title: 'Loading history…'),
          ],
          error: (e, _) => [
            _HistoryMessage(
              key: const Key('promotion-history-error'),
              title: 'Could not load promotion history.',
              action: TextButton(
                key: const Key('promotion-history-retry'),
                onPressed: () => ref.invalidate(employeePromotionsProvider(employee.employeeId)),
                child: const Text('Retry'),
              ),
            ),
          ],
          data: (records) => records.isEmpty
              ? [
                  const _HistoryMessage(
                    key: Key('promotion-history-empty'),
                    title: 'No promotions yet',
                    subtitle: 'Designation and role changes for this employee will be listed here.',
                  ),
                ]
              : [for (final r in records) _PromotionHistoryCard(record: r, roleLabels: roleLabels)],
        ),
      ],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const _HistoryMessage({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
        ],
        if (action != null) action!,
      ]),
    );
  }
}

/// One record — web history row: designation change (+ "Promotion"),
/// role change (+ "Role change"), effective date, updated by, "Applied".
class _PromotionHistoryCard extends StatelessWidget {
  final PromotionRecordModel record;
  final Map<String, String> roleLabels;
  const _PromotionHistoryCard({required this.record, required this.roleLabels});

  String _role(String slug) => slug.isEmpty ? '—' : (roleLabels[slug] ?? slug);
  String _or(String v) => v.isEmpty ? '—' : v;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Container(
      key: Key('promotion-${r.id}'),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (r.designationChanged)
                    _ChangeLine(
                      key: Key('promotion-${r.id}-designation'),
                      text: '${_or(r.previousDesignation)} → ${_or(r.newDesignation)}',
                      badge: 'Promotion',
                      color: AppColors.info,
                    ),
                  if (r.roleChanged)
                    _ChangeLine(
                      key: Key('promotion-${r.id}-role'),
                      text: '${_role(r.previousRole)} → ${_role(r.newRole)}',
                      badge: 'Role change',
                      color: AppColors.warning,
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: 'Applied', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(formatPromotionDate(r.effectiveDate),
                  key: Key('promotion-${r.id}-date'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              Icon(Icons.person_outline, size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _or(r.promotedBy),
                  key: Key('promotion-${r.id}-by'),
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

class _ChangeLine extends StatelessWidget {
  final String text;
  final String badge;
  final Color color;
  const _ChangeLine({super.key, required this.text, required this.badge, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(text, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
        _StatusPill(label: badge, color: color),
      ]),
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

  /// Returns the success message once the promotion is saved, else null.
  static Future<String?> show(
    BuildContext context, {
    required EmployeeModel employee,
  }) {
    return showModalBottomSheet<String>(
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
    _effectiveDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    if (_submitting) return;
    if (_designation.isEmpty) {
      setState(() => _error = 'Select a new designation.');
      return;
    }
    if (_roleSlug.isEmpty) {
      setState(() => _error = 'Select a system role.');
      return;
    }
    // Web PromotionTab: nothing to submit without a change.
    if (_designation == widget.employee.designation && _roleSlug == widget.employee.role) {
      setState(() => _error = kPromotionNoChange);
      return;
    }
    // Matches web's exact copy/gate: PromotionTab.tsx blocks submit with
    // this same message until the elevation checkbox is ticked.
    if (_isElevated && !_confirmed) {
      setState(() => _error = 'Confirm the role change before submitting.');
      return;
    }
    if (_effectiveDate.isEmpty) {
      setState(() => _error = 'Effective date is required.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await promoteEmployeeAction(
      ref,
      widget.employee.employeeId,
      fromDesignation: widget.employee.designation,
      fromRole: widget.employee.role,
      designation: _designation,
      role: _roleSlug,
      effectiveDate: _effectiveDate,
      remarks: _remarksCtrl.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _submitting = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop(_isElevated
        ? "Designation and role updated. New access applies at the employee's next login."
        : 'Designation updated successfully.');
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
                      child: Text('Promote Employee', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
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
                          child: Text(formatPromotionDate(_effectiveDate), style: AppTextStyles.body),
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
                        Text(_error!,
                            style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
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

    final names =
        deptId == null ? const <String>[] : ref.watch(employeeDesignationsByDeptProvider(deptId)).valueOrNull ?? [];
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
          items:
              options.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
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
    final roles =
        (ref.watch(employeeFormRolesProvider).valueOrNull ?? []).where((r) => r.name != 'system_admin').toList();
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

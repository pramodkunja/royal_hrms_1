import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/data/models/departments_model.dart';
import '../../data/models/employee_model.dart';
import '../providers/employee_providers.dart';

// ignore_for_file: use_build_context_synchronously

class AddEmployeeSheet extends ConsumerStatefulWidget {
  final EmployeeModel? editing; // null = add, non-null = edit

  const AddEmployeeSheet({super.key, this.editing});

  static Future<bool> show(BuildContext context, {EmployeeModel? editing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AddEmployeeSheet(editing: editing),
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<AddEmployeeSheet> {
  late final EmployeeFormData _form;
  final _errors = <String, String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _form = widget.editing != null
        ? EmployeeFormData.fromModel(widget.editing!)
        : EmployeeFormData();
  }

  bool get _isEditing => widget.editing != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(isEditing: _isEditing),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: Icons.person_outline,
                    label: 'PERSONAL INFORMATION',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'First Name',
                          required: true,
                          initialValue: _form.firstName,
                          error: _errors['first_name'],
                          onChanged: (v) => _form.firstName = v,
                          hint: 'e.g. Anjali',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          label: 'Last Name',
                          required: true,
                          initialValue: _form.lastName,
                          error: _errors['last_name'],
                          onChanged: (v) => _form.lastName = v,
                          hint: 'e.g. Sharma',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Work Email',
                          required: true,
                          initialValue: _form.email,
                          error: _errors['email'],
                          onChanged: (v) => _form.email = v,
                          hint: 'name@company.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          label: 'Phone',
                          initialValue: _form.phone,
                          onChanged: (v) => _form.phone = v,
                          hint: '+91 98765 43210',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeader(
                    icon: Icons.work_outline,
                    label: 'EMPLOYMENT DETAILS',
                  ),
                  const SizedBox(height: 14),
                  // Role + Department
                  Row(
                    children: [
                      Expanded(child: _RoleDropdown(form: _form, error: _errors['role'], onChanged: _rebuild)),
                      const SizedBox(width: 12),
                      Expanded(child: _DeptDropdown(form: _form, error: _errors['department'], onChanged: _rebuild)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Designation + Branch
                  Row(
                    children: [
                      Expanded(child: _DesignationDropdown(form: _form, error: _errors['designation'], onChanged: _rebuild)),
                      const SizedBox(width: 12),
                      Expanded(child: _BranchDropdown(form: _form, error: _errors['branch'], onChanged: _rebuild)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Employee Type + Date of Joining
                  Row(
                    children: [
                      Expanded(child: _EmployeeTypeDropdown(form: _form, onChanged: _rebuild)),
                      const SizedBox(width: 12),
                      Expanded(child: _DateField(form: _form, error: _errors['date_of_joining'], onChanged: _rebuild)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Info banner
                  if (!_isEditing)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A temporary password will be emailed to the employee. '
                              'They will be prompted to change it on first login.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          _Footer(
            isEditing: _isEditing,
            submitting: _submitting,
            onCancel: () => Navigator.pop(context, false),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  void _rebuild() => setState(() {});

  Future<void> _submit() async {
    setState(() {
      _errors.clear();
      _errors.addAll(_form.validate());
    });
    if (_errors.isNotEmpty) return;

    setState(() => _submitting = true);
    final error = await ref.read(employeesProvider.notifier).create(_form);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      Navigator.pop(context, true);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isEditing;
  const _Header({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add_outlined,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing ? 'Edit Employee' : 'Add New Employee',
              style: AppTextStyles.h4,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textHint,
            onPressed: () => Navigator.pop(context, false),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final bool required;
  final String? initialValue;
  final String? error;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    this.required = false,
    this.initialValue,
    this.error,
    required this.onChanged,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label, required: required),
        const SizedBox(height: 5),
        TextFormField(
          initialValue: initialValue,
          style: AppTextStyles.body,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: _inputDec(hint ?? '', error: error),
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Role dropdown ──────────────────────────────────────────────────────────────

class _RoleDropdown extends ConsumerWidget {
  final EmployeeFormData form;
  final String? error;
  final VoidCallback onChanged;

  const _RoleDropdown({
    required this.form,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(employeeFormRolesProvider);
    final roles = rolesAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Role', required: true),
        const SizedBox(height: 5),
        DropdownButtonFormField<dynamic>(
          initialValue: form.roleId,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— Select Role —', error: error),
          hint: Text('— Select Role —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: roles.map((r) => DropdownMenuItem<dynamic>(
            value: r.id,
            child: Text(r.displayName, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) {
            form.roleId = value;
            onChanged();
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Department dropdown ────────────────────────────────────────────────────────

class _DeptDropdown extends ConsumerWidget {
  final EmployeeFormData form;
  final String? error;
  final VoidCallback onChanged;

  const _DeptDropdown({
    required this.form,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(employeeFormDepartmentsProvider);
    final depts = deptsAsync.valueOrNull ?? [];

    final selected = depts
        .where((d) => d.name == form.department)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Department', required: true),
        const SizedBox(height: 5),
        DropdownButtonFormField<DepartmentModel>(
          initialValue: selected,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— Select Dept —', error: error),
          hint: Text('— Select Dept —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: depts.map((d) => DropdownMenuItem(
            value: d,
            child: Text(d.name, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (dept) {
            form.department   = dept?.name ?? '';
            form.departmentId = dept?.id;
            form.designation  = '';  // reset designation
            onChanged();
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Designation dropdown ──────────────────────────────────────────────────────

class _DesignationDropdown extends ConsumerWidget {
  final EmployeeFormData form;
  final String? error;
  final VoidCallback onChanged;

  const _DesignationDropdown({
    required this.form,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptId = form.departmentId;
    final List<String> names;

    if (deptId != null) {
      final async = ref.watch(employeeDesignationsByDeptProvider(deptId));
      names = async.valueOrNull ?? [];
    } else {
      names = [];
    }

    final isEnabled = deptId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Designation', required: true),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: form.designation.isEmpty ? null : form.designation,
          style: AppTextStyles.body.copyWith(
            color: isEnabled ? AppColors.textPrimary : AppColors.textHint,
          ),
          isExpanded: true,
          decoration: _inputDec(
            isEnabled ? '— Select —' : 'Select department first',
            error: error,
            enabled: isEnabled,
          ),
          hint: Text(
            isEnabled ? '— Select —' : 'Select department first',
            style: AppTextStyles.body.copyWith(color: AppColors.textHint),
          ),
          items: isEnabled
              ? names.map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
                  )).toList()
              : null,
          onChanged: isEnabled
              ? (value) {
                  form.designation = value ?? '';
                  onChanged();
                }
              : null,
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Branch dropdown ────────────────────────────────────────────────────────────

class _BranchDropdown extends ConsumerWidget {
  final EmployeeFormData form;
  final String? error;
  final VoidCallback onChanged;

  const _BranchDropdown({
    required this.form,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(employeeBranchesProvider);
    final branches = branchesAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Branch', required: true),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: form.branch.isEmpty ? null : form.branch,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— Select Branch —', error: error),
          hint: Text('— Select Branch —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: branches.map((b) => DropdownMenuItem(
            value: b.name,
            child: Text(b.name, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) {
            form.branch = value ?? '';
            onChanged();
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Employee type dropdown ────────────────────────────────────────────────────

class _EmployeeTypeDropdown extends StatelessWidget {
  final EmployeeFormData form;
  final VoidCallback onChanged;

  const _EmployeeTypeDropdown({required this.form, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = ['Permanent', 'Contract', 'Intern', 'Part-time'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Employee Type'),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: form.employeeType,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('Select type'),
          items: types.map((t) => DropdownMenuItem(
            value: t,
            child: Text(t, style: AppTextStyles.body),
          )).toList(),
          onChanged: (value) {
            form.employeeType = value ?? 'Permanent';
            onChanged();
          },
        ),
      ],
    );
  }
}

// ── Date of joining field ──────────────────────────────────────────────────────

class _DateField extends StatefulWidget {
  final EmployeeFormData form;
  final String? error;
  final VoidCallback onChanged;

  const _DateField({
    required this.form,
    this.error,
    required this.onChanged,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _display(widget.form.dateOfJoining));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _display(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.form.dateOfJoining.isNotEmpty
          ? DateTime.tryParse(widget.form.dateOfJoining) ?? now
          : now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final iso =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    widget.form.dateOfJoining = iso;
    _ctrl.text = _display(iso);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Date of Joining', required: true),
        const SizedBox(height: 5),
        TextFormField(
          controller: _ctrl,
          readOnly: true,
          style: AppTextStyles.body,
          onTap: _pick,
          decoration: _inputDec('dd/mm/yyyy', error: widget.error).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textHint),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 3),
          Text(widget.error!,
              style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool isEditing;
  final bool submitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _Footer({
    required this.isEditing,
    required this.submitting,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_outlined, size: 18),
              label: Text(isEditing ? 'Save Changes' : 'Add Employee'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  const _Label({required this.text, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        children: required
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                )
              ]
            : [],
      ),
    );
  }
}

InputDecoration _inputDec(String hint, {String? error, bool enabled = true}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
      filled: true,
      fillColor: enabled ? AppColors.surface : AppColors.background,
      errorText: null,  // we show errors manually
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: error != null ? AppColors.error : AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      isDense: true,
    );

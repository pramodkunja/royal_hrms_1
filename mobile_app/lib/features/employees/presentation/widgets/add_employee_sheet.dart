import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../settings/data/models/departments_model.dart';
import '../../../settings/data/models/roles_model.dart';
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
  EmployeeFormData? _createForm;
  EmployeeUpdateFormData? _editForm;
  final _errors = <String, String>{};
  bool _submitting = false;
  bool _branchPrefilled = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _editForm = EmployeeUpdateFormData.fromModel(widget.editing!);
    } else {
      _createForm = EmployeeFormData();
    }
  }

  bool get _isEditing => widget.editing != null;

  @override
  Widget build(BuildContext context) {
    // Mirrors web's AddEmployeeModal: non-system_admin users can only add
    // employees under their own branch, so the field is pre-filled and
    // locked as soon as the branch list loads (the backend doesn't enforce
    // this server-side, so the client is the only guard).
    final currentUser = ref.watch(authStateProvider).valueOrNull?.user;
    final branchLocked = !_isEditing && currentUser != null && currentUser.role != 'system_admin';
    if (branchLocked && !_branchPrefilled) {
      final branches = ref.watch(employeeBranchesProvider).valueOrNull;
      if (branches != null && (_createForm?.branch.isEmpty ?? false)) {
        final own = branches
            .where((b) => b.name.toLowerCase() == (currentUser.branch ?? '').toLowerCase())
            .toList();
        if (own.isNotEmpty) {
          _createForm!.branch = own.first.name;
          _branchPrefilled = true;
        }
      }
    }
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
                children: _isEditing ? _editFields() : _createFields(branchLocked),
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

  // ── Create-mode fields ───────────────────────────────────────────────────

  List<Widget> _createFields(bool branchLocked) {
    final form = _createForm!;
    return [
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
              initialValue: form.firstName,
              error: _errors['first_name'],
              onChanged: (v) => form.firstName = v,
              hint: 'e.g. Anjali',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Field(
              label: 'Last Name',
              required: true,
              initialValue: form.lastName,
              error: _errors['last_name'],
              onChanged: (v) => form.lastName = v,
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
              initialValue: form.email,
              error: _errors['email'],
              onChanged: (v) => form.email = v,
              hint: 'name@company.com',
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Field(
              label: 'Phone',
              initialValue: form.phone,
              error: _errors['phone'],
              onChanged: (v) => form.phone = v,
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
          Expanded(
            child: _RoleIdDropdown(
              selectedId: form.roleId,
              error: _errors['role'],
              onSelected: (id) => setState(() => form.roleId = id),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DeptDropdown(
              selectedName: form.department.isEmpty ? null : form.department,
              error: _errors['department'],
              onSelected: (dept) => setState(() {
                form.department = dept?.name ?? '';
                form.departmentId = dept?.id;
                form.designation = '';
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      // Designation + Branch
      Row(
        children: [
          Expanded(
            child: _DesignationDropdown(
              departmentId: form.departmentId,
              selectedDesignation: form.designation,
              error: _errors['designation'],
              onSelected: (v) => setState(() => form.designation = v ?? ''),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BranchDropdown(
              selectedBranch: form.branch.isEmpty ? null : form.branch,
              error: _errors['branch'],
              locked: branchLocked,
              onSelected: (v) => setState(() => form.branch = v ?? ''),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      // Employee Type + Date of Joining
      Row(
        children: [
          Expanded(child: _EmployeeTypeDropdown(form: form, onChanged: _rebuild)),
          const SizedBox(width: 12),
          Expanded(
            child: _DateField(
              label: 'Date of Joining',
              isoValue: form.dateOfJoining,
              error: _errors['date_of_joining'],
              onChanged: (iso) => setState(() => form.dateOfJoining = iso),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
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
            Icon(Icons.info_outline,
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
    ];
  }

  // ── Edit-mode fields ─────────────────────────────────────────────────────

  List<Widget> _editFields() {
    final form = _editForm!;
    // The employee record only stores `department` as a name string — the
    // Designation dropdown needs the matching Department's id to enable
    // itself, so resolve it here once the department list loads (it's never
    // set by EmployeeUpdateFormData.fromModel, which has no access to it).
    if (form.departmentId == null && form.department.isNotEmpty) {
      final depts = ref.watch(employeeFormDepartmentsProvider).valueOrNull ?? [];
      final match = depts.where((d) => d.name == form.department).firstOrNull;
      if (match != null) form.departmentId = match.id;
    }
    // Resolve whether the employee's current role is manager-type from the
    // real Role.can_manage_team flag (not the role name — see
    // EmployeeUpdateFormData.isManagerRole doc comment) as soon as the roles
    // list loads. Without this, form.canManageTeam stays null and
    // isManagerRole defaults to false, which would wrongly show the
    // Reporting Manager field (and send reporting_manager_id) for a manager.
    if (form.canManageTeam == null && form.role.isNotEmpty) {
      final roles = ref.watch(employeeFormRolesProvider).valueOrNull ?? [];
      final match = roles.where((r) => r.name == form.role).firstOrNull;
      if (match != null) form.canManageTeam = match.canManageTeam;
    }
    return [
      const _SectionHeader(
        icon: Icons.person_outline,
        label: 'PERSONAL INFORMATION',
      ),
      const SizedBox(height: 14),
      // Full Name, Phone and Date of Joining are read-only forever here —
      // matches web's Profile tab, which never offers them as editable even
      // though the backend's PUT would technically accept a change.
      _ReadOnlyField(label: 'Full Name', value: form.fullName),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _ReadOnlyField(
              label: 'Phone',
              value: form.phone.isEmpty ? '—' : form.phone,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DateField(
              label: 'Date of Birth',
              required: true,
              error: _errors['date_of_birth'],
              isoValue: form.dateOfBirth,
              onChanged: (iso) => setState(() => form.dateOfBirth = iso),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _ChoiceDropdown(
              label: 'Gender',
              value: form.gender,
              items: const [
                {'value': 'male', 'label': 'Male'},
                {'value': 'female', 'label': 'Female'},
                {'value': 'other', 'label': 'Other / Prefer not to say'},
              ],
              onChanged: (v) => setState(() => form.gender = v ?? ''),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ChoiceDropdown(
              label: 'Marital Status',
              value: form.maritalStatus,
              items: const [
                {'value': 'single', 'label': 'Single'},
                {'value': 'married', 'label': 'Married'},
                {'value': 'divorced', 'label': 'Divorced'},
                {'value': 'widowed', 'label': 'Widowed'},
              ],
              onChanged: (v) => setState(() => form.maritalStatus = v ?? ''),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _Field(
              label: "Father's Name",
              initialValue: form.fatherName,
              onChanged: (v) => form.fatherName = v,
              hint: "Father's full name",
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ChoiceDropdown(
              label: 'Blood Group',
              value: form.bloodGroup,
              items: const [
                {'value': 'A+', 'label': 'A+'},
                {'value': 'A-', 'label': 'A-'},
                {'value': 'B+', 'label': 'B+'},
                {'value': 'B-', 'label': 'B-'},
                {'value': 'O+', 'label': 'O+'},
                {'value': 'O-', 'label': 'O-'},
                {'value': 'AB+', 'label': 'AB+'},
                {'value': 'AB-', 'label': 'AB-'},
              ],
              onChanged: (v) => setState(() => form.bloodGroup = v ?? ''),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _Field(
        label: 'Current Address',
        initialValue: form.currentAddress,
        onChanged: (v) => form.currentAddress = v,
        hint: 'House / Flat no., Street, City, State, PIN',
        maxLines: 3,
      ),
      const SizedBox(height: 14),
      _Field(
        label: 'Permanent Address',
        initialValue: form.permanentAddress,
        onChanged: (v) => form.permanentAddress = v,
        hint: 'Leave blank if same as current',
        maxLines: 3,
      ),
      const SizedBox(height: 22),
      const _SectionHeader(
        icon: Icons.work_outline,
        label: 'EMPLOYMENT DETAILS',
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _RoleSlugDropdown(
              selectedName: form.role,
              error: _errors['role'],
              onSelected: (name) => setState(() {
                form.role = name;
                // Re-resolve immediately (rather than waiting for the
                // `_editFields()` build-time lookup above) so a role change
                // that flips manager-ness takes effect in the same frame —
                // e.g. hiding the Reporting Manager field right away.
                final roles = ref.read(employeeFormRolesProvider).valueOrNull ?? [];
                form.canManageTeam =
                    roles.where((r) => r.name == name).firstOrNull?.canManageTeam ?? false;
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DeptDropdown(
              selectedName: form.department.isEmpty ? null : form.department,
              error: _errors['department'],
              onSelected: (dept) => setState(() {
                form.department = dept?.name ?? '';
                form.departmentId = dept?.id;
                form.designation = '';
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _DesignationDropdown(
              departmentId: form.departmentId,
              selectedDesignation: form.designation,
              error: _errors['designation'],
              onSelected: (v) => setState(() => form.designation = v ?? ''),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BranchDropdown(
              selectedBranch: form.branch.isEmpty ? null : form.branch,
              error: _errors['branch'],
              onSelected: (v) => setState(() {
                form.branch = v ?? '';
                // HR/manager pickers are filtered by branch — a previous
                // selection may no longer be valid for the new branch.
                form.hrId = null;
                form.hrName = null;
                form.reportingManagerId = null;
                form.reportingManagerName = null;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _ReadOnlyField(
        label: 'Date of Joining',
        value: form.dateOfJoining.isEmpty ? '—' : form.dateOfJoining,
      ),
      const SizedBox(height: 22),
      const _SectionHeader(
        icon: Icons.supervisor_account_outlined,
        label: 'REPORTING & HR',
      ),
      const SizedBox(height: 14),
      _HrDropdown(
        branch: form.branch,
        selectedId: form.hrId,
        onSelected: (opt) => setState(() {
          form.hrId = opt?.id;
          form.hrName = opt?.fullName;
        }),
      ),
      if (!form.isManagerRole) ...[
        const SizedBox(height: 14),
        _ManagerDropdown(
          branch: form.branch,
          selectedId: form.reportingManagerId,
          onSelected: (opt) => setState(() {
            form.reportingManagerId = opt?.id;
            form.reportingManagerName = opt?.fullName;
          }),
        ),
      ],
    ];
  }

  void _rebuild() => setState(() {});

  Future<void> _submit() async {
    if (_isEditing) {
      await _submitEdit();
    } else {
      await _submitCreate();
    }
  }

  Future<void> _submitCreate() async {
    final form = _createForm!;
    setState(() {
      _errors.clear();
      _errors.addAll(form.validate());
    });
    if (_errors.isNotEmpty) return;

    setState(() => _submitting = true);
    final error = await createEmployeeAction(ref, form);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _showError(error);
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _submitEdit() async {
    final form = _editForm!;
    setState(() {
      _errors.clear();
      _errors.addAll(form.validate());
    });
    if (_errors.isNotEmpty) return;

    setState(() => _submitting = true);
    final error = await updateEmployeeAction(ref, widget.editing!.employeeId, form);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _showError(error);
    } else {
      Navigator.pop(context, true);
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
      decoration: BoxDecoration(
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
            child: Icon(Icons.person_add_outlined,
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
        Expanded(child: Divider(color: AppColors.border)),
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
  final int maxLines;

  const _Field({
    required this.label,
    this.required = false,
    this.initialValue,
    this.error,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
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
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: _inputDec(hint ?? '', error: error),
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Choice dropdown (edit mode — Gender / Marital Status / Blood Group) ────────

class _ChoiceDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<Map<String, String>> items;
  final ValueChanged<String?> onChanged;

  const _ChoiceDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— Select —'),
          hint: Text('— Select —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: items.map((it) => DropdownMenuItem<String>(
            value: it['value'],
            child: Text(it['label']!, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Read-only display field (edit mode — identity fields locked forever) ───────

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _Label(text: label),
          const SizedBox(width: 6),
          Icon(Icons.lock_outline, size: 11, color: AppColors.textHint),
        ]),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

// ── Role dropdown (create mode — keyed by role id) ─────────────────────────────

class _RoleIdDropdown extends ConsumerWidget {
  final dynamic selectedId;
  final String? error;
  final ValueChanged<dynamic> onSelected;

  const _RoleIdDropdown({
    this.selectedId,
    this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(employeeFormRolesProvider);
    // system_admin is never assignable via employee create/edit — the
    // backend rejects it outright, and web excludes it from this dropdown.
    final roles =
        (rolesAsync.valueOrNull ?? []).where((r) => r.name != 'system_admin').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Role', required: true),
        const SizedBox(height: 5),
        DropdownButtonFormField<dynamic>(
          initialValue: selectedId,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— Select Role —', error: error),
          hint: Text('— Select Role —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: roles.map((r) => DropdownMenuItem<dynamic>(
            value: r.id,
            child: Text(r.displayName, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onSelected,
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Role dropdown (edit mode — keyed by Role.name slug, what PUT expects) ──────

class _RoleSlugDropdown extends ConsumerWidget {
  final String selectedName;
  final String? error;
  final ValueChanged<String> onSelected;

  const _RoleSlugDropdown({
    required this.selectedName,
    this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(employeeFormRolesProvider);
    // system_admin is never assignable via employee create/edit — the
    // backend rejects it outright, and web excludes it from this dropdown.
    final roles =
        (rolesAsync.valueOrNull ?? []).where((r) => r.name != 'system_admin').toList();
    final selected = roles.where((r) => r.name == selectedName).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Role', required: true),
        const SizedBox(height: 5),
        DropdownButtonFormField<RoleModel>(
          initialValue: selected,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— Select Role —', error: error),
          hint: Text('— Select Role —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: roles.map((r) => DropdownMenuItem(
            value: r,
            child: Text(r.displayName, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (r) => onSelected(r?.name ?? ''),
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Department dropdown (shared by add + edit) ────────────────────────────────

class _DeptDropdown extends ConsumerWidget {
  final String? selectedName;
  final String? error;
  final ValueChanged<DepartmentModel?> onSelected;

  const _DeptDropdown({
    this.selectedName,
    this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(employeeFormDepartmentsProvider);
    final depts = deptsAsync.valueOrNull ?? [];

    final selected = depts
        .where((d) => d.name == selectedName)
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
          onChanged: onSelected,
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Designation dropdown (shared by add + edit) ────────────────────────────────

class _DesignationDropdown extends ConsumerWidget {
  final int? departmentId;
  final String selectedDesignation;
  final String? error;
  final ValueChanged<String?> onSelected;

  const _DesignationDropdown({
    required this.departmentId,
    required this.selectedDesignation,
    this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptId = departmentId;
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
          initialValue: selectedDesignation.isEmpty ? null : selectedDesignation,
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
          onChanged: isEnabled ? onSelected : null,
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── Branch dropdown (shared by add + edit) ─────────────────────────────────────

class _BranchDropdown extends ConsumerWidget {
  final String? selectedBranch;
  final String? error;
  final bool locked;
  final ValueChanged<String?> onSelected;

  const _BranchDropdown({
    this.selectedBranch,
    this.error,
    this.locked = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(employeeBranchesProvider);
    final branches = branchesAsync.valueOrNull ?? [];

    // Mirrors _DeptDropdown's matching: only pass a value the menu actually
    // contains. DropdownButtonFormField requires its value to match exactly
    // one item (or be null) — feeding it the employee's raw stored branch
    // name when that branch isn't in the fetched list (e.g. renamed,
    // deactivated, or paginated out) makes the field disable itself
    // entirely, which reads as "not accessible".
    final selected =
        branches.any((b) => b.name == selectedBranch) ? selectedBranch : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _Label(text: 'Branch', required: true),
          if (locked) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 11, color: AppColors.textHint),
          ],
        ]),
        const SizedBox(height: 5),
        IgnorePointer(
          ignoring: locked,
          child: Opacity(
            opacity: locked ? 0.6 : 1,
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              style: AppTextStyles.body,
              isExpanded: true,
              decoration: _inputDec('— Select Branch —', error: error),
              hint: Text('— Select Branch —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
              items: branches.map((b) => DropdownMenuItem(
                value: b.name,
                child: Text(b.name, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: onSelected,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(error!, style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

// ── HR contact dropdown (edit-only) ────────────────────────────────────────────

class _HrDropdown extends ConsumerWidget {
  final String branch;
  final String? selectedId;
  final ValueChanged<EmployeePickerOption?> onSelected;

  const _HrDropdown({
    required this.branch,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeHrOptionsProvider(branch));
    final options = async.valueOrNull ?? [];
    final selected = options.where((o) => o.id == selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'HR Contact'),
        const SizedBox(height: 5),
        DropdownButtonFormField<EmployeePickerOption?>(
          initialValue: selected,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec('— None —'),
          hint: Text('— None —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: [
            DropdownMenuItem<EmployeePickerOption?>(
              value: null,
              child: Text('— None —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
            ),
            ...options.map((o) => DropdownMenuItem<EmployeePickerOption?>(
                  value: o,
                  child: Text('${o.fullName} (${o.department})',
                      style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onSelected,
        ),
      ],
    );
  }
}

// ── Reporting manager dropdown (edit-only) ─────────────────────────────────────

class _ManagerDropdown extends ConsumerWidget {
  final String branch;
  final String? selectedId;
  final ValueChanged<EmployeePickerOption?> onSelected;

  const _ManagerDropdown({
    required this.branch,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = branch.isNotEmpty;
    final options = isEnabled
        ? (ref.watch(employeeManagerOptionsProvider(branch)).valueOrNull ?? [])
        : <EmployeePickerOption>[];
    final selected = options.where((o) => o.id == selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(text: 'Reporting Manager'),
        const SizedBox(height: 5),
        DropdownButtonFormField<EmployeePickerOption?>(
          initialValue: selected,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: _inputDec(
            isEnabled ? '— None —' : 'Select branch first',
            enabled: isEnabled,
          ),
          hint: Text(
            isEnabled ? '— None —' : 'Select branch first',
            style: AppTextStyles.body.copyWith(color: AppColors.textHint),
          ),
          items: isEnabled
              ? [
                  DropdownMenuItem<EmployeePickerOption?>(
                    value: null,
                    child: Text('— None —', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
                  ),
                  ...options.map((o) => DropdownMenuItem<EmployeePickerOption?>(
                        value: o,
                        child: Text('${o.fullName} (${o.department})',
                            style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
                      )),
                ]
              : null,
          onChanged: isEnabled ? onSelected : null,
        ),
      ],
    );
  }
}

// ── Employee type dropdown (create-only) ────────────────────────────────────────

class _EmployeeTypeDropdown extends StatelessWidget {
  final EmployeeFormData form;
  final VoidCallback onChanged;

  const _EmployeeTypeDropdown({required this.form, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = ['Permanent', 'Contract', 'Intern', 'Probation'];
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

// ── Date field (shared — used for both Date of Joining and Date of Birth) ──────

class _DateField extends StatefulWidget {
  final String label;
  final bool required;
  final String isoValue;
  final String? error;
  final ValueChanged<String> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const _DateField({
    required this.label,
    this.required = true,
    required this.isoValue,
    this.error,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _display(widget.isoValue));
  }

  @override
  void didUpdateWidget(covariant _DateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isoValue != widget.isoValue) {
      _ctrl.text = _display(widget.isoValue);
    }
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
      initialDate: widget.isoValue.isNotEmpty
          ? DateTime.tryParse(widget.isoValue) ?? now
          : now,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final iso =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _ctrl.text = _display(iso);
    widget.onChanged(iso);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: widget.label, required: widget.required),
        const SizedBox(height: 5),
        TextFormField(
          controller: _ctrl,
          readOnly: true,
          style: AppTextStyles.body,
          onTap: _pick,
          decoration: _inputDec('dd/mm/yyyy', error: widget.error).copyWith(
            suffixIcon: Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textHint),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 3),
          Text(widget.error!,
              style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w500)),
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
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.border),
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
            child: AppButton(
              label: isEditing ? 'Save Changes' : 'Add Employee',
              onPressed: submitting ? null : onSubmit,
              isLoading: submitting,
              leadingIcon: Icons.person_add_outlined,
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
                TextSpan(
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
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      isDense: true,
    );

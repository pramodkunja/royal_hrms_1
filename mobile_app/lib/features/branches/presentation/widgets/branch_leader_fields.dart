import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/branch_model.dart' show BranchAdminCandidate;
import '../../domain/branch_admin_leader.dart';
import '../providers/branch_providers.dart';

/// Add Branch → "Assign Branch Admin (optional)" — web LeaderFields: by
/// default a new person (Full name, Work email, Designation pre-filled
/// "Branch Manager"); "Assign an existing employee instead" (offered only
/// when the active-employee list has someone) switches to a search + picker
/// showing "<name> (<employee ID>) — <branch or 'no branch'>".
class BranchLeaderFields extends ConsumerStatefulWidget {
  const BranchLeaderFields({
    super.key,
    required this.form,
    required this.onChanged,
    required this.errors,
    this.enabled = true,
  });

  final BranchLeaderForm form;
  final ValueChanged<BranchLeaderForm> onChanged;

  /// Keys: employee, name, email, designation (validateBranchLeader).
  final Map<String, String> errors;
  final bool enabled;

  @override
  ConsumerState<BranchLeaderFields> createState() => _BranchLeaderFieldsState();
}

class _BranchLeaderFieldsState extends ConsumerState<BranchLeaderFields> {
  late final _name = TextEditingController(text: widget.form.name);
  late final _email = TextEditingController(text: widget.form.email);
  late final _designation = TextEditingController(text: widget.form.designation);
  late final _search = TextEditingController(text: widget.form.search);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _designation.dispose();
    _search.dispose();
    super.dispose();
  }

  void _set(BranchLeaderForm f) => widget.onChanged(f);

  InputDecoration _dec(String hint, String? error) => InputDecoration(
        hintText: hint,
        errorText: error,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    final options = ref.watch(branchLeaderOptionsProvider);
    final employees = options.valueOrNull?.employees ?? const <BranchAdminCandidate>[];

    return Container(
      key: const Key('branch-leader-section'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(TextSpan(style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600), children: [
          const TextSpan(text: 'Assign Branch Admin '),
          TextSpan(text: '(optional)', style: TextStyle(fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
        ])),
        const SizedBox(height: 10),
        Text('Branch Admin',
            style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
        if (options.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(key: Key('branch-leader-loading'), minHeight: 2),
          ),
        // Web shows the switch only when there is someone to pick.
        if (employees.isNotEmpty)
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('branch-leader-existing-toggle'),
              value: f.mode == BranchLeaderMode.existing,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Assign an existing employee instead', style: AppTextStyles.caption.copyWith(fontSize: 12)),
              onChanged: widget.enabled
                  ? (v) => _set(f.copyWith(mode: v == true ? BranchLeaderMode.existing : BranchLeaderMode.newPerson))
                  : null,
            ),
          ),
        const SizedBox(height: 6),
        if (f.mode == BranchLeaderMode.existing) ..._existing(f, employees) else ..._newPerson(f),
        const SizedBox(height: 8),
      ]),
    );
  }

  List<Widget> _newPerson(BranchLeaderForm f) => [
        TextField(
          key: const Key('branch-leader-name'),
          controller: _name,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.words,
          decoration: _dec('Full name', widget.errors['name']),
          onChanged: (v) => _set(f.copyWith(name: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('branch-leader-email'),
          controller: _email,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          decoration: _dec('Work email', widget.errors['email']),
          onChanged: (v) => _set(f.copyWith(email: v)),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('branch-leader-designation'),
          controller: _designation,
          enabled: widget.enabled,
          decoration: _dec('Designation', widget.errors['designation']),
          onChanged: (v) => _set(f.copyWith(designation: v)),
        ),
      ];

  List<Widget> _existing(BranchLeaderForm f, List<BranchAdminCandidate> employees) {
    final filtered = filterBranchLeaderCandidates(employees, f.search);
    // A chosen employee that the search hides stays selected (web keeps the
    // select's value); it is listed so the picker can still show it.
    final chosen = employees.where((e) => e.code == f.employeeCode).firstOrNull;
    final items = [
      if (chosen != null && !filtered.contains(chosen)) chosen,
      ...filtered,
    ];
    return [
      TextField(
        key: const Key('branch-leader-search'),
        controller: _search,
        enabled: widget.enabled,
        decoration: _dec('Search by name, email, or employee ID…', null),
        onChanged: (v) => _set(f.copyWith(search: v)),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: ValueKey('branch-leader-employee-${f.employeeCode}-${items.length}'),
        initialValue: f.employeeCode,
        isExpanded: true,
        decoration: _dec('', widget.errors['employee']),
        items: [
          const DropdownMenuItem(value: '', child: Text('— Select employee —')),
          for (final e in items)
            DropdownMenuItem(
              value: e.code,
              child: Text('${e.fullName} (${e.employeeId}) — ${e.branch.isEmpty ? 'no branch' : e.branch}',
                  overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: widget.enabled ? (v) => _set(f.copyWith(employeeCode: v ?? '')) : null,
      ),
    ];
  }
}

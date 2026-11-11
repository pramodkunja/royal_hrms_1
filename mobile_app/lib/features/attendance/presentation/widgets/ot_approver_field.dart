import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show authStateProvider;
import '../../../../core/theme/app_text_styles.dart';
import '../../../employees/data/models/employee_model.dart' show EmployeePickerOption;
import '../../../employees/presentation/providers/employee_providers.dart' show employeeHrOptionsProvider;
import '../providers/attendance_providers.dart' show friendlyAttendanceError;

// "Approved By" on HR Attendance → OT Entry. Web OtEntryTab.tsx fills this
// select from GET /employees/hrs/ (API.employees.hrList) and saves
// approved_by = the chosen person's employee_id. The backend
// (accounts HRListView) lists active HR users — holders of
// onboarding.approve, minus org-wide settings.edit roles — for ONE branch,
// requires that `branch` query parameter, and needs employees.view.
//
// Web sends no branch, so production answers it with 400 and web's list is
// always empty. Mobile asks for the selected OT employee's branch instead
// (decision agreed for Task 42) — the same endpoint and eligibility, scoped
// to that employee. The approver is optional, as on web: with none, the
// backend saves the entry as Pending (services_hr_ops.create_overtime).

/// The approver to send, or a reason it can't be sent: the selection must be
/// one of the approvers currently listed for the employee's branch.
({String? approvedBy, String? error}) otApproverForSubmit(String? selected, List<EmployeePickerOption>? listed) {
  if (selected == null || selected.isEmpty) return (approvedBy: null, error: null);
  if (listed != null && listed.any((o) => o.employeeId == selected)) return (approvedBy: selected, error: null);
  return (
    approvedBy: null,
    error: 'The selected approver is no longer available for this employee. Choose another approver or leave it empty.',
  );
}

class OtApproverField extends ConsumerWidget {
  const OtApproverField({
    super.key,
    required this.employeeSelected,
    required this.branch,
    required this.value,
    required this.onChanged,
  });

  /// No employee yet: nothing to look approvers up for.
  final bool employeeSelected;

  /// The selected employee's branch ('' when the employee has none).
  final String branch;

  /// The chosen approver's employee_id (null = none).
  final String? value;
  final ValueChanged<String?> onChanged;

  InputDecoration get _decoration => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _note(String text, {Key? key, Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text, key: key, style: AppTextStyles.bodySmall.copyWith(color: color ?? AppColors.textSecondary)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!employeeSelected) {
      return DropdownButtonFormField<String>(
        key: const Key('ot-approver-disabled'),
        decoration: _decoration.copyWith(hintText: 'Select an employee first'),
        isExpanded: true,
        items: const [],
        onChanged: null,
      );
    }
    // HRListView answers 403 without employees.view — don't ask.
    if (!userHasPermission(ref.watch(authStateProvider).valueOrNull?.user, 'employees.view')) {
      return _note("You don't have permission to list HR approvers. The entry will be saved without an approver.",
          key: const Key('ot-approver-no-permission'));
    }
    if (branch.isEmpty) {
      return _note(
          "This employee has no branch, so no HR approver can be listed. The entry will be saved without "
          'an approver.',
          key: const Key('ot-approver-no-branch'));
    }
    return ref.watch(employeeHrOptionsProvider(branch)).when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(key: Key('ot-approver-loading')),
          error: (e, _) => Row(
            key: const Key('ot-approver-error'),
            children: [
              Expanded(
                child: Text("Couldn't load approvers: ${friendlyAttendanceError(e)}",
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
              ),
              TextButton(
                key: const Key('ot-approver-retry'),
                onPressed: () => ref.invalidate(employeeHrOptionsProvider(branch)),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (approvers) {
            if (approvers.isEmpty) {
              return _note('No HR approver is available for $branch. The entry will be saved without an approver.',
                  key: const Key('ot-approver-empty'));
            }
            // A selection that isn't in this branch's list is never shown as chosen.
            final current = approvers.any((a) => a.employeeId == value) ? value : null;
            return DropdownButtonFormField<String?>(
              key: ValueKey('ot-approver-$branch-$current'),
              initialValue: current,
              decoration: _decoration,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Select approver…')),
                for (final a in approvers)
                  DropdownMenuItem<String?>(
                    value: a.employeeId,
                    // Web shows the full name only.
                    child: Text(a.fullName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged,
            );
          },
        );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/datasources/employees_remote_datasource.dart';
import '../../data/models/employee_model.dart';
import '../providers/employee_providers.dart';

/// Bottom sheet for setting/clearing the L1 (and, when applicable, L2)
/// override for one Approval Matrix workflow row. L1 options come from the
/// manager picker, L2 options from the HR picker — both already filtered by
/// the employee's own branch, matching the pickers used in
/// [AddEmployeeSheet]'s "Reporting & HR" section.
class ApprovalOverrideSheet extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  final EmployeeApprovalMatrixRow row;

  const ApprovalOverrideSheet({
    super.key,
    required this.employee,
    required this.row,
  });

  static Future<bool> show(
    BuildContext context, {
    required EmployeeModel employee,
    required EmployeeApprovalMatrixRow row,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApprovalOverrideSheet(employee: employee, row: row),
    );
    return result ?? false;
  }

  @override
  ConsumerState<ApprovalOverrideSheet> createState() =>
      _ApprovalOverrideSheetState();
}

class _ApprovalOverrideSheetState extends ConsumerState<ApprovalOverrideSheet> {
  EmployeePickerOption? _l1;
  EmployeePickerOption? _l2;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.row.l1IsOverride && widget.row.l1ApproverId != null) {
      _l1 = EmployeePickerOption(
        id: widget.row.l1ApproverId!,
        employeeId: '',
        fullName: widget.row.l1ApproverName ?? '',
        department: '',
        branch: widget.employee.branch,
      );
    }
    if (widget.row.l2IsOverride && widget.row.l2ApproverId != null) {
      _l2 = EmployeePickerOption(
        id: widget.row.l2ApproverId!,
        employeeId: '',
        fullName: widget.row.l2ApproverName ?? '',
        department: '',
        branch: widget.employee.branch,
      );
    }
  }

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await ref
        .read(employeeApprovalMatrixProvider(widget.employee.employeeId).notifier)
        .updateOverride(
          widget.row.workflowType,
          l1OverrideId: _l1?.id,
          l2OverrideId: widget.row.isSingleLevel ? null : _l2?.id,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.employee.branch;
    final managersAsync = ref.watch(employeeManagerOptionsProvider(branch));
    final hrAsync = ref.watch(employeeHrOptionsProvider(branch));
    final managers = managersAsync.valueOrNull ?? [];
    final hrs = hrAsync.valueOrNull ?? [];

    // Selected values must be option instances from the live list (equality
    // is by reference for DropdownButtonFormField), so re-resolve by id.
    final selectedL1 = managers.where((o) => o.id == _l1?.id).firstOrNull ?? _l1;
    final selectedL2 = hrs.where((o) => o.id == _l2?.id).firstOrNull ?? _l2;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Override — ${widget.row.workflowLabel}',
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
              const SizedBox(height: 4),
              Text(
                'Leave a field on "Global default" to inherit the org-wide rule.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 18),

              _OverrideDropdown(
                label: widget.row.l1ApproverLabel.isEmpty
                    ? 'L1 Approver'
                    : 'L1 Approver (${widget.row.l1ApproverLabel})',
                options: managers,
                selected: selectedL1,
                onSelected: (o) => setState(() => _l1 = o),
              ),

              if (!widget.row.isSingleLevel) ...[
                const SizedBox(height: 14),
                _OverrideDropdown(
                  label: (widget.row.l2ApproverLabel ?? '').isEmpty
                      ? 'L2 Approver'
                      : 'L2 Approver (${widget.row.l2ApproverLabel})',
                  options: hrs,
                  selected: selectedL2,
                  onSelected: (o) => setState(() => _l2 = o),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500)),
              ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
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
                    child: FilledButton(
                      onPressed: _submitting ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverrideDropdown extends StatelessWidget {
  final String label;
  final List<EmployeePickerOption> options;
  final EmployeePickerOption? selected;
  final ValueChanged<EmployeePickerOption?> onSelected;

  const _OverrideDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<EmployeePickerOption?>(
          initialValue: selected,
          style: AppTextStyles.body,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            isDense: true,
          ),
          hint: Text('— Global default —',
              style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
          items: [
            DropdownMenuItem<EmployeePickerOption?>(
              value: null,
              child: Text('— Global default —',
                  style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
            ),
            ...options.map((o) => DropdownMenuItem<EmployeePickerOption?>(
                  value: o,
                  child: Text(
                    o.fullName.isEmpty ? o.employeeId : o.fullName,
                    style: AppTextStyles.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: onSelected,
        ),
      ],
    );
  }
}

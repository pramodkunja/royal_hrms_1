import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../leave/domain/entities/leave_entity.dart';
import '../providers/approvals_providers.dart';

// Minimal quick-create form — mirrors web's NewLeaveModal (leave type, from
// date, to date, reason only; duration defaults to full_day server-side).
// The Leave module's own Apply Leave tab has the fuller form (half-day,
// document upload, handover); this stays intentionally lightweight since
// it's meant for a fast submission from the Approvals inbox.
class NewLeaveRequestSheet extends ConsumerStatefulWidget {
  const NewLeaveRequestSheet({super.key});

  @override
  ConsumerState<NewLeaveRequestSheet> createState() =>
      _NewLeaveRequestSheetState();
}

class _NewLeaveRequestSheetState extends ConsumerState<NewLeaveRequestSheet> {
  String? _leaveType;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonCtrl = TextEditingController();

  bool _submitting = false;
  String? _submitError;
  Map<String, String?> _errors = {};

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_fromDate ?? now) : (_toDate ?? _fromDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate:
          isFrom ? now.subtract(const Duration(days: 30)) : (_fromDate ?? now),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = null;
      } else {
        _toDate = picked;
      }
      _errors = {..._errors, 'from': null, 'to': null};
    });
  }

  bool _validate() {
    final errs = <String, String?>{};
    if (_leaveType == null) errs['type'] = 'Please select a leave type.';
    if (_fromDate == null) errs['from'] = 'From date is required.';
    if (_toDate == null) errs['to'] = 'To date is required.';
    setState(() => _errors = errs);
    return errs.isEmpty;
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final err = await ref.read(myLeaveRequestsProvider.notifier).apply(
          leaveTypeCode: _leaveType!,
          fromDate: _iso(_fromDate!),
          toDate: _iso(_toDate!),
          reason: _reasonCtrl.text,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _submitting = false;
        _submitError = err;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Select date';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.beach_access_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('New Leave Request',
                        style: AppTextStyles.h4.copyWith(fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_submitError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.25)),
                          ),
                          child: Text(_submitError!,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.error)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _label('Leave Type', required: true),
                      const SizedBox(height: 6),
                      _buildLeaveTypeField(),
                      if (_errors['type'] != null) _errMsg(_errors['type']!),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('From Date', required: true),
                                const SizedBox(height: 6),
                                _buildDateField(
                                    _fromDate,
                                    () => _pickDate(isFrom: true),
                                    _errors['from']),
                                if (_errors['from'] != null)
                                  _errMsg(_errors['from']!),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('To Date', required: true),
                                const SizedBox(height: 6),
                                _buildDateField(
                                    _toDate,
                                    () => _pickDate(isFrom: false),
                                    _errors['to']),
                                if (_errors['to'] != null)
                                  _errMsg(_errors['to']!),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _label('Reason'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Optional reason',
                          filled: true,
                          fillColor: AppColors.backgroundLow,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppColors.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_outlined, size: 16),
                        label: Text(
                            _submitting ? 'Submitting…' : 'Submit Request',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
    );
  }

  Widget _buildLeaveTypeField() {
    return GestureDetector(
      onTap: _showLeaveTypePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: _errors['type'] != null
              ? AppColors.error.withValues(alpha: 0.05)
              : AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  _errors['type'] != null ? AppColors.error : AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _leaveType != null
                    ? LeaveTypeColors.labelForCode(_leaveType!)
                    : 'Select leave type',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: _leaveType != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontWeight:
                      _leaveType != null ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _showLeaveTypePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Select Leave Type', style: AppTextStyles.label),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.border),
          ...LeaveTypeColors.allCodes.map((code) {
            final isSelected = _leaveType == code;
            return InkWell(
              onTap: () {
                setState(() {
                  _leaveType = code;
                  _errors = {..._errors, 'type': null};
                });
                Navigator.of(context).pop();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(LeaveTypeColors.colorValueForCode(code)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(LeaveTypeColors.labelForCode(code),
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary)),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle,
                          size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  Widget _buildDateField(DateTime? value, VoidCallback onTap, String? error) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: error != null
              ? AppColors.error.withValues(alpha: 0.05)
              : AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: error != null ? AppColors.error : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14,
                color: value != null ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_fmt(value),
                  style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      fontWeight:
                          value != null ? FontWeight.w600 : FontWeight.w400),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.3)),
        if (required)
          Text(' *',
              style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _errMsg(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 12, color: AppColors.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(fontSize: 10, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

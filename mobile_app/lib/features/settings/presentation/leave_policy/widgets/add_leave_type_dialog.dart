import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/validators/form_validators.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../providers/settings_providers.dart';

// Creates a new custom leave type via POST /api/leave/policy/ (real backend
// call — see LeavePoliciesNotifier.createPolicy / LeavePolicyCreateSerializer).
// Only collects the basic fields the web's simple "Add Leave Type" modal
// collects; the rest of the (~25-field) rule engine defaults to the
// LeavePolicyFormData defaults and can be refined afterwards from the full
// edit sheet (LeavePolicyFormSheet).
class AddLeaveTypeDialog extends StatefulWidget {
  final WidgetRef ref;
  const AddLeaveTypeDialog({super.key, required this.ref});

  @override
  State<AddLeaveTypeDialog> createState() => _AddLeaveTypeDialogState();
}

class _AddLeaveTypeDialogState extends State<AddLeaveTypeDialog> {
  final _nameCtrl = TextEditingController();
  final _annualDaysCtrl = TextEditingController(text: '0');
  final _carryFwdLimitCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  bool _canCarryForward = false;
  bool _isActive = true;
  bool _saving = false;
  String? _nameError;
  String? _annualDaysError;
  String? _carryFwdLimitError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _annualDaysCtrl.dispose();
    _carryFwdLimitCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: AppTextStyles.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _submit() async {
    final form = LeavePolicyFormData(
      annualDays: double.tryParse(_annualDaysCtrl.text) ?? -1,
      canCarryForward: _canCarryForward,
      maxCarryForwardDays: int.tryParse(_carryFwdLimitCtrl.text) ?? 0,
      policyNote: _noteCtrl.text.trim(),
      isActive: _isActive,
    );
    final errors = form.validate();
    final name = _nameCtrl.text.trim();
    final nameError = FormValidators.leaveTypeName(name);
    if (nameError != null) {
      errors['name'] = nameError;
    }
    if (errors.isNotEmpty) {
      setState(() {
        _nameError = errors['name'];
        _annualDaysError = errors['annualDays'];
        _carryFwdLimitError = errors['maxCarryForwardDays'];
      });
      return;
    }

    setState(() => _saving = true);
    final notifier = widget.ref.read(leavePoliciesProvider.notifier);
    final result = await notifier.createPolicy(form, leaveTypeLabel: name);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Leave Type',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        SizedBox(height: 2),
                        Text(
                            'Basic setup — refine detailed rules afterwards from Edit',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                color: AppColors.background,
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        style: AppTextStyles.body,
                        autofocus: true,
                        onChanged: (v) {
                          final cleaned = FormValidators.sanitizeLeaveTypeName(v);
                          if (cleaned != v) {
                            _nameCtrl.value = _nameCtrl.value.copyWith(
                              text: cleaned,
                              selection: TextSelection.collapsed(offset: cleaned.length),
                            );
                          }
                          setState(() => _nameError = null);
                        },
                        decoration: _dec('Leave Type Name *', _nameError),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _annualDaysCtrl,
                        style: AppTextStyles.body,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,1}$'))
                        ],
                        onChanged: (_) =>
                            setState(() => _annualDaysError = null),
                        decoration: _dec('Annual Days *', _annualDaysError),
                      ),
                      const SizedBox(height: 14),
                      _ToggleRow(
                        icon: Icons.repeat_rounded,
                        label: 'Allow Carry Forward',
                        subtitleOn: 'Unused days roll over to next year',
                        subtitleOff: 'Unused days expire at year end',
                        value: _canCarryForward,
                        onChanged: (v) => setState(() {
                          _canCarryForward = v;
                          if (!v) {
                            _carryFwdLimitCtrl.text = '0';
                            _carryFwdLimitError = null;
                          }
                        }),
                      ),
                      if (_canCarryForward) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _carryFwdLimitCtrl,
                          style: AppTextStyles.body,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) =>
                              setState(() => _carryFwdLimitError = null),
                          decoration: _dec(
                              'Max Carry Forward Days *', _carryFwdLimitError),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _noteCtrl,
                        style: AppTextStyles.body,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: _dec('Policy Note'),
                      ),
                      const SizedBox(height: 6),
                      _ToggleRow(
                        icon: Icons.check_circle_outline,
                        label: 'Active',
                        subtitleOn:
                            'Employees can select and apply for this leave',
                        subtitleOff: 'Hidden from Apply Leave and dashboards',
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text('Add Leave Type',
                                style: AppTextStyles.label
                                    .copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle row (mirrors LeavePolicyFormSheet's _ToggleRow) ────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitleOn;
  final String subtitleOff;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitleOn,
    required this.subtitleOff,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: value
            ? AppColors.success.withValues(alpha: 0.07)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.success.withValues(alpha: 0.40)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : icon,
            color: value ? AppColors.success : AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.label
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? subtitleOn : subtitleOff,
                  style: AppTextStyles.caption.copyWith(
                    color: value ? AppColors.success : AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

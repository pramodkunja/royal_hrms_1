import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../leave/domain/entities/leave_entity.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../providers/settings_providers.dart';

/// Quick-edit sheet for a leave type's basic fields — mirrors web's
/// "Leave Types" tab edit modal (`PolicyTab.tsx`) exactly: Annual Days,
/// Allow Carry Forward + limit, Policy Note, Active. The full ~25-field rule
/// engine (application rules, eligibility, documentation, etc.) lives on its
/// own "Leave Policy" tab (`LeavePolicyRulesTab`) now, matching web's split
/// between `PolicyTab.tsx` and `LeavePoliciesTab.tsx` — this sheet used to
/// carry all of it in one place, which is what the web app never does.
class LeavePolicyFormSheet extends StatefulWidget {
  final LeavePolicyModel policy;
  final WidgetRef ref;

  const LeavePolicyFormSheet({super.key, required this.policy, required this.ref});

  @override
  State<LeavePolicyFormSheet> createState() => _LeavePolicyFormSheetState();
}

class _LeavePolicyFormSheetState extends State<LeavePolicyFormSheet> {
  late final TextEditingController _annualDaysCtrl;
  late final TextEditingController _carryFwdLimitCtrl;
  late final TextEditingController _noteCtrl;
  late bool _canCarryForward;
  late bool _isActive;

  bool _saving = false;
  String? _annualDaysError;
  String? _carryFwdLimitError;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    final form = LeavePolicyFormData.fromModel(widget.policy);
    _annualDaysCtrl = TextEditingController(text: _fmt(form.annualDays));
    // A stale non-zero value with carry-forward off shouldn't resurface —
    // the field is hidden and would otherwise silently resubmit unchanged.
    _carryFwdLimitCtrl = TextEditingController(
        text: form.canCarryForward ? '${form.maxCarryForwardDays}' : '0');
    _noteCtrl = TextEditingController(text: form.policyNote);
    _canCarryForward = form.canCarryForward;
    _isActive = form.isActive;
  }

  @override
  void dispose() {
    _annualDaysCtrl.dispose();
    _carryFwdLimitCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(LeaveTypeColors.colorValueForCode(widget.policy.leaveType));
    final title = 'Edit: ${widget.policy.leaveTypeDisplay}';
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DlgHeader(
              color: color,
              title: title,
              subtitle: 'Annual entitlement, carry-forward and status',
              onClose: () => Navigator.pop(context),
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
                          if (!v) _carryFwdLimitCtrl.text = '0';
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
                            : Text('Save Changes',
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

  // Only the 5 basic fields are user-editable here — every rule field is
  // carried through unchanged from the existing policy (fromModel), exactly
  // like the toggle-active/toggle-status actions elsewhere in this screen,
  // so saving from this sheet can never clobber the Leave Policy tab's rules.
  Future<void> _submit() async {
    final base = LeavePolicyFormData.fromModel(widget.policy);
    base.annualDays = double.tryParse(_annualDaysCtrl.text) ?? -1;
    base.canCarryForward = _canCarryForward;
    base.maxCarryForwardDays = int.tryParse(_carryFwdLimitCtrl.text) ?? 0;
    base.policyNote = _noteCtrl.text.trim();
    base.isActive = _isActive;

    final errors = base.validate();
    if (errors.isNotEmpty) {
      setState(() {
        _annualDaysError = errors['annualDays'];
        _carryFwdLimitError = errors['maxCarryForwardDays'];
      });
      return;
    }

    setState(() => _saving = true);
    final notifier = widget.ref.read(leavePoliciesProvider.notifier);
    final result = await notifier.updatePolicy(widget.policy.leaveType, base);
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
}

// ── Toggle row (generalised version of Departments' _StatusToggle) ────────────

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

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DlgHeader extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader(
      {required this.color,
      required this.title,
      required this.subtitle,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: color,
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
            child: const Icon(Icons.beach_access_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

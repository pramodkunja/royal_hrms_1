import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../leave/domain/entities/leave_entity.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../providers/settings_providers.dart';

// Two modes:
// - Editing one of the 6 real, backend-persisted types (policy != null &&
//   !policy.isPreview) — saves via LeavePoliciesNotifier.updatePolicy (real PUT).
// - Adding, or editing, a locally-added custom type (policy == null, or
//   policy.isPreview == true) — the backend's leave_type is a fixed 6-item
//   enum with no create endpoint, so this only calls [onPreviewSave] to update
//   in-memory state (see LeavePolicyScreen). Shows a Name field the real-edit
//   mode doesn't need, since the 6 real types already have a fixed name.
class LeavePolicyFormSheet extends StatefulWidget {
  final LeavePolicyModel? policy; // null = add
  final WidgetRef ref;
  final ValueChanged<LeavePolicyModel>? onPreviewSave;

  const LeavePolicyFormSheet(
      {super.key, this.policy, required this.ref, this.onPreviewSave});

  @override
  State<LeavePolicyFormSheet> createState() => _LeavePolicyFormSheetState();
}

class _LeavePolicyFormSheetState extends State<LeavePolicyFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _annualDaysCtrl;
  late final TextEditingController _carryFwdLimitCtrl;
  late final TextEditingController _noteCtrl;
  late bool _canCarryForward;
  late bool _isActive;
  bool _saving = false;
  String? _nameError;
  String? _annualDaysError;
  String? _carryFwdLimitError;

  bool get _isPreviewMode => widget.policy == null || widget.policy!.isPreview;
  bool get _isAdd => widget.policy == null;

  @override
  void initState() {
    super.initState();
    final p = widget.policy;
    _nameCtrl = TextEditingController(text: p?.leaveTypeDisplay ?? '');
    _annualDaysCtrl =
        TextEditingController(text: p != null ? _fmt(p.annualDays) : '0');
    _carryFwdLimitCtrl =
        TextEditingController(text: '${p?.maxCarryForwardDays ?? 0}');
    _noteCtrl = TextEditingController(text: p?.policyNote ?? '');
    _canCarryForward = p?.canCarryForward ?? false;
    _isActive = p?.isActive ?? true;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _annualDaysCtrl.dispose();
    _carryFwdLimitCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.policy != null && !_isPreviewMode
        ? Color(LeaveTypeColors.colorValueForCode(widget.policy!.leaveType))
        : AppColors.textSecondary;
    final title =
        _isAdd ? 'Add Leave Type' : 'Edit: ${widget.policy!.leaveTypeDisplay}';
    return ConstrainedBox(
      // Caps the dialog so the header always stays put and the form body
      // below scrolls within whatever room is left — without this bound,
      // Flexible below has nothing to size against and the content overflows
      // past the dialog instead of scrolling.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DlgHeader(
              color: color,
              title: title,
              subtitle: _isPreviewMode
                  ? 'Preview only — not yet saved to the server'
                  : 'Update entitlement, carry-forward and policy note',
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
                      if (_isPreviewMode) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          style: AppTextStyles.body,
                          autofocus: true,
                          onChanged: (_) => setState(() => _nameError = null),
                          decoration: _dec('Leave Type Name *', _nameError),
                        ),
                        const SizedBox(height: 14),
                      ],
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
                        onChanged: (v) => setState(() => _canCarryForward = v),
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
                            : Text(_isAdd ? 'Add Leave Type' : 'Save Changes',
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
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
    if (_isPreviewMode && _nameCtrl.text.trim().isEmpty) {
      errors['name'] = 'Leave type name is required.';
    }
    if (errors.isNotEmpty) {
      setState(() {
        _nameError = errors['name'];
        _annualDaysError = errors['annualDays'];
        _carryFwdLimitError = errors['maxCarryForwardDays'];
      });
      return;
    }

    if (_isPreviewMode) {
      final existing = widget.policy;
      widget.onPreviewSave!(LeavePolicyModel(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
        leaveType: existing?.leaveType ??
            'preview_${DateTime.now().millisecondsSinceEpoch}',
        leaveTypeDisplay: _nameCtrl.text.trim(),
        annualDays: form.annualDays,
        canCarryForward: form.canCarryForward,
        maxCarryForwardDays: form.maxCarryForwardDays,
        policyNote: form.policyNote,
        isActive: form.isActive,
        updatedAt: existing?.updatedAt ?? '',
        isPreview: true,
      ));
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    final notifier = widget.ref.read(leavePoliciesProvider.notifier);
    final result = await notifier.updatePolicy(widget.policy!.leaveType, form);
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

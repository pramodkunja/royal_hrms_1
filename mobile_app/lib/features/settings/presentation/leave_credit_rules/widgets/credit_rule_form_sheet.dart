import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/leave_credit_rule_model.dart';

typedef CreditRuleSubmit = void Function(CreditRuleFormData form);

class CreditRuleFormSheet extends StatefulWidget {
  final LeaveCreditRuleModel? rule; // null = add
  final CreditRuleSubmit onSubmit;

  const CreditRuleFormSheet({super.key, this.rule, required this.onSubmit});

  @override
  State<CreditRuleFormSheet> createState() => _CreditRuleFormSheetState();
}

class _CreditRuleFormSheetState extends State<CreditRuleFormSheet> {
  late final TextEditingController _leaveTypeCtrl;
  late final TextEditingController _accrualDaysCtrl;
  late final TextEditingController _maxBalanceCtrl;
  late final TextEditingController _minServiceCtrl;
  late final TextEditingController _encashLimitCtrl;
  late AccrualFrequency _frequency;
  late bool _encashable;
  late bool _isActive;
  final Map<String, String?> _errors = {};

  bool get _isAdd => widget.rule == null;

  @override
  void initState() {
    super.initState();
    final form = widget.rule != null
        ? CreditRuleFormData.fromModel(widget.rule!)
        : CreditRuleFormData();
    _leaveTypeCtrl = TextEditingController(text: form.leaveType);
    _accrualDaysCtrl = TextEditingController(text: _fmt(form.accrualDays));
    _maxBalanceCtrl = TextEditingController(text: '${form.maxBalance}');
    _minServiceCtrl = TextEditingController(text: '${form.minServiceMonths}');
    _encashLimitCtrl = TextEditingController(text: '${form.encashLimit}');
    _frequency = form.frequency;
    _encashable = form.encashable;
    _isActive = form.isActive;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _leaveTypeCtrl.dispose();
    _accrualDaysCtrl.dispose();
    _maxBalanceCtrl.dispose();
    _minServiceCtrl.dispose();
    _encashLimitCtrl.dispose();
    super.dispose();
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
            _DlgHeader(
              title: _isAdd
                  ? 'Add Credit Rule'
                  : 'Edit: ${widget.rule!.leaveType}',
              subtitle: 'Auto-accrual schedule and encashment policy',
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
                        controller: _leaveTypeCtrl,
                        style: AppTextStyles.body,
                        autofocus: true,
                        onChanged: (_) =>
                            setState(() => _errors.remove('leaveType')),
                        decoration: _dec('Leave Type *', _errors['leaveType']),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _accrualDaysCtrl,
                              style: AppTextStyles.body,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,1}$'))
                              ],
                              onChanged: (_) =>
                                  setState(() => _errors.remove('accrualDays')),
                              decoration: _dec(
                                  'Accrual Days *', _errors['accrualDays']),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<AccrualFrequency>(
                              initialValue: _frequency,
                              style: AppTextStyles.body,
                              decoration: _dec('Frequency'),
                              items: AccrualFrequency.values
                                  .map((f) => DropdownMenuItem(
                                      value: f, child: Text(f.label)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _frequency = v ?? _frequency),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _maxBalanceCtrl,
                              style: AppTextStyles.body,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (_) =>
                                  setState(() => _errors.remove('maxBalance')),
                              decoration: _dec('Max Balance (days) *',
                                  _errors['maxBalance']),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _minServiceCtrl,
                              style: AppTextStyles.body,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: _dec('Min Service (months)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ToggleRow(
                        icon: Icons.currency_exchange_rounded,
                        label: 'Allow Encashment',
                        subtitleOn: 'Employees can encash unused days',
                        subtitleOff: 'This leave type cannot be encashed',
                        value: _encashable,
                        onChanged: (v) => setState(() => _encashable = v),
                      ),
                      if (_encashable) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _encashLimitCtrl,
                          style: AppTextStyles.body,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) =>
                              setState(() => _errors.remove('encashLimit')),
                          decoration: _dec(
                              'Encash Limit (days) *', _errors['encashLimit']),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ToggleRow(
                        icon: Icons.check_circle_outline,
                        label: 'Active',
                        subtitleOn: 'This rule is currently applied',
                        subtitleOff: 'This rule is disabled',
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(_isAdd ? 'Add Rule' : 'Save Changes',
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

  void _submit() {
    final form = CreditRuleFormData(
      leaveType: _leaveTypeCtrl.text.trim(),
      accrualDays: double.tryParse(_accrualDaysCtrl.text) ?? -1,
      frequency: _frequency,
      maxBalance: int.tryParse(_maxBalanceCtrl.text) ?? -1,
      encashable: _encashable,
      encashLimit: int.tryParse(_encashLimitCtrl.text) ?? 0,
      minServiceMonths: int.tryParse(_minServiceCtrl.text) ?? 0,
      isActive: _isActive,
    );
    final errors = form.validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    widget.onSubmit(form);
    Navigator.pop(context);
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

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
                Text(label,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
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
              activeTrackColor: AppColors.success),
        ],
      ),
    );
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DlgHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader(
      {required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            child:
                const Icon(Icons.paid_outlined, color: Colors.white, size: 20),
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

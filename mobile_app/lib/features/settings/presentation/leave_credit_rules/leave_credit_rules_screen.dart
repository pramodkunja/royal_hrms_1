import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/leave_credit_rule_model.dart';
import '../providers/settings_providers.dart';
import 'widgets/credit_rule_form_sheet.dart';

// Tab body shown inside LeavePolicyScreen's "Credit Rules" tab.
//
// Two distinct halves:
// 1. "Credit Annual Leave" — a REAL, working backend action (POST
//    /leave/balance/credit/, see LeavePoliciesNotifier.creditAnnualLeave).
// 2. "Accrual Rules" list below — local-only preview. No backend model or
//    endpoint exists for per-type accrual schedules yet (confirmed against
//    apps/hrms/ — no accrual/credit_rule/encash anywhere), so this mirrors
//    the web's own leave-credit-rules/page.tsx, which is also seed-data-only
//    with a fake save. Clearly labelled "Preview" so it isn't mistaken for a
//    saved setting.
class CreditRulesTab extends ConsumerStatefulWidget {
  const CreditRulesTab({super.key});

  @override
  ConsumerState<CreditRulesTab> createState() => CreditRulesTabState();
}

class CreditRulesTabState extends ConsumerState<CreditRulesTab> {
  List<LeaveCreditRuleModel> _rules = List.of(kSeedCreditRules);

  // Called by the parent screen's FAB via a GlobalKey.
  void openAdd() {
    _openSheet(null, (form) {
      setState(() {
        _rules = [
          ..._rules,
          LeaveCreditRuleModel(
            id: DateTime.now().millisecondsSinceEpoch,
            leaveType: form.leaveType,
            accrualDays: form.accrualDays,
            frequency: form.frequency,
            maxBalance: form.maxBalance,
            encashable: form.encashable,
            encashLimit: form.encashLimit,
            minServiceMonths: form.minServiceMonths,
            isActive: form.isActive,
          ),
        ];
      });
    });
  }

  void _openEdit(LeaveCreditRuleModel rule) {
    _openSheet(rule, (form) {
      setState(() {
        _rules = _rules.map((r) {
          if (r.id != rule.id) return r;
          return LeaveCreditRuleModel(
            id: r.id,
            leaveType: form.leaveType,
            accrualDays: form.accrualDays,
            frequency: form.frequency,
            maxBalance: form.maxBalance,
            encashable: form.encashable,
            encashLimit: form.encashLimit,
            minServiceMonths: form.minServiceMonths,
            isActive: form.isActive,
          );
        }).toList();
      });
    });
  }

  Future<void> _openSheet(
      LeaveCreditRuleModel? rule, CreditRuleSubmit onSubmit) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CreditRuleFormSheet(rule: rule, onSubmit: onSubmit),
      ),
    );
  }

  Future<void> _confirmDelete(LeaveCreditRuleModel rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Credit Rule'),
        content: Text(
            'Delete the rule for "${rule.leaveType}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _rules = _rules.where((r) => r.id != rule.id).toList());
    }
  }

  final _yearCtrl = TextEditingController(text: '${DateTime.now().year}');
  bool _crediting = false;

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _creditAllEmployees() async {
    final year = int.tryParse(_yearCtrl.text);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Credit All Employees'),
        content: Text(
            'Credit annual leave balances for all active employees for $year?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Credit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _crediting = true);
    try {
      final message = await ref
          .read(leavePoliciesProvider.notifier)
          .creditAnnualLeave(year: year);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _crediting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        _CreditAnnualLeaveCard(
          yearCtrl: _yearCtrl,
          crediting: _crediting,
          onCredit: _creditAllEmployees,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('ACCRUAL RULES',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6)),
            const SizedBox(width: 8),
            const _AutomationBadge(),
            const Spacer(),
            Text('${_rules.length} rules',
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Auto-accrual schedules, carry-forward limits and encashment policy. '
          'Not yet connected to a backend — changes here reset when you leave this screen.',
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textHint, height: 1.4, fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (_rules.isEmpty)
          const _EmptyView()
        else
          ..._rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RuleCard(
                  rule: r,
                  onEdit: () => _openEdit(r),
                  onDelete: () => _confirmDelete(r),
                ),
              )),
      ],
    );
  }
}

// ── Credit Annual Leave — real action card ─────────────────────────────────────

class _CreditAnnualLeaveCard extends StatelessWidget {
  final TextEditingController yearCtrl;
  final bool crediting;
  final VoidCallback onCredit;
  const _CreditAnnualLeaveCard({
    required this.yearCtrl,
    required this.crediting,
    required this.onCredit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.currency_exchange_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Credit Leave Balances',
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Credit annual leave balances for all active employees based on the configured '
            'Leave Policy. Employees who already have a balance record for the selected year '
            'are skipped automatically.',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Text('FINANCIAL YEAR',
              style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: yearCtrl,
            keyboardType: TextInputType.number,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: crediting ? null : onCredit,
              icon: crediting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(crediting ? 'Crediting…' : 'Credit All Employees'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationBadge extends StatelessWidget {
  const _AutomationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('AUTOMATION COMING SOON',
          style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
    );
  }
}

// ── Rule card ─────────────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final LeaveCreditRuleModel rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RuleCard(
      {required this.rule, required this.onEdit, required this.onDelete});

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(rule.leaveType,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              _StatusPill(isActive: rule.isActive),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.backgroundLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(_fmt(rule.accrualDays),
                  style: AppTextStyles.h3
                      .copyWith(color: AppColors.primary, fontSize: 20)),
              const SizedBox(width: 4),
              Text('days',
                  style: AppTextStyles.caption
                      .copyWith(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(width: 8),
              _Chip(label: rule.frequency.label, color: AppColors.info),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                  label: 'Max ${rule.maxBalance}d',
                  color: AppColors.textSecondary),
              _Chip(
                label: rule.encashable
                    ? 'Encash up to ${rule.encashLimit}d'
                    : 'No Encashment',
                color: rule.encashable ? AppColors.success : AppColors.textHint,
              ),
              if (rule.minServiceMonths > 0)
                _Chip(
                    label: '${rule.minServiceMonths}mo service',
                    color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(isActive ? 'Active' : 'Inactive',
          style: AppTextStyles.caption.copyWith(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.paid_outlined,
                size: 40, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text('No credit rules yet.', style: AppTextStyles.bodySecondary),
          ],
        ),
      ),
    );
  }
}

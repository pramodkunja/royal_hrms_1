import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/settings_providers.dart';

// Tab body shown inside LeavePolicyScreen's "Credit Rules" tab.
//
// "Credit Leave Balances" is a REAL, working backend action (POST
// /leave/balance/credit/, see LeavePoliciesNotifier.creditAnnualLeave) and
// is unchanged.
//
// HO-35 (Task 87): the "Accrual Rules" list that used to sit below it was
// seed data (kSeedCreditRules) with add / edit / delete that only changed
// local state — no backend model or endpoint exists for per-type accrual
// schedules, so every edit was silently discarded when the screen closed.
// Those controls are removed; an explicit "not available" notice takes their
// place. Nothing here pretends to persist.
class CreditRulesTab extends ConsumerStatefulWidget {
  const CreditRulesTab({super.key});

  @override
  ConsumerState<CreditRulesTab> createState() => CreditRulesTabState();
}

class CreditRulesTabState extends ConsumerState<CreditRulesTab> {
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _CreditAnnualLeaveCard(
          yearCtrl: _yearCtrl,
          crediting: _crediting,
          onCredit: _creditAllEmployees,
        ),
        const SizedBox(height: 20),
        const AccrualRulesUnavailableNotice(),
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
                child: Icon(Icons.currency_exchange_rounded,
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
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5),
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

/// Shown where the unsupported accrual-rule editor used to be (HO-35):
/// read-only, no values, no actions.
class AccrualRulesUnavailableNotice extends StatelessWidget {
  const AccrualRulesUnavailableNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('accrual-rules-unavailable'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Automatic accrual rules — not available',
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Scheduled accrual, carry-forward limits and encashment rules '
                  "aren't supported by the server yet, so they can't be set here. "
                  'Use Credit All Employees above to credit annual balances from the '
                  'Leave Policy.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

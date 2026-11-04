import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/widgets/dashboard_section.dart';
import '../../data/models/payslip_model.dart';
import '../../data/models/payslip_query_model.dart';
import '../providers/payroll_providers.dart';

String _when(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} ${d.year}, $hh:$mm';
}

/// "Payslip queries" for one payslip (web my-payslip page): its queries
/// with status and HR's response, and Raise Query while the payslip allows
/// one.
class PayslipQueriesSection extends ConsumerWidget {
  const PayslipQueriesSection({super.key, required this.payslip, required this.monthLabel});

  final PayslipModel payslip;
  final String monthLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queriesAsync = ref.watch(myPayslipQueriesProvider);
    final eligibility = canRaisePayslipQuery(payslip.status, payslip.queryDeadline);
    final mine = queriesForPayslip(queriesAsync.valueOrNull ?? const [], payslip.id);

    return SectionCard(
      key: const Key('payslip-queries'),
      title: 'Payslip queries',
      icon: Icons.forum_outlined,
      accentColor: AppColors.primary,
      trailing: eligibility.allowed
          ? TextButton.icon(
              key: const Key('raise-query'),
              onPressed: () => RaisePayslipQuerySheet.show(context, payslip: payslip, monthLabel: monthLabel),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Raise Query'),
            )
          : null,
      child: queriesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Row(children: [
          Expanded(
            child: Text(userFriendlyMessage(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
          TextButton(onPressed: () => ref.invalidate(myPayslipQueriesProvider), child: const Text('Retry')),
        ]),
        data: (_) {
          if (mine.isEmpty) {
            final hint = eligibility.allowed
                ? (payslip.queryDeadline != null
                    ? 'No queries on this payslip. You can raise one until ${_when(payslip.queryDeadline!)}.'
                    : 'No queries on this payslip.')
                : (eligibility.reason ?? 'No queries on this payslip.');
            return Text(hint, key: const Key('payslip-queries-empty'), style: AppTextStyles.bodySecondary);
          }
          return Column(children: [for (final q in mine) _QueryTile(query: q)]);
        },
      ),
    );
  }
}

class _QueryTile extends StatelessWidget {
  const _QueryTile({required this.query});
  final PayslipQueryModel query;

  @override
  Widget build(BuildContext context) {
    final q = query;
    final color = q.isResolved ? AppColors.success : AppColors.warning;
    return Container(
      key: Key('payslip-query-${q.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Raised ${_when(q.createdAt)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(payslipQueryStatusLabel(q.status),
                style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(q.description, style: AppTextStyles.bodySmall),
        if (q.isResolved) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                [
                  'HR RESPONSE',
                  if (q.resolvedByName?.isNotEmpty ?? false) q.resolvedByName!,
                  if (q.resolvedAt != null) _when(q.resolvedAt!),
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(q.resolutionNote.isEmpty ? '—' : q.resolutionNote, style: AppTextStyles.bodySmall),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Raise a query on [payslip] (web: "Raise a query — <month>" modal).
class RaisePayslipQuerySheet extends ConsumerStatefulWidget {
  const RaisePayslipQuerySheet({super.key, required this.payslip, required this.monthLabel});

  final PayslipModel payslip;
  final String monthLabel;

  static Future<void> show(BuildContext context, {required PayslipModel payslip, required String monthLabel}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => RaisePayslipQuerySheet(payslip: payslip, monthLabel: monthLabel),
      );

  @override
  ConsumerState<RaisePayslipQuerySheet> createState() => _RaisePayslipQuerySheetState();
}

class _RaisePayslipQuerySheetState extends ConsumerState<RaisePayslipQuerySheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return; // one request at a time
    final problem = validatePayslipQueryText(_ctrl.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final err =
        await ref.read(payslipQueryActionsProvider).raise(payslipId: widget.payslip.id, description: _ctrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _sending = false;
        _error = err; // the text stays for another try
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: const Text('Your query has been sent to HR.'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final length = _ctrl.text.trim().length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Raise a query — ${widget.monthLabel}', style: AppTextStyles.h3),
            const SizedBox(height: 14),
            TextField(
              key: const Key('payslip-query-text'),
              controller: _ctrl,
              enabled: !_sending,
              maxLines: 5,
              maxLength: kPayslipQueryMaxLength,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'What looks wrong on this payslip? *',
                alignLabelWithHint: true,
                counterText: '$length/$kPayslipQueryMaxLength · HR will reply here.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  key: const Key('payslip-query-error'),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('payslip-query-send'),
                  onPressed: _sending || length == 0 ? null : _send,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: Text(_sending ? 'Sending…' : 'Send Query'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

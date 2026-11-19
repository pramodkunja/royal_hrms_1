import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/formatters/en_in_format.dart';
import '../../../../../shared/widgets/app_error_state.dart';
import '../../../../profile/presentation/widgets/profile_widgets.dart';
import '../../../data/models/company_plan_model.dart';
import '../../../domain/plan_details_logic.dart';
import '../../providers/settings_providers.dart';
import 'company_widgets.dart';

// Company Settings → Plan Details (web PlanDetailsTab.tsx). settings.edit
// only; read-only — it shows what the company purchased, which modules are
// included / enabled, how other public plans compare and the payment history.
// Every figure comes from GET /settings/company/plan/; nothing here changes
// the plan, its modules or payments, and nothing is computed or invented.

/// Web `fmtDate`: an ISO date as "05 Nov 2026", "—" when absent.
String planDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '—' : formatEnInDate(d, padDay: true);
}

class PlanDetailsTab extends ConsumerWidget {
  const PlanDetailsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyPlanProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('Loading plan details…')),
      ),
      error: (e, _) => AppErrorState.forError(e, onRetry: () => ref.invalidate(companyPlanProvider)),
      data: (d) => _Content(details: d),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.details});
  final PlanDetails details;

  @override
  Widget build(BuildContext context) {
    final cur = details.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _YourPlan(details: details),
        const SizedBox(height: 16),
        _Modules(details: details),
        if (details.otherPlans.isNotEmpty) ...[const SizedBox(height: 16), _OtherPlans(details: details)],
        if (cur != null) ...[const SizedBox(height: 16), _Payments(details: details, cur: cur)],
      ],
    );
  }
}

// ── shared bits ───────────────────────────────────────────────────────────────

Widget _label(String text) => Text(
      text,
      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
    );

Widget _chips(List<PlanFeatureLabel> items) => items.isEmpty
    ? Text('—', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
    : Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final i in items)
            Tooltip(message: i.description, child: CompanyBadge(i.label, CompanyBadgeTone.neutral)),
        ],
      );

Widget _fact(String label, String value, {String? extra}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value),
            if (extra != null)
              TextSpan(text: extra, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ]),
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );

Widget _tile(String label, String value, {Color? tone}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800, color: tone)),
        ],
      ),
    );

/// Lays children out two per row, stacking on narrow widths / large text.
Widget _grid(List<Widget> children) => _PairGrid(children: children);

class _PairGrid extends StatelessWidget {
  const _PairGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= ProfileTwoUp.kMinPairWidth && scale <= ProfileTwoUp.kMaxPairTextScale;
      if (!two) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]]
          ],
        );
      }
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        rows.add(Padding(
          padding: EdgeInsets.only(bottom: i + 2 < children.length ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ));
      }
      return Column(children: rows);
    });
  }
}

CompanyBadgeTone _paymentTone(String s) => switch (s) {
      'paid' => CompanyBadgeTone.success,
      'partially_paid' || 'pending' => CompanyBadgeTone.warn,
      'failed' => CompanyBadgeTone.error,
      _ => CompanyBadgeTone.neutral,
    };

// ── Your plan ─────────────────────────────────────────────────────────────────

class _YourPlan extends StatelessWidget {
  const _YourPlan({required this.details});
  final PlanDetails details;

  @override
  Widget build(BuildContext context) {
    final cur = details.current;
    String money(String? v, [String? code]) => v == null ? '—' : formatMoney(v, code ?? cur?.currency ?? 'INR');
    return ProfileSectionCard(
      icon: Icons.workspace_premium_outlined,
      title: 'Your plan',
      child: cur == null
          ? Container(
              key: const Key('plan-none'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No subscription plan is assigned to your company yet. The modules below are what your users '
                      'can use today. Contact your account manager to choose a plan.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cur.planName, style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  CompanyBadge(
                    cur.status == 'active' ? 'Active' : 'Inactive',
                    cur.status == 'active' ? CompanyBadgeTone.success : CompanyBadgeTone.neutral,
                  ),
                  CompanyBadge(kPaymentLabel[cur.paymentStatus] ?? cur.paymentStatus, _paymentTone(cur.paymentStatus)),
                  CompanyBadge(
                    kActivationLabel[cur.activation] ?? cur.activation,
                    cur.activation == 'active' ? CompanyBadgeTone.success : CompanyBadgeTone.warn,
                  ),
                ]),
                if (cur.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(cur.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 14),
                _grid([
                  _fact('Billing cycle', periodLabel(cur.billingPeriod)),
                  _fact('Start date', planDate(cur.startsOn)),
                  _fact(
                    'End date',
                    cur.endsOn != null ? planDate(cur.endsOn) : 'No end date',
                    extra: cur.daysLeft != null ? ' · ${cur.daysLeft} day${cur.daysLeft == 1 ? '' : 's'} left' : null,
                  ),
                  _fact(
                    'Price',
                    '${money(cur.pricePerEmployee)} / employee / month',
                    extra: gstSuffix(cur.gstInclusive, cur.gstRate),
                  ),
                  if (cur.employeeCount != null) _fact('Employees', '${cur.employeeCount}'),
                ]),
                if (cur.periodEnded) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('plan-period-ended'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.event_busy_outlined, size: 18, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The subscription period ended on ${planDate(cur.endsOn)}. Your access continues — '
                            'contact your account manager to renew.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _grid([
                  _tile('Total plan amount', cur.totalAmount != null ? money(cur.totalAmount) : 'Not set'),
                  _tile('Amount paid', money(cur.amountPaid)),
                  if ((double.tryParse(cur.amountPendingConfirmation) ?? 0) > 0)
                    _tile('Awaiting confirmation', money(cur.amountPendingConfirmation)),
                  _tile(
                    'Outstanding',
                    cur.paymentStatus == 'waived' ? 'Waived' : money(cur.amountOutstanding),
                    tone: (double.tryParse(cur.amountOutstanding ?? '') ?? 0) > 0 ? AppColors.warning : null,
                  ),
                ]),
                const SizedBox(height: 14),
                _label('Plan features'),
                const SizedBox(height: 6),
                _chips(cur.features),
              ],
            ),
    );
  }
}

// ── Modules ───────────────────────────────────────────────────────────────────

class _Modules extends StatelessWidget {
  const _Modules({required this.details});
  final PlanDetails details;

  @override
  Widget build(BuildContext context) {
    final rows = sortedModules(details.modules);
    return ProfileSectionCard(
      icon: Icons.apps_outlined,
      title: 'Modules',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moduleSummaryLine(moduleSummary(details.modules)),
            key: const Key('plan-module-summary'),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 20, color: AppColors.border),
            _ModuleRow(row: rows[i], hasPlan: details.hasPlan),
          ],
          const SizedBox(height: 16),
          _label('Always included'),
          const SizedBox(height: 6),
          _chips(details.alwaysIncluded),
          const SizedBox(height: 12),
          _label('Coming soon'),
          const SizedBox(height: 6),
          _chips(details.comingSoon),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.row, required this.hasPlan});
  final PlanModuleRow row;
  final bool hasPlan;

  @override
  Widget build(BuildContext context) {
    final sourceTone = switch (row.source) {
      'not_included' => CompanyBadgeTone.neutral,
      'removed' => CompanyBadgeTone.error,
      'added' => CompanyBadgeTone.info,
      _ => CompanyBadgeTone.success,
    };
    final outside = enabledOutsidePlan(row, hasPlan);
    final accessTone = row.access == 'enabled'
        ? CompanyBadgeTone.success
        : (row.access == 'pending' ? CompanyBadgeTone.warn : CompanyBadgeTone.neutral);
    final note = sourceNote(row);
    return Opacity(
      opacity: !row.included && !row.enabled ? 0.65 : 1,
      child: Column(
        key: Key('plan-module-${row.key}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          if (row.category.isNotEmpty)
            Text(row.category, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
          if (row.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(row.description, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            hasPlan
                ? CompanyBadge(kSourceLabel[row.source] ?? row.source, sourceTone)
                : const CompanyBadge('No plan', CompanyBadgeTone.neutral),
            outside
                ? const CompanyBadge('Enabled (not part of your plan)', CompanyBadgeTone.success)
                : CompanyBadge(kAccessLabel[row.access] ?? row.access, accessTone),
          ]),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

// ── Other plans ───────────────────────────────────────────────────────────────

class _OtherPlans extends StatelessWidget {
  const _OtherPlans({required this.details});
  final PlanDetails details;

  @override
  Widget build(BuildContext context) {
    final comparison = comparisonRows(details);
    return ProfileSectionCard(
      icon: Icons.compare_arrows_outlined,
      title: 'Other plans',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For information — to change plans, contact your account manager.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final p in details.otherPlans) ...[
            _OtherPlanCard(plan: p, details: details),
            const SizedBox(height: 12)
          ],
          if (comparison.isNotEmpty) _Comparison(details: details, rows: comparison),
        ],
      ),
    );
  }
}

class _OtherPlanCard extends StatelessWidget {
  const _OtherPlanCard({required this.plan, required this.details});
  final OtherPlan plan;
  final PlanDetails details;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final periods = p.billingPeriods.map(periodLabel).join(' or ').toLowerCase();
    final extra = moduleLabels(details, p.additionalModules);
    final missing = moduleLabels(details, p.modulesNotIncluded);
    return Container(
      key: Key('plan-other-${p.code}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800)),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(p.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: formatMoney(p.pricePerEmployee, p.currency),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' / employee / month${gstSuffix(p.gstInclusive, p.gstRate)}'),
              TextSpan(
                text: ' · billed $periods',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ]),
            style: AppTextStyles.bodySmall,
          ),
          if (p.estimates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For your ${p.estimateEmployeeCount} employees: '
                    '${p.estimates.map((e) => '${formatMoney(e.total, p.currency)} / ${e.billingPeriod == 'yearly' ? 'year' : 'month'}').join(' · ')}'
                    ' (incl. GST)',
                    style: AppTextStyles.caption,
                  ),
                  if (!p.fitsEmployeeCount)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'This plan is for ${p.minEmployees ?? 1}–${p.maxEmployees ?? 'any number of'} employees.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'You would also get: ',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
              ),
              TextSpan(text: extra.isNotEmpty ? extra.join(', ') : 'no additional modules'),
            ]),
            style: AppTextStyles.bodySmall,
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Not in this plan: ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: missing.join(', ')),
              ]),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (p.features.isNotEmpty) ...[
            const SizedBox(height: 8),
            _label('Features'),
            const SizedBox(height: 4),
            _chips(p.features),
          ],
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.details, required this.rows});
  final PlanDetails details;
  final List<ComparisonRow> rows;

  @override
  Widget build(BuildContext context) {
    final cur = details.current;
    final headStyle = AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700);
    Widget cell(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: w);
    Widget mark(bool on, Color color) => on ? Icon(Icons.check, size: 16, color: color) : const Text('—');
    return SingleChildScrollView(
      key: const Key('plan-comparison'),
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
        children: [
          TableRow(children: [
            cell(Text('Module', style: headStyle)),
            cell(Text(cur != null ? '${cur.planName} (current)' : 'Today', style: headStyle)),
            for (final p in details.otherPlans) cell(Text(p.name, style: headStyle)),
          ]),
          for (final r in rows)
            TableRow(children: [
              cell(Text(r.label, style: AppTextStyles.caption)),
              cell(mark(r.current, AppColors.success)),
              for (final p in details.otherPlans)
                cell(mark(r.plans[p.code] == true, r.current ? AppColors.success : AppColors.primary)),
            ]),
        ],
      ),
    );
  }
}

// ── Payment history ───────────────────────────────────────────────────────────

class _Payments extends StatelessWidget {
  const _Payments({required this.details, required this.cur});
  final PlanDetails details;
  final CurrentPlan cur;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Payment history',
      child: details.payments.isEmpty
          ? Text(
              cur.paymentStatus == 'waived' ? 'Payment is waived for this subscription.' : 'No payments recorded yet.',
              key: const Key('plan-no-payments'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            )
          : Column(
              children: [
                for (var i = 0; i < details.payments.length; i++) ...[
                  if (i > 0) Divider(height: 20, color: AppColors.border),
                  _PaymentRow(payment: details.payments[i]),
                ],
              ],
            ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final PlanPayment payment;

  @override
  Widget build(BuildContext context) {
    final confirmed = payment.status == 'confirmed';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMoney(payment.amount, payment.currency),
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${planDate(payment.paidOn)} · ${payment.method}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                'Reference: ${payment.reference.isEmpty ? '—' : payment.reference}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: CompanyBadge(
            confirmed ? 'Confirmed' : 'Awaiting confirmation',
            confirmed ? CompanyBadgeTone.success : CompanyBadgeTone.warn,
          ),
        ),
      ],
    );
  }
}

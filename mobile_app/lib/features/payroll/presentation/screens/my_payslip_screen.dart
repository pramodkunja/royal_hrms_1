import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../../../dashboard/presentation/widgets/dashboard_section.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/models/payslip_model.dart';
import '../providers/payroll_providers.dart';
import '../widgets/payslip_queries_section.dart';

/// Employee-facing "My Payslips" — restored after the wider admin Payroll
/// module (Run Payroll, Payroll Rules) was removed from mobile. Unlike the
/// original mock this replaced (hardcoded demo months/amounts, zero API
/// calls), every figure here comes from GET /payroll/my-payslips/
/// (myPayslipsProvider), the employee's own profile (myProfileProvider, for
/// name/employee code/department/bank details — the payslip record itself
/// doesn't carry those), and Company settings (companyProvider, for the
/// letterhead) — mirrors what web's own my-payslip page actually renders.
///
/// Three things the old mock showed have no backend equivalent and are
/// intentionally NOT here: PAN/UAN (not on the employee profile or payslip
/// API), a TDS/Loan EMI deduction line (not modeled anywhere in
/// apps/payroll), and a per-category reimbursement breakdown (the API only
/// has one flat `reimbursements` total, no sub-categories).
class MyPayslipScreen extends ConsumerStatefulWidget {
  const MyPayslipScreen({super.key});

  @override
  ConsumerState<MyPayslipScreen> createState() => _MyPayslipScreenState();
}

class _MyPayslipScreenState extends ConsumerState<MyPayslipScreen> {
  String? _selectedId;
  bool _acknowledging = false;

  static const _kMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _monthLabel(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return '${_kMonthNames[parsed.month - 1]} ${parsed.year}';
  }

  String _shortDate(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    const months = [
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
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final payslipsAsync = ref.watch(myPayslipsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPayslipsProvider);
        ref.invalidate(myProfileProvider);
        ref.invalidate(myPayslipQueriesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlueHeroBanner(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('My Payslips',
                      style: AppTextStyles.h3.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'View your monthly salary breakdown',
                    style: AppTextStyles.bodySecondary
                        .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: payslipsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SectionError(
                  message: friendlyPayrollError(e),
                  onRetry: () => ref.invalidate(myPayslipsProvider),
                ),
                data: (payslips) {
                  if (payslips.isEmpty) {
                    return SectionCard(
                      title: 'Payslips',
                      icon: Icons.receipt_long_outlined,
                      accentColor: AppColors.primary,
                      child: const SectionMessage(
                        icon: Icons.receipt_long_outlined,
                        label: 'No payslips available yet.',
                      ),
                    );
                  }
                  final selected = payslips.firstWhere(
                    (p) => p.id == _selectedId,
                    orElse: () => payslips.first,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MonthSelector(
                        payslips: payslips,
                        selectedId: selected.id,
                        monthLabel: _monthLabel,
                        onSelect: (id) => setState(() => _selectedId = id),
                      ),
                      const SizedBox(height: 14),
                      _PayslipDetailCard(
                        payslip: selected,
                        monthLabel: _monthLabel(selected.cycleStart),
                        payDateLabel: _shortDate(selected.payDate),
                        acknowledging: _acknowledging,
                        onAcknowledge: () => _acknowledge(selected.id),
                      ),
                      const SizedBox(height: 14),
                      PayslipQueriesSection(
                        payslip: selected,
                        monthLabel: _monthLabel(selected.cycleStart),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acknowledge(String id) async {
    setState(() => _acknowledging = true);
    final error = await ref.read(myPayslipsProvider.notifier).acknowledge(id);
    if (!mounted) return;
    setState(() => _acknowledging = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Payslip acknowledged.'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Month selector ───────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final List<PayslipModel> payslips;
  final String selectedId;
  final String Function(String) monthLabel;
  final ValueChanged<String> onSelect;

  const _MonthSelector({
    required this.payslips,
    required this.selectedId,
    required this.monthLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: payslips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = payslips[index];
          final isSelected = p.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(p.id),
            child: Container(
              width: 132,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthLabel(p.cycleStart),
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    payslipStatusLabel(p.status),
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Payslip detail card ───────────────────────────────────────────────────────

class _PayslipDetailCard extends ConsumerWidget {
  final PayslipModel payslip;
  final String monthLabel;
  final String payDateLabel;
  final bool acknowledging;
  final VoidCallback onAcknowledge;

  const _PayslipDetailCard({
    required this.payslip,
    required this.monthLabel,
    required this.payDateLabel,
    required this.acknowledging,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final companyAsync = ref.watch(companyProvider);

    return SectionCard(
      title: monthLabel,
      icon: Icons.receipt_long_outlined,
      accentColor: AppColors.primary,
      trailing: _StatusChip(status: payslip.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          companyAsync.maybeWhen(
            data: (company) => _CompanyLine(
                companyName: company.companyName,
                cin: company.cin,
                address: [company.address, company.city, company.state, company.pinCode]
                    .where((s) => s.isNotEmpty)
                    .join(', ')),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
          // Web: "Salary Date: 09 Nov 2026" (fmtDate, en-IN).
          Text('Salary Date: ${formatPayslipDate(payslip.payDate)}',
              key: const Key('payslip-salary-date'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 14),
          profileAsync.maybeWhen(
            data: (profile) => _EmployeeMetaGrid(
              employeeIdCode: payslip.employeeIdCode,
              bankName: profile.detail.bankName,
              accountNumber: profile.detail.accountNumber,
              ifscCode: profile.detail.ifscCode,
            ),
            orElse: () => _EmployeeMetaGrid(employeeIdCode: payslip.employeeIdCode),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          _StatsRow(payslip: payslip, monthLabel: monthLabel),
          const SizedBox(height: 16),
          _EarningsSection(payslip: payslip),
          const SizedBox(height: 12),
          _DeductionsSection(payslip: payslip),
          if (payslip.reimbursements > 0) ...[
            const SizedBox(height: 12),
            _ReimbursementLine(amount: payslip.reimbursements),
          ],
          const SizedBox(height: 16),
          _NetPayBanner(
            payslip: payslip,
            // Web netSubline: "Paid on <date>[ · <bank> ••••1234]".
            subline: 'Paid on ${formatPayslipDate(payslip.payDate)}'
                '${profileAsync.valueOrNull?.detail.bankName.isNotEmpty == true ? ' · ${profileAsync.valueOrNull!.detail.bankName} ${maskPayslipAccount(profileAsync.valueOrNull!.detail.accountNumber)}' : ''}',
          ),
          if (payslip.payslipPdfUrl != null &&
              payslip.payslipPdfUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(payslip.payslipPdfUrl!),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Open PDF'),
            ),
          ],
          if (payslip.status == 'sent') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: acknowledging ? null : onAcknowledge,
              icon: acknowledging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                  acknowledging ? 'Acknowledging…' : 'Acknowledge Payslip'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Web footer.
          Text(
            'This is a computer-generated payslip and does not require a signature.'
            '${companyAsync.valueOrNull?.officialPhone.isNotEmpty == true ? ' For queries contact HR at ${companyAsync.valueOrNull!.officialPhone}.' : ''}',
            key: const Key('payslip-footer'),
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _CompanyLine extends StatelessWidget {
  final String companyName;
  final String cin;
  final String address;
  const _CompanyLine({required this.companyName, required this.cin, this.address = ''});

  @override
  Widget build(BuildContext context) {
    if (companyName.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        cin.isEmpty ? companyName : '$companyName · CIN: $cin',
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      if (address.isNotEmpty)
        Text(address,
            key: const Key('payslip-company-address'),
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        payslipStatusLabel(status),
        style: AppTextStyles.caption
            .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Employee meta ─────────────────────────────────────────────────────────────

class _EmployeeMetaGrid extends StatelessWidget {
  final String employeeIdCode;
  final String bankName;
  final String accountNumber;
  final String ifscCode;

  const _EmployeeMetaGrid({
    required this.employeeIdCode,
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
  });

  @override
  Widget build(BuildContext context) {
    // Web strip: always these four, "—" when unknown.
    final items = <(String, String)>[
      ('Employee ID', employeeIdCode.isNotEmpty ? employeeIdCode : '—'),
      ('Bank', bankName.isNotEmpty ? bankName : '—'),
      ('Account No.', maskPayslipAccount(accountNumber)),
      ('IFSC Code', ifscCode.isNotEmpty ? ifscCode : '—'),
    ];

    return Wrap(
      key: const Key('payslip-strip'),
      spacing: 20,
      runSpacing: 10,
      children: items
          .map((item) => SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint)),
                    const SizedBox(height: 2),
                    Text(
                      item.$2,
                      style: AppTextStyles.label
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final PayslipModel payslip;
  final String monthLabel;
  const _StatsRow({required this.payslip, this.monthLabel = ''});

  @override
  Widget build(BuildContext context) {
    final lop = payslip.lopDays > 0 ? payslip.lopDays : 0;
    final stats = [
      ('Working Days', payslip.totalWorkingDays.toString()),
      ('Paid Days', payslipNumber(payslip.paidDays)),
      ('Loss of Pay', payslipNumber(lop)),
    ];
    // Web sub-lines.
    final subs = [
      monthLabel,
      'days credited',
      payslip.lopDays > 0 ? '${formatPayslipInr(payslip.lopDeduction)} deducted' : 'no LOP',
    ];
    return Row(
      children: [for (var i = 0; i < stats.length; i++) (stats[i], subs[i])]
          .map((e) => (e.$1.$1, e.$1.$2, e.$2))
          .map((s) => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$2, style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text(
                      s.$1,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      s.$3,
                      style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Earnings / Deductions ─────────────────────────────────────────────────────

class _EarningsSection extends StatelessWidget {
  final PayslipModel payslip;
  const _EarningsSection({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double)>[
      ('Basic Salary', payslip.basic),
      ('House Rent Allowance (HRA)', payslip.hra),
      ('Special Allowance', payslip.specialAllowance),
      ('Bonus', payslip.bonus),
      for (final entry in payslip.otherEarnings.entries)
        (entry.key, double.tryParse(entry.value?.toString() ?? '') ?? 0.0),
    // Web hides only zero amounts.
    ].where((r) => r.$2 != 0).toList();

    return _MoneySection(
      title: 'EARNINGS',
      color: AppColors.success,
      rows: rows,
      totalLabel: 'Gross Earnings',
      total: payslip.grossEarnings,
    );
  }
}

class _DeductionsSection extends StatelessWidget {
  final PayslipModel payslip;
  const _DeductionsSection({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double)>[
      ('Provident Fund (PF)', payslip.pfEmployee),
      ('ESI', payslip.esiEmployee),
      ('Professional Tax (PT)', payslip.ptDeduction),
      ('Labour Welfare Fund', payslip.lwfEmployee),
      for (final entry in payslip.otherDeductions.entries)
        (entry.key, double.tryParse(entry.value?.toString() ?? '') ?? 0.0),
      // Web: LOP last.
      ('Loss of Pay (LOP)', payslip.lopDeduction),
    ].where((r) => r.$2 != 0).toList();

    return _MoneySection(
      title: 'DEDUCTIONS',
      color: AppColors.error,
      rows: rows,
      totalLabel: 'Total Deductions',
      total: payslip.totalDeductions,
    );
  }
}

class _MoneySection extends StatelessWidget {
  final String title;
  final Color color;
  final List<(String, double)> rows;
  final String totalLabel;
  final double total;

  const _MoneySection({
    required this.title,
    required this.color,
    required this.rows,
    required this.totalLabel,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.$1,
                          style: AppTextStyles.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(formatPayslipInr(r.$2),
                          style: AppTextStyles.body),
                    ],
                  ),
                )),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(totalLabel,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                formatPayslipInr(total),
                style: AppTextStyles.label
                    .copyWith(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReimbursementLine extends StatelessWidget {
  final double amount;
  const _ReimbursementLine({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard_outlined, size: 16, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(child: Text('Reimbursements', style: AppTextStyles.label)),
          Text(
            formatPayslipInr(amount),
            style: AppTextStyles.label
                .copyWith(fontWeight: FontWeight.w700, color: AppColors.info),
          ),
        ],
      ),
    );
  }
}

// ── Net pay ────────────────────────────────────────────────────────────────────

class _NetPayBanner extends StatelessWidget {
  final PayslipModel payslip;
  final String subline;
  const _NetPayBanner({required this.payslip, this.subline = ''});

  @override
  Widget build(BuildContext context) {
    final denom = payslip.grossEarnings + payslip.totalDeductions;
    final ratio =
        denom <= 0 ? 0.5 : (payslip.grossEarnings / denom).clamp(0.0, 1.0); // web: 50% when both are 0

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A6E), Color(0xFF0E2447)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Salary Credited',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subline.isNotEmpty)
            Text(subline,
                key: const Key('payslip-net-subline'),
                style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(
            formatPayslipInr(payslip.netPay),
            key: const Key('payslip-net-amount'),
            style: AppTextStyles.h2
                .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          Text('In Hand',
              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          // Web: "Gross ₹X − Ded. ₹Y [+ Reimb. ₹Z]".
          Text(
            'Gross ${formatPayslipInr(payslip.grossEarnings)} − Ded. ${formatPayslipInr(payslip.totalDeductions)}'
            '${payslip.reimbursements > 0 ? ' + Reimb. ${formatPayslipInr(payslip.reimbursements)}' : ''}',
            key: const Key('payslip-net-breakdown'),
            style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

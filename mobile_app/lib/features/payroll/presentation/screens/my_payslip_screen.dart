import 'dart:typed_data';

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
import '../../domain/payslip_layout.dart';
import '../payslip_images.dart';
import '../payslip_pdf.dart';
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
                  Text('My Payslips', style: AppTextStyles.h3.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    // Web my-payslip/page.tsx:233.
                    'View and download your monthly salary statements',
                    style: AppTextStyles.bodySecondary.copyWith(color: Colors.white.withValues(alpha: 0.85)),
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
                      // Web my-payslip/page.tsx:195-198.
                      child: Column(children: [
                        const SectionMessage(icon: Icons.receipt_long_outlined, label: 'No payslips yet'),
                        Text('Your payslips will appear here once payroll is processed for your account.',
                            key: const Key('payslip-empty-desc'),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                      ]),
                    );
                  }
                  final selected = payslips.firstWhere(
                    (p) => p.id == _selectedId,
                    orElse: () => payslips.first,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PayslipEmployeeCard(),
                      const SizedBox(height: 14),
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
    // HO-19: the strip was a fixed 68 × 132 px — two text lines at system
    // font scale 1.5 overflowed it by 8 px. Grow both with the text scale
    // (the month text keeps its ellipsis for anything beyond 1.6×).
    final t = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Web sidebar heading.
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('SELECT MONTH',
            key: const Key('payslip-select-month'),
            style: AppTextStyles.caption.copyWith(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
      ),
      SizedBox(
        height: 84 * t,
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
                width: 132 * t.clamp(1.0, 1.6),
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
                    const SizedBox(height: 2),
                    // Web: the pay date under the month.
                    Text(
                      formatPayslipDate(p.payDate),
                      key: Key('payslip-month-paydate-${p.id}'),
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10, color: isSelected ? Colors.white.withValues(alpha: 0.75) : AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payslipStatusLabel(p.status),
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? Colors.white.withValues(alpha: 0.85) : AppColors.textHint,
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
      ),
    ]);
  }
}

// ── Employee card (web sidebar) ───────────────────────────────────────────────

/// Web my-payslip sidebar: initials avatar, name, designation, employee ID,
/// then Department and Date of Join — all from the employee's own record
/// (GET /employees/me/), "—" while it isn't available.
class _PayslipEmployeeCard extends ConsumerWidget {
  const _PayslipEmployeeCard();

  static String _initials(String name) =>
      name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    const white = Colors.white;
    Widget field(String k, String v, Key key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.toUpperCase(),
                style: AppTextStyles.caption.copyWith(fontSize: 10, letterSpacing: 0.6, color: AppColors.textHint)),
            const SizedBox(height: 2),
            Text(v.isEmpty ? '—' : v, key: key, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
          ]),
        );
    return Container(
      key: const Key('payslip-employee-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: white.withValues(alpha: 0.2),
                border: Border.all(color: white.withValues(alpha: 0.4), width: 2),
              ),
              child: Text(me == null ? '—' : _initials(me.fullName),
                  key: const Key('payslip-emp-initials'),
                  style: AppTextStyles.h4.copyWith(color: white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text(me?.fullName ?? '—',
                key: const Key('payslip-emp-name'),
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(color: white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            // Web `me?.designation ?? "—"`: an empty designation stays empty.
            Text(me?.designation ?? '—',
                key: const Key('payslip-emp-designation'),
                style: AppTextStyles.caption.copyWith(color: white.withValues(alpha: 0.75))),
            const SizedBox(height: 2),
            Text(me?.employeeId ?? '—',
                key: const Key('payslip-emp-id'),
                style: AppTextStyles.caption.copyWith(fontSize: 11, color: white.withValues(alpha: 0.6))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            field('Department', me?.department ?? '', const Key('payslip-emp-department')),
            Divider(height: 1, color: AppColors.border),
            field('Date of Join', (me?.dateOfJoining ?? '').isEmpty ? '' : formatPayslipDate(me!.dateOfJoining!),
                const Key('payslip-emp-doj')),
          ]),
        ),
      ]),
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

    final company = companyAsync.valueOrNull;
    final detail = profileAsync.valueOrNull?.detail;
    final letterhead = PayslipLetterhead.merge(
      name: company?.companyName ?? '',
      cin: company?.cin ?? '',
      addressLine: company?.address ?? '',
      city: company?.city ?? '',
      state: company?.state ?? '',
      pinCode: company?.pinCode ?? '',
      saved: payslip.companyHeader,
    );
    final officialPhone = company?.officialPhone ?? '';
    // Web PayslipDocument: the live company logo (`logo_url`) heads the
    // standard letterhead; the wage slip has none.
    final logoUrl = payslip.isWageSlip ? '' : (company?.logoUrl ?? '');
    final logo = logoUrl.isEmpty ? null : ref.watch(payslipImageProvider(logoUrl)).valueOrNull;

    return SectionCard(
      title: monthLabel,
      icon: Icons.receipt_long_outlined,
      accentColor: AppColors.primary,
      trailing: _StatusChip(status: payslip.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (payslip.isWageSlip)
            // Web WageSlipDocument — the layout the company chose in Payroll
            // Settings; it carries its own letterhead, employee block and
            // totals, so none of the standard sections below apply.
            _WageSlipDocument(
              key: const Key('payslip-wage-slip'),
              payslip: payslip,
              letterhead: letterhead,
            )
          else ...[
            _CompanyLine(companyName: letterhead.name, cin: letterhead.cin, address: letterhead.address, logo: logo),
            const SizedBox(height: 4),
            // Web: "Salary Date: 09 Nov 2026" (fmtDate, en-IN).
            Text('Salary Date: ${formatPayslipDate(payslip.payDate)}',
                key: const Key('payslip-salary-date'),
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
            const SizedBox(height: 14),
            _EmployeeMetaGrid(
              items: standardStrip(
                payslip,
                bankName: detail?.bankName ?? '',
                maskedAccount: maskPayslipAccount(detail?.accountNumber ?? ''),
                ifsc: detail?.ifscCode ?? '',
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            _StatsRow(payslip: payslip, monthLabel: monthLabel),
            const SizedBox(height: 16),
            _EarningsSection(payslip: payslip),
            const SizedBox(height: 12),
            _DeductionsSection(payslip: payslip),
            // Additions / arrears paid on top of gross — shown only then.
            if (additionsPanel(payslip) case final panel?) ...[
              const SizedBox(height: 12),
              _AdditionsPanel(rows: panel.rows, total: panel.total),
            ],
            if (payslip.reimbursements > 0) ...[
              const SizedBox(height: 12),
              _ReimbursementLine(amount: payslip.reimbursements),
            ],
            const SizedBox(height: 16),
            _NetPayBanner(
              payslip: payslip,
              // Web netSubline: "Paid on <date>[ · <bank> ••••1234]".
              subline: 'Paid on ${formatPayslipDate(payslip.payDate)}'
                  '${(detail?.bankName ?? '').isNotEmpty ? ' · ${detail!.bankName} ${maskPayslipAccount(detail.accountNumber)}' : ''}',
            ),
          ],
          const SizedBox(height: 12),
          // HO-28: web's "Print / Save PDF" + "Download PDF" (see payslip_pdf.dart).
          _PayslipPdfActions(
            payslip: payslip,
            pdfContext: PayslipPdfContext(
              monthLabel: monthLabel,
              companyName: letterhead.name,
              companyCin: letterhead.cin,
              companyAddress: letterhead.address,
              bankName: detail?.bankName ?? '',
              accountNumber: detail?.accountNumber ?? '',
              ifscCode: detail?.ifscCode ?? '',
              officialPhone: officialPhone,
            ),
            logoUrl: logoUrl,
          ),
          if (payslip.status == 'sent') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('payslip-acknowledge'),
              onPressed: acknowledging ? null : onAcknowledge,
              icon: acknowledging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              // Web my-payslip/page.tsx:240.
              label: Text(acknowledging ? 'Acknowledging…' : 'Acknowledge'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
          if (!payslip.isWageSlip) ...[
            const SizedBox(height: 14),
            // Web footer.
            Text(
              'This is a computer-generated payslip and does not require a signature.'
              '${officialPhone.isNotEmpty ? ' For queries contact HR at $officialPhone.' : ''}',
              key: const Key('payslip-footer'),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanyLine extends StatelessWidget {
  final String companyName;
  final String cin;
  final String address;

  /// The company logo bytes (null: none, or not available).
  final Uint8List? logo;
  const _CompanyLine({required this.companyName, required this.cin, this.address = '', this.logo});

  @override
  Widget build(BuildContext context) {
    if (companyName.isEmpty && logo == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (logo != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          // Web: maxHeight 48, maxWidth 160, object-fit contain, 8 below.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 48, maxWidth: 160),
            child: Image.memory(logo!,
                key: const Key('payslip-logo'),
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                gaplessPlayback: true),
          ),
        ),
      if (companyName.isNotEmpty)
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
        style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Employee meta ─────────────────────────────────────────────────────────────

class _EmployeeMetaGrid extends StatelessWidget {
  /// Web `strip`: label/value cells (see [standardStrip]).
  final List<(String, String)> items;

  const _EmployeeMetaGrid({required this.items});

  @override
  Widget build(BuildContext context) {
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
                    Text(item.$1, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                    const SizedBox(height: 2),
                    Text(
                      item.$2,
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
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
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
    final rows = [for (final r in standardEarningRows(payslip)) (r.label, r.amount)]; // shared with the PDF

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
    final rows = [for (final r in standardDeductionRows(payslip)) (r.label, r.amount)]; // shared with the PDF

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
                    Text(formatPayslipInr(r.$2), style: AppTextStyles.body),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(totalLabel, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                formatPayslipInr(total),
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Web "Additions" panel: one-time additions / arrears paid on top of the
/// saved gross (shown only then), with their total.
class _AdditionsPanel extends StatelessWidget {
  final List<AmountRow> rows;
  final double total;
  const _AdditionsPanel({required this.rows, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('payslip-additions'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.add_circle_outline, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text('ADDITIONS',
                style: AppTextStyles.caption
                    .copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.success)),
          ),
          Text(formatPayslipInr(total),
              key: const Key('payslip-additions-total'),
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800, color: AppColors.success)),
        ]),
        const SizedBox(height: 6),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(child: Text(r.label, style: AppTextStyles.body)),
              Text(formatPayslipInr(r.amount), style: AppTextStyles.body),
            ]),
          ),
      ]),
    );
  }
}

/// Web WageSlipDocument: letterhead, employee block, SALARY HEAD / ACTUAL /
/// EARNING / DEDUCTION grid, totals and signatures — the company's wage-slip
/// format. Saved values only; Net Salary is the stored net pay.
class _WageSlipDocument extends ConsumerWidget {
  final PayslipModel payslip;
  final PayslipLetterhead letterhead;
  const _WageSlipDocument({super.key, required this.payslip, required this.letterhead});

  static const _line = BorderSide(color: Colors.black87, width: 0.8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp =
        (payslip.stampUrl ?? '').isEmpty ? null : ref.watch(payslipImageProvider(payslip.stampUrl!)).valueOrNull;
    final m = wageSlipModel(payslip);
    final info = wageSlipInfo(payslip);
    final cell = AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.black87);
    final bold = cell.copyWith(fontWeight: FontWeight.w700);
    final rows = m.earnings.length > m.deductions.length ? m.earnings.length : m.deductions.length;
    final infoRows = info.left.length > info.right.length ? info.left.length : info.right.length;

    Widget pad(String t, {TextStyle? style, TextAlign align = TextAlign.left, Color? fill}) => Container(
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Text(t, style: style ?? cell, textAlign: align),
        );
    Widget num(String t, {TextStyle? style}) => pad(t, style: style, align: TextAlign.right);

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border.fromBorderSide(_line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: const BoxDecoration(border: Border(bottom: _line)),
          child: Column(children: [
            if (payslip.principalEmployerName.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Text(payslip.principalEmployerName,
                    key: const Key('wageslip-principal'), style: bold.copyWith(fontSize: 10.5)),
              ),
            Text(letterhead.name.isEmpty ? '—' : letterhead.name,
                key: const Key('wageslip-company'),
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC00000),
                    decoration: TextDecoration.underline)),
            if (letterhead.address.isNotEmpty)
              Text(letterhead.address, textAlign: TextAlign.center, style: cell.copyWith(fontSize: 10.5)),
            const SizedBox(height: 6),
            Text(wageSlipPeriodLabel(payslip.cycleStart, payslip.cycleEnd),
                key: const Key('wageslip-title'), textAlign: TextAlign.center, style: bold),
          ]),
        ),
        Table(
          key: const Key('wageslip-info'),
          border: const TableBorder.symmetric(inside: _line),
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(2.6),
            2: FlexColumnWidth(2.2),
            3: FlexColumnWidth(1.8)
          },
          children: [
            for (var i = 0; i < infoRows; i++)
              TableRow(children: [
                pad(i < info.left.length ? info.left[i].$1 : '', style: bold, fill: const Color(0xFFFAFAFA)),
                pad(i < info.left.length ? info.left[i].$2 : ''),
                pad(i < info.right.length ? info.right[i].$1 : '', style: bold, fill: const Color(0xFFFAFAFA)),
                num(i < info.right.length ? info.right[i].$2 : ''),
              ]),
          ],
        ),
        Table(
          key: const Key('wageslip-grid'),
          border: const TableBorder(top: _line, bottom: _line, horizontalInside: _line, verticalInside: _line),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2.4),
            4: FlexColumnWidth(2)
          },
          children: [
            TableRow(children: [
              for (final h in const ['SALARY HEAD', 'ACTUAL', 'EARNING', 'DEDUCTION', ''])
                pad(h, style: bold, align: TextAlign.center, fill: const Color(0xFFB4C6E7)),
            ]),
            for (var i = 0; i < rows; i++)
              TableRow(children: [
                pad(i < m.earnings.length ? m.earnings[i].label : ''),
                num(i < m.earnings.length && m.earnings[i].actual != null
                    ? formatWageSlipAmount(m.earnings[i].actual!)
                    : ''),
                num(i < m.earnings.length ? formatWageSlipAmount(m.earnings[i].earned) : ''),
                pad(i < m.deductions.length ? m.deductions[i].label : ''),
                num(i < m.deductions.length ? formatWageSlipAmount(m.deductions[i].amount) : ''),
              ]),
            TableRow(children: [
              pad('TOTAL GROSS', style: bold),
              num(formatWageSlipAmount(m.totals.actual), style: bold),
              num(formatWageSlipAmount(m.totals.earned), style: bold),
              pad('TOTAL DEDUCTION', style: bold),
              num(formatWageSlipAmount(m.totals.deductions), style: bold),
            ]),
            TableRow(children: [
              pad('NET SALARY PAY', style: bold),
              Container(),
              Container(
                key: const Key('wageslip-net'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                alignment: Alignment.centerRight,
                child: Text(formatWageSlipAmount(m.totals.net), style: bold),
              ),
              Container(),
              Container(),
            ]),
          ],
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Employee Signature', style: cell),
                Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  if (stamp != null)
                    // Web .ws-stamp: max 80 high, 140 wide, contain.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 80, maxWidth: 140),
                      child: Image.memory(stamp, key: const Key('wageslip-stamp'), fit: BoxFit.contain),
                    ),
                  Text('Authorized Signature', style: cell),
                ]),
              ]),
        ),
      ]),
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
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.info),
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
    final addition = additionsPanel(payslip);
    final denom = payslip.grossEarnings + payslip.totalDeductions;
    final ratio = denom <= 0 ? 0.5 : (payslip.grossEarnings / denom).clamp(0.0, 1.0); // web: 50% when both are 0

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
            style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          Text('In Hand', style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.75))),
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
            '${addition == null ? '' : ' + Add. ${formatPayslipInr(addition.total)}'}'
            '${payslip.reimbursements > 0 ? ' + Reimb. ${formatPayslipInr(payslip.reimbursements)}' : ''}',
            key: const Key('payslip-net-breakdown'),
            style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

// ── PDF actions (HO-28) ──────────────────────────────────────────────────────

/// "Print / Save PDF" and "Share PDF" build the payslip shown above into a
/// PDF on the device (Android print dialog offers "Save as PDF"); "Download
/// PDF" opens the server's stored file — web's same button — and, like web,
/// is disabled ("PDF not yet available for this payslip") when the server has
/// none (today: always). Busy while building; an error message never carries
/// a URL or payslip data.
class _PayslipPdfActions extends ConsumerStatefulWidget {
  final PayslipModel payslip;
  final PayslipPdfContext pdfContext;

  /// The company logo link (standard layout only; empty = none).
  final String logoUrl;
  const _PayslipPdfActions({required this.payslip, required this.pdfContext, this.logoUrl = ''});

  @override
  ConsumerState<_PayslipPdfActions> createState() => _PayslipPdfActionsState();
}

class _PayslipPdfActionsState extends ConsumerState<_PayslipPdfActions> {
  bool _busy = false;

  Future<Uint8List> _bytes() async {
    final fonts = await ref.read(payslipPdfFontsProvider)();
    // Embed the actual image bytes (logo / stamp), fetched without the app's
    // login and held in memory only; a missing image is simply left out.
    final stampUrl = widget.payslip.stampUrl ?? '';
    final logo = widget.logoUrl.isEmpty ? null : await ref.read(payslipImageProvider(widget.logoUrl).future);
    final stamp = stampUrl.isEmpty ? null : await ref.read(payslipImageProvider(stampUrl).future);
    return buildPayslipPdf(widget.payslip, widget.pdfContext.withImages(logo: logo, stamp: stamp), fonts).save();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Couldn't prepare the payslip PDF. Please try again."),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final out = ref.read(payslipPdfOutputProvider);
    final name = payslipPdfFileName(widget.payslip);
    final stored = widget.payslip.payslipPdfUrl;
    final hasStored = stored != null && stored.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('payslip-print-pdf'),
              onPressed: _busy ? null : () => _run(() async => out.print((_) => _bytes(), name)),
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print / Save PDF'),
            ),
            OutlinedButton.icon(
              key: const Key('payslip-share-pdf'),
              onPressed: _busy ? null : () => _run(() async => out.share(await _bytes(), name)),
              icon: const Icon(Icons.ios_share_outlined, size: 18),
              label: const Text('Share PDF'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: hasStored ? 'Download the PDF issued for this payslip' : 'PDF not yet available for this payslip',
          child: OutlinedButton.icon(
            key: const Key('payslip-download-pdf'),
            onPressed: hasStored ? () => launchUrl(Uri.parse(stored), mode: LaunchMode.externalApplication) : null,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(hasStored ? 'Download PDF' : 'Download PDF (not yet available)'),
          ),
        ),
      ],
    );
  }
}

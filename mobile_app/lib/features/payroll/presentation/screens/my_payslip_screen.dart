import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class _Month {
  final String label;       // "June 2026"
  final String salaryDate;  // "30 Jun 2026"
  const _Month(this.label, this.salaryDate);
}

const _kMonths = <_Month>[
  _Month('June 2026',  '30 Jun 2026'),
  _Month('May 2026',   '30 May 2026'),
  _Month('April 2026', '30 Apr 2026'),
  _Month('March 2026', '31 Mar 2026'),
];

// All months are paid in this static demo

// ─── Earnings & deductions for June 2026 ─────────────────────────────────────

const _kEarnings = <_LineItem>[
  _LineItem('Basic Salary',                '₹45,000'),
  _LineItem('House Rent Allowance (HRA)',  '₹18,000'),
  _LineItem('Dearness Allowance (DA)',     '₹4,500'),
  _LineItem('Special Allowance',           '₹6,000'),
  _LineItem('Bonus',                       '₹5,000'),
  _LineItem('Overtime',                    '₹2,000'),
];

const _kDeductions = <_LineItem>[
  _LineItem('Provident Fund (PF)',  '₹5,400'),
  _LineItem('Professional Tax (PT)', '₹200'),
  _LineItem('TDS',                  '₹3,500'),
  _LineItem('Loan EMI',             '₹5,000'),
];

class _LineItem {
  final String label;
  final String amount;
  const _LineItem(this.label, this.amount);
}

class _Reimb {
  final String label;
  final String amount;
  const _Reimb(this.label, this.amount);
}

const _kReimb = <_Reimb>[
  _Reimb('TRAVEL',   '₹2,000'),
  _Reimb('MEDICAL',  '₹500'),
  _Reimb('INTERNET', '₹500'),
  _Reimb('FOOD',     '₹1,000'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyPayslipScreen extends StatefulWidget {
  const MyPayslipScreen({super.key});

  @override
  State<MyPayslipScreen> createState() => _MyPayslipScreenState();
}

class _MyPayslipScreenState extends State<MyPayslipScreen> {
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page header ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Payslips', style: AppTextStyles.h2),
                    const SizedBox(height: 2),
                    Text(
                      'View and download your monthly salary statements',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.email_outlined, size: 14),
                label: const Text('Email'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Employee info card ───────────────────────────────────
                _EmployeeCard(),
                const SizedBox(height: 12),

                // ── Month selector ───────────────────────────────────────
                _MonthSelector(
                  selected: _selectedMonth,
                  onSelect: (i) => setState(() => _selectedMonth = i),
                ),
                const SizedBox(height: 16),

                // ── Payslip document ─────────────────────────────────────
                _PayslipDocument(month: _kMonths[_selectedMonth]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Employee card ────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Avatar + name row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B3A6B), Color(0xFF2A5298)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.2),
                  child: const Text(
                    'AM',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arjun Mehta',
                          style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text('Senior Software Developer',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text('EMP-0042',
                            style: AppTextStyles.label.copyWith(
                                color: Colors.white70, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Detail fields
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                    child: _EmpField('DEPARTMENT', 'Engineering')),
                Expanded(
                    child: _EmpField('DATE OF JOIN', '14 Mar 2022')),
                Expanded(
                    child: _EmpField('PAN', 'ABCPM1234X')),
                Expanded(
                    child: _EmpField('UAN', '100987654321')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmpField extends StatelessWidget {
  final String label;
  final String value;
  const _EmpField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ─── Month selector ───────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _MonthSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT MONTH',
            style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kMonths.asMap().entries.map((e) {
              final isSelected = e.key == selected;
              return GestureDetector(
                onTap: () => onSelect(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFE5E7EB)),
                    boxShadow: isSelected ? AppColors.cardShadow : null,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value.label,
                              style: AppTextStyles.body.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(e.value.salaryDate,
                              style: AppTextStyles.label.copyWith(
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Paid',
                            style: AppTextStyles.label.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Payslip document ─────────────────────────────────────────────────────────

class _PayslipDocument extends StatelessWidget {
  final _Month month;
  const _PayslipDocument({required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Company header ─────────────────────────────────────────────
          _CompanyHeader(month: month),

          // ── Employee meta ──────────────────────────────────────────────
          _EmployeeMeta(),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Stats row ─────────────────────────────────────────────────
          _StatsRow(month: month),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Earnings & Deductions ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Earnings
                _SectionHeader(
                  label: 'EARNINGS',
                  color: const Color(0xFF111827),
                  showBar: true,
                  barColor: AppColors.primary,
                ),
                const SizedBox(height: 10),
                ..._kEarnings.map((item) => _EarningsRow(item: item)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gross Earnings',
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text('₹80,500',
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.primary)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Deductions
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        label: 'DEDUCTIONS',
                        color: const Color(0xFFEF4444),
                        showBar: true,
                        barColor: const Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 10),
                      ..._kDeductions.map((item) =>
                          _DeductionRow(item: item)),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFFFCA5A5), height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Deductions',
                              style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: const Color(0xFFEF4444))),
                          Text('₹14,100',
                              style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: const Color(0xFFEF4444))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Reimbursements ─────────────────────────────────────────────
          _ReimbursementsSection(),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Net salary ─────────────────────────────────────────────────
          _NetSalarySection(),

          // ── Footer ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Text(
              'This is a computer-generated payslip and does not require a signature. '
              'For queries, contact HR at hr@royalstaffing.in',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Company header ───────────────────────────────────────────────────────────

class _CompanyHeader extends StatelessWidget {
  final _Month month;
  const _CompanyHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B3A6B), Color(0xFF2A5298)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Royal Staffing Services LLP',
                    style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  '4th Floor, Tech Park, Whitefield,\nBengaluru — 560066',
                  style: AppTextStyles.label.copyWith(
                      color: Colors.white70, fontSize: 10, height: 1.5),
                ),
                const SizedBox(height: 3),
                Text(
                  'CIN: U74999KA2018PTC099876',
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white60, fontSize: 9),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text('PAYSLIP',
                    style: AppTextStyles.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 2)),
              ),
              const SizedBox(height: 6),
              Text(month.label,
                  style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text('Salary Date: ${month.salaryDate}',
                  style: AppTextStyles.label
                      .copyWith(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Employee meta row ────────────────────────────────────────────────────────

class _EmployeeMeta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _MetaField('EMPLOYEE ID', 'EMP-0042')),
          Expanded(child: _MetaField('BANK', 'HDFC Bank')),
          Expanded(child: _MetaField('ACCOUNT NO.', 'XXXX4521')),
          Expanded(child: _MetaField('IFSC CODE', 'HDFC0001234')),
        ],
      ),
    );
  }
}

class _MetaField extends StatelessWidget {
  final String label;
  final String value;
  const _MetaField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.body.copyWith(
                fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final _Month month;
  const _StatsRow({required this.month});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          _StatBlock(
            value: '26',
            label: 'Working Days',
            sub: 'in ${month.label}',
          ),
          const VerticalDivider(
              color: Color(0xFFE5E7EB), width: 1, thickness: 1),
          _StatBlock(
            value: '26',
            label: 'Paid Days',
            sub: 'days credited',
          ),
          const VerticalDivider(
              color: Color(0xFFE5E7EB), width: 1, thickness: 1),
          _StatBlock(
            value: '0',
            label: 'Loss of Pay',
            sub: 'no LOP',
            valueColor: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final String sub;
  final Color? valueColor;
  const _StatBlock(
      {required this.value,
      required this.label,
      required this.sub,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: AppTextStyles.h2.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 28)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary, fontSize: 11)),
            Text(sub,
                style: AppTextStyles.label.copyWith(
                    color: AppColors.textHint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final bool showBar;
  final Color barColor;
  const _SectionHeader({
    required this.label,
    required this.color,
    this.showBar = false,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBar) ...[
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 7),
        ],
        Text(label,
            style: AppTextStyles.label.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ],
    );
  }
}

// ─── Earnings row ─────────────────────────────────────────────────────────────

class _EarningsRow extends StatelessWidget {
  final _LineItem item;
  const _EarningsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.label,
              style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary, fontSize: 13)),
          Text(item.amount,
              style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Deduction row ────────────────────────────────────────────────────────────

class _DeductionRow extends StatelessWidget {
  final _LineItem item;
  const _DeductionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.label,
              style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary, fontSize: 13)),
          Text(item.amount,
              style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: const Color(0xFFEF4444))),
        ],
      ),
    );
  }
}

// ─── Reimbursements section ───────────────────────────────────────────────────

class _ReimbursementsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('REIMBURSEMENTS',
                  style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.6)),
              const Spacer(),
              Text('₹4,000',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _kReimb.map((r) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Column(
                    children: [
                      Text(r.label,
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 4),
                      Text(r.amount,
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Net salary section ───────────────────────────────────────────────────────

class _NetSalarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Salary Credited',
              style: AppTextStyles.h4
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 6),

          // Formula row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      _FormulaChip('Gross ₹80,500',
                          const Color(0xFFEFF6FF), AppColors.primary),
                      const Text('−',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444))),
                      _FormulaChip('Ded. ₹14,100',
                          const Color(0xFFFEF2F2),
                          const Color(0xFFEF4444)),
                      const Text('+',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A))),
                      _FormulaChip('Reimb. ₹4,000',
                          const Color(0xFFF0FDF4),
                          const Color(0xFF16A34A)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('In Hand',
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Net amount bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B3A6B), Color(0xFF2A5298)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net Salary',
                        style: AppTextStyles.label.copyWith(
                            color: Colors.white70, fontSize: 11)),
                    Text('June 2026',
                        style: AppTextStyles.label.copyWith(
                            color: Colors.white60, fontSize: 10)),
                  ],
                ),
                Text('₹70,400',
                    style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24)),
              ],
            ),
          ),

          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: 0.874,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹0',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textHint, fontSize: 10)),
              Text('₹80,500 Gross',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textHint, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color color;
  const _FormulaChip(this.label, this.bg, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: AppTextStyles.label
              .copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

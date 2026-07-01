import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ─── Static employee data shared across steps ──────────────────────────────────

class _Emp {
  final String initials;
  final Color avatarColor;
  final String name;
  final String empCode;
  final String department;
  const _Emp(this.initials, this.avatarColor, this.name, this.empCode,
      this.department);
}

const _kEmps = <_Emp>[
  _Emp('AM', Color(0xFF6C5CE7), 'Arjun Mehta', 'EMP001', 'Engineering'),
  _Emp('PS', Color(0xFF6C5CE7), 'Priya Sharma', 'EMP002', 'HR'),
  _Emp('RS', Color(0xFF0E7C86), 'Rahul Singh', 'EMP003', 'Sales'),
  _Emp('MI', Color(0xFF6C5CE7), 'Meena Iyer', 'EMP004', 'Finance'),
  _Emp('SK', Color(0xFF0E7C86), 'Suresh Kumar', 'EMP005', 'Operations'),
];

// Step titles and icons
const _kStepLabels = [
  'Period Setup',
  'Earn. & Deduct.',
  'Reimb. & Bonuses',
  'Calculation',
  'Validation',
  'Approval',
  'Payslips',
  'Bank Transfer',
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class RunPayrollScreen extends StatefulWidget {
  const RunPayrollScreen({super.key});

  @override
  State<RunPayrollScreen> createState() => _RunPayrollScreenState();
}

class _RunPayrollScreenState extends State<RunPayrollScreen> {
  int _step = 0;

  // Step 4: Calculation
  bool _calculated = false;

  // Step 5: Validation — 3 issues, each can be fixed/ignored
  final _issueStates = <String>['none', 'none', 'none'];

  // Step 6: Approval
  bool _approvalComplete = false;
  final _approvalComment = TextEditingController(
      text: 'All calculations verified. Ready for disbursement.');

  // Step 7: Payslips
  bool _payslipsGenerated = false;

  bool get _validationClear =>
      _issueStates.every((s) => s == 'fixed' || s == 'ignored');

  @override
  void dispose() {
    _approvalComment.dispose();
    super.dispose();
  }

  void _next() {
    // Validation: don't advance if issues remain
    if (_step == 4 && !_validationClear) return;
    if (_step == 7) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Run Payroll — June 2026', style: AppTextStyles.h4),
            Text('Step ${_step + 1} of 8 · ${_kStepLabels[_step]}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: _StepperBar(current: _step),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildStep(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return const _Step1PeriodSetup();
      case 1:
        return const _Step2EarnDeduct();
      case 2:
        return const _Step3ReimbBonuses();
      case 3:
        return _Step4Calculation(
          calculated: _calculated,
          onCalculate: () => setState(() => _calculated = true),
        );
      case 4:
        return _Step5Validation(
          issueStates: _issueStates,
          onStateChange: (i, s) => setState(() => _issueStates[i] = s),
        );
      case 5:
        return _Step6Approval(
          approvalComplete: _approvalComplete,
          commentController: _approvalComment,
          onApprove: () => setState(() => _approvalComplete = true),
        );
      case 6:
        return _Step7Payslips(
          generated: _payslipsGenerated,
          onGenerate: () => setState(() => _payslipsGenerated = true),
        );
      case 7:
        return const _Step8BankTransfer();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFooter() {
    final continueLabel = _step == 7 ? 'Finish Payroll' : 'Continue';
    final continueEnabled = _step != 4 || _validationClear;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Back'),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: continueEnabled ? _next : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: _step == 7
                    ? AppColors.success
                    : continueEnabled
                        ? AppColors.primary
                        : Colors.grey.shade300,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(continueLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stepper progress bar ─────────────────────────────────────────────────────

class _StepperBar extends StatelessWidget {
  final int current;
  const _StepperBar({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_kStepLabels.length * 2 - 1, (i) {
            if (i.isOdd) {
              // connector line
              final stepIdx = i ~/ 2;
              final done = stepIdx < current;
              return Container(
                width: 18,
                height: 2,
                color: done ? AppColors.success : const Color(0xFFD1D5DB),
              );
            }
            final idx = i ~/ 2;
            final done = idx < current;
            final active = idx == current;
            return _StepCircle(
                index: idx, done: done, active: active, label: _kStepLabels[idx]);
          }),
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int index;
  final bool done;
  final bool active;
  final String label;
  const _StepCircle(
      {required this.index,
      required this.done,
      required this.active,
      required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Widget inner;
    if (done) {
      bg = AppColors.success;
      inner = const Icon(Icons.check, color: Colors.white, size: 12);
    } else if (active) {
      bg = AppColors.primary;
      inner = Text('${index + 1}',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700));
    } else {
      bg = const Color(0xFFD1D5DB);
      inner = Text('${index + 1}',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: inner,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: active
                ? AppColors.primary
                : done
                    ? AppColors.success
                    : AppColors.textSecondary,
            fontWeight: active || done ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _card({required Widget child, EdgeInsets? padding}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: child,
  );
}

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title,
        style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary)),
  );
}

Widget _labeledDropdown(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: AppTextStyles.label
              .copyWith(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(value,
                    style: AppTextStyles.body.copyWith(fontSize: 13))),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    ],
  );
}

Widget _tableHeader(List<String> cols, List<double> flexes) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: List.generate(cols.length, (i) {
        return Expanded(
          flex: (flexes[i] * 10).round(),
          child: Text(cols[i],
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        );
      }),
    ),
  );
}

Widget _tableRow(List<Widget> cells, List<double> flexes,
    {bool isLast = false, bool isTotal = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isTotal ? const Color(0xFFF0F4FF) : Colors.white,
      border: Border(
          bottom: BorderSide(
              color: isLast ? Colors.transparent : const Color(0xFFF3F4F6))),
    ),
    child: Row(
      children: List.generate(cells.length, (i) {
        return Expanded(
          flex: (flexes[i] * 10).round(),
          child: cells[i],
        );
      }),
    ),
  );
}

Widget _empAvatar(_Emp e) {
  return CircleAvatar(
    radius: 14,
    backgroundColor: e.avatarColor.withOpacity(0.15),
    child: Text(e.initials,
        style: TextStyle(
            color: e.avatarColor, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ─── Step 1: Period Setup ─────────────────────────────────────────────────────

class _Step1PeriodSetup extends StatelessWidget {
  const _Step1PeriodSetup();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Payroll Period Configuration'),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _labeledDropdown('Payroll Month', 'June')),
                const SizedBox(width: 12),
                Expanded(child: _labeledDropdown('Year', '2026')),
              ]),
              const SizedBox(height: 12),
              _labeledDropdown('Branch', 'All Branches'),
              const SizedBox(height: 12),
              _labeledDropdown('Department', 'All Departments'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _labeledDropdown('Employee Type', 'All Employees')),
                const SizedBox(width: 12),
                Expanded(
                    child: _labeledDropdown('Payroll Type', 'Monthly')),
              ]),
              const SizedBox(height: 12),
              _labeledDropdown('Salary Date', '30 June 2026'),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('248 employees will be included in this payroll run',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        '246 active · 2 on notice period · 0 separated this month',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Earnings & Deductions ───────────────────────────────────────────

class _Step2EarnDeduct extends StatelessWidget {
  const _Step2EarnDeduct();

  @override
  Widget build(BuildContext context) {
    const earnCols = ['Employee', 'Basic', 'HRA', 'DA', 'Sp. Allow', 'OT', 'Gross'];
    const earnFlex = [2.0, 1.2, 1.0, 1.0, 1.2, 1.0, 1.2];

    const deductCols = ['Employee', 'PF', 'ESI', 'PT', 'TDS', 'Loan', 'Adv.', 'LOP', 'Total'];
    const deductFlex = [2.0, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 1.0];

    const earningsData = [
      ['Arjun Mehta', '45,000', '18,000', '4,500', '8,000', '5,000', '80,500'],
      ['Priya Sharma', '35,000', '14,000', '3,500', '2,000', '2,000', '56,500'],
      ['Rahul Singh', '50,000', '20,000', '5,000', '12,000', '7,000', '94,000'],
      ['Meena Iyer', '40,000', '16,000', '4,000', '5,000', '0', '65,000'],
      ['Suresh Kumar', '30,000', '12,000', '3,000', '3,000', '1,500', '49,500'],
    ];
    const earningsTotals = ['Total', '2,00,000', '80,000', '20,000', '30,000', '15,500', '3,45,500'];

    const deductData = [
      ['Arjun Mehta', '5,400', '0', '200', '6,000', '2,000', '500', '315', '14,415'],
      ['Priya Sharma', '4,200', '0', '200', '3,500', '0', '1,000', '412', '9,312'],
      ['Rahul Singh', '6,000', '0', '200', '4,800', '0', '500', '700', '12,200'],
      ['Meena Iyer', '4,800', '0', '200', '8,000', '2,500', '0', '280', '15,780'],
      ['Suresh Kumar', '3,600', '0', '200', '4,000', '500', '0', '210', '9,510'],
    ];
    const deductTotals = ['Total', '24,000', '0', '1,000', '26,300', '5,000', '2,000', '1,917', '61,217'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Earnings
        _card(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Text('Earnings Review', style: AppTextStyles.h4),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('₹3,45,500 Total',
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.success, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 620,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _tableHeader(earnCols, earnFlex),
                      ),
                      ...earningsData.asMap().entries.map((e) => _tableRow(
                            e.value
                                .asMap()
                                .entries
                                .map((c) => Text(
                                    c.key == 0 ? c.value : '₹${c.value}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: c.key == 0
                                            ? FontWeight.w600
                                            : FontWeight.w400)))
                                .toList(),
                            earnFlex,
                            isLast: e.key == earningsData.length - 1,
                          )),
                      _tableRow(
                        earningsTotals
                            .asMap()
                            .entries
                            .map((c) => Text(
                                c.key == 0
                                    ? c.value
                                    : '₹${c.value}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)))
                            .toList(),
                        earnFlex,
                        isTotal: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Deductions
        _card(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.trending_down,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Text('Deductions Review', style: AppTextStyles.h4),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('₹61,217 Total',
                          style: AppTextStyles.label.copyWith(
                              color: const Color(0xFFEF4444), fontSize: 10)),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 700,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _tableHeader(deductCols, deductFlex),
                      ),
                      ...deductData.asMap().entries.map((e) => _tableRow(
                            e.value
                                .asMap()
                                .entries
                                .map((c) => Text(
                                    c.key == 0 ? c.value : '₹${c.value}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: c.key == 0
                                            ? FontWeight.w600
                                            : FontWeight.w400)))
                                .toList(),
                            deductFlex,
                            isLast: e.key == deductData.length - 1,
                          )),
                      _tableRow(
                        deductTotals
                            .asMap()
                            .entries
                            .map((c) => Text(
                                c.key == 0 ? c.value : '₹${c.value}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFEF4444))))
                            .toList(),
                        deductFlex,
                        isTotal: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 3: Reimbursements & Bonuses ────────────────────────────────────────

class _Step3ReimbBonuses extends StatelessWidget {
  const _Step3ReimbBonuses();

  @override
  Widget build(BuildContext context) {
    const reimbCols = ['Employee', 'Travel', 'Fuel', 'Medical', 'Internet', 'Food', 'Total'];
    const reimbFlex = [2.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.2];

    const bonusCols = ['Employee', 'Bonus', 'Incentive', 'Festival', 'Perf.', 'Total'];
    const bonusFlex = [2.0, 1.0, 1.0, 1.0, 1.0, 1.2];

    const reimbData = [
      ['Arjun Mehta', '2,000', '1,500', '500', '500', '0', '4,500'],
      ['Priya Sharma', '1,000', '0', '500', '500', '500', '2,500'],
      ['Rahul Singh', '3,000', '2,000', '0', '0', '500', '5,500'],
      ['Meena Iyer', '1,500', '0', '500', '500', '0', '2,500'],
      ['Suresh Kumar', '500', '500', '500', '0', '500', '2,000'],
    ];
    const reimbTotals = ['Total', '8,000', '4,000', '2,000', '1,500', '1,500', '17,000'];

    const bonusData = [
      ['Arjun Mehta', '5,000', '3,000', '0', '2,000', '10,000'],
      ['Priya Sharma', '0', '2,000', '1,000', '0', '3,000'],
      ['Rahul Singh', '5,000', '5,000', '0', '3,000', '13,000'],
      ['Meena Iyer', '0', '0', '1,000', '2,000', '3,000'],
      ['Suresh Kumar', '0', '1,000', '1,000', '0', '2,000'],
    ];
    const bonusTotals = ['Total', '10,000', '11,000', '3,000', '7,000', '31,000'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reimbursements
        _card(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        color: Color(0xFF3B82F6), size: 18),
                    const SizedBox(width: 8),
                    Text('Reimbursements', style: AppTextStyles.h4),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('₹17,000 Total',
                          style: AppTextStyles.label.copyWith(
                              color: const Color(0xFF3B82F6), fontSize: 10)),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 580,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _tableHeader(reimbCols, reimbFlex),
                      ),
                      ...reimbData.asMap().entries.map((e) => _tableRow(
                            e.value
                                .asMap()
                                .entries
                                .map((c) => Text(
                                    c.key == 0 ? c.value : '₹${c.value}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: c.key == 0
                                            ? FontWeight.w600
                                            : FontWeight.w400)))
                                .toList(),
                            reimbFlex,
                            isLast: e.key == reimbData.length - 1,
                          )),
                      _tableRow(
                        reimbTotals
                            .asMap()
                            .entries
                            .map((c) => Text(
                                c.key == 0 ? c.value : '₹${c.value}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3B82F6))))
                            .toList(),
                        reimbFlex,
                        isTotal: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Bonuses
        _card(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_outlined,
                        color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Text('Bonuses & Incentives', style: AppTextStyles.h4),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('₹31,000 Total',
                          style: AppTextStyles.label.copyWith(
                              color: const Color(0xFFF59E0B), fontSize: 10)),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 520,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _tableHeader(bonusCols, bonusFlex),
                      ),
                      ...bonusData.asMap().entries.map((e) => _tableRow(
                            e.value
                                .asMap()
                                .entries
                                .map((c) => Text(
                                    c.key == 0 ? c.value : '₹${c.value}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: c.key == 0
                                            ? FontWeight.w600
                                            : FontWeight.w400)))
                                .toList(),
                            bonusFlex,
                            isLast: e.key == bonusData.length - 1,
                          )),
                      _tableRow(
                        bonusTotals
                            .asMap()
                            .entries
                            .map((c) => Text(
                                c.key == 0 ? c.value : '₹${c.value}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF59E0B))))
                            .toList(),
                        bonusFlex,
                        isTotal: true,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 4: Calculation ──────────────────────────────────────────────────────

class _Step4Calculation extends StatelessWidget {
  final bool calculated;
  final VoidCallback onCalculate;
  const _Step4Calculation(
      {required this.calculated, required this.onCalculate});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard4('Total Gross', '₹3,93,500', Icons.payments_outlined,
          const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      _StatCard4('Total Deductions', '₹61,217', Icons.remove_circle_outline,
          const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      _StatCard4('Net Payroll', '₹3,32,283', Icons.account_balance_wallet_outlined,
          AppColors.success, const Color(0xFFF0FDF4)),
      _StatCard4('Employees', '5', Icons.people_outline, AppColors.primary,
          const Color(0xFFF0F4FF)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.0,
          children: cards,
        ),
        const SizedBox(height: 16),

        if (!calculated) ...[
          _card(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(Icons.calculate_outlined,
                      color: Color(0xFF3B82F6), size: 32),
                ),
                const SizedBox(height: 12),
                Text('Ready to Calculate',
                    style: AppTextStyles.h4
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  'All configurations are set. Click the button below\nto compute final salaries for all 5 employees.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onCalculate,
                    icon:
                        const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Calculate All Salaries'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Calculation complete! All 5 employee salaries computed successfully.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.success)),
                ),
              ],
            ),
          ),
          _card(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: _tableHeader(
                      ['Employee', 'Dept', 'Gross', 'Deductions', 'Net Pay'],
                      [2.0, 1.5, 1.5, 1.5, 1.5]),
                ),
                ..._kEmps.asMap().entries.map((e) {
                  const grossList = [
                    '₹85,000', '₹59,000', '₹99,500', '₹67,500', '₹51,500'
                  ];
                  const dedList = [
                    '₹14,415', '₹9,312', '₹12,200', '₹15,780', '₹9,510'
                  ];
                  const netList = [
                    '₹70,585', '₹49,688', '₹87,300', '₹51,720', '₹41,990'
                  ];
                  return _tableRow([
                    Row(children: [
                      _empAvatar(e.value),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(e.value.name,
                              style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                    Text(e.value.department,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(grossList[e.key],
                        style: AppTextStyles.bodySmall
                            .copyWith(color: const Color(0xFF3B82F6))),
                    Text(dedList[e.key],
                        style: AppTextStyles.bodySmall
                            .copyWith(color: const Color(0xFFEF4444))),
                    Text(netList[e.key],
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ], [2.0, 1.5, 1.5, 1.5, 1.5],
                      isLast: e.key == _kEmps.length - 1);
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard4 extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  const _StatCard4(this.title, this.value, this.icon, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: AppTextStyles.h4
                        .copyWith(color: AppColors.textPrimary, fontSize: 16)),
                Text(title,
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 5: Validation ───────────────────────────────────────────────────────

class _Step5Validation extends StatelessWidget {
  final List<String> issueStates;
  final void Function(int, String) onStateChange;

  const _Step5Validation(
      {required this.issueStates, required this.onStateChange});

  @override
  Widget build(BuildContext context) {
    final errCount = issueStates.where((s) => s == 'none').length;
    final allClear = errCount == 0;

    final issues = [
      _ValidationIssue(
        severity: 'critical',
        title: 'Missing Bank Account — Arjun Mehta',
        description: 'Bank account details are missing. Salary cannot be disbursed.',
        index: 0,
      ),
      _ValidationIssue(
        severity: 'warning',
        title: 'Overtime not approved — Rahul Singh',
        description: 'OT hours logged but not yet approved by manager.',
        index: 1,
      ),
      _ValidationIssue(
        severity: 'warning',
        title: 'TDS mismatch — Meena Iyer',
        description: 'Computed TDS differs from declared investment savings.',
        index: 2,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: allClear
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: allClear
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFCA5A5)),
          ),
          child: Row(
            children: [
              Icon(
                allClear
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: allClear ? AppColors.success : const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allClear
                      ? 'All checks passed! Payroll is ready for approval.'
                      : '$errCount issue${errCount > 1 ? 's' : ''} found — resolve all critical issues before proceeding.',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: allClear
                          ? AppColors.success
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Issues list
        ...issues.map((issue) {
          final state = issueStates[issue.index];
          return _IssueCard(
            issue: issue,
            state: state,
            onFix: () => onStateChange(issue.index, 'fixed'),
            onIgnore: () => onStateChange(issue.index, 'ignored'),
          );
        }),
      ],
    );
  }
}

class _ValidationIssue {
  final String severity;
  final String title;
  final String description;
  final int index;
  const _ValidationIssue(
      {required this.severity,
      required this.title,
      required this.description,
      required this.index});
}

class _IssueCard extends StatelessWidget {
  final _ValidationIssue issue;
  final String state;
  final VoidCallback onFix;
  final VoidCallback onIgnore;

  const _IssueCard(
      {required this.issue,
      required this.state,
      required this.onFix,
      required this.onIgnore});

  @override
  Widget build(BuildContext context) {
    final isCritical = issue.severity == 'critical';
    final accentColor =
        isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final bgColor =
        isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final borderColor =
        isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A);
    final resolved = state != 'none';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: resolved ? const Color(0xFFF8FAFC) : bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: resolved ? const Color(0xFFE5E7EB) : borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  resolved
                      ? Icons.check_circle_outline
                      : isCritical
                          ? Icons.cancel_outlined
                          : Icons.warning_amber_rounded,
                  color: resolved ? AppColors.success : accentColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: resolved
                                  ? const Color(0xFFDCFCE7)
                                  : isCritical
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              resolved
                                  ? state == 'fixed'
                                      ? 'Fixed'
                                      : 'Ignored'
                                  : isCritical
                                      ? 'Critical'
                                      : 'Warning',
                              style: AppTextStyles.label.copyWith(
                                  fontSize: 9,
                                  color: resolved
                                      ? AppColors.success
                                      : accentColor,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(issue.title,
                          style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: resolved
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(issue.description,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!resolved)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  if (isCritical)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onFix,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Fix Issue',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  if (isCritical) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onIgnore,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Ignore',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Step 6: Approval ─────────────────────────────────────────────────────────

class _Step6Approval extends StatelessWidget {
  final bool approvalComplete;
  final TextEditingController commentController;
  final VoidCallback onApprove;

  const _Step6Approval({
    required this.approvalComplete,
    required this.commentController,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Approval Workflow', style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text('June 2026 payroll requires multi-level approval.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              // Timeline item 1 — always approved
              _ApprovalTimelineItem(
                name: 'Rajan Pillai',
                role: 'HR Manager',
                initials: 'RP',
                avatarColor: const Color(0xFF6C5CE7),
                status: 'approved',
                timestamp: '30 Jun 2026 · 10:22 AM',
                comment: 'All calculations look good.',
              ),
              const SizedBox(height: 16),
              // Timeline item 2 — pending (or approved)
              if (!approvalComplete) ...[
                _ApprovalTimelineItem(
                  name: 'Divya Krishnan',
                  role: 'Finance Head',
                  initials: 'DK',
                  avatarColor: const Color(0xFF0E7C86),
                  status: 'pending',
                  timestamp: null,
                  comment: null,
                ),
                Container(
                  margin: const EdgeInsets.only(left: 40, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add comment (optional)',
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: commentController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                  color: Color(0xFFD1D5DB))),
                          contentPadding: const EdgeInsets.all(10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onApprove,
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                textStyle: const TextStyle(fontSize: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.close, size: 14),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(
                                    color: Color(0xFFEF4444)),
                                textStyle: const TextStyle(fontSize: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.undo, size: 14),
                              label: const Text('Send Back'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                textStyle: const TextStyle(fontSize: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _ApprovalTimelineItem(
                  name: 'Divya Krishnan',
                  role: 'Finance Head',
                  initials: 'DK',
                  avatarColor: const Color(0xFF0E7C86),
                  status: 'approved',
                  timestamp: '30 Jun 2026 · 10:48 AM',
                  comment: commentController.text,
                ),
                const SizedBox(height: 16),
              ],
              // Timeline item 3 — pending until approved
              _ApprovalTimelineItem(
                name: 'CEO Office',
                role: 'Final Authority',
                initials: 'CE',
                avatarColor: const Color(0xFF6C5CE7),
                status: approvalComplete ? 'approved' : 'pending',
                timestamp:
                    approvalComplete ? '30 Jun 2026 · 11:05 AM' : null,
                comment: approvalComplete ? 'Approved for disbursement.' : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalTimelineItem extends StatelessWidget {
  final String name;
  final String role;
  final String initials;
  final Color avatarColor;
  final String status;
  final String? timestamp;
  final String? comment;

  const _ApprovalTimelineItem({
    required this.name,
    required this.role,
    required this.initials,
    required this.avatarColor,
    required this.status,
    required this.timestamp,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final statusColor =
        isApproved ? AppColors.success : AppColors.textSecondary;
    final statusBg =
        isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor.withOpacity(0.15),
              child: Text(initials,
                  style: TextStyle(
                      color: avatarColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTextStyles.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(role,
                            style: AppTextStyles.label.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      isApproved ? 'Approved' : 'Pending',
                      style: AppTextStyles.label.copyWith(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (timestamp != null) ...[
                const SizedBox(height: 3),
                Text(timestamp!,
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
              if (comment != null && comment!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Text(comment!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 7: Payslips ─────────────────────────────────────────────────────────

class _Step7Payslips extends StatelessWidget {
  final bool generated;
  final VoidCallback onGenerate;
  const _Step7Payslips({required this.generated, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Counter banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: generated
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: generated
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(
                generated ? Icons.receipt_long : Icons.receipt_long_outlined,
                color: generated ? AppColors.success : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  generated
                      ? '5 of 5 payslips generated successfully.'
                      : '0 of 5 payslips generated. Click "Generate All" to proceed.',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: generated
                          ? AppColors.success
                          : AppColors.textSecondary),
                ),
              ),
              if (!generated)
                ElevatedButton(
                  onPressed: onGenerate,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Generate All'),
                ),
            ],
          ),
        ),

        _card(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: _tableHeader(
                    ['Employee', 'Net Pay', 'Status', 'Actions'],
                    [2.5, 1.5, 1.5, 1.5]),
              ),
              ..._kEmps.asMap().entries.map((e) {
                const netList = [
                  '₹70,585', '₹49,688', '₹87,300', '₹51,720', '₹41,990'
                ];
                return _tableRow([
                  Row(children: [
                    _empAvatar(e.value),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(e.value.name,
                            style: AppTextStyles.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  Text(netList[e.key],
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: generated
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      generated ? 'Generated' : 'Pending',
                      style: AppTextStyles.label.copyWith(
                          fontSize: 9,
                          color: generated
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.download_outlined,
                          size: 16,
                          color: generated
                              ? AppColors.primary
                              : const Color(0xFFD1D5DB)),
                      const SizedBox(width: 6),
                      Icon(Icons.email_outlined,
                          size: 16,
                          color: generated
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFD1D5DB)),
                      const SizedBox(width: 6),
                      Icon(Icons.visibility_outlined,
                          size: 16,
                          color: generated
                              ? AppColors.textSecondary
                              : const Color(0xFFD1D5DB)),
                    ],
                  ),
                ], [2.5, 1.5, 1.5, 1.5],
                    isLast: e.key == _kEmps.length - 1);
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 8: Bank Transfer ────────────────────────────────────────────────────

class _Step8BankTransfer extends StatefulWidget {
  const _Step8BankTransfer();

  @override
  State<_Step8BankTransfer> createState() => _Step8BankTransferState();
}

class _Step8BankTransferState extends State<_Step8BankTransfer> {
  final _paidRows = List.filled(5, false);

  @override
  Widget build(BuildContext context) {
    const bankNames = ['HDFC Bank', 'SBI', 'ICICI Bank', 'Axis Bank', 'Kotak'];
    const accounts = ['XXXX1234', 'XXXX5678', 'XXXX9012', 'XXXX3456', 'XXXX7890'];
    const ifscList = ['HDFC0001', 'SBIN0002', 'ICIC0003', 'UTIB0004', 'KKBK0005'];
    const netList = ['₹70,585', '₹49,688', '₹87,300', '₹51,720', '₹41,990'];

    final allPaid = _paidRows.every((p) => p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: allPaid
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: allPaid
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(
                allPaid ? Icons.check_circle : Icons.account_balance_outlined,
                color:
                    allPaid ? AppColors.success : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allPaid
                          ? 'All salaries marked as paid!'
                          : 'Total Net Payable: ₹3,01,283',
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (!allPaid)
                      Text('5 employees · June 2026 payroll',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Employee bank table
        _card(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: _tableHeader(
                    ['Employee', 'Bank', 'Account', 'Net Pay', 'Status', ''],
                    [2.0, 1.4, 1.2, 1.2, 1.2, 0.8]),
              ),
              ..._kEmps.asMap().entries.map((e) {
                final paid = _paidRows[e.key];
                return _tableRow([
                  Row(children: [
                    _empAvatar(e.value),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(e.value.name,
                            style: AppTextStyles.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(bankNames[e.key],
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(ifscList[e.key],
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary, fontSize: 9)),
                    ],
                  ),
                  Text(accounts[e.key],
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  Text(netList[e.key],
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: paid
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      paid ? 'Paid' : 'Pending',
                      style: AppTextStyles.label.copyWith(
                          fontSize: 9,
                          color: paid
                              ? AppColors.success
                              : const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _paidRows[e.key] = !paid),
                    borderRadius: BorderRadius.circular(6),
                    child: Icon(
                      paid
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: paid ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ], [2.0, 1.4, 1.2, 1.2, 1.2, 0.8],
                    isLast: e.key == _kEmps.length - 1);
              }),

              // Total row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F4FF),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 20,
                      child: Text(''),
                    ),
                    const Expanded(
                      flex: 14,
                      child: Text(''),
                    ),
                    const Expanded(
                      flex: 12,
                      child: Text(''),
                    ),
                    Expanded(
                      flex: 12,
                      child: Text('₹3,01,283',
                          style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    Expanded(
                      flex: 12,
                      child: Text('Total',
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Expanded(flex: 8, child: Text('')),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.account_balance, size: 14),
                label: const Text('Generate Bank File'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  textStyle: const TextStyle(fontSize: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined, size: 14),
                label: const Text('Export Excel'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  textStyle: const TextStyle(fontSize: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    setState(() => _paidRows.fillRange(0, _paidRows.length, true)),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: const Text('Mark All Paid'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

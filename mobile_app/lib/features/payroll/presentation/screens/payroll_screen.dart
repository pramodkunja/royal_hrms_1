import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'run_payroll_screen.dart';

// ─── Static data ──────────────────────────────────────────────────────────────

class _PayrollRun {
  final String month;
  final int employees;
  final String grossPayroll;
  final String netPayroll;
  final String salaryDate;
  final bool isPaid;
  const _PayrollRun({
    required this.month,
    required this.employees,
    required this.grossPayroll,
    required this.netPayroll,
    required this.salaryDate,
    required this.isPaid,
  });
}

class _EmpPayroll {
  final String initials;
  final Color avatarColor;
  final String name;
  final String empCode;
  final String department;
  final String basic;
  final String hra;
  final String grossEarnings;
  final String deductions;
  final String netSalary;
  const _EmpPayroll({
    required this.initials,
    required this.avatarColor,
    required this.name,
    required this.empCode,
    required this.department,
    required this.basic,
    required this.hra,
    required this.grossEarnings,
    required this.deductions,
    required this.netSalary,
  });
}

const _kPayrollRuns = <_PayrollRun>[
  _PayrollRun(
    month: 'May 2026', employees: 246, grossPayroll: '₹33,90,500',
    netPayroll: '₹29,84,200', salaryDate: '30 May 2026', isPaid: true,
  ),
  _PayrollRun(
    month: 'Apr 2026', employees: 244, grossPayroll: '₹33,10,000',
    netPayroll: '₹29,12,800', salaryDate: '30 Apr 2026', isPaid: true,
  ),
  _PayrollRun(
    month: 'Mar 2026', employees: 243, grossPayroll: '₹32,50,000',
    netPayroll: '₹28,60,500', salaryDate: '31 Mar 2026', isPaid: true,
  ),
  _PayrollRun(
    month: 'Jun 2026', employees: 248, grossPayroll: '₹34,55,000',
    netPayroll: '₹30,30,830', salaryDate: 'Pending', isPaid: false,
  ),
];

const _kEmployees = <_EmpPayroll>[
  _EmpPayroll(
    initials: 'AM', avatarColor: Color(0xFF6C5CE7),
    name: 'Arjun Mehta', empCode: 'EMP001', department: 'Engineering',
    basic: '₹45,000', hra: '₹18,000', grossEarnings: '₹80,500',
    deductions: '₹14,415', netSalary: '₹70,085',
  ),
  _EmpPayroll(
    initials: 'PS', avatarColor: Color(0xFF6C5CE7),
    name: 'Priya Sharma', empCode: 'EMP002', department: 'HR',
    basic: '₹35,000', hra: '₹14,000', grossEarnings: '₹56,500',
    deductions: '₹9,312', netSalary: '₹49,188',
  ),
  _EmpPayroll(
    initials: 'RS', avatarColor: Color(0xFF0E7C86),
    name: 'Rahul Singh', empCode: 'EMP003', department: 'Sales',
    basic: '₹50,000', hra: '₹20,000', grossEarnings: '₹94,000',
    deductions: '₹12,200', netSalary: '₹89,800',
  ),
  _EmpPayroll(
    initials: 'MI', avatarColor: Color(0xFF6C5CE7),
    name: 'Meena Iyer', empCode: 'EMP004', department: 'Finance',
    basic: '₹40,000', hra: '₹16,000', grossEarnings: '₹65,000',
    deductions: '₹15,780', netSalary: '₹52,720',
  ),
  _EmpPayroll(
    initials: 'SK', avatarColor: Color(0xFF0E7C86),
    name: 'Suresh Kumar', empCode: 'EMP005', department: 'Operations',
    basic: '₹30,000', hra: '₹12,000', grossEarnings: '₹49,500',
    deductions: '₹9,510', netSalary: '₹41,290',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payroll Management', style: AppTextStyles.h2),
                        const SizedBox(height: 2),
                        Text(
                          'Process, approve and disburse salaries — June 2026',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.history, size: 14),
                    label: const Text('History'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RunPayrollScreen()),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Run Payroll'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Analytics'),
                ],
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                isScrollable: false,
              ),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _DashboardTab(),
              const _ReportsTab(),
              const _AnalyticsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCards(),
          const SizedBox(height: 16),
          _buildPayrollCalendar(),
          const SizedBox(height: 14),
          _buildRecentPayrollRuns(),
          const SizedBox(height: 14),
          _buildEmployeePreview(),
        ],
      ),
    );
  }

  // ── Stat cards ─────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final stats = [
      _StatItem(
        label: 'Total Employees', value: '248', sub: 'Active this month',
        icon: Icons.people_outline,
        iconColor: const Color(0xFF0E7C86),
        iconBg: const Color(0xFFE6F1FB),
      ),
      _StatItem(
        label: 'Gross Payroll', value: '₹34,55,000', sub: 'Before deductions',
        icon: Icons.currency_rupee_rounded,
        iconColor: AppColors.primary,
        iconBg: const Color(0xFFE8EFFA),
      ),
      _StatItem(
        label: 'Net Payroll', value: '₹30,30,830', sub: 'After all deductions',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: AppColors.success,
        iconBg: AppColors.successContainer,
      ),
      _StatItem(
        label: 'Pending Payroll', value: '3', sub: 'Awaiting approval',
        icon: Icons.hourglass_empty_rounded,
        iconColor: AppColors.warning,
        iconBg: AppColors.warningContainer,
      ),
      _StatItem(
        label: 'Processed Payroll', value: '12', sub: 'Disbursed this quarter',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        iconBg: AppColors.successContainer,
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _StatCard(item: stats[i]),
      ),
    );
  }

  // ── Payroll Calendar ────────────────────────────────────────────────────────

  Widget _buildPayrollCalendar() {
    // June 2026: June 1 = Monday → firstWd=1 (Sun=0 grid)
    const int firstWd = 1;
    const int daysInMonth = 30;
    const int salaryDay = 30;
    const Set<int> holidays = {8, 14, 21};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Payroll Calendar', style: AppTextStyles.h4),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'June 2026',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),

          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: firstWd + daysInMonth,
            itemBuilder: (_, idx) {
              if (idx < firstWd) return const SizedBox();
              final day = idx - firstWd + 1;
              final isSalary = day == salaryDay;
              final isHoliday = holidays.contains(day);

              Color? bg;
              Color textColor = AppColors.textPrimary;
              if (isSalary) {
                bg = AppColors.primary;
                textColor = Colors.white;
              } else if (isHoliday) {
                bg = AppColors.warningContainer;
                textColor = AppColors.warning;
              }

              return Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: (isSalary || isHoliday)
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Legend
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text('Salary Date — 30 Jun',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warning, width: 1),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Holidays (3)',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),

          // Run June Payroll button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Run June Payroll'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Payroll Runs ─────────────────────────────────────────────────────

  Widget _buildRecentPayrollRuns() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.update_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Recent Payroll Runs', style: AppTextStyles.h4),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined, size: 13),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Expanded(
                    flex: 3,
                    child: _ColHeader('MONTH')),
                Expanded(
                    flex: 2,
                    child: _ColHeader('EMP')),
                Expanded(
                    flex: 3,
                    child: _ColHeader('NET PAYROLL')),
                Expanded(
                    flex: 2,
                    child: _ColHeader('STATUS')),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // Rows
          ..._kPayrollRuns.map((run) => _PayrollRunRow(run: run)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Employee Payroll Preview ────────────────────────────────────────────────

  Widget _buildEmployeePreview() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Employee Payroll Preview — June 2026',
                      style: AppTextStyles.h4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Showing 5 of 248 employees',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          ..._kEmployees.map((e) => _EmployeePayrollCard(emp: e)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  const _StatItem({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, size: 15, color: item.iconColor),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.sub,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textHint, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textHint,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _PayrollRunRow extends StatelessWidget {
  final _PayrollRun run;
  const _PayrollRunRow({required this.run});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.month,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${run.employees} emp · ${run.grossPayroll}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${run.employees}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.netPayroll,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  run.salaryDate,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _StatusBadge(isPaid: run.isPaid),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.visibility_outlined,
                      size: 16, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isPaid;
  const _StatusBadge({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? AppColors.successContainer : AppColors.warningContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Pending',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isPaid ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

class _EmployeePayrollCard extends StatelessWidget {
  final _EmpPayroll emp;
  const _EmployeePayrollCard({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee name row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: emp.avatarColor,
                child: Text(
                  emp.initials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${emp.empCode} · ${emp.department}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Salary breakdown row
          Row(
            children: [
              _SalaryItem(label: 'Basic', value: emp.basic),
              const SizedBox(width: 1),
              _SalaryItem(label: 'HRA', value: emp.hra),
              const SizedBox(width: 1),
              _SalaryItem(label: 'Gross', value: emp.grossEarnings,
                  bold: true),
              const SizedBox(width: 1),
              _SalaryItem(label: 'Deductions', value: emp.deductions,
                  valueColor: AppColors.error),
              const SizedBox(width: 1),
              _SalaryItem(label: 'Net', value: emp.netSalary,
                  valueColor: AppColors.success, bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _SalaryItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textHint),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Placeholder tabs ─────────────────────────────────────────────────────────

// ─── Reports Tab ─────────────────────────────────────────────────────────────

class _ReportItem {
  final IconData icon;
  final String title;
  final String description;
  final String size;
  final bool downloaded;
  const _ReportItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.size,
    this.downloaded = false,
  });
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  static const _statutory = <_ReportItem>[
    _ReportItem(
      icon: Icons.description_outlined,
      title: 'PF Report',
      description: 'Employee & employer PF contribution summary with UAN mapping',
      size: '48 KB',
      downloaded: true,
    ),
    _ReportItem(
      icon: Icons.health_and_safety_outlined,
      title: 'ESI Report',
      description: 'ESI deductions for eligible employees below ₹21,000 threshold',
      size: '32 KB',
    ),
    _ReportItem(
      icon: Icons.receipt_outlined,
      title: 'PT Report',
      description: 'Professional Tax deductions by state and salary slab',
      size: '18 KB',
    ),
    _ReportItem(
      icon: Icons.account_balance_outlined,
      title: 'TDS Report (Form 16)',
      description: 'Monthly TDS deducted per employee with annual projected liability',
      size: '124 KB',
    ),
  ];

  static const _summary = <_ReportItem>[
    _ReportItem(
      icon: Icons.table_chart_outlined,
      title: 'Salary Register',
      description: 'Detailed salary register with all earnings and deductions for all employees',
      size: '210 KB',
    ),
    _ReportItem(
      icon: Icons.bar_chart_outlined,
      title: 'Payroll Summary',
      description: 'High-level payroll cost summary by department and employee type',
      size: '56 KB',
    ),
    _ReportItem(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Bank Advice',
      description: 'Bank transfer file for NEFT/RTGS bulk salary disbursement',
      size: '14 KB',
    ),
    _ReportItem(
      icon: Icons.summarize_outlined,
      title: 'Monthly Payroll Report',
      description: 'Complete monthly payroll report with variance analysis vs prior month',
      size: '98 KB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter row
          _buildFilterRow(),
          const SizedBox(height: 20),

          // Statutory Reports
          const Text(
            'STATUTORY REPORTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemCount: _statutory.length,
            itemBuilder: (_, i) => _ReportCard(item: _statutory[i]),
          ),
          const SizedBox(height: 20),

          // Payroll Summary
          const Text(
            'PAYROLL SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemCount: _summary.length,
            itemBuilder: (_, i) => _ReportCard(item: _summary[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        _FilterChip(
          icon: Icons.calendar_today_outlined,
          label: 'June 2026',
        ),
        const SizedBox(width: 10),
        _FilterChip(
          icon: Icons.business_outlined,
          label: 'All Branches',
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.filter_list_outlined, size: 14),
          label: const Text('Filter Reports'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FilterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down,
              size: 16, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportItem item;
  const _ReportCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, size: 16, color: AppColors.primary),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              item.description,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          // Badge row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'June 2026',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.size,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons
          if (item.downloaded)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check, size: 12),
                    label: const Text('Downloaded'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      textStyle: const TextStyle(fontSize: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check, size: 12),
                    label: const Text('Downloaded'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      textStyle: const TextStyle(fontSize: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 12),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      textStyle: const TextStyle(fontSize: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.table_view_outlined, size: 12),
                    label: const Text('Export Excel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      textStyle: const TextStyle(fontSize: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsStats(),
          const SizedBox(height: 14),
          _buildMonthlyTrend(),
          const SizedBox(height: 14),
          _buildCostByDepartment(),
          const SizedBox(height: 14),
          _buildOvertimeTrend(),
          const SizedBox(height: 14),
          _buildEarningsVsDeductions(),
        ],
      ),
    );
  }

  // ── Analytics stat cards ───────────────────────────────────────────────────

  Widget _buildAnalyticsStats() {
    final stats = [
      _StatItem(
        label: 'Avg. Salary',
        value: '₹69,083',
        sub: 'Per employee / month',
        icon: Icons.people_outline,
        iconColor: const Color(0xFF0E7C86),
        iconBg: const Color(0xFFE6F1FB),
      ),
      _StatItem(
        label: 'Payroll Growth',
        value: '+8.7%',
        sub: 'vs last quarter',
        icon: Icons.trending_up_rounded,
        iconColor: AppColors.success,
        iconBg: AppColors.successContainer,
      ),
      _StatItem(
        label: 'OT Cost',
        value: '₹65,000',
        sub: 'June 2026',
        icon: Icons.hourglass_bottom_rounded,
        iconColor: AppColors.warning,
        iconBg: AppColors.warningContainer,
      ),
      _StatItem(
        label: 'Compliance',
        value: '100%',
        sub: 'Statutory deductions',
        icon: Icons.refresh_rounded,
        iconColor: const Color(0xFF0E7C86),
        iconBg: const Color(0xFFE6F1FB),
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _StatCard(item: stats[i]),
      ),
    );
  }

  // ── Monthly Payroll Trend ──────────────────────────────────────────────────

  Widget _buildMonthlyTrend() {
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    const gross = [29.5, 29.8, 30.5, 31.0, 31.8, 34.5];
    const net = [26.2, 26.5, 27.2, 27.6, 28.2, 30.1];
    const maxVal = 36.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Monthly Payroll Trend', style: AppTextStyles.h4),
              const Spacer(),
              _LegendDotInline(AppColors.primary, 'Gross'),
              const SizedBox(width: 10),
              _LegendDotInline(AppColors.success, 'Net'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(labels.length, (i) {
                final gH = (gross[i] / maxVal) * 110;
                final nH = (net[i] / maxVal) * 110;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 14,
                              height: gH,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3)),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Container(
                              width: 14,
                              height: nH,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(labels[i],
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textHint)),
                        const SizedBox(height: 2),
                        Text('₹${gross[i]}L',
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        Text('₹${net[i]}L',
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cost by Department ─────────────────────────────────────────────────────

  Widget _buildCostByDepartment() {
    const depts = [
      _DeptData('Engineering', 0.23, 28, Color(0xFF1E4E8C)),
      _DeptData('Sales', 0.27, 35, Color(0xFF1B8A6B)),
      _DeptData('Finance', 0.19, 18, Color(0xFFD97706)),
      _DeptData('HR', 0.16, 12, Color(0xFFC0392B)),
      _DeptData('Operations', 0.14, 42, Color(0xFF6C5CE7)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_large_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Cost by Department', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutPainter(depts),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  children: depts
                      .map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: d.color,
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(d.name,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textPrimary)),
                                ),
                                Text(
                                  '${(d.pct * 100).round()}%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${d.emp} emp)',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textHint),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Overtime Cost Trend ────────────────────────────────────────────────────

  Widget _buildOvertimeTrend() {
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    const values = [42, 38, 51, 47, 63, 65]; // in K

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_outlined,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('Overtime Cost Trend', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LinePainter(values.map((v) => v.toDouble()).toList()),
            ),
          ),
          const SizedBox(height: 6),
          // X-axis labels + values
          Row(
            children: List.generate(labels.length, (i) {
              return Expanded(
                child: Column(
                  children: [
                    Text('₹${values[i]}K',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning),
                        textAlign: TextAlign.center),
                    Text(labels[i],
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textHint),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Earnings vs Deductions ─────────────────────────────────────────────────

  Widget _buildEarningsVsDeductions() {
    const depts = [
      ('Engineering', 0.13, Color(0xFF1E4E8C)),
      ('Sales', 0.04, Color(0xFF1B8A6B)),
      ('Finance', 0.19, Color(0xFFD97706)),
      ('HR', 0.13, Color(0xFFC0392B)),
      ('Operations', 0.17, Color(0xFF6C5CE7)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Earnings vs Deductions', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 14),
          ...depts.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(d.$1,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                        ),
                        Text(
                          '${(d.$2 * 100).round()}% deductions',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: d.$2,
                        backgroundColor: AppColors.backgroundMid,
                        valueColor: AlwaysStoppedAnimation(d.$3),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Shared Analytics helpers ─────────────────────────────────────────────────

class _LegendDotInline extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDotInline(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DeptData {
  final String name;
  final double pct;
  final int emp;
  final Color color;
  const _DeptData(this.name, this.pct, this.emp, this.color);
}

// ── Donut chart painter ───────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<_DeptData> data;
  const _DonutPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.55;

    final paint = Paint()..style = PaintingStyle.fill;
    double startAngle = -3.14159 / 2; // start from top

    for (final d in data) {
      final sweep = d.pct * 2 * 3.14159;
      paint.color = d.color;
      final path = Path();
      path.moveTo(cx + outerR * _cos(startAngle),
          cy + outerR * _sin(startAngle));
      path.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
          startAngle, sweep, false);
      path.lineTo(cx + innerR * _cos(startAngle + sweep),
          cy + innerR * _sin(startAngle + sweep));
      path.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
          startAngle + sweep, -sweep, false);
      path.close();
      canvas.drawPath(path, paint);
      startAngle += sweep;
    }

    // gap lines (white)
    final gapPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    double a = -3.14159 / 2;
    for (final d in data) {
      canvas.drawLine(
        Offset(cx + innerR * _cos(a), cy + innerR * _sin(a)),
        Offset(cx + outerR * _cos(a), cy + outerR * _sin(a)),
        gapPaint,
      );
      a += d.pct * 2 * 3.14159;
    }
  }

  double _cos(double a) => _approxCos(a);
  double _sin(double a) => _approxSin(a);

  // Dart's math library is not imported, use the dart:math via import at top.
  // We'll use import 'dart:math' at the file level instead.
  double _approxCos(double a) {
    // Use series expansion or just rely on dart:math
    return _dartCos(a);
  }

  double _approxSin(double a) {
    return _dartSin(a);
  }

  // These delegate to dart:math functions
  static double _dartCos(double a) => _mathCos(a);
  static double _dartSin(double a) => _mathSin(a);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Line chart painter ────────────────────────────────────────────────────────

class _LinePainter extends CustomPainter {
  final List<double> values;
  const _LinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b) * 0.85;
    final range = maxV - minV;
    final count = values.length;

    double xOf(int i) => (i / (count - 1)) * size.width;
    double yOf(double v) =>
        size.height - ((v - minV) / range) * size.height * 0.85 - 10;

    final points = List.generate(count, (i) => Offset(xOf(i), yOf(values[i])));

    // Area fill
    final areaPath = Path();
    areaPath.moveTo(points.first.dx, size.height);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..color = AppColors.warning.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Line
    final linePaint = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    for (final p in points) {
      canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = AppColors.warning
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// top-level math helpers so CustomPainter doesn't need a dart:math import inline
double _mathCos(double a) {
  // Taylor series: cos(a) ≈ 1 - a²/2 + a⁴/24 - a⁶/720
  // Normalize a to [-π, π]
  const pi = 3.14159265358979;
  while (a > pi) {
    a -= 2 * pi;
  }
  while (a < -pi) {
    a += 2 * pi;
  }
  final a2 = a * a;
  return 1.0 - a2 / 2 + a2 * a2 / 24 - a2 * a2 * a2 / 720;
}

double _mathSin(double a) {
  const pi = 3.14159265358979;
  while (a > pi) {
    a -= 2 * pi;
  }
  while (a < -pi) {
    a += 2 * pi;
  }
  final a2 = a * a;
  return a - a * a2 / 6 + a * a2 * a2 / 120 - a * a2 * a2 * a2 / 5040;
}

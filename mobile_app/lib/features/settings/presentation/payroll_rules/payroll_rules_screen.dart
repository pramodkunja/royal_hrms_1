import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/settings_app_bar.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

enum _ComponentType { percentage, fixedAmount, variable, slabBased }

class _EarnRow {
  final String name;
  final _ComponentType type;
  final String value;
  final String appliesOn;
  final String effectiveDate;
  bool enabled;
  _EarnRow({
    required this.name,
    required this.type,
    required this.value,
    required this.appliesOn,
    required this.effectiveDate,
    this.enabled = true,
  });
}

class _DeductRow {
  final String name;
  final _ComponentType type;
  final String value;
  final String appliesOn;
  final String effectiveDate;
  final bool statutory;
  bool enabled;
  _DeductRow({
    required this.name,
    required this.type,
    required this.value,
    required this.appliesOn,
    required this.effectiveDate,
    this.statutory = false,
    this.enabled = true,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PayrollRulesScreen extends StatefulWidget {
  const PayrollRulesScreen({super.key});

  @override
  State<PayrollRulesScreen> createState() => _PayrollRulesScreenState();
}

class _PayrollRulesScreenState extends State<PayrollRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Earnings components
  final _earnings = [
    _EarnRow(name: 'Basic Salary', type: _ComponentType.percentage, value: '40%', appliesOn: '% of CTC', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'HRA', type: _ComponentType.percentage, value: '50%', appliesOn: '% of Basic', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Dearness Allowance', type: _ComponentType.percentage, value: '15%', appliesOn: '% of Basic', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Special Allowance', type: _ComponentType.percentage, value: '10%', appliesOn: '% of Basic', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Conveyance Allowance', type: _ComponentType.fixedAmount, value: '₹1,600', appliesOn: 'Fixed / Month', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Medical Allowance', type: _ComponentType.fixedAmount, value: '₹1,250', appliesOn: 'Fixed / Month', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Travel Allowance', type: _ComponentType.fixedAmount, value: '₹2,000', appliesOn: 'Fixed / Month', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Internet Allowance', type: _ComponentType.fixedAmount, value: '₹500', appliesOn: 'Fixed / Month', effectiveDate: '2025-04-01', enabled: false),
    _EarnRow(name: 'Incentives', type: _ComponentType.variable, value: 'Variable', appliesOn: 'Performance', effectiveDate: '2025-04-01'),
    _EarnRow(name: 'Overtime', type: _ComponentType.fixedAmount, value: 'Variable', appliesOn: 'Per OT Hour', effectiveDate: '2025-04-01'),
  ];

  // Deduction components
  final _deductions = [
    _DeductRow(name: 'Provident Fund (PF)', type: _ComponentType.percentage, value: '12%', appliesOn: '% of Basic', effectiveDate: '2025-04-01', statutory: true),
    _DeductRow(name: 'ESI', type: _ComponentType.percentage, value: '0.75%', appliesOn: '% of Gross', effectiveDate: '2025-04-01', statutory: true),
    _DeductRow(name: 'Professional Tax', type: _ComponentType.fixedAmount, value: '₹200', appliesOn: 'Fixed / Month', effectiveDate: '2025-04-01', statutory: true),
    _DeductRow(name: 'Income Tax (TDS)', type: _ComponentType.slabBased, value: 'As per slab', appliesOn: 'Annual Slab', effectiveDate: '2025-04-01', statutory: true),
    _DeductRow(name: 'Labour Welfare Fund', type: _ComponentType.fixedAmount, value: '₹25', appliesOn: 'Fixed / Month', effectiveDate: '2025-04-01', statutory: true),
    _DeductRow(name: 'Loan EMI', type: _ComponentType.fixedAmount, value: 'Variable', appliesOn: 'Per Loan', effectiveDate: '2025-04-01'),
    _DeductRow(name: 'Salary Advance Recovery', type: _ComponentType.fixedAmount, value: 'Variable', appliesOn: 'Per Recovery', effectiveDate: '2025-04-01'),
    _DeductRow(name: 'Loss of Pay (LOP)', type: _ComponentType.variable, value: 'Variable', appliesOn: 'Per Day', effectiveDate: '2025-04-01'),
    _DeductRow(name: 'Other Deductions', type: _ComponentType.fixedAmount, value: 'Variable', appliesOn: 'Configurable', effectiveDate: '2025-04-01', enabled: false),
  ];

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

  int get _activeEarnings => _earnings.where((e) => e.enabled).length;
  int get _activeDeductions => _deductions.where((d) => d.enabled).length;
  int get _statutoryCount =>
      _deductions.where((d) => d.statutory).length;
  int get _totalActive => _activeEarnings + _activeDeductions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'Payroll Rules',
        trailing: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.save_outlined, size: 14),
          label: const Text('Save All Changes'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 34),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Earnings Rules'),
            Tab(text: 'Deduction Rules'),
            Tab(text: 'Payroll Run Settings'),
          ],
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: Column(
        children: [
          // Stat cards
          _StatCards(
            earnings: _earnings.length,
            deductions: _deductions.length,
            statutory: _statutoryCount,
            active: _totalActive,
          ),
          const Divider(height: 1, color: AppColors.border),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _EarningsTab(
                  rows: _earnings,
                  onToggle: (i, val) => setState(() => _earnings[i].enabled = val),
                ),
                _DeductionsTab(
                  rows: _deductions,
                  onToggle: (i, val) =>
                      setState(() => _deductions[i].enabled = val),
                ),
                const _PayrollRunSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat cards ───────────────────────────────────────────────────────────────

class _StatCards extends StatelessWidget {
  final int earnings;
  final int deductions;
  final int statutory;
  final int active;

  const _StatCards({
    required this.earnings,
    required this.deductions,
    required this.statutory,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.currency_exchange_outlined,
            iconColor: AppColors.primary,
            count: earnings,
            label: 'Earning\nComponents',
          ),
          _StatDivider(),
          _StatChip(
            icon: Icons.remove_circle_outline,
            iconColor: const Color(0xFFEF4444),
            count: deductions,
            label: 'Deduction\nRules',
          ),
          _StatDivider(),
          _StatChip(
            icon: Icons.sync_outlined,
            iconColor: AppColors.textSecondary,
            count: statutory,
            label: 'Statutory\nRules',
          ),
          _StatDivider(),
          _StatChip(
            icon: Icons.link_outlined,
            iconColor: AppColors.textSecondary,
            count: active,
            label: 'Active\nRules',
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: const Color(0xFFE5E7EB),
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: AppTextStyles.h4.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: iconColor == AppColors.primary
                      ? AppColors.primary
                      : iconColor == const Color(0xFFEF4444)
                          ? const Color(0xFFEF4444)
                          : AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary, fontSize: 9, height: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared component table ───────────────────────────────────────────────────

Widget _typeBadge(_ComponentType type) {
  late String label;
  late Color color;
  late Color bg;

  switch (type) {
    case _ComponentType.percentage:
      label = 'Percentage';
      color = AppColors.primary;
      bg = const Color(0xFFEBF0FA);
    case _ComponentType.fixedAmount:
      label = 'Fixed Amount';
      color = AppColors.textSecondary;
      bg = const Color(0xFFF3F4F6);
    case _ComponentType.variable:
      label = 'Variable';
      color = AppColors.success;
      bg = const Color(0xFFDCFCE7);
    case _ComponentType.slabBased:
      label = 'Slab-based';
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFFEF3C7);
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(
      label,
      style: AppTextStyles.label.copyWith(
          color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

Widget _tableColumnHeader() {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    decoration: const BoxDecoration(
      color: Color(0xFFF8FAFC),
      border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text('COMPONENT',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ),
        Expanded(
          flex: 2,
          child: Text('TYPE',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ),
        Expanded(
          flex: 2,
          child: Text('VALUE',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ),
        const SizedBox(
          width: 56,
          child: Text('STATUS',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ),
      ],
    ),
  );
}

// ─── Earnings tab ─────────────────────────────────────────────────────────────

class _EarningsTab extends StatelessWidget {
  final List<_EarnRow> rows;
  final void Function(int, bool) onToggle;

  const _EarningsTab({required this.rows, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final activeCount = rows.where((r) => r.enabled).length;

    return ListView(
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF0FA),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.currency_exchange_outlined,
                    size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Earnings Components',
                      style: AppTextStyles.h4
                          .copyWith(color: AppColors.textPrimary)),
                  Text('${rows.length} rules · $activeCount active',
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
              const Spacer(),
              Text(
                'Toggle to enable/disable · Edit to configure',
                style: AppTextStyles.label.copyWith(
                    color: AppColors.textHint, fontSize: 9),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Table
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: _tableColumnHeader(),
              ),
              ...rows.asMap().entries.map((e) => _EarnRowTile(
                    row: e.value,
                    index: e.key,
                    isLast: e.key == rows.length - 1,
                    onToggle: (val) => onToggle(e.key, val),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _EarnRowTile extends StatelessWidget {
  final _EarnRow row;
  final int index;
  final bool isLast;
  final ValueChanged<bool> onToggle;

  const _EarnRowTile({
    required this.row,
    required this.index,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: row.enabled ? Colors.white : const Color(0xFFFAFAFA),
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6))),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    row.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: row.enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: _typeBadge(row.type)),
                Expanded(
                  flex: 2,
                  child: Text(
                    row.value,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: row.enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.78,
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: row.enabled,
                    onChanged: onToggle,
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: row.effectiveDate),
                      _MetaChip(
                          icon: Icons.functions_outlined,
                          label: row.appliesOn),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textSecondary),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Deductions tab ───────────────────────────────────────────────────────────

class _DeductionsTab extends StatelessWidget {
  final List<_DeductRow> rows;
  final void Function(int, bool) onToggle;

  const _DeductionsTab({required this.rows, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final activeCount = rows.where((r) => r.enabled).length;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.remove_circle_outline,
                    size: 14, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deduction Rules',
                      style: AppTextStyles.h4
                          .copyWith(color: AppColors.textPrimary)),
                  Text('${rows.length} rules · $activeCount active',
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
              const Spacer(),
              Text(
                'Toggle to enable/disable · Edit to configure',
                style: AppTextStyles.label.copyWith(
                    color: AppColors.textHint, fontSize: 9),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: _tableColumnHeader(),
              ),
              ...rows.asMap().entries.map((e) => _DeductRowTile(
                    row: e.value,
                    isLast: e.key == rows.length - 1,
                    onToggle: (val) => onToggle(e.key, val),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _DeductRowTile extends StatelessWidget {
  final _DeductRow row;
  final bool isLast;
  final ValueChanged<bool> onToggle;

  const _DeductRowTile({
    required this.row,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: row.enabled ? Colors.white : const Color(0xFFFAFAFA),
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6))),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: row.enabled
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: _typeBadge(row.type)),
                Expanded(
                  flex: 2,
                  child: Text(
                    row.value,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: row.enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.78,
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: row.enabled,
                    onChanged: onToggle,
                    activeColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: row.effectiveDate),
                      _MetaChip(
                          icon: Icons.functions_outlined,
                          label: row.appliesOn),
                      if (row.statutory)
                        _MetaChip(
                          icon: Icons.sync_outlined,
                          label: 'Statutory',
                          color: const Color(0xFF4A148C),
                          bg: const Color(0xFFF3E5F5),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textSecondary),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Meta chip (date / applies-on / statutory) ────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? bg;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    final b = bg ?? const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: b, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(label,
              style: AppTextStyles.label
                  .copyWith(color: c, fontSize: 10)),
        ],
      ),
    );
  }
}

// ─── Payroll Run Settings tab ─────────────────────────────────────────────────

class _PayrollRunSettingsTab extends StatefulWidget {
  const _PayrollRunSettingsTab();

  @override
  State<_PayrollRunSettingsTab> createState() => _PayrollRunSettingsTabState();
}

class _PayrollRunSettingsTabState extends State<_PayrollRunSettingsTab> {
  String _payFrequency = 'Monthly';
  String _ptState = 'Karnataka';
  String _lopCalc = 'Working Days';

  final _lockDateCtrl = TextEditingController(text: '25');
  final _payDayCtrl = TextEditingController(text: '28');
  final _esiCeilingCtrl = TextEditingController(text: '21000');
  final _autoApproveCtrl = TextEditingController(text: '0');
  final _employerPfCtrl = TextEditingController(text: '12');

  @override
  void dispose() {
    _lockDateCtrl.dispose();
    _payDayCtrl.dispose();
    _esiCeilingCtrl.dispose();
    _autoApproveCtrl.dispose();
    _employerPfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section header
        _RunSectionHeader(
          title: 'Payroll Run Configuration',
          subtitle: 'Controls how payroll is processed each cycle',
        ),
        const SizedBox(height: 16),

        // Form card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              // Row 1
              Row(
                children: [
                  Expanded(
                    child: _RunDropdown(
                      label: 'Pay Frequency',
                      hint: 'How often payroll is run',
                      value: _payFrequency,
                      items: const ['Monthly', 'Bi-Monthly', 'Weekly'],
                      onChanged: (v) => setState(() => _payFrequency = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RunTextField(
                      label: 'Payroll Lock Date',
                      hint: 'Day of month payroll gets locked',
                      controller: _lockDateCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 2
              Row(
                children: [
                  Expanded(
                    child: _RunTextField(
                      label: 'Pay Day',
                      hint: 'Day salaries are disbursed',
                      controller: _payDayCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RunTextField(
                      label: 'ESI Ceiling (Gross ₹)',
                      hint: 'Employees above this are ESI exempt',
                      controller: _esiCeilingCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 3
              Row(
                children: [
                  Expanded(
                    child: _RunDropdown(
                      label: 'PT State',
                      hint: 'State for Professional Tax calculation',
                      value: _ptState,
                      items: const [
                        'Karnataka',
                        'Maharashtra',
                        'Tamil Nadu',
                        'Andhra Pradesh',
                        'Telangana',
                        'West Bengal',
                      ],
                      onChanged: (v) => setState(() => _ptState = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RunDropdown(
                      label: 'LOP Calculation',
                      hint: 'Days basis for per-day LOP deduction',
                      value: _lopCalc,
                      items: const [
                        'Working Days',
                        'Calendar Days',
                        'Fixed 30 Days',
                      ],
                      onChanged: (v) => setState(() => _lopCalc = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 4
              Row(
                children: [
                  Expanded(
                    child: _RunTextField(
                      label: 'Auto-approve Threshold',
                      hint: 'Net salary below this auto-approves payroll',
                      controller: _autoApproveCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RunTextField(
                      label: 'Employer PF %',
                      hint: "Employer's PF contribution rate",
                      controller: _employerPfCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Save Run Settings button
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined, size: 15),
            label: const Text('Save Run Settings'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _RunSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _RunSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _RunDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _RunDropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 2),
        Text(hint,
            style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            isDense: true,
          ),
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w500),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textSecondary),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RunTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _RunTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 2),
        Text(hint,
            style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary, fontSize: 10)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

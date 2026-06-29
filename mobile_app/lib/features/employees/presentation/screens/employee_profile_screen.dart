import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_model.dart';
import '../providers/employee_providers.dart';
import '../widgets/add_employee_sheet.dart';

// ignore_for_file: use_build_context_synchronously

class EmployeeProfileScreen extends ConsumerWidget {
  final String employeeId;
  final EmployeeModel? initialEmployee;

  const EmployeeProfileScreen({
    super.key,
    required this.employeeId,
    this.initialEmployee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(employeeDetailProvider(employeeId));
    final employee = detailAsync.valueOrNull ?? initialEmployee;

    if (employee == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Employee Profile',
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        ),
        body: detailAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('Employee not found')),
      );
    }

    return _ProfileShell(employee: employee, employeeId: employeeId);
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

class _ProfileShell extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  final String employeeId;
  const _ProfileShell({required this.employee, required this.employeeId});

  @override
  ConsumerState<_ProfileShell> createState() => _ProfileShellState();
}

class _ProfileShellState extends ConsumerState<_ProfileShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool? _isActiveOverride;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (!_tabCtrl.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChange);
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _isActive => _isActiveOverride ?? widget.employee.isActive;

  Future<void> _onToggle(bool value) async {
    if (_toggling) return;
    setState(() { _isActiveOverride = value; _toggling = true; });
    final err = await ref
        .read(employeesProvider.notifier)
        .updateStatus(widget.employee.id, value);
    if (!mounted) return;
    if (err != null) {
      setState(() => _isActiveOverride = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ref.invalidate(employeeDetailProvider(widget.employeeId));
    }
    if (mounted) setState(() => _toggling = false);
  }

  Future<void> _onSave() async {
    final ok = await AddEmployeeSheet.show(context, editing: widget.employee);
    if (ok) {
      ref.invalidate(employeeDetailProvider(widget.employeeId));
      ref.invalidate(employeesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final isProfileTab = _tabCtrl.index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
            const Spacer(),
            Text('Employee Profile',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Stack(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 22, color: AppColors.textSecondary),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        leadingWidth: 44,
      ),
      bottomNavigationBar: isProfileTab
          ? _BottomBar(
              onCancel: () => Navigator.of(context).pop(),
              onSave: _onSave,
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Profile card ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ProfileCard(
                employee: emp,
                isActive: _isActive,
                isToggling: _toggling,
                onToggle: _onToggle,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          // ── Main tab bar ─────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: AppTextStyles.label
                    .copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: AppTextStyles.label
                    .copyWith(fontWeight: FontWeight.w500),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                dividerColor: AppColors.border,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Salary'),
                  Tab(text: 'Payroll'),
                  Tab(text: 'Leave'),
                  Tab(text: 'Attendance'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _ProfileTab(employee: emp),
            const _ComingSoon(label: 'Salary'),
            const _ComingSoon(label: 'Payroll'),
            const _ComingSoon(label: 'Leave'),
            const _ComingSoon(label: 'Attendance'),
          ],
        ),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final EmployeeModel employee;
  final bool isActive;
  final bool isToggling;
  final ValueChanged<bool> onToggle;

  const _ProfileCard({
    required this.employee,
    required this.isActive,
    required this.isToggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.elevatedShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Gradient header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF2A6ACC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.50),
                            width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          employee.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.camera_alt_outlined,
                            size: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  employee.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // ID + Status pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (employee.employeeId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${employee.employeeId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (employee.employeeId.isNotEmpty &&
                        employee.status.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          )),
                      const SizedBox(width: 6),
                    ],
                    if (employee.status.isNotEmpty)
                      Text(
                        _capFirst(employee.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
                      ),
                  ],
                ),
                if (employee.designation.isNotEmpty ||
                    employee.department.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [employee.designation, employee.department]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // ── 3-column info row ─────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    label: 'JOINED',
                    value: _fmtDate(employee.dateOfJoining),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                const VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    label: 'LOCATION',
                    value: employee.branch.isEmpty ? '—' : employee.branch,
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    label: 'DEPT',
                    value: employee.department.isEmpty
                        ? '—'
                        : employee.department,
                    icon: Icons.business_outlined,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // ── Active toggle ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success : AppColors.textHint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Active Employee' : 'Inactive Employee',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.success : AppColors.textHint,
                  ),
                ),
                const Spacer(),
                if (isToggling)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: isActive,
                    onChanged: onToggle,
                    activeTrackColor: AppColors.success,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _capFirst(String s) =>
      s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textHint,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Profile tab (sub-tabs + section content) ───────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final EmployeeModel employee;
  const _ProfileTab({required this.employee});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  int _sub = 0;

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Sub-tab pills ──────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: ['Basic Detail', 'Employee Detail', 'Personal Detail']
                  .asMap()
                  .entries
                  .map((e) {
                final isSel = e.key == _sub;
                return GestureDetector(
                  onTap: () => setState(() => _sub = e.key),
                  child: Container(
                    margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Section card ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // clean section header with left accent
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    border: const Border(
                      left: BorderSide(color: AppColors.primary, width: 4),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          [
                            Icons.list_alt_outlined,
                            Icons.badge_outlined,
                            Icons.person_outlined
                          ][_sub],
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ['Basic Detail', 'Employee Detail', 'Personal Detail']
                            [_sub],
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.upload_outlined,
                          size: 18, color: AppColors.textHint),
                      const SizedBox(width: 12),
                      const Icon(Icons.download_outlined,
                          size: 18, color: AppColors.textHint),
                    ],
                  ),
                ),
                // field content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: _sub == 0
                      ? _BasicDetailContent(emp: emp)
                      : _sub == 1
                          ? _EmployeeDetailContent(emp: emp)
                          : _PersonalDetailContent(emp: emp),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Basic Detail content ──────────────────────────────────────────────────────

class _BasicDetailContent extends StatelessWidget {
  final EmployeeModel emp;
  const _BasicDetailContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          label1: 'Employee Code', value1: _str(emp.employeeId), req1: true,
          label2: 'First Name',   value2: _str(emp.firstName),  req2: true,
        ),
        _FieldRow(
          label1: 'Middle Name', value1: '—',
          label2: 'Last Name',   value2: _str(emp.lastName), req2: true,
        ),
        const _FieldRow(
          label1: 'Gender',   value1: '—', req1: true,
          label2: 'Category', value2: '—', req2: true,
        ),
        const _FieldRow(
          label1: 'Prof Tax Location', value1: '—',
          label2: 'Date Of Birth',     value2: '—', req2: true,
        ),
        _FieldRow(
          label1: 'Date of Joining', value1: _fmt(emp.dateOfJoining), req1: true,
          label2: 'ESI Location',    value2: '—', req2: true,
        ),
        const _FieldRow(
          label1: 'Metro/Non-Metro (TDS)', value1: '—', req1: true,
          label2: 'ESI Dispensary',        value2: '—', req2: true,
        ),
        const _DisplayField(label: 'Contract Period', value: '—'),
      ],
    );
  }

  String _str(String v) => v.isEmpty ? '—' : v;

  String _fmt(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Employee Detail content ───────────────────────────────────────────────────

class _EmployeeDetailContent extends StatelessWidget {
  final EmployeeModel emp;
  const _EmployeeDetailContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    final status = emp.status.isEmpty
        ? '—'
        : emp.status[0].toUpperCase() + emp.status.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          label1: 'Department',  value1: _str(emp.department),  req1: true,
          label2: 'Designation', value2: _str(emp.designation), req2: true,
        ),
        _FieldRow(
          label1: 'Branch',              value1: _str(emp.branch), req1: true,
          label2: 'Reporting Manager',   value2: '—', req2: true,
        ),
        _FieldRow(
          label1: 'Employment Type', value1: '—', req1: true,
          label2: 'Work Location',   value2: _str(emp.branch),
        ),
        const _FieldRow(
          label1: 'Cost Centre',  value1: '—',
          label2: 'Probation End', value2: '—',
        ),
        const _FieldRow(
          label1: 'Confirmation Status', value1: '—',
          label2: 'Grade',               value2: '—',
        ),
        _FieldRow(
          label1: 'Band',            value1: '—',
          label2: 'Employee Status', value2: status,
        ),
        _DisplayField(
          label: 'Self Service Role',
          value: _str(emp.roleDisplay),
        ),
      ],
    );
  }

  String _str(String v) => v.isEmpty ? '—' : v;
}

// ── Personal Detail content ───────────────────────────────────────────────────

class _PersonalDetailContent extends StatelessWidget {
  final EmployeeModel emp;
  const _PersonalDetailContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldRow(
          label1: 'Marital Status', value1: '—',
          label2: 'Spouse Name',    value2: '—',
        ),
        const _FieldRow(
          label1: 'Nationality', value1: '—', req1: true,
          label2: 'Religion',    value2: '—',
        ),
        const _FieldRow(
          label1: 'Blood Group',       value1: '—',
          label2: 'Differently Abled', value2: '—',
        ),
        _FieldRow(
          label1: 'Personal Email', value1: _str(emp.email),
          label2: 'Mobile Number',  value2: _str(emp.phone), req2: true,
        ),
        const _FieldRow(
          label1: 'PAN',     value1: '—', req1: true,
          label2: 'Aadhaar', value2: '—', req2: true,
        ),
        _DisplayField(
          label: 'Login (Work) Email',
          value: _str(emp.email),
          required: true,
        ),
      ],
    );
  }

  String _str(String v) => v.isEmpty ? '—' : v;
}

// ── Field row (2-column layout) ────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label1;
  final String value1;
  final String label2;
  final String value2;
  final bool req1;
  final bool req2;

  const _FieldRow({
    required this.label1,
    required this.value1,
    required this.label2,
    required this.value2,
    this.req1 = false,
    this.req2 = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _DisplayField(
              label: label1,
              value: value1,
              required: req1,
              padBottom: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DisplayField(
              label: label2,
              value: value2,
              required: req2,
              padBottom: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Display field (read-only form-field style) ────────────────────────────────

class _DisplayField extends StatelessWidget {
  final String label;
  final String value;
  final bool required;
  final bool padBottom;

  const _DisplayField({
    required this.label,
    required this.value,
    this.required = false,
    this.padBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty || value == '—';
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              children: required
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isEmpty ? '—' : value,
              style: AppTextStyles.body.copyWith(
                color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar (Cancel + Save) ────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _BottomBar({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Cancel',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Save',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coming soon ───────────────────────────────────────────────────────────────

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.construction_outlined,
                size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text('$label coming soon', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text('This section is under development.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

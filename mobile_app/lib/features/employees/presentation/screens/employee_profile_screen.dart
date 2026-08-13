import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/datasources/employees_remote_datasource.dart';
import '../../data/models/employee_model.dart';
import '../providers/employee_providers.dart';
import '../widgets/add_employee_sheet.dart';
import '../widgets/approval_override_sheet.dart';
import '../widgets/employee_attendance_tab.dart';
import '../widgets/employee_leave_tab.dart';
import '../widgets/promotion_tab.dart';
import '../widgets/wishes_tab.dart';

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
    _tabCtrl = TabController(length: 7, vsync: this);
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
    final err = await updateEmployeeStatusAction(ref, widget.employee.id, value);
    if (!mounted) return;
    if (err != null) {
      setState(() => _isActiveOverride = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ref.invalidate(employeeDetailProvider(widget.employeeId));
      // The Employees list screen (if still mounted underneath this pushed
      // route) otherwise wouldn't notice this status change until the user
      // manually pulls to refresh — see employee_providers.dart's doc
      // comment on employeeListProvider for why it's a separate provider
      // from `employeesProvider` here.
      ref.invalidate(employeeListProvider);
      ref.invalidate(employeeStatsProvider);
    }
    if (mounted) setState(() => _toggling = false);
  }

  Future<void> _onSave() async {
    final ok = await AddEmployeeSheet.show(context, editing: widget.employee);
    if (ok) {
      ref.invalidate(employeeDetailProvider(widget.employeeId));
      ref.invalidate(employeesProvider);
      ref.invalidate(employeeListProvider);
      ref.invalidate(employeeStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Employee updated successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
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
        title: Text('Employee Profile',
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        actions: const [
          NotificationBellButton(),
          SizedBox(width: 4),
        ],
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
                  Tab(text: 'Leave'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'Approval Matrix'),
                  Tab(text: 'Promotion'),
                  Tab(text: 'Benefit'),
                  Tab(text: 'Send Wishes'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _ProfileTab(employee: emp, onEdit: _onSave),
            EmployeeLeaveTab(employee: emp),
            EmployeeAttendanceTab(employee: emp),
            _ApprovalMatrixTab(employee: emp),
            PromotionTab(employee: emp),
            const _ComingSoon(
              label: 'Benefit',
              icon: Icons.card_giftcard_outlined,
            ),
            WishesTab(employee: emp),
          ],
        ),
      ),
    );
  }
}

// ── Date helper ───────────────────────────────────────────────────────────────

String _fmtDate(String raw) {
  if (raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return raw;
  }
}

String _cap(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

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
    final emp = employee;
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, const Color(0xFF2A6ACC)],
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
                          emp.initials,
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
                        child: Icon(Icons.camera_alt_outlined,
                            size: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  emp.fullName,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (emp.employeeId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${emp.employeeId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (emp.employeeId.isNotEmpty &&
                        emp.status.isNotEmpty) ...[
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
                    if (emp.status.isNotEmpty)
                      Text(
                        _cap(emp.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
                      ),
                  ],
                ),
                if (emp.designation.isNotEmpty ||
                    emp.department.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [emp.designation, emp.department]
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
                    value: _fmtDate(emp.dateOfJoining),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    label: 'BRANCH',
                    value: emp.branch.isEmpty ? '—' : emp.branch,
                    icon: Icons.location_on_outlined,
                  ),
                ),
                VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    label: 'DEPT',
                    value: emp.department.isEmpty ? '—' : emp.department,
                    icon: Icons.business_outlined,
                  ),
                ),
              ],
            ),
          ),

          // ── 2-column info row: DOB + Phone ────────────────────────────
          Divider(height: 1, color: AppColors.border),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _InfoCell(
                    label: 'DATE OF BIRTH',
                    value: _fmtDate(emp.dateOfBirth),
                    icon: Icons.cake_outlined,
                  ),
                ),
                VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    label: 'PHONE',
                    value: emp.phone.isEmpty ? '—' : emp.phone,
                    icon: Icons.phone_outlined,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.border),

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

// ── Profile tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final EmployeeModel employee;
  final VoidCallback onEdit;
  const _ProfileTab({required this.employee, required this.onEdit});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  int _sub = 0;

  static const _sections = [
    'Personal',
    'Education & Experience',
    'Bank Details',
    'Emergency Contact',
    'Documents',
  ];

  static const _icons = [
    Icons.person_outlined,
    Icons.school_outlined,
    Icons.account_balance_outlined,
    Icons.local_phone_outlined,
    Icons.folder_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    return ListView(
      // Every TabBarView child here would otherwise inherit the same
      // PrimaryScrollController from the enclosing NestedScrollView — fine
      // on mobile, but on web/desktop the Scrollbar requires exactly one
      // attached ScrollPosition and throws once more than one tab's
      // scrollable shares the controller (all 8 tabs stay mounted via
      // TabBarView's AutomaticKeepAlive once visited).
      primary: false,
      padding: EdgeInsets.zero,
      children: [
        // ── Section pills ──────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: _sections.asMap().entries.map((entry) {
                final index = entry.key;
                final label = entry.value;
                final isSelected = index == _sub;
                return GestureDetector(
                  onTap: () => setState(() => _sub = index),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: index < _sections.length - 1 ? 10 : 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
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
              // Matches the app's other card radius (12) rather than this
        // section's previous one-off 14.
        borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    border: Border(
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
                          _icons[_sub],
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _sections[_sub],
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (_sub == 0)
                        InkWell(
                          onTap: widget.onEdit,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('Edit',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Section content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  child: [
                    _PersonalContent(emp: emp),
                    _EducationContent(emp: emp),
                    _BankContent(emp: emp),
                    _EmergencyContent(emp: emp),
                    _DocumentsContent(emp: emp),
                  ][_sub],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Personal section ──────────────────────────────────────────────────────────

class _PersonalContent extends StatelessWidget {
  final EmployeeModel emp;
  const _PersonalContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          label1: 'Employee ID', value1: _s(emp.employeeId), locked1: true,
          label2: 'Role',        value2: _s(emp.roleDisplay),
        ),
        _FieldRow(
          label1: 'Department',  value1: _s(emp.department),
          label2: 'Designation', value2: _s(emp.designation),
        ),
        _FieldRow(
          label1: 'Date of Birth', value1: _fmtDate(emp.dateOfBirth),
          label2: 'Gender',        value2: _s(emp.gender),
        ),
        _FieldRow(
          label1: 'Marital Status', value1: _s(emp.maritalStatus),
          label2: "Father's Name",  value2: _s(emp.fatherName),
        ),
        _FieldRow(
          label1: 'Blood Group', value1: _s(emp.bloodGroup),
          label2: 'Phone',       value2: _s(emp.phone), locked2: true,
        ),
        _FieldRow(
          label1: 'Reporting Manager',
          value1: emp.reportingManagerName == null || emp.reportingManagerName!.isEmpty
              ? 'Not assigned'
              : emp.reportingManagerName!,
          locked1: true,
          label2: 'HR Contact',
          value2: emp.hrName == null || emp.hrName!.isEmpty
              ? 'Not assigned'
              : emp.hrName!,
          locked2: true,
        ),
        _DisplayField(label: 'Work Email', value: _s(emp.email), locked: true),
        _DisplayField(
          label: 'Current Address',
          value: _s(emp.currentAddress),
          maxLines: 3,
        ),
        _DisplayField(
          label: 'Permanent Address',
          value: _s(emp.permanentAddress),
          maxLines: 3,
          padBottom: false,
        ),
      ],
    );
  }

  String _s(String v) => v.isEmpty ? '—' : v;
}

// ── Education & Experience section ────────────────────────────────────────────

class _EducationContent extends StatelessWidget {
  final EmployeeModel emp;
  const _EducationContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          label1: 'Highest Qualification', value1: _s(emp.highestQualification),
          label2: 'Specialization',        value2: _s(emp.specialization),
        ),
        _DisplayField(
          label: 'Institution / University',
          value: _s(emp.institution),
        ),
        _FieldRow(
          label1: 'Year of Passing',      value1: _s(emp.yearOfPassing),
          label2: 'Total Experience (yrs)', value2: _s(emp.totalExperienceYears),
        ),
        _FieldRow(
          label1: 'Previous Employer',    value1: _s(emp.previousEmployer),
          label2: 'Previous Designation', value2: _s(emp.previousDesignation),
        ),
        _DisplayField(
          label: 'Reason for Leaving',
          value: _s(emp.leavingReason),
          maxLines: 3,
          padBottom: false,
        ),
      ],
    );
  }

  String _s(String v) => v.isEmpty ? '—' : v;
}

// ── Bank Details section ──────────────────────────────────────────────────────

class _BankContent extends StatelessWidget {
  final EmployeeModel emp;
  const _BankContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          label1: 'Account Holder Name', value1: _s(emp.accountHolderName),
          label2: 'Account Type',        value2: _s(emp.accountType),
        ),
        _FieldRow(
          label1: 'Account Number', value1: _s(emp.accountNumber),
          label2: 'IFSC Code',      value2: _s(emp.ifscCode),
        ),
        _FieldRow(
          label1: 'Bank Name',   value1: _s(emp.bankName),
          label2: 'Bank Branch', value2: _s(emp.bankBranch),
        ),
      ],
    );
  }

  String _s(String v) => v.isEmpty ? '—' : v;
}

// ── Emergency Contact section ─────────────────────────────────────────────────

class _EmergencyContent extends StatelessWidget {
  final EmployeeModel emp;
  const _EmergencyContent({required this.emp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldRow(
          label1: 'Contact Name', value1: _s(emp.emergencyName),
          label2: 'Relationship', value2: _s(emp.emergencyRelationship),
        ),
        _FieldRow(
          label1: 'Phone Number', value1: _s(emp.emergencyPhone),
          label2: 'Email',        value2: _s(emp.emergencyEmail),
          padBottom: false,
        ),
      ],
    );
  }

  String _s(String v) => v.isEmpty ? '—' : v;
}

// ── Documents section ─────────────────────────────────────────────────────────
// Real documents only — only pan_card, aadhaar_card, degree_certificate,
// experience_letter, other exist server-side, so there is no fixed slot list
// to show as "Not uploaded" placeholders; just render whatever came back.

// Matches EmployeeDocument.TYPE_CHOICES server-side.
const List<Map<String, String>> _kEmployeeDocTypes = [
  {'value': 'pan_card', 'label': 'PAN Card'},
  {'value': 'aadhaar_card', 'label': 'Aadhaar Card'},
  {'value': 'degree_certificate', 'label': 'Degree Certificate'},
  {'value': 'experience_letter', 'label': 'Experience Letter'},
  {'value': 'other', 'label': 'Other'},
];

class _DocumentsContent extends ConsumerStatefulWidget {
  final EmployeeModel emp;
  const _DocumentsContent({required this.emp});

  @override
  ConsumerState<_DocumentsContent> createState() => _DocumentsContentState();
}

class _DocumentsContentState extends ConsumerState<_DocumentsContent> {
  bool _uploading = false;

  Future<void> _pickAndUpload(String documentType) async {
    // The top-level "Upload Document" button already disabled itself via
    // `_uploading`, but each existing document's "Replace" icon button
    // (_DocCard.onReplace) called straight into this method with no guard
    // of its own — a user could tap Upload, then immediately tap Replace
    // on a different document, firing two concurrent uploads. Both entry
    // points now share this one guard.
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (file.size > 5 * 1024 * 1024) {
      _showMessage('File must be under 5 MB.', isError: true);
      return;
    }

    setState(() => _uploading = true);
    final err = await ref.read(employeesProvider.notifier).uploadDocument(
          widget.emp.employeeId,
          documentType: documentType,
          bytes: file.bytes!,
          filename: file.name,
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (err != null) {
      _showMessage(err, isError: true);
    } else {
      _showMessage('Document uploaded.');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showDocTypePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Select Document Type',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
            ),
            ..._kEmployeeDocTypes.map((t) => ListTile(
                  title: Text(t['label']!, style: AppTextStyles.body),
                  onTap: () => Navigator.pop(context, t['value']),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) await _pickAndUpload(selected);
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _uploading ? null : _showDocTypePicker,
            icon: _uploading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(Icons.upload_outlined, size: 16, color: AppColors.primary),
            label: Text(_uploading ? 'Uploading…' : 'Upload Document'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (emp.documents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined,
                      size: 28, color: AppColors.textHint),
                  const SizedBox(height: 10),
                  Text('No documents uploaded yet.',
                      style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
          )
        else
          ...emp.documents.map((doc) => _DocCard(
                doc: doc,
                onReplace: _uploading ? null : () => _pickAndUpload(doc.documentType),
              )),
      ],
    );
  }
}

String _fmtFileSize(int bytes) {
  if (bytes <= 0) return '';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}

class _DocCard extends StatelessWidget {
  final EmployeeDocumentEntity doc;
  // Null while an upload/replace is already in flight elsewhere on this
  // screen — disables the button rather than leaving it silently ignoring
  // taps, so the user sees the same "can't act right now" feedback the
  // top-level Upload Document button already gives.
  final VoidCallback? onReplace;
  const _DocCard({required this.doc, required this.onReplace});

  Future<void> _open() async {
    final uri = Uri.tryParse(doc.fileUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (doc.uploadedAt.isNotEmpty) _fmtDate(doc.uploadedAt),
      if (doc.fileSize > 0) _fmtFileSize(doc.fileSize),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.insert_drive_file_outlined,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.documentTypeDisplay.isEmpty
                      ? doc.fileName
                      : doc.documentTypeDisplay,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(meta.isEmpty ? doc.fileName : meta,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_outlined,
                size: 18, color: AppColors.textSecondary),
            tooltip: 'Replace',
            onPressed: onReplace,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.visibility_outlined,
                size: 18, color: AppColors.primary),
            tooltip: 'View',
            onPressed: doc.fileUrl.isEmpty ? null : _open,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── 2-column field row ────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label1;
  final String value1;
  final String label2;
  final String value2;
  final bool padBottom;
  // Matches web's Personal card: identity fields the employee/admin can
  // never edit here (Employee ID, Phone, Reporting Manager, HR Contact,
  // Work Email) render with a tinted "locked" style instead of the plain one.
  final bool locked1;
  final bool locked2;

  const _FieldRow({
    required this.label1,
    required this.value1,
    required this.label2,
    required this.value2,
    this.padBottom = true,
    this.locked1 = false,
    this.locked2 = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 14 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _DisplayField(
              label: label1,
              value: value1,
              padBottom: false,
              locked: locked1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DisplayField(
              label: label2,
              value: value2,
              padBottom: false,
              locked: locked2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Read-only display field ───────────────────────────────────────────────────

class _DisplayField extends StatelessWidget {
  final String label;
  final String value;
  final bool padBottom;
  final int maxLines;
  final bool locked;

  const _DisplayField({
    required this.label,
    required this.value,
    this.padBottom = true,
    this.maxLines = 1,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty || value == '—';
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 14 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: locked ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: locked ? AppColors.backgroundLow : AppColors.background,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isEmpty ? '—' : value,
              style: AppTextStyles.body.copyWith(
                color: isEmpty
                    ? AppColors.textHint
                    : (locked ? AppColors.primary : AppColors.textPrimary),
                fontWeight: locked ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: maxLines,
              overflow: maxLines > 1
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _BottomBar({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
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
                side: BorderSide(color: AppColors.border),
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
            child: AppButton(label: 'Save', onPressed: onSave),
          ),
        ],
      ),
    );
  }
}

// ── Coming soon ───────────────────────────────────────────────────────────────

class _ComingSoon extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ComingSoon({required this.label, this.icon = Icons.construction_outlined});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + a min-height constraint (rather than a bare Center)
    // so this still centers normally when there's room, but scrolls instead
    // of overflowing when the tab view is squeezed short (e.g. a small
    // browser window, or a device in landscape with little vertical space).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        // See _ProfileTab's identical primary: false comment above — same
        // shared-PrimaryScrollController hazard applies to every tab here.
        primary: false,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
                  child: Icon(icon, size: 30, color: AppColors.primary),
                ),
                const SizedBox(height: 14),
                Text('$label coming soon', style: AppTextStyles.h4),
                const SizedBox(height: 6),
                Text('This section is under development.',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Approval Matrix tab ────────────────────────────────────────────────────────

class _ApprovalMatrixTab extends ConsumerWidget {
  final EmployeeModel employee;
  const _ApprovalMatrixTab({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrixAsync =
        ref.watch(employeeApprovalMatrixProvider(employee.employeeId));
    // Matches web's ApprovalMatrixTab exactly — it gates the Override action
    // on usePermission("settings.edit"), not a hardcoded role list (role
    // slugs like 'hr_admin' vs the current 'hr' aren't stable across
    // deployments, but permission grants are). Everyone who can reach this
    // screen at all can already VIEW the matrix (gated server-side by the
    // same `employees.view` permission as the profile itself).
    final canEdit =
        ref.watch(authStateProvider).valueOrNull?.user?.hasPermission('settings.edit') ??
            false;

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _ReportingRelationshipsCard(employee: employee, canEdit: canEdit),
        const SizedBox(height: 12),
        matrixAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No approval workflows configured.',
                      style: AppTextStyles.bodySecondary),
                ),
              );
            }
            return Column(
              children: rows
                  .map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ApprovalMatrixCard(
                          employee: employee,
                          row: row,
                          canEdit: canEdit,
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load approval matrix.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reporting Relationships card (Reporting Manager + Branch HR) ──────────────

class _ReportingRelationshipsCard extends StatelessWidget {
  final EmployeeModel employee;
  final bool canEdit;
  const _ReportingRelationshipsCard({required this.employee, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        // Matches the app's other card radius (12) rather than this
        // section's previous one-off 14.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reporting Relationships',
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Reporting manager and branch HR assigned to this employee',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RelationshipCell(
                  icon: Icons.verified_user_outlined,
                  label: 'Reporting Manager',
                  name: employee.reportingManagerName,
                  canEdit: canEdit,
                  onEdit: () async {
                    final ok = await _RelationshipEditDialog.show(
                      context,
                      title: 'Edit Reporting Manager',
                      employee: employee,
                      currentId: employee.reportingManagerId,
                      optionsProvider: employeeManagerOptionsProvider,
                      onSave: (ref, employeeId, selectedId) => ref
                          .read(employeesProvider.notifier)
                          .updateReportingManager(employeeId, selectedId),
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Reporting manager updated.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RelationshipCell(
                  icon: Icons.groups_outlined,
                  label: 'Branch HR',
                  name: employee.hrName,
                  canEdit: canEdit,
                  onEdit: () async {
                    final ok = await _RelationshipEditDialog.show(
                      context,
                      title: 'Edit Branch HR',
                      employee: employee,
                      currentId: employee.hrId,
                      optionsProvider: employeeHrOptionsProvider,
                      onSave: (ref, employeeId, selectedId) => ref
                          .read(employeesProvider.notifier)
                          .updateHr(employeeId, selectedId),
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Branch HR updated.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelationshipCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? name;
  final bool canEdit;
  final VoidCallback onEdit;

  const _RelationshipCell({
    required this.icon,
    required this.label,
    required this.name,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = name == null || name!.isEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  isEmpty ? 'Not assigned' : name!,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canEdit)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.edit_outlined,
                        size: 15, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reporting Relationships edit dialog (shared by Manager + HR) ──────────────

class _RelationshipEditDialog extends ConsumerStatefulWidget {
  final String title;
  final EmployeeModel employee;
  final String? currentId;
  final AutoDisposeFutureProviderFamily<List<EmployeePickerOption>, String>
      optionsProvider;
  final Future<String?> Function(
      WidgetRef ref, String employeeId, String? selectedId) onSave;

  const _RelationshipEditDialog({
    required this.title,
    required this.employee,
    required this.currentId,
    required this.optionsProvider,
    required this.onSave,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required EmployeeModel employee,
    required String? currentId,
    required AutoDisposeFutureProviderFamily<List<EmployeePickerOption>, String>
        optionsProvider,
    required Future<String?> Function(
            WidgetRef ref, String employeeId, String? selectedId)
        onSave,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RelationshipEditDialog(
        title: title,
        employee: employee,
        currentId: currentId,
        optionsProvider: optionsProvider,
        onSave: onSave,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<_RelationshipEditDialog> createState() =>
      _RelationshipEditDialogState();
}

class _RelationshipEditDialogState
    extends ConsumerState<_RelationshipEditDialog> {
  String? _selectedId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentId;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.onSave(
        ref, widget.employee.employeeId, _selectedId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync =
        ref.watch(widget.optionsProvider(widget.employee.branch));
    final options = optionsAsync.valueOrNull ?? [];
    final loading = optionsAsync.isLoading;

    return AlertDialog(
      title: Text(widget.title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 12)),
            const SizedBox(height: 10),
          ],
          Text('Select a specific person, or leave as "— Global default —" to revert.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            hint: Text(loading ? 'Loading…' : '— Global default —'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('— Global default —'),
              ),
              ...options.map((o) => DropdownMenuItem<String?>(
                    value: o.id,
                    child: Text('${o.fullName} (${o.employeeId})',
                        overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: loading ? null : (v) => setState(() => _selectedId = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ApprovalMatrixCard extends StatelessWidget {
  final EmployeeModel employee;
  final EmployeeApprovalMatrixRow row;
  final bool canEdit;

  const _ApprovalMatrixCard({
    required this.employee,
    required this.row,
    required this.canEdit,
  });

  Future<void> _edit(BuildContext context) async {
    final ok = await ApprovalOverrideSheet.show(
      context,
      employee: employee,
      row: row,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${row.workflowLabel} approval overrides updated.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        // Matches the app's other card radius (12) rather than this
        // section's previous one-off 14.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 4),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.workflowLabel,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (canEdit)
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 17, color: AppColors.textSecondary),
                    tooltip: 'Override',
                    onPressed: () => _edit(context),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApproverLine(
                  label: row.l1ApproverLabel.isEmpty
                      ? 'L1 Approver'
                      : row.l1ApproverLabel,
                  name: row.l1ApproverName,
                  isOverride: row.l1IsOverride,
                ),
                const SizedBox(height: 12),
                if (row.isSingleLevel)
                  Row(
                    children: [
                      Text(
                        'L2 Approver',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Pill(label: 'Single level', color: AppColors.textHint),
                    ],
                  )
                else
                  _ApproverLine(
                    label: (row.l2ApproverLabel ?? '').isEmpty
                        ? 'L2 Approver'
                        : row.l2ApproverLabel!,
                    name: row.l2ApproverName,
                    isOverride: row.l2IsOverride,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproverLine extends StatelessWidget {
  final String label;
  final String? name;
  final bool isOverride;

  const _ApproverLine({
    required this.label,
    this.name,
    required this.isOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = name == null || name!.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                isEmpty ? 'Not assigned' : name!,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _Pill(
              label: isOverride ? 'Override' : 'Global default',
              color: isOverride ? AppColors.warning : AppColors.info,
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

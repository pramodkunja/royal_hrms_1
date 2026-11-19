import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/access_control.dart' show AppModules, userHasModule;
import '../../../auth/domain/entities/user_entity.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/permissions/permission_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../separation/presentation/notice_period.dart' show formatNoticePeriod;
import '../../data/datasources/employees_remote_datasource.dart';
import '../../data/models/employee_model.dart';
import '../../domain/experience.dart';
import '../../domain/employee_profile_sections.dart';
import '../providers/employee_providers.dart';
import '../widgets/add_employee_sheet.dart';
import '../widgets/approval_override_sheet.dart';
import '../../../contacts/presentation/screens/contact_matrix_screen.dart' show contactLauncherProvider;
import '../widgets/custom_fields_block.dart';
import '../widgets/employee_assets_tab.dart';
import '../widgets/employee_salary_payroll_tabs.dart' show EmployeePayrollTab, EmployeeSalaryTab;
import '../widgets/employee_attendance_tab.dart';
import '../widgets/employee_file_viewer.dart';
import '../widgets/employee_leave_tab.dart';
import '../widgets/employee_section_edit_sheet.dart';
import '../widgets/promotion_tab.dart';
import '../widgets/reset_password_dialog.dart';
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
          title: Text('Employee Profile', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        ),
        body: detailAsync.isLoading
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('Loading employee…', style: AppTextStyles.bodySecondary),
                ]),
              )
            // Web employees/[id]/page.tsx:381-396.
            : Center(
                child: Padding(
                  key: const Key('employee-not-found'),
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_search_outlined, size: 48, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text('Employee not found', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('No employee exists with code $employeeId.',
                        textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('employee-not-found-back'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Employees'),
                    ),
                  ]),
                ),
              ),
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

class _ProfileShellState extends ConsumerState<_ProfileShell> with TickerProviderStateMixin {
  // Web PROFILE_TABS order. Web ProfileTabBar TAB_MODULES: Salary and
  // Payroll (payroll), Leave, Attendance and Assets only when the
  // company's subscription includes that module (unknown list → shown). The
  // list follows the signed-in user, so a module change (token refresh)
  // updates the tabs; the selected tab is kept when it still exists.
  static const _kTabModules = {
    'salary': AppModules.payroll,
    'payroll': AppModules.payroll,
    'leave': AppModules.leave,
    'attendance': AppModules.attendance,
    'assets': AppModules.assets,
  };
  static const _kAllTabs = [
    'profile', 'salary', 'payroll', 'leave', 'attendance', 'approval',
    'promotion', 'assets', 'wishes', //
  ];

  late TabController _tabCtrl;
  late List<String> _tabKeys;
  bool? _isActiveOverride;
  bool _toggling = false;
  bool _confirmingStatus = false;

  List<String> _keysFor(UserEntity? user) => [
        for (final k in _kAllTabs)
          if (userHasModule(user, _kTabModules[k])) k
      ];

  @override
  void initState() {
    super.initState();
    _tabKeys = _keysFor(ref.read(authStateProvider).valueOrNull?.user);
    _tabCtrl = TabController(length: _tabKeys.length, vsync: this);
    _tabCtrl.addListener(_onTabChange);
  }

  /// Rebuilds the controller when the available tabs change, keeping the
  /// selected tab if it is still there (else Profile).
  void _syncTabs(List<String> keys) {
    if (keys.length == _tabKeys.length && keys.every(_tabKeys.contains)) return;
    final selected = _tabKeys[_tabCtrl.index];
    final index = keys.indexOf(selected);
    _tabCtrl.removeListener(_onTabChange);
    _tabCtrl.dispose();
    _tabKeys = keys;
    _tabCtrl = TabController(length: keys.length, vsync: this, initialIndex: index < 0 ? 0 : index);
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

  /// Web employees/page.tsx "Activate/Deactivate Employee" confirmation:
  /// nothing is sent until the user confirms; Cancel (or dismissing) sends
  /// nothing. While the dialog or the request is open, further taps on the
  /// switch are ignored.
  Future<void> _onToggle(bool value) async {
    if (_toggling || _confirmingStatus) return;
    _confirmingStatus = true;
    final confirmed = await confirmEmployeeStatusChange(
      context,
      fullName: widget.employee.fullName,
      activate: value,
    );
    _confirmingStatus = false;
    if (!confirmed || !mounted) return;
    setState(() {
      _isActiveOverride = value;
      _toggling = true;
    });
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
        // Web employees/[id]/page.tsx:635.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Changes saved successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Education / Bank / Emergency: web edits these sections in place under
  /// employees.edit; here each opens its own form (EmployeeSectionEditSheet),
  /// which saves just that section and reloads the employee.
  Future<void> _onEditSection(EmployeeProfileSection section) async {
    final ok = await EmployeeSectionEditSheet.show(context, widget.employee, section);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Changes saved successfully.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onResetPassword() async {
    final emp = widget.employee;
    final done = await showResetPasswordDialog(
      context,
      // The employee code, as web's API.employees.resetPassword(id).
      employeeId: emp.employeeId.isNotEmpty ? emp.employeeId : widget.employeeId,
      employeeName: emp.fullName,
    );
    if (done == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(done.message),
      // Web: an error-styled toast when the email could not be sent, even
      // though the password did change.
      backgroundColor: done.emailSent == false ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    _syncTabs(_keysFor(ref.watch(authStateProvider).valueOrNull?.user));
    // Editing and activating/deactivating need employees.edit (web
    // employees/[id]/page.tsx canEdit); without it the profile is read-only.
    final canEdit = ref.watch(permissionProvider('employees.edit'));
    // Web employees/[id]/page.tsx: while onboarding is pending/draft the
    // header (with Reset Password) stays, but the tabs and the edit form —
    // which carries is_active — are replaced by "Onboarding form not
    // submitted". The backend itself doesn't lock edits; this is web's UI.
    final pendingOnboarding = emp.isPendingOnboarding;
    final profileCard = _ProfileCard(
      employee: emp,
      isActive: _isActive,
      isToggling: _toggling,
      onToggle: canEdit && !pendingOnboarding ? _onToggle : null,
    );

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
        title: Text('Employee Profile', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          // Web ProfileHeader: "ID Card" (→ /dashboard/employees/<id>/id-card),
          // offered unless the employee's onboarding is still pending.
          // Icon buttons (tooltip + semantics label carry the name): two
          // text-labelled buttons plus the bell squeezed the title to "Em…"
          // on a 411 dp phone (device audit HO-05).
          if (!pendingOnboarding)
            IconButton(
              key: const Key('employee-id-card'),
              visualDensity: VisualDensity.compact,
              tooltip: 'ID Card',
              color: AppColors.primary,
              onPressed: () => context.push(AppRoutes.employeeIdCardPath(widget.employeeId)),
              icon: const Icon(Icons.badge_outlined, size: 20),
            ),
          // Web ProfileHeader: "Reset Password" for employees.edit holders.
          if (canEdit)
            IconButton(
              key: const Key('employee-reset-password'),
              visualDensity: VisualDensity.compact,
              tooltip: 'Reset Password',
              color: AppColors.primary,
              onPressed: _onResetPassword,
              icon: const Icon(Icons.key_outlined, size: 20),
            ),
          const NotificationBellButton(),
          const SizedBox(width: 4),
        ],
        titleSpacing: 8,
        automaticallyImplyLeading: false,
        leadingWidth: 44,
      ),
      // No pinned Cancel / Save bar (device audit HO-06): web's ProfileForm
      // hides its footer in read-only mode and shows it only after "Edit"
      // (readOnly={!isEditing}); here the Personal section's own Edit opens
      // the edit form, which carries its own Cancel / Save. The old bar's
      // "Save" only opened that same form, and its "Cancel" left the page.
      body: pendingOnboarding
          ? ListView(
              key: const Key('employee-pending-onboarding'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                profileCard,
                const SizedBox(height: 12),
                _PendingOnboardingCard(status: emp.onboardingStatus),
              ],
            )
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: profileCard,
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
                      labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                      unselectedLabelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w500),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 2.5,
                      dividerColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      // Web PROFILE_TABS order; Assets replaces the old Benefit
                      // placeholder — web has no Benefits feature.
                      tabs: [
                        for (final k in _tabKeys)
                          switch (k) {
                            'profile' => const Tab(text: 'Profile'),
                            'salary' => const Tab(key: Key('employee-tab-salary'), text: 'Salary'),
                            'payroll' => const Tab(key: Key('employee-tab-payroll'), text: 'Payroll'),
                            'leave' => const Tab(key: Key('employee-tab-leave'), text: 'Leave'),
                            'attendance' => const Tab(key: Key('employee-tab-attendance'), text: 'Attendance'),
                            'approval' => const Tab(text: 'Approval Matrix'),
                            'promotion' => const Tab(text: 'Promotion'),
                            'assets' => const Tab(key: Key('employee-tab-assets'), text: 'Assets'),
                            _ => const Tab(text: 'Send Wishes'),
                          },
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  for (final k in _tabKeys)
                    switch (k) {
                      'profile' => _ProfileTab(
                          employee: emp,
                          onEdit: canEdit ? _onSave : null,
                          onEditSection: canEdit ? _onEditSection : null,
                        ),
                      'salary' => EmployeeSalaryTab(employee: emp),
                      'payroll' => EmployeePayrollTab(employee: emp),
                      'leave' => EmployeeLeaveTab(employee: emp),
                      'attendance' => EmployeeAttendanceTab(employee: emp),
                      'approval' => _ApprovalMatrixTab(employee: emp),
                      'promotion' => PromotionTab(employee: emp),
                      'assets' => EmployeeAssetsTab(employee: emp),
                      _ => WishesTab(employee: emp),
                    },
                ],
              ),
            ),
    );
  }
}

// ── Pending onboarding ────────────────────────────────────────────────────────

/// Web employees/[id]/page.tsx, shown instead of the tabs while the employee
/// hasn't submitted the onboarding form (onboarding_status pending / draft).
class _PendingOnboardingCard extends StatelessWidget {
  const _PendingOnboardingCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final badge = status == 'draft' ? 'Form saved as draft' : 'Awaiting employee submission';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.assignment_outlined, size: 26, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Onboarding form not submitted',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'This employee has not yet submitted their onboarding form for approval. '
            'Profile details will appear here once they submit and HR approves their application.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            key: const Key('employee-onboarding-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined, size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(badge,
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.warning)),
              ],
            ),
          ),
        ],
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
      'Dec',
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
  final ValueChanged<bool>? onToggle; // null: read-only

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
                        border: Border.all(color: Colors.white.withValues(alpha: 0.50), width: 2.5),
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
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Icon(Icons.camera_alt_outlined, size: 13, color: AppColors.primary),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    if (emp.employeeId.isNotEmpty && emp.status.isNotEmpty) ...[
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
                if (emp.designation.isNotEmpty || emp.department.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [emp.designation, emp.department].where((s) => s.isNotEmpty).join(' · '),
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
                VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    label: 'BRANCH',
                    value: emp.branch.isEmpty ? '—' : emp.branch,
                    icon: Icons.location_on_outlined,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
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
                VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                Expanded(
                  child: _InfoCell(
                    key: const Key('employee-header-phone'),
                    label: 'PHONE',
                    value: emp.phone.isEmpty ? '—' : emp.phone,
                    icon: Icons.phone_outlined,
                    // Web ProfileHeader.tsx:145: a tel: link.
                    onTap: emp.phone.isEmpty ? null : () => _callPhone(context, emp.phone),
                  ),
                ),
              ],
            ),
          ),

          // Web ProfileHeader "Current Experience" = experienceFrom(DOJ)
          // (HO-29). Web's "Total Experience" shows the same value (it
          // ignores total_experience_years), so it isn't copied here.
          Divider(height: 1, color: AppColors.border),
          _InfoCell(
            key: const Key('employee-current-experience'),
            label: 'CURRENT EXPERIENCE',
            value: experienceFrom(emp.dateOfJoining),
            icon: Icons.schedule_outlined,
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
  final VoidCallback? onTap;

  const _InfoCell({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cell = _buildCell();
    return onTap == null ? cell : InkWell(onTap: onTap, child: cell);
  }

  Widget _buildCell() {
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
              color: onTap == null ? AppColors.textPrimary : AppColors.primary,
              decoration: onTap == null ? null : TextDecoration.underline,
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
  final VoidCallback? onEdit; // null: read-only
  final ValueChanged<EmployeeProfileSection>? onEditSection; // null: read-only
  const _ProfileTab({required this.employee, required this.onEdit, this.onEditSection});

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
    'EPF / Statutory',
    'Documents',
  ];

  static const _icons = [
    Icons.person_outlined,
    Icons.school_outlined,
    Icons.account_balance_outlined,
    Icons.local_phone_outlined,
    Icons.account_balance_wallet_outlined,
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
                    margin: EdgeInsets.only(right: index < _sections.length - 1 ? 10 : 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
                      if ((_sub == 0 && widget.onEdit != null) ||
                          (_sub >= 1 && _sub <= 4 && widget.onEditSection != null))
                        InkWell(
                          key: Key(
                              'profile-edit-${_sub == 0 ? 'personal' : EmployeeProfileSection.values[_sub - 1].name}'),
                          onTap: _sub == 0
                              ? widget.onEdit
                              : () => widget.onEditSection!(EmployeeProfileSection.values[_sub - 1]),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
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
                    _PersonalContent(emp: emp, canEdit: widget.onEdit != null),
                    _EducationContent(emp: emp, canEdit: widget.onEdit != null),
                    _BankContent(emp: emp, canEdit: widget.onEdit != null),
                    _EmergencyContent(emp: emp, canEdit: widget.onEdit != null),
                    _ProfileSectionView(
                        emp: emp, section: EmployeeProfileSection.statutory, canEdit: widget.onEdit != null),
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

// ── Custom fields (Settings → Onboarding Fields), per section ──────────────────
// Web employees/[id]/page.tsx: each section shows its visible custom fields;
// employees.edit holders edit them (PUT custom_field_values for every
// configured text-type key, merged server-side) and manage file fields.

class _EmployeeCustomFields extends ConsumerWidget {
  final EmployeeModel emp;
  final int step;
  final bool canEdit;
  const _EmployeeCustomFields({required this.emp, required this.step, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomFieldsBlock(
      step: step,
      values: emp.customFieldValues,
      files: emp.customFileFields,
      onSaveText: canEdit
          ? (config, edits) => saveEmployeeCustomFields(
              ref, emp.employeeId, employeeCustomFieldsPayload(config, emp.customFieldValues, edits))
          : null,
      canEditFiles: canEdit,
      // Signed links expire (~1 hour): a fresh employee detail has a new one.
      freshFileUrl: (id) async {
        final fresh = await ref.read(employeesDataSourceProvider).fetchEmployee(emp.employeeId);
        return fresh.customFileFields.where((f) => f.id == id).firstOrNull?.fileUrl;
      },
      onUpload: (key, name, bytes) => uploadEmployeeCustomFile(ref, emp.employeeId, key, name, bytes),
      onDelete: (id) => deleteEmployeeCustomFile(ref, emp.employeeId, id),
    );
  }
}

// ── Personal section ──────────────────────────────────────────────────────────

/// Web PROFILE_SECTIONS "personal" (employees/_data.ts:144-176), in web's
/// order and with web's labels; read-only identity / approver fields are
/// shown locked. Personal-details fields hidden in Settings → Onboarding
/// Fields (step 0) are left out, as web applyFieldConfig.
class _PersonalContent extends ConsumerWidget {
  final EmployeeModel emp;
  final bool canEdit;
  const _PersonalContent({required this.emp, this.canEdit = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(profileFieldConfigProvider).valueOrNull;
    String assigned(String? v) => v == null || v.isEmpty ? 'Not assigned' : v;
    final pairs = <({String? key, String label, String value, bool locked, Key? id})>[
      (key: null, label: 'Employee ID', value: _s(emp.employeeId), locked: true, id: null),
      (key: null, label: 'First Name', value: _s(emp.firstName), locked: true, id: const Key('personal-first-name')),
      (key: null, label: 'Last Name', value: _s(emp.lastName), locked: true, id: const Key('personal-last-name')),
      (key: null, label: 'Login Email', value: _s(emp.email), locked: false, id: const Key('personal-login-email')),
      (key: null, label: 'Phone', value: _s(emp.phone), locked: false, id: null),
      (
        key: null,
        label: 'Date of Joining',
        value: _fmtDate(emp.dateOfJoining),
        locked: false,
        id: const Key('personal-doj')
      ),
      (key: null, label: 'Department', value: _s(emp.department), locked: false, id: null),
      (key: null, label: 'Designation', value: _s(emp.designation), locked: false, id: null),
      (key: null, label: 'Role', value: _s(emp.roleDisplay), locked: false, id: null),
      (key: null, label: 'Branch', value: _s(emp.branch), locked: false, id: const Key('personal-branch')),
      (key: null, label: 'Reporting Manager', value: assigned(emp.reportingManagerName), locked: true, id: null),
      (
        key: null,
        label: 'Reporting Approver',
        value: assigned(emp.reportingApproverName),
        locked: true,
        id: const Key('personal-reporting-approver')
      ),
      (key: null, label: 'Branch HR', value: assigned(emp.hrName), locked: true, id: const Key('personal-branch-hr')),
      // Read-only; set on Settings → Notice Period.
      (
        key: null,
        label: 'Notice Period',
        value: formatNoticePeriod(emp.noticePeriodDays),
        locked: true,
        id: const Key('employee-notice-period')
      ),
      (key: 'date_of_birth', label: 'Date of Birth', value: _fmtDate(emp.dateOfBirth), locked: false, id: null),
      (key: 'gender', label: 'Gender', value: _s(emp.gender), locked: false, id: null),
      (key: 'marital_status', label: 'Marital Status', value: _s(emp.maritalStatus), locked: false, id: null),
      (key: 'father_name', label: "Father's Name", value: _s(emp.fatherName), locked: false, id: null),
      (key: 'blood_group', label: 'Blood Group', value: _s(emp.bloodGroup), locked: false, id: null),
    ].where((f) => f.key == null || isPersonalFieldVisible(f.key!, config)).toList();

    return Column(
      key: const Key('employee-personal-fields'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pairs.length; i += 2)
          if (i + 1 < pairs.length)
            _FieldRow(
              label1: pairs[i].label,
              value1: pairs[i].value,
              locked1: pairs[i].locked,
              key1: pairs[i].id,
              label2: pairs[i + 1].label,
              value2: pairs[i + 1].value,
              locked2: pairs[i + 1].locked,
              key2: pairs[i + 1].id,
            )
          else
            _DisplayField(key: pairs[i].id, label: pairs[i].label, value: pairs[i].value, locked: pairs[i].locked),
        if (isPersonalFieldVisible('current_address', config))
          _DisplayField(
            label: 'Current Address',
            value: _s(emp.currentAddress),
            maxLines: 3,
          ),
        if (isPersonalFieldVisible('permanent_address', config))
          _DisplayField(
            label: 'Permanent Address',
            value: _s(emp.permanentAddress),
            maxLines: 3,
            padBottom: false,
          ),
        _EmployeeCustomFields(emp: emp, step: 0, canEdit: canEdit),
      ],
    );
  }

  String _s(String v) => v.isEmpty ? '—' : v;
}

// ── Education & Experience / Bank Details / Emergency Contact ─────────────────
// Web PROFILE_SECTIONS "education" / "bank" / "emergency": each a single
// record of fields (labels and select labels from employee_profile_sections),
// built-in fields hidden per Settings → Onboarding Fields as web
// applyFieldConfig, then that step's custom fields. Edited through
// EmployeeSectionEditSheet (the header's Edit, employees.edit).

class _EducationContent extends StatelessWidget {
  final EmployeeModel emp;
  final bool canEdit;
  const _EducationContent({required this.emp, this.canEdit = false});

  @override
  Widget build(BuildContext context) =>
      _ProfileSectionView(emp: emp, section: EmployeeProfileSection.education, canEdit: canEdit);
}

class _BankContent extends StatelessWidget {
  final EmployeeModel emp;
  final bool canEdit;
  const _BankContent({required this.emp, this.canEdit = false});

  @override
  Widget build(BuildContext context) =>
      _ProfileSectionView(emp: emp, section: EmployeeProfileSection.bank, canEdit: canEdit);
}

class _EmergencyContent extends StatelessWidget {
  final EmployeeModel emp;
  final bool canEdit;
  const _EmergencyContent({required this.emp, this.canEdit = false});

  @override
  Widget build(BuildContext context) =>
      _ProfileSectionView(emp: emp, section: EmployeeProfileSection.emergency, canEdit: canEdit);
}

class _ProfileSectionView extends ConsumerWidget {
  const _ProfileSectionView({required this.emp, required this.section, required this.canEdit});

  final EmployeeModel emp;
  final EmployeeProfileSection section;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = kEmployeeProfileSections[section]!;
    final config = ref.watch(profileFieldConfigProvider).valueOrNull;
    final values = profileSectionValues(section, emp);
    final fields = def.fields.where((f) => isProfileFieldVisible(section, f.key, config)).toList();
    Widget cell(ProfileFieldDef f) => _DisplayField(
          key: Key('profile-field-${f.key}'),
          label: f.label,
          value: profileFieldDisplay(f, values[f.key] ?? ''),
          maxLines: f.kind == ProfileFieldKind.textarea ? 3 : 1,
        );
    // Two per row like web's grid; a "full" field takes its own row.
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      final next = i + 1 < fields.length ? fields[i + 1] : null;
      if (f.full || next == null || next.full) {
        rows.add(cell(f));
      } else {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: cell(f)), const SizedBox(width: 12), Expanded(child: cell(next))],
        ));
        i++;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        // Web maps no Onboarding Fields step to EPF / Statutory: no custom fields.
        if (def.step != null) _EmployeeCustomFields(emp: emp, step: def.step!, canEdit: canEdit),
        if (section == EmployeeProfileSection.statutory && !emp.statutoryReturned)
          Padding(
            key: const Key('profile-statutory-not-returned'),
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Stored UAN, Aadhaar name and ESI values aren't returned by the server, so they can't be shown here.",
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

// ── Documents section ─────────────────────────────────────────────────────────
// Web ProfileForm DocsCards (ProfileForm.tsx:411-519) + page.tsx
// buildDocEntries: one card per configured visible document type (Settings →
// Document Types, in order; web's built-in list until it loads), "Not
// uploaded" or "{date} · {size}", Upload / Replace and Preview per card. The
// server accepts only configured types ("Invalid document type."), so there
// is no free type picker. Uploads of a type no card shows are listed below
// the cards (web hides them — deliberate difference).

class _DocumentsContent extends ConsumerStatefulWidget {
  final EmployeeModel emp;
  const _DocumentsContent({required this.emp});

  @override
  ConsumerState<_DocumentsContent> createState() => _DocumentsContentState();
}

class _DocumentsContentState extends ConsumerState<_DocumentsContent> {
  /// The type being uploaded (web uploadingDocType); one at a time.
  String? _uploadingType;
  String? _uploadError;

  Future<void> _pickAndUpload(String documentType) async {
    if (_uploadingType != null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    // The server's own limit (EmployeeDocument.MAX_FILE_SIZE); checked first
    // so a large file isn't sent only to be refused.
    if (file.size > 5 * 1024 * 1024) {
      setState(() => _uploadError = 'File must be under 5 MB.');
      return;
    }

    setState(() {
      _uploadingType = documentType;
      _uploadError = null;
    });
    final err = await ref.read(employeesProvider.notifier).uploadDocument(
          widget.emp.employeeId,
          documentType: documentType,
          bytes: file.bytes!,
          filename: file.name,
        );
    if (!mounted) return;
    setState(() {
      _uploadingType = null;
      // Web: the server's message, else "Failed to upload document. Please try again."
      _uploadError = err == null ? null : (err.trim().isEmpty ? 'Failed to upload document. Please try again.' : err);
    });
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Document uploaded.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final config = ref.watch(employeeDocumentTypesProvider).valueOrNull ?? const [];
    final slots = buildEmployeeDocSlots(config, emp.documents);
    final extra = unslottedEmployeeDocs(slots, emp.documents);
    final busy = _uploadingType != null;

    return Column(
      key: const Key('employee-doc-slots'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'All documents uploaded by the employee or '),
            TextSpan(text: 'HR', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        if (_uploadError != null) ...[
          const SizedBox(height: 6),
          Text(_uploadError!,
              key: const Key('employee-doc-upload-error'),
              style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 14),
        for (final slot in slots)
          if (slot.doc != null)
            _DocCard(
              key: ValueKey('doc-${slot.doc!.id}'),
              employeeId: emp.employeeId,
              doc: slot.doc!,
              title: slot.label,
              uploading: _uploadingType == slot.typeKey,
              onReplace: busy ? null : () => _pickAndUpload(slot.typeKey),
            )
          else
            _EmptyDocSlot(
              key: Key('employee-doc-slot-${slot.typeKey}'),
              label: slot.label,
              uploading: _uploadingType == slot.typeKey,
              onUpload: busy ? null : () => _pickAndUpload(slot.typeKey),
            ),
        for (final doc in extra)
          _DocCard(
            key: ValueKey('doc-${doc.id}'),
            employeeId: emp.employeeId,
            doc: doc,
            onReplace: null,
            showReplace: false,
          ),
      ],
    );
  }
}

/// A configured type with nothing uploaded (web: ti-file-off, "Not
/// uploaded", Upload, Preview disabled).
class _EmptyDocSlot extends StatelessWidget {
  const _EmptyDocSlot({super.key, required this.label, required this.uploading, required this.onUpload});
  final String label;
  final bool uploading;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(8)),
          child: uploading
              ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.file_present_outlined, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(uploading ? 'Uploading…' : 'Not uploaded', style: AppTextStyles.caption),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.upload_outlined, size: 18, color: AppColors.textSecondary),
          tooltip: 'Upload document',
          onPressed: uploading ? null : onUpload,
          visualDensity: VisualDensity.compact,
        ),
        const IconButton(
          icon: Icon(Icons.visibility_outlined, size: 18),
          tooltip: 'Not uploaded',
          onPressed: null,
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class _DocCard extends ConsumerStatefulWidget {
  final String employeeId;
  final EmployeeDocumentEntity doc;
  // Null while an upload/replace is already in flight elsewhere on this
  // screen — disables the button rather than leaving it silently ignoring
  // taps, so the user sees the same "can't act right now" feedback the
  // top-level Upload Document button already gives.
  final VoidCallback? onReplace;

  /// The slot's configured name; defaults to the server's type label.
  final String? title;
  final bool uploading;
  const _DocCard({
    super.key,
    required this.employeeId,
    required this.doc,
    required this.onReplace,
    this.title,
    this.uploading = false,
    this.showReplace = true,
  });

  /// False for uploads outside the configured slots (no type to replace into).
  final bool showReplace;

  @override
  ConsumerState<_DocCard> createState() => _DocCardState();
}

class _DocCardState extends ConsumerState<_DocCard> {
  bool _opening = false;
  String? _error;

  // Web DocPreviewModal: the file is fetched (no app login for the file
  // host's signed link) and shown inside the app — PDF, JPG or PNG — with a
  // visible error when it can't be. Previously the raw link was handed to an
  // external browser via canLaunchUrl, which is false on Android 11+ for
  // https without a manifest <queries> entry, so View silently did nothing.
  // See EmployeeDocumentDownloader and ProfileDocumentViewer.
  Future<void> _open() async {
    if (_opening) return;
    final doc = widget.doc;
    final dataSource = ref.read(employeesDataSourceProvider);
    final employeeId = widget.employeeId;
    setState(() {
      _opening = true;
      _error = null;
    });
    final message = await openEmployeeFileInApp(
      context,
      ref,
      id: doc.id,
      url: doc.fileUrl,
      fileName: doc.fileName,
      title: doc.documentTypeDisplay.isEmpty ? doc.fileName : doc.documentTypeDisplay,
      // The signed link expires (~1 hour); a fresh employee detail carries
      // a new one for the same document, or none when it was removed.
      freshUrl: () async {
        final fresh = await dataSource.fetchEmployee(employeeId);
        return fresh.documents.where((d) => d.id == doc.id).firstOrNull?.fileUrl;
      },
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    // Web DocsCards: "{Nov 18, 2026} · {size}" / "Uploading…".
    final meta = widget.uploading
        ? 'Uploading…'
        : [
            if (doc.uploadedAt.isNotEmpty) webShortDate(doc.uploadedAt),
            if (doc.fileSize > 0) webFileSize(doc.fileSize),
          ].join(' · ');
    final title = widget.title ?? (doc.documentTypeDisplay.isEmpty ? doc.fileName : doc.documentTypeDisplay);

    return Container(
      key: Key('employee-doc-${doc.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(meta.isEmpty ? doc.fileName : meta,
                        style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (widget.showReplace)
                IconButton(
                  icon: Icon(Icons.refresh_outlined, size: 18, color: AppColors.textSecondary),
                  tooltip: 'Replace document',
                  onPressed: widget.uploading ? null : widget.onReplace,
                  visualDensity: VisualDensity.compact,
                ),
              if (_opening)
                const Padding(
                  key: Key('employee-doc-opening'),
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  key: Key('employee-doc-view-${doc.id}'),
                  icon: Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                  tooltip: doc.fileUrl.isEmpty ? 'No file to view' : 'Preview document',
                  onPressed: doc.fileUrl.isEmpty ? null : _open,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (_error != null)
            Padding(
              key: Key('employee-doc-error-${doc.id}'),
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ),
                  TextButton(
                    key: Key('employee-doc-retry-${doc.id}'),
                    onPressed: _opening ? null : _open,
                    child: const Text('Retry'),
                  ),
                ],
              ),
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
  // Matches web's Personal card: identity fields the employee/admin can
  // never edit here (Employee ID, Phone, Reporting Manager, HR Contact,
  // Work Email) render with a tinted "locked" style instead of the plain one.
  final bool locked1;
  final bool locked2;
  final Key? key1;
  final Key? key2;

  const _FieldRow({
    required this.label1,
    required this.value1,
    required this.label2,
    required this.value2,
    this.locked1 = false,
    this.locked2 = false,
    this.key1,
    this.key2,
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
              key: key1,
              label: label1,
              value: value1,
              padBottom: false,
              locked: locked1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DisplayField(
              key: key2,
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
    super.key,
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
                color: isEmpty ? AppColors.textHint : (locked ? AppColors.primary : AppColors.textPrimary),
                fontWeight: locked ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              maxLines: maxLines,
              overflow: maxLines > 1 ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ],
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
    final matrixAsync = ref.watch(employeeApprovalMatrixProvider(employee.employeeId));
    // Web ApprovalMatrixTab canEditEmployeeScoped: employees.edit + the
    // employee in the viewer's own branch (org-wide viewers: any branch).
    final canEdit = canEditEmployeeApprovals(ref.watch(authStateProvider).valueOrNull?.user, employee.branch);

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _ReportingRelationshipsCard(employee: employee, canEdit: canEdit),
        const SizedBox(height: 16),
        // Web ApprovalMatrixTab.tsx:442-446: the matrix's own heading.
        Text('Approval Matrix',
            key: const Key('approval-matrix-heading'),
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('By default the global role rules apply. Override below to assign a specific person for this employee.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        matrixAsync.when(
          skipLoadingOnRefresh: false,
          data: (rows) {
            if (rows.isEmpty) {
              return Padding(
                key: const Key('approval-matrix-empty'),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No approval matrix configured.', style: AppTextStyles.bodySecondary),
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
          loading: () => Padding(
            key: const Key('approval-matrix-loading'),
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Loading approval matrix…', style: AppTextStyles.bodySecondary),
            ]),
          ),
          error: (e, _) {
            final err = approvalMatrixLoadError(e);
            final denied = err.kind == ApprovalMatrixLoadErrorKind.forbidden;
            return Container(
              key: Key('approval-matrix-error-${err.kind.name}'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(denied ? Icons.lock_outline : Icons.error_outline, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(err.message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                  ),
                ]),
                // A permission refusal won't change on retry; anything else may.
                if (!denied)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('approval-matrix-retry'),
                      onPressed: () => ref.invalidate(employeeApprovalMatrixProvider(employee.employeeId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
              ]),
            );
          },
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
          Text('Reporting Relationships', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Used as the default approvers for all workflows unless overridden below',
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
                      onSave: (ref, employeeId, selectedId) =>
                          ref.read(employeesProvider.notifier).updateReportingManager(employeeId, selectedId),
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
                      onSave: (ref, employeeId, selectedId) =>
                          ref.read(employeesProvider.notifier).updateHr(employeeId, selectedId),
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
                    child: Icon(Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
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
  final AutoDisposeFutureProviderFamily<List<EmployeePickerOption>, String> optionsProvider;
  final Future<String?> Function(WidgetRef ref, String employeeId, String? selectedId) onSave;

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
    required AutoDisposeFutureProviderFamily<List<EmployeePickerOption>, String> optionsProvider,
    required Future<String?> Function(WidgetRef ref, String employeeId, String? selectedId) onSave,
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
  ConsumerState<_RelationshipEditDialog> createState() => _RelationshipEditDialogState();
}

class _RelationshipEditDialogState extends ConsumerState<_RelationshipEditDialog> {
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
    final err = await widget.onSave(ref, widget.employee.employeeId, _selectedId);
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
    final optionsAsync = ref.watch(widget.optionsProvider(widget.employee.branch));
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
          // Web RelationshipEditorModal (ApprovalMatrixTab.tsx:47-115):
          // "Select person", "— Select —" placeholder, no way to clear the
          // relationship, Save disabled until someone is picked.
          Text('Select person', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('relationship-picker-${options.length}'),
            initialValue: options.any((o) => o.id == _selectedId) ? _selectedId : null,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            hint: Text(loading ? 'Loading…' : '— Select —'),
            items: [
              for (final o in options)
                DropdownMenuItem<String>(
                  value: o.id,
                  child: Text('${o.fullName} (${o.employeeId})', overflow: TextOverflow.ellipsis),
                ),
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
          key: const Key('relationship-save'),
          onPressed: _saving || loading || _selectedId == null || _selectedId!.isEmpty ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                    icon: Icon(Icons.edit_outlined, size: 17, color: AppColors.textSecondary),
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
                  label: row.l1ApproverLabel.isEmpty ? 'L1 Approver' : row.l1ApproverLabel,
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
                    label: (row.l2ApproverLabel ?? '').isEmpty ? 'L2 Approver' : row.l2ApproverLabel!,
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

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  // A new controller or tab list (module change) must reach the header.
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar.controller != tabBar.controller || old.tabBar.tabs.length != tabBar.tabs.length;
}

/// Web employees/page.tsx Activate/Deactivate confirm modal: title
/// "<Activate|Deactivate> Employee", "Are you sure you want to
/// <activate|deactivate> <b>Full Name</b>?", Cancel and a confirm button
/// (red for Deactivate). True only when confirmed — and only once, however
/// fast the button is tapped.
Future<bool> confirmEmployeeStatusChange(
  BuildContext context, {
  required String fullName,
  required bool activate,
}) async {
  final label = activate ? 'Activate' : 'Deactivate';
  var done = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      void close(bool result) {
        if (done) return;
        done = true;
        Navigator.of(dialogContext).pop(result);
      }

      return AlertDialog(
        key: const Key('employee-status-confirm'),
        title: Text('$label Employee'),
        content: Text.rich(
          TextSpan(
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, height: 1.6),
            children: [
              TextSpan(text: 'Are you sure you want to ${label.toLowerCase()} '),
              TextSpan(text: fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('employee-status-cancel'),
            onPressed: () => close(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('employee-status-confirm-button'),
            style: activate ? null : FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => close(true),
            child: Text(label),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Opens the dialer for [phone] (web's `tel:` link); says so when it can't.
Future<void> _callPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final launcher = ProviderScope.containerOf(context).read(contactLauncherProvider);
  var opened = false;
  try {
    opened = await launcher(Uri(scheme: 'tel', path: phone));
  } catch (_) {}
  if (!opened) {
    messenger.showSnackBar(SnackBar(
      content: const Text('Could not open the dialer.'),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

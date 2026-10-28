import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/presentation/providers/branch_providers.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
import '../widgets/leave_dashboard_tab.dart';
import '../widgets/apply_leave_tab.dart';
import '../widgets/leave_approvals_tab.dart';
import '../widgets/team_calendar_tab.dart';
import '../widgets/leave_analytics_tab.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool? _isEmployeeForController;
  final List<String> _selectedBranches = [];

  // Approvals is hidden for plain employees — matches the web frontend's
  // LeavePageClient (ALL_TABS.approvals.hideForEmployee), since a self-only
  // request queue would show "Approve/Reject" buttons that just 403
  // (backend blocks approving your own leave request).
  void _ensureController(bool isEmployee) {
    if (_tabController != null && _isEmployeeForController == isEmployee) {
      return;
    }
    _tabController?.dispose();
    _tabController = TabController(length: isEmployee ? 4 : 5, vsync: this);
    _isEmployeeForController = isEmployee;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String get _branchLabel {
    if (_selectedBranches.isEmpty) return 'All Branches';
    if (_selectedBranches.length == 1) return _selectedBranches.first;
    return '${_selectedBranches.length} Branches';
  }

  Future<void> _openBranchSheet() async {
    // _BranchSheet watches branchListProvider itself (see below) instead of
    // this reading a snapshot up front — a plain `ref.read()` here would
    // capture the provider mid-AsyncLoading on its very first use (it's
    // autoDispose and nothing else in this screen keeps it warm), showing
    // "No branches loaded" forever even though the fetch was actually still
    // in flight and would have resolved moments later.
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BranchSheet(
        initial: List.from(_selectedBranches),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedBranches
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _selectedBranches.isNotEmpty;
    final role =
        ref.watch(authStateProvider).valueOrNull?.user?.role ?? 'employee';
    final isEmployee = role == 'employee';
    // Branch filter is system_admin only — matches web's LeavePageClient
    // (BranchFilterSelect only renders for isSystemAdmin). manager/hr_admin
    // are already branch-scoped server-side and never need it; employees
    // only ever see their own requests.
    final isSystemAdmin = role == 'system_admin';
    _ensureController(isEmployee);
    final tabController = _tabController!;

    final tabs = [
      const Tab(text: 'Dashboard'),
      const Tab(text: 'Apply Leave'),
      if (!isEmployee) const Tab(text: 'Approvals'),
      const Tab(text: 'Calendar'),
      const Tab(text: 'Analytics'),
    ];
    final tabViews = [
      LeaveDashboardTab(
        onApprovals: isEmployee ? null : () => tabController.animateTo(2),
        selectedBranches: _selectedBranches,
      ),
      ApplyLeaveTab(
        onDashboard: () => tabController.animateTo(0),
      ),
      if (!isEmployee) LeaveApprovalsTab(selectedBranches: _selectedBranches),
      const TeamCalendarTab(),
      const LeaveAnalyticsTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (blue hero) ─────────────────────────────────────────────
            BlueHeroBanner(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leave Management',
                            style:
                                AppTextStyles.h4.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          'Apply, approve and track leave requests',
                          style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  if (isSystemAdmin) const SizedBox(width: 8),
                  // Branch selector button
                  if (isSystemAdmin)
                    GestureDetector(
                      onTap: _openBranchSheet,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: hasFilter
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasFilter
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_outlined,
                                size: 13,
                                color: hasFilter
                                    ? AppColors.primary
                                    : Colors.white),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 80),
                              child: Text(
                                _branchLabel,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: hasFilter
                                      ? AppColors.primary
                                      : Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasFilter) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${_selectedBranches.length}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 3),
                            Icon(Icons.expand_more,
                                size: 15,
                                color: hasFilter
                                    ? AppColors.primary
                                    : Colors.white70),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Tab bar (pinned, plain background) ──────────────────────────────
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelStyle: AppTextStyles.label.copyWith(fontSize: 12),
                unselectedLabelStyle:
                    AppTextStyles.label.copyWith(fontSize: 12),
                dividerColor: AppColors.border,
                padding: EdgeInsets.zero,
              ),
            ),

            // ── Tab content ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
      // Hidden while already on the Apply Leave tab (index 1 in both the
      // employee's 4-tab and approver's 5-tab layout) — redundant there.
      //
      // Scoped to its own ListenableBuilder (rather than a TabController
      // listener calling setState on the whole screen, as this used to do)
      // so switching tabs no longer reconstructs `tabs`/`tabViews` and
      // reruns every tab body's build()/ref.watch calls just to show or
      // hide this button — only this small builder re-evaluates on tab
      // change now. Trade-off: Scaffold's built-in FAB show/hide scale
      // transition no longer applies here (the property it receives is
      // always a non-null widget), so the button appears/disappears
      // instantly instead of animating — everything else about it is
      // unchanged.
      floatingActionButton: ListenableBuilder(
        listenable: tabController,
        builder: (context, _) => tabController.index == 1
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                heroTag: 'leave-apply-fab',
                onPressed: () => tabController.animateTo(1),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Apply My Leave',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }
}

// ── Branch selector bottom sheet ──────────────────────────────────────────────

class _BranchSheet extends ConsumerStatefulWidget {
  final List<String> initial;
  const _BranchSheet({required this.initial});

  @override
  ConsumerState<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends ConsumerState<_BranchSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initial);
  }

  void _toggle(String branch) {
    setState(() {
      if (_selected.contains(branch)) {
        _selected.remove(branch);
      } else {
        _selected.add(branch);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final branchesAsync = ref.watch(branchListProvider);
    final branches =
        branchesAsync.valueOrNull?.map((b) => b.branchName).toList() ??
            const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),

        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.business_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('FILTER BY BRANCH',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontSize: 11)),
              const Spacer(),
              if (_selected.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: Text('Clear',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.border),

        // Branch list
        if (branchesAsync.isLoading && branches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          )
        else if (branchesAsync.hasError && branches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text('Could not load branches. Pull down to retry.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          )
        else if (branches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text('No branches found.',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          ),
        for (final branch in branches)
          InkWell(
            onTap: () => _toggle(branch),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              color: _selected.contains(branch)
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _selected.contains(branch)
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _selected.contains(branch)
                            ? AppColors.primary
                            : AppColors.border,
                        width: _selected.contains(branch) ? 0 : 1.5,
                      ),
                    ),
                    child: _selected.contains(branch)
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(branch,
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 13,
                            fontWeight: _selected.contains(branch)
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _selected.contains(branch)
                                ? AppColors.textPrimary
                                : AppColors.textSecondary)),
                  ),
                  if (_selected.contains(branch))
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        Divider(height: 1, color: AppColors.border),

        // Apply button
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Show All Branches'
                    : 'Apply (${_selected.length} selected)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

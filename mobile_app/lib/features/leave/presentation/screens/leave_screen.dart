import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../branches/presentation/providers/branch_providers.dart';
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
  late final TabController _tabController;
  final List<String> _selectedBranches = [];

  static const _tabs = [
    Tab(text: 'Dashboard'),
    Tab(text: 'Apply Leave'),
    Tab(text: 'Approvals'),
    Tab(text: 'Calendar'),
    Tab(text: 'Analytics'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _branchLabel {
    if (_selectedBranches.isEmpty) return 'All Branches';
    if (_selectedBranches.length == 1) return _selectedBranches.first;
    return '${_selectedBranches.length} Branches';
  }

  Future<void> _openBranchSheet() async {
    final branches = ref
        .read(branchListProvider)
        .valueOrNull
        ?.map((b) => b.branchName)
        .toList() ?? [];
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BranchSheet(
        branches: branches,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + Tab bar (pinned) ─────────────────────────────────────
            Container(
              color: AppColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title + subtitle
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Leave Management', style: AppTextStyles.h4),
                              const SizedBox(height: 2),
                              Text(
                                'Apply, approve and track leave requests',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Branch selector button
                        GestureDetector(
                          onTap: _openBranchSheet,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: hasFilter
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : AppColors.backgroundLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: hasFilter
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business_outlined,
                                    size: 13,
                                    color: hasFilter
                                        ? AppColors.primary
                                        : AppColors.textSecondary),
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
                                          : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasFilter) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(
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
                                        : AppColors.textHint),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: _tabs,
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
                ],
              ),
            ),

            // ── Tab content ───────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  LeaveDashboardTab(
                    onApply: () => _tabController.animateTo(1),
                    onApprovals: () => _tabController.animateTo(2),
                    selectedBranches: _selectedBranches,
                  ),
                  ApplyLeaveTab(
                    onDashboard: () => _tabController.animateTo(0),
                  ),
                  const LeaveApprovalsTab(),
                  const TeamCalendarTab(),
                  const LeaveAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Branch selector bottom sheet ──────────────────────────────────────────────

class _BranchSheet extends StatefulWidget {
  final List<String> branches;
  final List<String> initial;
  const _BranchSheet({required this.branches, required this.initial});

  @override
  State<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends State<_BranchSheet> {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        const SizedBox(height: 10),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),

        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.business_outlined,
                  size: 15, color: AppColors.primary),
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
        const Divider(height: 1, color: AppColors.border),

        // Branch list
        if (widget.branches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text('No branches loaded.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          ),
        for (final branch in widget.branches)
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
                    width: 20, height: 20,
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
                    const Icon(Icons.check_circle,
                        size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        const Divider(height: 1, color: AppColors.border),

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

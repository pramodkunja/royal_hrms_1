import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';
import 'leave_request_detail_sheet.dart';

// Matches the reference web dashboard's BALANCE_DISPLAY exactly — icon + color
// per type is deliberately distinct from the LEAVE_TYPE_CONFIG identity colors
// used elsewhere (Apply tab, calendar): casual=success, earned=primary, sick=info.
// Only these 3 leave types get a summary card here (LWP/maternity/paternity excluded too).
final _kBalanceDisplay = [
  (code: 'casual', icon: Icons.check_circle_outline, color: AppColors.success),
  (
    code: 'earned',
    icon: Icons.calendar_month_outlined,
    color: AppColors.primary
  ),
  (code: 'sick', icon: Icons.medical_services_outlined, color: AppColors.info),
];

// Web's LeaveDashboard.tsx scopeLabel — subtitle on the approver's Pending card.
// Role names: 'manager__team_lead' is this deployment's current value for
// managers ('manager' was a legacy alias); 'hr' is current for HR ('hr_admin'
// legacy) — mirrors the backend's own _is_hr_role() aliasing.
String _scopeLabel(String role) => switch (role) {
      'manager' || 'manager__team_lead' => "Your team's requests",
      'hr' || 'hr_admin' => 'Your branch requests',
      _ => 'Organisation-wide requests',
    };

// ── Date formatter (ISO → 'D MMM') ───────────────────────────────────────────

String _fmtIso(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const m = [
      '',
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
      'Dec'
    ];
    return '${d.day} ${m[d.month]}';
  } catch (_) {
    return iso;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class LeaveDashboardTab extends ConsumerStatefulWidget {
  final VoidCallback? onApprovals;
  final List<String> selectedBranches;

  const LeaveDashboardTab({
    super.key,
    this.onApprovals,
    this.selectedBranches = const [],
  });

  @override
  ConsumerState<LeaveDashboardTab> createState() => _LeaveDashboardTabState();
}

class _LeaveDashboardTabState extends ConsumerState<LeaveDashboardTab> {
  bool _actionLoading = false;

  // Web's LeaveDashboard.tsx: two distinct sub-tabs for approver roles —
  // "pending" (the real scope=team approval queue) vs "mine" (their own
  // leave history, fetched with no scope param at all).
  bool _showPending = true;

  // Only ever non-empty for system_admin — the branch selector button that
  // feeds this is hidden for every other role (see leave_screen.dart). The
  // backend's `branch` query param only accepts one value, so a multi-select
  // narrows to the first pick. Switching branches keys a fresh provider
  // instance (family arg changes), so there's no separate page to reset.
  String get _branchFilter =>
      widget.selectedBranches.isEmpty ? '' : widget.selectedBranches.first;

  // Dashboard never filters by department — that's Approvals-tab-only
  // (matches web's LeaveApprovals.tsx, where LeaveDashboard.tsx has no
  // department filter either).
  LeaveTeamFilter get _teamFilter =>
      (branch: _branchFilter, department: '');

  void _showSnackError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _promptRejectReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.cancel_outlined,
                  size: 17, color: AppColors.error),
            ),
            const SizedBox(width: 10),
            Text('Reject Request', style: AppTextStyles.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejection Reason *',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText:
                      'Explain why this leave request is being rejected…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveTeam(String id) async {
    setState(() => _actionLoading = true);
    final err = await ref
        .read(leaveTeamPendingProvider(_teamFilter).notifier)
        .approveRequest(id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) _showSnackError(err);
  }

  Future<void> _rejectTeam(String id) async {
    final reason = await _promptRejectReason();
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await ref
        .read(leaveTeamPendingProvider(_teamFilter).notifier)
        .rejectRequest(id, reason);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) _showSnackError(err);
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(leaveBalancesProvider);
    final myRequestsAsync = ref.watch(leaveRequestsProvider);
    final authAsync = ref.watch(authStateProvider);

    final role = authAsync.valueOrNull?.user?.role ?? 'employee';
    final isEmployee = role == 'employee';

    final myRequests = myRequestsAsync.valueOrNull ?? [];

    // Approver's real approval queue — only fetched/watched for non-employee
    // roles, but watched unconditionally (regardless of which sub-tab is
    // active) so the "Pending Approvals" count on the stat card and the tab
    // pill badge always reflect the live server-side count.
    final teamAsync =
        isEmployee ? null : ref.watch(leaveTeamPendingProvider(_teamFilter));
    final teamPage = teamAsync?.valueOrNull;

    final pendingCount = isEmployee
        ? myRequests.where((r) => r.isPending).length
        : (teamPage?.count ?? 0);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(leaveBalancesProvider);
        ref.invalidate(leaveRequestsProvider);
        if (!isEmployee) ref.invalidate(leaveTeamPendingProvider);
      },
      child: CustomScrollView(
        slivers: [
          // ── Balance cards ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text('LEAVE BALANCE',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6)),
                ),
                SizedBox(
                  height: 116,
                  // The Pending Approvals/My Pending card must always render
                  // regardless of how leaveBalancesProvider is doing — it has
                  // its own independent data source (leaveTeamPendingProvider
                  // / myRequests) and previously sat entirely inside
                  // balancesAsync.when()'s `data` branch, so a slow or failed
                  // balances fetch (an unrelated dataset) silently hid the
                  // pending count/card too. Build it unconditionally, and
                  // only the balance cards themselves vary with
                  // balancesAsync's state.
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _PendingCountCard(
                          count: pendingCount,
                          label: isEmployee ? 'My Pending' : 'Pending Approvals',
                          subtitle: isEmployee
                              ? 'Awaiting approval'
                              : _scopeLabel(role),
                          onTap: isEmployee ? null : widget.onApprovals,
                        ),
                      ),
                      ...balancesAsync.when(
                        loading: () => [
                          SizedBox(
                            width: 260,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                        error: (_, __) => [
                          SizedBox(
                            width: 220,
                            child: Center(
                              child: Text('Could not load balances',
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.error)),
                            ),
                          ),
                        ],
                        data: (items) {
                          final byType = {
                            for (final b in items) b.typeCode.toLowerCase(): b
                          };
                          // Always render all 3 cards, defaulting to 0/0 when
                          // the backend has no balance record yet — matches
                          // web's BALANCE_DISPLAY.map(), which never hides a
                          // card for missing data (see LeaveDashboard.tsx).
                          return _kBalanceDisplay.map((d) {
                            final b = byType[d.code];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _BalanceCard(
                                label: isEmployee
                                    ? (b?.typeName ??
                                        LeaveTypeColors.labelForCode(d.code))
                                    : 'My ${LeaveTypeColors.shortLabelForCode(d.code)}',
                                available: b?.available ?? 0,
                                total: b?.total ?? 0,
                                icon: d.icon,
                                color: d.color,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── AI Insight ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 15, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: 'Tip: ',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w700)),
                        TextSpan(
                            text: 'Pull down to refresh your leave data. '
                                'Apply early to allow time for approval.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.info)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isEmployee)
            ..._employeeRequestSlivers(myRequests, myRequestsAsync)
          else
            ..._approverRequestSlivers(
                role, myRequests, myRequestsAsync, teamAsync, teamPage),
        ],
      ),
    );
  }

  // ── Employee: single "My Leave Requests" list (unchanged from before) ──────

  List<Widget> _employeeRequestSlivers(
    List<LeaveRequestEntity> myRequests,
    AsyncValue<List<LeaveRequestEntity>> myRequestsAsync,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Icon(Icons.list_alt_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('My Leave Requests',
                    style: AppTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      if (myRequestsAsync.isLoading)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
        )
      else if (myRequestsAsync.hasError)
        SliverToBoxAdapter(
          child: AppErrorState(
            message: friendlyLeaveError(myRequestsAsync.error!),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            onRetry: () => ref.invalidate(leaveRequestsProvider),
          ),
        )
      else if (myRequests.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined,
                    size: 44, color: AppColors.textHint),
                const SizedBox(height: 10),
                Text('No leave requests yet.',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final r = myRequests[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => showLeaveRequestDetailSheet(
                      ctx,
                      initial: r,
                      canApprove: r.canApprove,
                    ),
                    child: _RequestCard(
                      request: r,
                      actionLoading: false,
                      onApprove: null,
                      onReject: null,
                    ),
                  ),
                );
              },
              childCount: myRequests.length,
            ),
          ),
        ),
    ];
  }

  // ── Approver: "Pending Approvals" (scope=team) / "My Leave Requests" ───────

  List<Widget> _approverRequestSlivers(
    String role,
    List<LeaveRequestEntity> myRequests,
    AsyncValue<List<LeaveRequestEntity>> myRequestsAsync,
    AsyncValue<LeaveLoadMoreState>? teamAsync,
    LeaveLoadMoreState? teamPage,
  ) {
    final pendingCount = teamPage?.count ?? 0;
    final hasBranchFilter = _branchFilter.isNotEmpty;

    return [
      // ── Sub-tab pills ─────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              _TabPill(
                label: 'Pending Approvals',
                count: pendingCount,
                selected: _showPending,
                onTap: () => setState(() => _showPending = true),
              ),
              const SizedBox(width: 8),
              _TabPill(
                label: 'My Leave Requests',
                selected: !_showPending,
                onTap: () => setState(() => _showPending = false),
              ),
            ],
          ),
        ),
      ),

      // ── Header + Apply button ────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Icon(Icons.list_alt_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _showPending ? 'Pending Approvals' : 'My Leave Requests',
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),

      if (_showPending)
        ..._teamPendingSlivers(teamAsync, teamPage, hasBranchFilter)
      else
        ..._myRequestsSlivers(myRequests, myRequestsAsync),
    ];
  }

  List<Widget> _teamPendingSlivers(
    AsyncValue<LeaveLoadMoreState>? teamAsync,
    LeaveLoadMoreState? teamPage,
    bool hasBranchFilter,
  ) {
    if (teamAsync == null || teamAsync.isLoading) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
        ),
      ];
    }
    if (teamAsync.hasError) {
      return [
        SliverToBoxAdapter(
          child: AppErrorState(
            message: friendlyLeaveError(teamAsync.error!),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            onRetry: () =>
                ref.invalidate(leaveTeamPendingProvider(_teamFilter)),
          ),
        ),
      ];
    }
    final results = teamPage?.items ?? const <LeaveRequestEntity>[];
    if (results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined,
                    size: 44, color: AppColors.textHint),
                const SizedBox(height: 10),
                Text(
                  hasBranchFilter
                      ? 'No requests for the selected branch.'
                      : 'No pending leave requests.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final r = results[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => showLeaveRequestDetailSheet(
                    ctx,
                    initial: r,
                    canApprove: r.canApprove,
                  ),
                  child: _RequestCard(
                    request: r,
                    actionLoading: _actionLoading,
                    onApprove: r.canApprove ? () => _approveTeam(r.id) : null,
                    onReject: r.canApprove ? () => _rejectTeam(r.id) : null,
                  ),
                ),
              );
            },
            childCount: results.length,
          ),
        ),
      ),
      if (teamPage!.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: teamPage.loadingMore
                ? Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : _LoadMoreButton(
                    onTap: () => ref
                        .read(leaveTeamPendingProvider(_teamFilter).notifier)
                        .loadMore(),
                  ),
          ),
        )
      else
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
    ];
  }

  List<Widget> _myRequestsSlivers(
    List<LeaveRequestEntity> myRequests,
    AsyncValue<List<LeaveRequestEntity>> myRequestsAsync,
  ) {
    if (myRequestsAsync.isLoading) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
        ),
      ];
    }
    if (myRequestsAsync.hasError) {
      return [
        SliverToBoxAdapter(
          child: AppErrorState(
            message: friendlyLeaveError(myRequestsAsync.error!),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            onRetry: () => ref.invalidate(leaveRequestsProvider),
          ),
        ),
      ];
    }
    if (myRequests.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined,
                    size: 44, color: AppColors.textHint),
                const SizedBox(height: 10),
                Text('You have not applied for any leave yet.',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final r = myRequests[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => showLeaveRequestDetailSheet(
                    ctx,
                    initial: r,
                    canApprove: r.canApprove,
                  ),
                  child: _RequestCard(
                    request: r,
                    actionLoading: false,
                    onApprove: null,
                    onReject: null,
                  ),
                ),
              );
            },
            childCount: myRequests.length,
          ),
        ),
      ),
    ];
  }
}

// ── Sub-tab pill (mirrors leave_approvals_tab.dart's _SubTabPill for visual
// consistency between the Dashboard's and Approvals tab's pending/history
// splits) ─────────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary)),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.warning)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Load more button (mirrors audit_screen.dart's _LoadMoreBtn for visual
// consistency — appears once the user has scrolled to the end of the loaded
// items, appends the next page instead of replacing the list) ───────────────

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.expand_more, size: 18),
          label: const Text('Load more'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}

// ── Balance Card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final String label;
  final double available;
  final double total;
  final IconData icon;
  final Color color;
  const _BalanceCard({
    required this.label,
    required this.available,
    required this.total,
    required this.icon,
    required this.color,
  });

  static String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(_fmt(available),
                        style: AppTextStyles.h3
                            .copyWith(color: color, fontSize: 20)),
                    Text('of ${_fmt(total)} days left',
                        style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending Count Card ────────────────────────────────────────────────────────

class _PendingCountCard extends StatelessWidget {
  final int count;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  const _PendingCountCard({
    required this.count,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap != null
                ? AppColors.warning.withValues(alpha: 0.3)
                : AppColors.border,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 1),
                      Text('$count',
                          style: AppTextStyles.h3.copyWith(
                              color: AppColors.warning, fontSize: 20)),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.done_all,
                      size: 13, color: AppColors.warning),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0,
                backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.warning),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final LeaveRequestEntity request;
  final bool actionLoading;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _RequestCard({
    required this.request,
    required this.actionLoading,
    this.onApprove,
    this.onReject,
  });

  static Color _statusColor(String s) => switch (s) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        'cancelled' => AppColors.textSecondary,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(request.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: sc),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              request.employee.isNotEmpty
                                  ? request.employee
                                  : 'You',
                              style: AppTextStyles.label.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 1),
                          if (request.branch.isNotEmpty)
                            Text(request.branch,
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withValues(alpha: 0.3)),
                      ),
                      child: Text(request.status,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: sc)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          LeaveTypeColors.shortLabelForCode(
                              request.leaveTypeCode),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(request.leaveType,
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 11, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_fmtIso(request.from)} – ${_fmtIso(request.to)}',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${request.days}d',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ),
                  ],
                ),
                if (request.isPending &&
                    onApprove != null &&
                    onReject != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: actionLoading ? null : onApprove,
                          icon: const Icon(Icons.check, size: 13),
                          label: const Text('Approve',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            // See the identical note in leave_approvals_tab's
                            // Approve button — AppColors.success is also the
                            // "already approved" status-pill fill, and
                            // Attendance's equivalent action already uses
                            // primary, so this aligns Leave with that.
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: actionLoading ? null : onReject,
                          icon: const Icon(Icons.close, size: 13),
                          label: const Text('Reject',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (request.isRejected && request.rejectReason != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.message_outlined,
                            size: 10, color: AppColors.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(request.rejectReason!,
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.error, fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

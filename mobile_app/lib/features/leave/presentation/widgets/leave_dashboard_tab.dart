import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';

// Matches the reference web dashboard's BALANCE_DISPLAY exactly — icon + color
// per type is deliberately distinct from the LEAVE_TYPE_CONFIG identity colors
// used elsewhere (Apply tab, calendar): casual=success, earned=primary, sick=info.
// Only these 3 leave types get a summary card here (LWP/maternity/paternity excluded too).
const _kBalanceDisplay = [
  (code: 'casual', icon: Icons.check_circle_outline,     color: AppColors.success),
  (code: 'earned', icon: Icons.calendar_month_outlined,  color: AppColors.primary),
  (code: 'sick',   icon: Icons.medical_services_outlined, color: AppColors.info),
];

// Web's LeaveDashboard.tsx scopeLabel — subtitle on the approver's Pending card.
String _scopeLabel(String role) => switch (role) {
  'manager'  => "Your team's requests",
  'hr_admin' => 'Your branch requests',
  _          => 'Organisation-wide requests',
};

// ── Date formatter (ISO → 'D MMM') ───────────────────────────────────────────

String _fmtIso(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month]}';
  } catch (_) {
    return iso;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class LeaveDashboardTab extends ConsumerStatefulWidget {
  final VoidCallback onApply;
  final VoidCallback? onApprovals;
  final List<String> selectedBranches;

  const LeaveDashboardTab({
    super.key,
    required this.onApply,
    this.onApprovals,
    this.selectedBranches = const [],
  });

  @override
  ConsumerState<LeaveDashboardTab> createState() => _LeaveDashboardTabState();
}

class _LeaveDashboardTabState extends ConsumerState<LeaveDashboardTab> {
  bool _actionLoading = false;

  Future<void> _approve(String id) async {
    setState(() => _actionLoading = true);
    final err = await ref
        .read(leaveRequestsProvider.notifier)
        .approveRequest(id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(String id) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.cancel_outlined, size: 17, color: AppColors.error),
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
                    fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 300,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Explain why this leave request is being rejected…'),
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
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await ref
        .read(leaveRequestsProvider.notifier)
        .rejectRequest(id, reason);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(leaveBalancesProvider);
    final requestsAsync = ref.watch(leaveRequestsProvider);
    final authAsync     = ref.watch(authStateProvider);

    final role       = authAsync.valueOrNull?.user?.role ?? 'employee';
    final isEmployee = role == 'employee';

    final allRequests = requestsAsync.valueOrNull ?? [];
    final filteredRequests = widget.selectedBranches.isEmpty
        ? allRequests
        : allRequests
            .where((r) => widget.selectedBranches.contains(r.branch))
            .toList();
    final pendingCount =
        allRequests.where((r) => r.isPending).length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(leaveBalancesProvider);
        ref.invalidate(leaveRequestsProvider);
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
                  child: balancesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Could not load balances',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error)),
                    ),
                    data: (items) {
                      final byType = {
                        for (final b in items) b.typeCode.toLowerCase(): b
                      };
                      // Always render all 3 cards, defaulting to 0/0 when the
                      // backend has no balance record yet — matches web's
                      // BALANCE_DISPLAY.map(), which never hides a card for
                      // missing data (see LeaveDashboard.tsx).
                      final balanceCards = _kBalanceDisplay.map((d) {
                        final b = byType[d.code];
                        return _BalanceCard(
                          label: isEmployee
                              ? (b?.typeName ?? LeaveTypeColors.labelForCode(d.code))
                              : 'My ${LeaveTypeColors.shortLabelForCode(d.code)}',
                          available: b?.available ?? 0,
                          total: b?.total ?? 0,
                          icon: d.icon,
                          color: d.color,
                        );
                      }).toList();

                      return ListView(
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
                          ...balanceCards.map((c) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: c,
                              )),
                        ],
                      );
                    },
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
                  const Icon(Icons.auto_awesome_outlined,
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

          // ── Requests header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_outlined,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.selectedBranches.isEmpty
                          ? 'Recent Leave Requests'
                          : 'Requests · ${filteredRequests.length} shown',
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: widget.onApply,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Apply My Leave',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading requests ────────────────────────────────────────────────
          if (requestsAsync.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            )

          // ── Error ───────────────────────────────────────────────────────────
          else if (requestsAsync.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Text('Could not load requests: ${requestsAsync.error}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.error)),
              ),
            )

          // ── Empty ───────────────────────────────────────────────────────────
          else if (filteredRequests.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 44, color: AppColors.textHint),
                    const SizedBox(height: 10),
                    Text(
                      widget.selectedBranches.isEmpty
                          ? 'No leave requests yet.'
                          : 'No requests found for the selected branch.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )

          // ── Request cards ───────────────────────────────────────────────────
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final r = filteredRequests[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RequestCard(
                        request: r,
                        actionLoading: _actionLoading,
                        onApprove:
                            r.isPending ? () => _approve(r.id) : null,
                        onReject:
                            r.isPending ? () => _showRejectDialog(r.id) : null,
                      ),
                    );
                  },
                  childCount: filteredRequests.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
                        style: AppTextStyles.h3.copyWith(color: color, fontSize: 20)),
                    Text('of ${_fmt(total)} days left',
                        style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Container(
                width: 26, height: 26,
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
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.warning, fontSize: 20)),
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
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.done_all,
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
                    const AlwaysStoppedAnimation<Color>(AppColors.warning),
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
    'approved'  => AppColors.success,
    'rejected'  => AppColors.error,
    'cancelled' => AppColors.textSecondary,
    _           => AppColors.warning,
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
                          Text(request.employee.isNotEmpty
                                  ? request.employee
                                  : 'You',
                              style:
                                  AppTextStyles.label.copyWith(fontSize: 13),
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
                        border:
                            Border.all(color: sc.withValues(alpha: 0.3)),
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
                    const Icon(Icons.calendar_month_outlined,
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side:
                                const BorderSide(color: AppColors.error),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (request.isRejected &&
                    request.rejectReason != null) ...[
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
                        const Icon(Icons.message_outlined,
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

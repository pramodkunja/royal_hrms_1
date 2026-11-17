import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';
import 'leave_number_format.dart';
import 'leave_request_detail_sheet.dart';
import 'package:mobile_app/core/network/api_client.dart';

// Web LeaveDashboard.tsx BALANCE_DISPLAY, in its order and with its labels —
// casual=success, sick=info, earned=primary (deliberately distinct from the
// LEAVE_TYPE_CONFIG identity colors used elsewhere). The fourth card is
// Loss of Pay (see _LopCard); maternity / paternity get no card, as on web.
final _kBalanceDisplay = [
  (code: 'casual', label: 'Casual Leave', icon: Icons.check_circle_outline, color: AppColors.success),
  (code: 'sick', label: 'Sick Leave', icon: Icons.medical_services_outlined, color: AppColors.info),
  (code: 'earned', label: 'Earned Leave', icon: Icons.calendar_month_outlined, color: AppColors.primary),
];

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

/// Web leave/_components/LeaveDashboard.tsx: the signed-in user's own leave —
/// balances and their own requests — for every role. Approving other
/// people's leave happens only in the Approvals screen (web removed it from
/// the Leave page), so the old mobile-only "Pending Approvals" queue with
/// Approve / Reject, chosen by role name, is gone (Task 71 finding M3).
class LeaveDashboardTab extends ConsumerStatefulWidget {
  const LeaveDashboardTab({super.key});

  @override
  ConsumerState<LeaveDashboardTab> createState() => _LeaveDashboardTabState();
}

class _LeaveDashboardTabState extends ConsumerState<LeaveDashboardTab> {
  @override
  Widget build(BuildContext context) {
    // Dashboard-only balances for web's calendar year (myLeaveBalancesProvider).
    final balancesAsync = ref.watch(myLeaveBalancesProvider);
    // Web renders the cards from `balances ?? []` — zeros while loading, for
    // a missing row, or when the request fails.
    final byType = {
      for (final b in balancesAsync.valueOrNull ?? const <LeaveBalanceEntity>[]) b.typeCode.toLowerCase(): b
    };
    final myRequestsAsync = ref.watch(leaveRequestsProvider);
    final myRequests = myRequestsAsync.valueOrNull ?? [];
    // Loss of Pay "Used" falls back to the own-scope stats when there is no
    // lwp balance row (web: stats?.lop_days ?? 0).
    final lopDaysTaken = ref.watch(myLeaveStatsProvider).valueOrNull?.lopDays;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // Re-reading the year first: a refresh after New Year asks for the
        // new year's balances and stats.
        ref.invalidate(leaveDashboardYearProvider);
        ref.invalidate(myLeaveBalancesProvider);
        ref.invalidate(leaveRequestsProvider);
        ref.invalidate(myLeaveStatsProvider);
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
                // Sized by its tallest card (no fixed height), so larger text
                // or text scaling grows the strip instead of overflowing it;
                // the cards share that height. Web's four cards: Casual,
                // Sick, Earned, Loss of Pay (no mobile-only My Pending card;
                // pending requests show in My Leave Requests below).
                SingleChildScrollView(
                  key: const Key('leave-balance-cards'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final d in _kBalanceDisplay)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _BalanceCard(
                              key: Key('leave-balance-card-${d.code}'),
                              label: d.label,
                              used: byType[d.code]?.used ?? 0,
                              total: byType[d.code]?.total ?? 0,
                              icon: d.icon,
                              color: d.color,
                            ),
                          ),
                        _LopCard(
                          key: const Key('leave-balance-card-lop'),
                          balance: byType['lwp'],
                          lopDaysTaken: lopDaysTaken,
                        ),
                      ],
                    ),
                  ),
                ),
                // Mobile addition: web shows the zero cards silently when
                // the balance request fails; here the failure is also named.
                if (balancesAsync.hasError && !balancesAsync.isLoading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      userFriendlyMessage(balancesAsync.error!),
                      key: const Key('leave-balance-error'),
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
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

          ..._myRequestSlivers(myRequests, myRequestsAsync),
        ],
      ),
    );
  }

  // ── "My Leave Requests" (web LeaveDashboard's own requests) ───────────────

  List<Widget> _myRequestSlivers(
    List<LeaveRequestEntity> myRequests,
    AsyncValue<List<LeaveRequestEntity>> myRequestsAsync,
  ) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Icon(Icons.list_alt_outlined, size: 15, color: AppColors.primary),
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
                    child: _RequestCard(request: r),
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

// ── Balance Card ──────────────────────────────────────────────────────────────

/// Web LeaveDashboard.tsx balance card: Available = total − used (not
/// clamped, so it can be negative), "Available", the bar at
/// round(used / total × 100)% (0 when total is 0), then "Used: x" and
/// "Total: y". Values are the server's, shown as JS Number() would.
class _BalanceCard extends StatelessWidget {
  final String label;
  final double used;
  final double total;
  final IconData icon;
  final Color color;
  const _BalanceCard({
    super.key,
    required this.label,
    required this.used,
    required this.total,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final available = total - used;
    // Web: width = round(used / total * 100)%; the bar box clips anything
    // beyond 100%, and a negative width is no fill.
    final pct = total > 0 ? ((used / total * 100).round() / 100).clamp(0.0, 1.0) : 0.0;
    final caption = AppTextStyles.caption.copyWith(fontSize: 10);
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
                    Text(label, style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(leaveDays(available),
                        key: const ValueKey('available'),
                        style: AppTextStyles.h3.copyWith(color: color, fontSize: 20)),
                    Text('Available', style: caption),
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
          const SizedBox(height: 6),
          // Wrap: at large text scales the pair stacks instead of overflowing.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              Text('Used: ${leaveDays(used)}', key: const ValueKey('used'), style: caption),
              Text('Total: ${leaveDays(total)}', key: const ValueKey('total'), style: caption),
            ],
          ),
        ],
      ),
    );
  }
}

/// A day count as web prints `Number(x)`: whole numbers without decimals,
/// otherwise every significant digit (1.5, 1.25 — never rounded).
String leaveDays(double v) => formatLeaveDays(v);

// ── Loss of Pay Card ──────────────────────────────────────────────────────────

/// Web LeaveDashboard.tsx "Loss of Pay (LOP)", in days:
///  - with an `lwp` balance row: Available = total − used, Used, Total, and
///    the bar at used / total;
///  - without one (most policies don't cap LWP): Available "—", Used = the
///    own-scope stats lop_days (approved requests' LOP days this year, 0
///    when absent), Total "No cap", an empty bar.
/// Nothing is calculated here beyond web's own total − used.
class _LopCard extends StatelessWidget {
  final LeaveBalanceEntity? balance;
  final double? lopDaysTaken;
  const _LopCard({super.key, required this.balance, required this.lopDaysTaken});

  static String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final b = balance;
    final color = AppColors.warning;
    final used = b?.used ?? lopDaysTaken ?? 0;
    final pct = b != null && b.total > 0 ? (b.used / b.total).clamp(0.0, 1.0) : 0.0;
    final caption = AppTextStyles.caption.copyWith(fontSize: 10);
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
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loss of Pay (LOP)', style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(b != null ? _fmt(b.available) : '—',
                        key: const Key('leave-lop-available'),
                        style: AppTextStyles.h3.copyWith(color: color, fontSize: 20)),
                    Text('Available', style: caption),
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
                child: Icon(Icons.money_off_outlined, size: 13, color: color),
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
          const SizedBox(height: 6),
          // Wrap, not Row: at large text scales the pair stacks instead of
          // overflowing the fixed card width.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              Text('Used: ${_fmt(used)}', key: const Key('leave-lop-used'), style: caption),
              Text(b != null ? 'Total: ${_fmt(b.total)}' : 'Total: No cap',
                  key: const Key('leave-lop-total'), style: caption),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final LeaveRequestEntity request;
  const _RequestCard({required this.request});

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
                          key: Key('leave-request-status-${request.id}'),
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

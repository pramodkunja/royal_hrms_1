import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../leave/presentation/providers/leave_providers.dart';
import '../../../leave/presentation/widgets/leave_request_detail_sheet.dart';
import '../../data/models/employee_model.dart';

// Mirrors leave_dashboard_tab.dart's _kBalanceDisplay convention exactly —
// same icon/color per leave type, so the "3 balance cards" visual identity
// stays consistent across the whole Leave feature (Dashboard, this HR tab).
final _kBalanceDisplay = [
  (code: 'casual', icon: Icons.check_circle_outline, color: AppColors.success),
  (
    code: 'earned',
    icon: Icons.calendar_month_outlined,
    color: AppColors.primary
  ),
  (code: 'sick', icon: Icons.medical_services_outlined, color: AppColors.info),
];

// ── Date formatter (ISO → 'D MMM') — mirrors leave_dashboard_tab.dart/
// leave_approvals_tab.dart's private helper of the same name. ────────────────

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

String _fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso.length >= 10 ? iso.substring(0, 10) : iso);
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
    return '${d.day} ${m[d.month]} ${d.year}';
  } catch (_) {
    return iso;
  }
}

String _fmtNum(num v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

// ── Widget ────────────────────────────────────────────────────────────────────

/// Employee Profile "Leave" tab (HR/admin view of another employee's leave
/// data) — mirrors web's LeaveTab.tsx. Read-only aside from the existing
/// Approve/Reject actions surfaced inside [showLeaveRequestDetailSheet] for
/// rows the viewer can actually act on (gated by the request's own
/// `canApprove`, same convention as everywhere else in this app).
class EmployeeLeaveTab extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const EmployeeLeaveTab({super.key, required this.employee});

  @override
  ConsumerState<EmployeeLeaveTab> createState() => _EmployeeLeaveTabState();
}

class _EmployeeLeaveTabState extends ConsumerState<EmployeeLeaveTab> {
  late int _year;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  void _changeYear(int delta) {
    setState(() {
      _year += delta;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final empId = widget.employee.employeeId;
    final statsAsync =
        ref.watch(employeeLeaveStatsProvider((empId, _year)));
    final requestsAsync =
        ref.watch(employeeLeaveRequestsProvider((empId, _year, _page)));

    return ListView(
      // See employee_profile_screen.dart's _ProfileTab for why this is
      // required (shared PrimaryScrollController from the enclosing
      // NestedScrollView across every kept-alive TabBarView child).
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _YearNavigator(
          year: _year,
          onPrev: () => _changeYear(-1),
          onNext: () => _changeYear(1),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 116,
          child: statsAsync.when(
            data: (stats) => _buildStatsRow(stats),
            loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Could not load leave stats.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.list_alt_outlined,
                size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Leave Requests', style: AppTextStyles.label),
          ],
        ),
        const SizedBox(height: 10),
        requestsAsync.when(
          data: _buildRequestsSection,
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child:
                Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
                'Could not load requests: ${friendlyLeaveError(e)}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  // ── Stat / balance cards row ────────────────────────────────────────────

  Widget _buildStatsRow(LeaveStatsEntity stats) {
    final byType = {
      for (final b in stats.balances) b.leaveTypeCode.toLowerCase(): b
    };
    final balanceCards = _kBalanceDisplay.map((d) {
      final b = byType[d.code];
      return _BalanceCard(
        label: b?.leaveTypeDisplay ?? LeaveTypeColors.labelForCode(d.code),
        available: b?.available ?? 0,
        total: b?.totalDays ?? 0,
        icon: d.icon,
        color: d.color,
      );
    }).toList();

    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        ...balanceCards.map((c) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: c,
            )),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _MiniStatCard(
            label: 'Pending Requests',
            value: '${stats.pending}',
            subtitle: 'In $_year',
            icon: Icons.pending_actions_outlined,
            color: AppColors.warning,
          ),
        ),
        _MiniStatCard(
          label: 'Loss of Pay (LOP)',
          value: _fmtNum(stats.lopDays),
          subtitle:
              '${stats.lopRequests} request${stats.lopRequests == 1 ? '' : 's'} in $_year',
          icon: Icons.money_off_outlined,
          color: AppColors.error,
        ),
      ],
    );
  }

  // ── Requests list + pagination ──────────────────────────────────────────

  Widget _buildRequestsSection(LeaveRequestPageEntity page) {
    if (page.results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined,
                  size: 44, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text('No leave requests found for $_year.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...page.results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => showLeaveRequestDetailSheet(
                  context,
                  initial: r,
                  canApprove: r.canApprove,
                ),
                child: _LeaveRequestRow(request: r),
              ),
            )),
        const SizedBox(height: 6),
        _PaginationBar(
          page: page.page,
          totalPages: page.totalPages,
          onPrev: page.page > 1 ? () => setState(() => _page--) : null,
          onNext:
              page.page < page.totalPages ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

// ── Year navigator ────────────────────────────────────────────────────────────

class _YearNavigator extends StatelessWidget {
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _YearNavigator({
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: onPrev,
            color: AppColors.textSecondary,
          ),
          Expanded(
            child: Center(
              child: Text('$year', style: AppTextStyles.labelLarge),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            onPressed: onNext,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ── Balance card (mirrors leave_dashboard_tab.dart's _BalanceCard) ──────────

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

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (available / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
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
                    Text(_fmtNum(available),
                        style: AppTextStyles.h3
                            .copyWith(color: color, fontSize: 20)),
                    Text('of ${_fmtNum(total)} days left',
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

// ── Mini stat card (mirrors leave_dashboard_tab.dart's _PendingCountCard,
// generalized for Pending Requests / LOP so both share the same visual
// identity as the balance cards beside them) ─────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
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
                    Text(value,
                        style: AppTextStyles.h3
                            .copyWith(color: color, fontSize: 20)),
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
              value: 0,
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

// ── Leave request row (mirrors leave_approvals_tab.dart's _ApprovalCard
// visual style, adapted with LOP badge + approver/actioned-date footer) ─────

class _LeaveRequestRow extends StatelessWidget {
  final LeaveRequestEntity request;
  const _LeaveRequestRow({required this.request});

  static Color _statusColor(String s) => switch (s) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        'cancelled' => AppColors.textSecondary,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final r = request;
    final sc = _statusColor(r.status);
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          LeaveTypeColors.shortLabelForCode(r.leaveTypeCode),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r.leaveType,
                          style: AppTextStyles.label.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
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
                      child: Text(r.status,
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
                    Icon(Icons.calendar_month_outlined,
                        size: 11, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_fmtIso(r.from)} – ${_fmtIso(r.to)}',
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
                      child: Text('${r.days}d',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w700,
                              fontSize: 10)),
                    ),
                    if (r.hasLopDays) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Text('LOP ${_fmtNum(r.lopDays)}d',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_outlined,
                        size: 10, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(
                        r.appliedOn.isEmpty
                            ? 'Applied —'
                            : 'Applied ${_fmtIso(r.appliedOn)}',
                        style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_outline,
                        size: 10, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        r.approvedBy.isNotEmpty
                            ? '${r.approvedBy} · ${_fmtDateTime(r.approvedAt)}'
                            : 'Not yet actioned',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (r.isRejected && r.rejectReason != null) ...[
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
                          child: Text(r.rejectReason!,
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

// ── Pagination bar (Prev/Next + "Page X of Y" — a simple bar precedent,
// since audit_screen.dart's own pagination is a plain Prev/Next row too) ─────

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Prev'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Page $page of $totalPages',
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Next'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

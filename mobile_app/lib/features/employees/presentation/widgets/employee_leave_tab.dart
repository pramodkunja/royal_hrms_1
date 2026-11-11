import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../leave/presentation/providers/leave_providers.dart';
import '../../../leave/presentation/widgets/leave_request_detail_sheet.dart';
import '../../../leave/presentation/widgets/leave_type_presentation.dart';
import '../../../settings/data/models/leave_policy_model.dart';
import '../../../settings/presentation/providers/settings_providers.dart' show leavePoliciesProvider;
import '../../data/models/employee_model.dart';
import '../../../dashboard/data/models/employee_leave_breakdown.dart' show LeaveStatementMonth, formatLeaveNumber;
import 'leave_credits_section.dart';
import 'monthly_leave_statement.dart';

// Web LeaveTab CURATED_STYLE: the bespoke icon/colour this tab uses for these
// 3 types specifically. Every other type is resolved like web's
// leaveTypeMap (resolveLeaveTypePresentation): built-in config, else the
// custom-type defaults.
final _kBalanceDisplay = [
  (code: 'casual', icon: Icons.check_circle_outline, color: AppColors.success),
  (code: 'earned', icon: Icons.calendar_month_outlined, color: AppColors.primary),
  (code: 'sick', icon: Icons.medical_services_outlined, color: AppColors.info),
];

// ── Date formatter (ISO → 'D MMM') — mirrors leave_dashboard_tab.dart/
// leave_approvals_tab.dart's private helper of the same name. ────────────────

String _fmtIso(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month]}';
  } catch (_) {
    return iso;
  }
}

String _fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso.length >= 10 ? iso.substring(0, 10) : iso);
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

  // Web LeaveTab: the Annual / Monthly view and the selected month live here,
  // so switching views (or years) keeps both. A null month means web's
  // defaultMonth(year) — the current month this year, Dec for a past year,
  // Jan for a future one.
  String _view = 'annual';
  int? _month;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  void didUpdateWidget(EmployeeLeaveTab old) {
    super.didUpdateWidget(old);
    // Another employee: nothing of the previous one's selection carries over.
    // (Stats and requests are keyed by employee code, so no stale data.)
    if (old.employee.employeeId != widget.employee.employeeId) {
      _page = 1;
      _month = null;
    }
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
    final statsAsync = ref.watch(employeeLeaveStatsProvider((empId, _year)));
    final requestsAsync = ref.watch(employeeLeaveRequestsProvider((empId, _year, _page)));

    // Web: Loss of Pay has its own card, so its balance row never shows as a
    // leave type; each type goes to the view matching its policy's
    // credit_schedule, unknown schedules are listed apart (never guessed).
    final stats = statsAsync.valueOrNull;
    final balances = (stats?.balances ?? const <BalanceSummaryEntity>[])
        .where((b) => b.leaveTypeCode.toLowerCase() != 'lwp')
        .toList();
    final groups = splitBySchedule(balances);
    final selectedMonth = _month ?? defaultStatementMonth(_year);
    // Web: useFetch(API.leave.policy) → buildLeaveTypesList, for custom leave
    // type labels. Not loaded / failed: the balance's own name (as web).
    _policies = ref.watch(leavePoliciesProvider).valueOrNull;

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
        if (statsAsync.hasError && stats == null)
          // Web LeaveTab: a failed stats load replaces the tab's content with
          // the server's message (alert-error). Mobile keeps the year
          // navigator and the separately loaded requests below, and adds Retry.
          _StatsErrorAlert(
            message: friendlyLeaveError(statsAsync.error!),
            retrying: statsAsync.isLoading,
            onRetry: () => ref.invalidate(employeeLeaveStatsProvider((empId, _year))),
          )
        else ...[
          _ViewSelector(
            view: _view,
            annualCount: groups.annual.length,
            monthlyCount: groups.monthly.length,
            onView: (v) => setState(() => _view = v),
          ),
          if (groups.unclassified.isNotEmpty) ...[
            const SizedBox(height: 12),
            _UnclassifiedWarning(rows: groups.unclassified, labelOf: _labelOf),
          ],
          const SizedBox(height: 14),
          statsAsync.when(
            // A refetch after an adjustment keeps showing the current figures.
            skipLoadingOnRefresh: true,
            // A failed refetch keeps the figures already shown.
            skipError: true,
            data: (stats) => _buildStatsRow(stats, groups, selectedMonth),
            loading: () => SizedBox(
              height: 116,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            // A first-load failure is handled above by _StatsErrorAlert.
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          if (_view == 'annual')
            // Web LeaveTab mounts this in its Annual view (schedule="annual");
            // it renders nothing for users who may not manage these credits.
            LeaveCreditsSection(employeeId: empId)
          else if (stats != null && groups.monthly.isNotEmpty) ...[
            MonthlyCreditsTable(
              rows: [
                for (final b in groups.monthly)
                  MonthlyCreditsRow(
                    leaveType: b.leaveTypeCode,
                    label: _labelOf(b),
                    month: statementMonthOf(b.statement, selectedMonth),
                    hasStatement: b.statement != null,
                  ),
              ],
              year: _year,
              month: selectedMonth,
              onMonth: (m) => setState(() => _month = m),
            ),
            for (final (i, b) in groups.monthly.where((b) => b.statement != null).indexed) ...[
              const SizedBox(height: 14),
              MonthlyLeaveStatementCard(
                // Web key `${leave_type}-${year}`: a new year starts a fresh card.
                key: ValueKey('${b.leaveTypeCode}-$_year'),
                leaveType: b.leaveTypeCode,
                label: _labelOf(b),
                year: _year,
                stmt: b.statement!,
                total: b.totalDays,
                used: b.usedDays,
                available: b.available,
                defaultOpen: i == 0,
              ),
            ],
          ],
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.list_alt_outlined, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Leave Requests', style: AppTextStyles.label),
          ],
        ),
        const SizedBox(height: 10),
        requestsAsync.when(
          data: _buildRequestsSection,
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Could not load requests: ${friendlyLeaveError(e)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ),
      ],
    );
  }

  // ── Stat / balance cards row ────────────────────────────────────────────

  Widget _buildStatsRow(
    LeaveStatsEntity stats,
    ({
      List<BalanceSummaryEntity> annual,
      List<BalanceSummaryEntity> monthly,
      List<BalanceSummaryEntity> unclassified
    }) groups,
    int selectedMonth,
  ) {
    final monthly = _view == 'monthly';
    final visible = monthly ? groups.monthly : groups.annual;

    final cards = <Widget>[
      for (final b in visible)
        if (monthly)
          _MonthlyBalanceCard(
            key: ValueKey('employee-leave-card-${b.leaveTypeCode}'),
            label: _labelOf(b),
            available: b.available,
            thisMonth: statementMonthOf(b.statement, selectedMonth),
            totalCredited: b.statement?.totalCredited,
            year: _year,
            icon: _styleOf(b).icon,
            color: _styleOf(b).color,
          )
        else
          _BalanceCard(
            key: ValueKey('employee-leave-card-${b.leaveTypeCode}'),
            label: _labelOf(b),
            available: b.available,
            total: b.totalDays,
            used: b.usedDays,
            icon: _styleOf(b).icon,
            color: _styleOf(b).color,
          ),
      _MiniStatCard(
        label: 'Pending Requests',
        value: '${stats.pending}',
        subtitle: 'Awaiting approval',
        icon: Icons.pending_actions_outlined,
        color: AppColors.warning,
      ),
      _MiniStatCard(
        label: 'Loss of Pay (LOP)',
        value: _fmtNum(stats.lopDays),
        subtitle: '${stats.lopRequests} request${stats.lopRequests == 1 ? '' : 's'} in $_year',
        icon: Icons.money_off_outlined,
        color: AppColors.error,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visible.isEmpty) ...[
          _EmptyScheduleCard(monthly: monthly),
          const SizedBox(height: 10),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in cards.indexed)
                  Padding(padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 10), child: c),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<LeavePolicyModel>? _policies;

  LeaveTypePresentation _present(BalanceSummaryEntity b) =>
      resolveLeaveTypePresentation(code: b.leaveTypeCode, balanceDisplay: b.leaveTypeDisplay, policies: _policies);

  /// Web labelOf: leaveTypeMap[leave_type]?.label ?? leave_type_display.
  String _labelOf(BalanceSummaryEntity b) => _present(b).label;

  /// Web: CURATED_STYLE for casual/earned/sick, else the resolved type's
  /// icon and colour (custom types: web's neutral defaults).
  ({IconData icon, Color color}) _styleOf(BalanceSummaryEntity b) {
    final curated = _kBalanceDisplay.where((d) => d.code == b.leaveTypeCode).firstOrNull;
    if (curated != null) return (icon: curated.icon, color: curated.color);
    final p = _present(b);
    return (icon: p.icon, color: p.color);
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
              Icon(Icons.business_outlined, size: 44, color: AppColors.textHint),
              const SizedBox(height: 10),
              Text('No leave requests found for $_year.',
                  style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
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
          onNext: page.page < page.totalPages ? () => setState(() => _page++) : null,
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
            key: const Key('employee-leave-year-prev'),
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
            key: const Key('employee-leave-year-next'),
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
  final double used;
  final IconData icon;
  final Color color;
  const _BalanceCard({
    super.key,
    required this.label,
    required this.available,
    required this.total,
    required this.used,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Web: progress = used / total.
    final pct = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
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
                    Text(_fmtNum(available), style: AppTextStyles.h3.copyWith(color: color, fontSize: 20)),
                    Text('of ${_fmtNum(total)} days left', style: AppTextStyles.caption.copyWith(fontSize: 10)),
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

// ── Annual / Monthly view selector (web LeaveTab role="tablist") ───────────

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({
    required this.view,
    required this.annualCount,
    required this.monthlyCount,
    required this.onView,
  });
  final String view;
  final int annualCount;
  final int monthlyCount;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    Widget chip(String v, String text, IconData icon) => ChoiceChip(
          key: Key('employee-leave-view-$v'),
          avatar: Icon(icon, size: 15, color: view == v ? Colors.white : AppColors.primary),
          label: Text(text),
          labelStyle: AppTextStyles.caption
              .copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: view == v ? Colors.white : AppColors.primary),
          selected: view == v,
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          onSelected: (_) => onView(v),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          chip('annual', 'Annual leave ($annualCount)', Icons.calendar_today_outlined),
          chip('monthly', 'Monthly leave ($monthlyCount)', Icons.event_note_outlined),
        ]),
        const SizedBox(height: 6),
        Text("Grouped by each leave type's credit schedule in Leave Policy.",
            style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Stats failed to load (web alert alert-error) ───────────────────────────

class _StatsErrorAlert extends StatelessWidget {
  const _StatsErrorAlert({required this.message, required this.onRetry, required this.retrying});
  final String message;
  final VoidCallback onRetry;

  /// A retry is on its way (the failed result stays until it answers).
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('employee-leave-stats-error'),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                key: const Key('employee-leave-stats-error-message'),
                style: AppTextStyles.caption.copyWith(fontSize: 12.5, color: AppColors.error)),
          ),
          if (retrying)
            Padding(
              key: const Key('employee-leave-stats-retrying'),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
              ),
            )
          else
            TextButton(
              key: const Key('employee-leave-stats-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

// ── Leave types without a policy (web alert-warn) ──────────────────────────

class _UnclassifiedWarning extends StatelessWidget {
  const _UnclassifiedWarning({required this.rows, required this.labelOf});
  final List<BalanceSummaryEntity> rows;
  final String Function(BalanceSummaryEntity) labelOf;

  @override
  Widget build(BuildContext context) {
    final names = rows.map((b) => '${labelOf(b)} (${formatLeaveNumber(b.available)} available)').join(', ');
    return Container(
      key: const Key('employee-leave-unclassified'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "No leave policy found for: $names. These aren't shown as annual or monthly — check Settings → "
              'Leave Management → Leave Types.',
              style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── No leave types in the selected view (web stat-card spanning the grid) ──

class _EmptyScheduleCard extends StatelessWidget {
  const _EmptyScheduleCard({required this.monthly});
  final bool monthly;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('employee-leave-empty-view'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(monthly ? 'No monthly leave types' : 'No annual leave types', style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(
            monthly
                ? 'No leave type for this employee is set to the Monthly credit schedule. Set one in Settings → '
                    'Leave Management → Leave Policy → Monthly Credit Settings.'
                : 'Every leave type for this employee is on the Monthly credit schedule — see the Monthly leave view.',
            style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Monthly-schedule balance card (web LeaveTab, isMonthly) ─────────────────
// Not "of N days": a monthly type's yearly total is the credits recorded so
// far, not an allocation — so no progress bar either.

class _MonthlyBalanceCard extends StatelessWidget {
  const _MonthlyBalanceCard({
    super.key,
    required this.label,
    required this.available,
    required this.thisMonth,
    required this.totalCredited,
    required this.year,
    required this.icon,
    required this.color,
  });
  final String label;
  final double available;
  final LeaveStatementMonth? thisMonth;
  final double? totalCredited;
  final int year;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final m = thisMonth;
    final sub = 'available now'
        '${m != null ? ' · ${formatLeaveNumber(m.credit)} credited in ${m.label}' : ''}'
        '${totalCredited != null ? ' · ${formatLeaveNumber(totalCredited!)} in $year' : ''}';
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(_fmtNum(available), style: AppTextStyles.h3.copyWith(color: color, fontSize: 20)),
                Text(sub,
                    key: const Key('employee-leave-monthly-sub'), style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 13, color: color),
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
                    Text(value, style: AppTextStyles.h3.copyWith(color: color, fontSize: 20)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(LeaveTypeColors.shortLabelForCode(r.leaveTypeCode),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 10)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withValues(alpha: 0.3)),
                      ),
                      child: Text(r.status,
                          style: AppTextStyles.caption.copyWith(fontSize: 9, fontWeight: FontWeight.w700, color: sc)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_fmtIso(r.from)} – ${_fmtIso(r.to)}',
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${r.days}d',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.info, fontWeight: FontWeight.w700, fontSize: 10)),
                    ),
                    if (r.hasLopDays) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Text('LOP ${_fmtNum(r.lopDays)}d',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_outlined, size: 10, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(r.appliedOn.isEmpty ? 'Applied —' : 'Applied ${_fmtIso(r.appliedOn)}',
                        style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_outline, size: 10, color: AppColors.textHint),
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
                        Icon(Icons.message_outlined, size: 10, color: AppColors.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(r.rejectReason!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 10),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Page $page of $totalPages', style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Next'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

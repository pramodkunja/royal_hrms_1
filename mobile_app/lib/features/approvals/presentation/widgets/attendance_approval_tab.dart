import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/formatters/en_in_format.dart';
import '../../data/models/attendance_approval_models.dart';
import '../providers/attendance_approval_providers.dart';
import '../../../profile/presentation/widgets/profile_widgets.dart' show ProfileSectionCard;
import 'approvals_kit.dart';
import 'approvals_ui.dart';

// Web fmtMonth: en-IN { month: "long", year: "numeric" } → "September 2026".
const _kMonthLong = [
  '', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November',
  'December',
];
String _fmtMonthYear(DateTime d) => '${_kMonthLong[d.month]} ${d.year}';
// Web fmtDate: { day: "2-digit", month: "short", year: "numeric" } → "05 Sept 2026".
String _fmtDate(DateTime d) => formatEnInDate(d, padDay: true);
// Web daily fmtDate: { day: "2-digit", month: "short" } → "05 Nov".
String _fmtDayMonth(DateTime d) => formatEnInDate(d, padDay: true).replaceFirst(' ${d.year}', '');
// Web fmtDateTime: { day, month: "short", hour: "2-digit", minute: "2-digit" } → "05 Nov, 03:07 pm".
String _fmtDateTime(DateTime utcOrLocal) {
  final d = utcOrLocal.toLocal();
  final h = (d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_fmtDayMonth(d)}, $h:$mm ${d.hour < 12 ? 'am' : 'pm'}';
}

// JS prints 8 not 8.0.
String _num(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

// Ports web's app/dashboard/approvals/_components/AttendanceApprovalTab.tsx —
// a payroll-cycle attendance sign-off screen (L1 manager -> L2 HR), distinct
// from leave/expense approvals. Cycle picker -> per-employee summary
// (expandable to a daily breakdown) -> a single cycle-level Approve action.
//
// Deliberate differences from web: the first cycle is selected on open, load
// errors get a Retry button, and success/error feedback is inline.
class AttendanceApprovalTab extends ConsumerStatefulWidget {
  const AttendanceApprovalTab({super.key});

  @override
  ConsumerState<AttendanceApprovalTab> createState() => _AttendanceApprovalTabState();
}

class _AttendanceApprovalTabState extends ConsumerState<AttendanceApprovalTab> {
  String? _selectedCycleId;

  @override
  Widget build(BuildContext context) {
    final cyclesAsync = ref.watch(pendingApprovalCyclesProvider);

    return cyclesAsync.when(
      loading: () => const Center(child: ApprovalsLoading(label: 'Loading pending approval cycles…')),
      error: (e, _) => Center(
        child: SingleChildScrollView(
          child: ApprovalsEmptyState.forError(e, onRetry: () => ref.invalidate(pendingApprovalCyclesProvider)),
        ),
      ),
      data: (cycles) {
        if (cycles.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.read(pendingApprovalCyclesProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: const [
                ApprovalsEmptyState(
                  kind: ApprovalsStateKind.empty,
                  title: 'No payroll cycles to approve',
                  message: 'No payroll cycles pending your attendance approval.',
                  icon: Icons.fact_check_outlined,
                ),
              ],
            ),
          );
        }

        final selectedId = _selectedCycleId != null && cycles.any((c) => c.id == _selectedCycleId)
            ? _selectedCycleId!
            : cycles.first.id;

        return RefreshIndicator(
          onRefresh: () => ref.read(pendingApprovalCyclesProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Payroll Period',
                        key: const Key('attendance-picker-heading'),
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in cycles)
                          _CycleButton(
                            cycle: c,
                            selected: c.id == selectedId,
                            onTap: () => setState(() => _selectedCycleId = c.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _CycleAttendancePanel(key: ValueKey(selectedId), cycleId: selectedId),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CycleButton extends StatelessWidget {
  final PayrollCycleModel cycle;
  final bool selected;
  final VoidCallback onTap;
  const _CycleButton({required this.cycle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // My Profile's ChoiceChip look: selected = primary fill + white text.
    return Semantics(
      button: true,
      selected: selected,
      child: ChoiceChip(
        key: Key('attendance-cycle-${cycle.id}'),
        showCheckmark: false,
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fmtMonthYear(cycle.cycleStart),
                style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textPrimary)),
            Text('Pay date: ${_fmtDate(cycle.payDate)}',
                style: AppTextStyles.caption.copyWith(
                    fontSize: 11, color: selected ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _CycleAttendancePanel extends ConsumerStatefulWidget {
  final String cycleId;
  const _CycleAttendancePanel({super.key, required this.cycleId});

  @override
  ConsumerState<_CycleAttendancePanel> createState() => _CycleAttendancePanelState();
}

class _CycleAttendancePanelState extends ConsumerState<_CycleAttendancePanel> {
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  final _expanded = <String>{};
  // Web's "self-attested" checkbox — the approver additionally confirms their
  // OWN attendance for the cycle. Optional; sent as self_approve.
  bool _selfApprove = false;
  String? _apiErr;
  String? _successMsg;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve(String level) async {
    // Disable on the very first tap, before any await.
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _apiErr = null;
    });
    final err = await approveCycleAttendance(
      ref,
      widget.cycleId,
      level,
      comment: _commentCtrl.text.trim(),
      selfApprove: _selfApprove,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (err != null) {
        _apiErr = err;
      } else {
        _commentCtrl.clear();
        _selfApprove = false;
        _successMsg = '$level attendance approval recorded.';
      }
    });
    if (err == null) {
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _successMsg = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(cycleAttendanceSummaryProvider(widget.cycleId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_successMsg != null)
          _Banner(
              key: const Key('attendance-success'),
              text: _successMsg!,
              color: AppColors.success,
              icon: Icons.check_circle_outline),
        if (_apiErr != null)
          _Banner(key: const Key('attendance-error'), text: _apiErr!, color: AppColors.error, icon: Icons.error_outline),
        summaryAsync.when(
          loading: () => const ApprovalsLoading(label: 'Loading attendance data…'),
          error: (e, _) => ApprovalsEmptyState.forError(e,
              compact: true, onRetry: () => ref.invalidate(cycleAttendanceSummaryProvider(widget.cycleId))),
          data: _buildSummary,
        ),
      ],
    );
  }

  Widget _buildSummary(CycleAttendanceSummary summary) {
    final cycle = summary.cycle;
    final l1Done = cycle.l1ApproverName != null && cycle.l1ApproverName!.isNotEmpty;
    final l2Done = cycle.l2ApproverName != null && cycle.l2ApproverName!.isNotEmpty;
    final mgrTotalCount = cycle.mgrTotalCount;
    final mgrApprovedCount = cycle.mgrApprovedCount;
    // Matches web exactly: gated on the backend-computed per-user pending row.
    final canDoL1 = cycle.currentUserPending && !l1Done;
    final canDoL2 = l1Done && !l2Done;
    final approvalLevel = canDoL1 ? 1 : (canDoL2 ? 2 : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const ApprovalsIconBox(Icons.calendar_month_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Attendance — ${_fmtMonthYear(cycle.cycleStart)}', style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text(
                        '${_fmtDate(cycle.cycleStart)} → ${_fmtDate(cycle.cycleEnd)}  ·  Pay date ${_fmtDate(cycle.payDate)}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ApprovalsBadge(
                    mgrTotalCount > 0
                        ? (l1Done
                            ? 'L1 ✓ All managers ($mgrTotalCount)'
                            : 'L1 $mgrApprovedCount/$mgrTotalCount managers')
                        : (l1Done ? 'L1 ✓ Approved' : 'L1 Pending'),
                    l1Done ? ApprovalsTone.success : (mgrApprovedCount > 0 ? ApprovalsTone.warning : ApprovalsTone.neutral),
                  ),
                  ApprovalsBadge(
                    l2Done ? 'L2 ✓ ${cycle.l2ApproverName}' : 'L2 Waiting',
                    l2Done ? ApprovalsTone.success : ApprovalsTone.neutral,
                  ),
                  if (cycle.hrSelfApprovedAt != null) const ApprovalsBadge('HR Self-Approved', ApprovalsTone.warning),
                ],
              ),
              if (mgrTotalCount > 0) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
                const SizedBox(height: 12),
                Text('Manager Sign-offs ($mgrApprovedCount/$mgrTotalCount approved)',
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: mgrApprovedCount / mgrTotalCount,
                    minHeight: 5,
                    backgroundColor: AppColors.border,
                    color: cycle.mgrAllApproved ? AppColors.success : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cycle.managerApprovals.map((m) => _ManagerSignoffPill(row: m)).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (summary.employees.isEmpty)
          const ApprovalsEmptyState(
            kind: ApprovalsStateKind.empty,
            title: 'No attendance records',
            message: 'No attendance records found for this period.',
            icon: Icons.event_busy_outlined,
            compact: true,
          )
        else
          for (final e in summary.employees)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EmployeeAttendanceRow(
                cycleId: widget.cycleId,
                row: e,
                expanded: _expanded.contains(e.employeeUuid),
                onTap: () => setState(() {
                  if (!_expanded.remove(e.employeeUuid)) _expanded.add(e.employeeUuid);
                }),
              ),
            ),
        const SizedBox(height: 6),
        if (approvalLevel != null)
          _approveFooter(approvalLevel)
        else if (!cycle.currentUserPending && !l1Done)
          ApprovalsCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'You have approved. Waiting for ${mgrTotalCount - mgrApprovedCount} other manager(s) to sign off.',
                    style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
              ),
            ]),
          )
        else if (l1Done && l2Done)
          ApprovalsCard(
            highlight: AppColors.success,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Attendance fully approved — L1 and L2 sign-off complete.',
                    style: AppTextStyles.label.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _approveFooter(int approvalLevel) {
    return ProfileSectionCard(
      icon: Icons.how_to_reg_outlined,
      title: approvalLevel == 1
          ? "Your sign-off is required — review your team's attendance and approve"
          : 'HR (L2) — Final sign-off on attendance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('attendance-comment'),
            controller: _commentCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Add approval note (optional)…', isDense: true),
          ),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('attendance-self-approve'),
            onTap: () => setState(() => _selfApprove = !_selfApprove),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(children: [
                Checkbox(value: _selfApprove, onChanged: (v) => setState(() => _selfApprove = v ?? false)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('I also confirm my own attendance for this period is accurate (self-attested)',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('attendance-approve'),
              onPressed: _submitting ? null : () => _approve('L$approvalLevel'),
              icon: _submitting
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: Text(_submitting ? 'Approving…' : 'Approve L$approvalLevel Attendance', textAlign: TextAlign.center),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeAttendanceRow extends ConsumerWidget {
  final String cycleId;
  final AttendanceSummaryRow row;
  final bool expanded;
  final VoidCallback onTap;
  const _EmployeeAttendanceRow({
    required this.cycleId,
    required this.row,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    // Compact stat strip: Present always, the rest only when there is something to see.
    final pills = <Widget>[
      ApprovalsChip('${row.presentDays} Present', tone: ApprovalsTone.success),
      if (row.lateDays > 0) ApprovalsChip('${row.lateDays} Late', tone: ApprovalsTone.warning),
      if (row.halfDays > 0) ApprovalsChip('${row.halfDays} Half day', tone: ApprovalsTone.info),
      if (row.onLeaveDays > 0) ApprovalsChip('${row.onLeaveDays} On leave', tone: ApprovalsTone.info),
      if (row.absentDays > 0) ApprovalsChip('${row.absentDays} Absent', tone: ApprovalsTone.error),
      // Web: the red "{n} LOP" chip only while collapsed.
      if (row.lopDays > 0 && !expanded) ApprovalsChip('${row.lopDays} LOP', tone: ApprovalsTone.error),
    ];
    final strip = Wrap(spacing: 6, runSpacing: 6, children: pills);
    final hours = ApprovalsKeyFigure('${_num(row.workingHours)}h', caption: 'worked');
    return ApprovalsCardShell(
      key: Key('attendance-employee-${row.employeeUuid}'),
      name: row.fullName,
      idText: row.employeeId.isEmpty ? null : row.employeeId,
      meta: [row.designation, row.department].where((e) => e.isNotEmpty).join(' · '),
      onTap: onTap,
      footer: expanded
          ? _DailyBreakdown(cycleId: cycleId, employeeId: row.employeeUuid)
          : Row(children: [
              Icon(Icons.calendar_view_week_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Daily breakdown',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.expand_more, size: 20, color: AppColors.textSecondary),
            ]),
      child: scale > 1.3
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [strip, const SizedBox(height: 10), hours])
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: strip),
              const SizedBox(width: 12),
              SizedBox(width: 140, child: Align(alignment: Alignment.centerRight, child: hours)),
            ]),
    );
  }
}

// Web STATUS_COLOR / STATUS_BG (EmployeeAttendanceRow.tsx).
Color _statusColor(String status) => switch (status) {
      'present' => AppColors.success,
      'late' => AppColors.warning,
      'half_day' => AppColors.info,
      'on_leave' => AppColors.accentPurple,
      'absent' => AppColors.error,
      'incomplete' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

Color? _statusTint(String status) => switch (status) {
      'absent' => AppColors.error.withValues(alpha: 0.06),
      'incomplete' => AppColors.warning.withValues(alpha: 0.05),
      'weekly_off' || 'holiday' => AppColors.textSecondary.withValues(alpha: 0.04),
      _ => null,
    };

class _DailyBreakdown extends ConsumerWidget {
  final String cycleId;
  final String employeeId;
  const _DailyBreakdown({required this.cycleId, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = EmployeeDailyAttendanceKey(cycleId, employeeId);
    final async = ref.watch(employeeDailyAttendanceProvider(key));
    return async.when(
      loading: () => const _LoadingLine(text: 'Loading daily records…', padding: 16, small: true),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(friendlyPayrollError(e), style: AppTextStyles.caption.copyWith(color: AppColors.error))),
          TextButton(
            key: Key('attendance-daily-retry-$employeeId'),
            onPressed: () => ref.invalidate(employeeDailyAttendanceProvider(key)),
            child: const Text('Retry'),
          ),
        ]),
      ),
      data: (daily) {
        if (daily.days.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No attendance records found for this period.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          );
        }
        final flagged = daily.days.where((d) => d.isFlagged).length;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text('Daily Breakdown — ${daily.fullName}',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                  if (flagged > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('$flagged day${flagged > 1 ? 's' : ''} flagged',
                            style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            for (final d in daily.days)
              Opacity(
                opacity: d.status == 'weekly_off' || d.status == 'holiday' ? 0.45 : 1,
                child: Container(
                  color: _statusTint(d.status),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 60,
                          child: Text(_fmtDayMonth(d.date),
                              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary))),
                      SizedBox(
                          width: 40,
                          child: Text(d.day, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
                      Expanded(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (d.isFlagged)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 4),
                              child: Icon(Icons.error_outline, size: 12, color: _statusColor(d.status)),
                            ),
                          Expanded(
                            child: Text(d.statusLabel,
                                style: AppTextStyles.caption.copyWith(
                                    color: _statusColor(d.status),
                                    fontWeight: d.isFlagged ? FontWeight.w700 : FontWeight.w400)),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(d.workingHours > 0 ? '${_num(d.workingHours)}h' : '—',
                          style: AppTextStyles.caption.copyWith(
                              color: d.workingHours > 0 ? AppColors.textPrimary : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        );
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ManagerSignoffPill extends StatelessWidget {
  final ManagerApprovalRow row;
  const _ManagerSignoffPill({required this.row});

  @override
  Widget build(BuildContext context) {
    final approved = row.approvedAt != null;
    final color = approved ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: approved ? AppColors.success.withValues(alpha: 0.07) : AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: approved ? AppColors.success : AppColors.border),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(approved ? Icons.check_circle_outline : Icons.access_time, size: 14, color: color),
          Text(row.managerName.isNotEmpty ? row.managerName : 'Manager',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (approved)
            Text(_fmtDateTime(row.approvedAt!), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          if (row.selfApprovedAt != null) _Badge(label: 'Self-Approved', color: AppColors.warning),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _Banner({super.key, required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.label.copyWith(color: color))),
        ]),
      );
}

class _LoadingLine extends StatelessWidget {
  final String text;
  final double padding;
  final bool small;
  const _LoadingLine({required this.text, required this.padding, this.small = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: padding),
        child: Center(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                  width: small ? 16 : 20, height: small ? 16 : 20, child: const CircularProgressIndicator(strokeWidth: 2)),
              Text(text, style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

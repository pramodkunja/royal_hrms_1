import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/attendance_approval_models.dart';
import '../providers/attendance_approval_providers.dart';

const _kMonthShort = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _fmtMonthYear(DateTime d) => '${_kMonthShort[d.month]} ${d.year}';
String _fmtDate(DateTime d) => '${d.day} ${_kMonthShort[d.month]} ${d.year}';

// Ports web's app/dashboard/approvals/_components/AttendanceApprovalTab.tsx —
// a payroll-cycle attendance sign-off screen (L1 manager -> L2 HR), distinct
// from leave/expense approvals. Cycle picker -> per-employee summary table
// (expandable to a daily breakdown) -> a single cycle-level Approve action.
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: friendlyPayrollError(e),
        onRetry: () => ref.invalidate(pendingApprovalCyclesProvider),
      ),
      data: (cycles) {
        if (cycles.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => ref.read(pendingApprovalCyclesProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                Icon(Icons.fact_check_outlined, size: 44, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text('No payroll cycles awaiting attendance approval.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cycles.length > 1) ...[
                  Text('Select Payroll Cycle', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cycles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = cycles[i];
                        final selected = c.id == selectedId;
                        return ChoiceChip(
                          label: Text(_fmtMonthYear(c.cycleStart)),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedCycleId = c.id),
                          labelStyle: AppTextStyles.labelSmall.copyWith(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _CycleAttendancePanel(cycleId: selectedId),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CycleAttendancePanel extends ConsumerStatefulWidget {
  final String cycleId;
  const _CycleAttendancePanel({required this.cycleId});

  @override
  ConsumerState<_CycleAttendancePanel> createState() => _CycleAttendancePanelState();
}

class _CycleAttendancePanelState extends ConsumerState<_CycleAttendancePanel> {
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _expandedEmployeeId;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CycleAttendancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleId != widget.cycleId) {
      _commentCtrl.clear();
      _expandedEmployeeId = null;
    }
  }

  Future<void> _approve(String level) async {
    setState(() => _submitting = true);
    final err = await approveCycleAttendance(ref, widget.cycleId, level, comment: _commentCtrl.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
    } else {
      _commentCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance $level approved.'), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(cycleAttendanceSummaryProvider(widget.cycleId));
    final settingsAsync = ref.watch(payrollSettingsProvider);
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final role = user?.role ?? '';
    final canL1 = ['system_admin', 'hr_admin', 'manager'].contains(role);
    final canL2 = ['system_admin', 'hr_admin'].contains(role);
    final isL1L2 = (settingsAsync.valueOrNull?.approvalLevels ?? ApprovalLevels.l1) == ApprovalLevels.l1l2;

    return summaryAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _ErrorView(
        message: friendlyPayrollError(e),
        onRetry: () => ref.invalidate(cycleAttendanceSummaryProvider(widget.cycleId)),
      ),
      data: (summary) {
        final l1Done = summary.cycle.l1ApproverName != null && summary.cycle.l1ApproverName!.isNotEmpty;
        final l2Done = summary.cycle.l2ApproverName != null && summary.cycle.l2ApproverName!.isNotEmpty;
        final canApproveNow = (!l1Done && canL1) || (l1Done && isL1L2 && !l2Done && canL2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${_fmtDate(summary.cycle.cycleStart)} — ${_fmtDate(summary.cycle.cycleEnd)}',
                          style: AppTextStyles.h4, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    _Badge(label: isL1L2 ? 'L1+L2 required' : 'L1 only', color: AppColors.info),
                  ]),
                  const SizedBox(height: 2),
                  Text('${summary.employees.length} employees · Pay date ${_fmtDate(summary.cycle.payDate)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  const SizedBox(height: 12),
                  _ApprovalStatusRow(label: 'L1 — Manager', done: l1Done, name: summary.cycle.l1ApproverName),
                  if (isL1L2) ...[
                    const SizedBox(height: 8),
                    _ApprovalStatusRow(label: 'L2 — HR', done: l2Done, name: summary.cycle.l2ApproverName),
                  ],
                  if (canApproveNow) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Comment (optional)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : () => _approve(!l1Done ? 'L1' : 'L2'),
                        icon: _submitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 16),
                        label: Text(_submitting ? 'Submitting…' : (!l1Done ? 'Approve L1 Attendance' : 'Approve L2 Attendance')),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Employee Attendance', style: AppTextStyles.h4),
            const SizedBox(height: 10),
            if (summary.employees.isEmpty)
              Text('No attendance records in this cycle period yet.', style: AppTextStyles.caption)
            else
              ...summary.employees.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EmployeeAttendanceRow(
                      cycleId: widget.cycleId,
                      row: e,
                      expanded: _expandedEmployeeId == e.employeeUuid,
                      onTap: () => setState(
                        () => _expandedEmployeeId = _expandedEmployeeId == e.employeeUuid ? null : e.employeeUuid,
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class _EmployeeAttendanceRow extends ConsumerWidget {
  final String cycleId;
  final AttendanceSummaryRow row;
  final bool expanded;
  final VoidCallback onTap;
  const _EmployeeAttendanceRow({required this.cycleId, required this.row, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.fullName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${row.employeeId} · ${row.department} · ${row.designation}',
                            style: AppTextStyles.caption.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: [
                  _Badge(label: 'Present ${row.presentDays}', color: AppColors.success),
                  if (row.lateDays > 0) _Badge(label: 'Late ${row.lateDays}', color: AppColors.warning),
                  if (row.absentDays > 0) _Badge(label: 'Absent ${row.absentDays}', color: AppColors.error),
                  if (row.incompleteDays > 0) _Badge(label: 'Incomplete ${row.incompleteDays}', color: AppColors.error),
                  if (row.onLeaveDays > 0) _Badge(label: 'Leave ${row.onLeaveDays}', color: AppColors.info),
                  if (row.lopDays > 0) _Badge(label: 'LOP ${row.lopDays}', color: AppColors.error),
                  _Badge(label: '${row.workingHours}h', color: AppColors.primary),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _DailyBreakdown(cycleId: cycleId, employeeId: row.employeeUuid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyBreakdown extends ConsumerWidget {
  final String cycleId;
  final String employeeId;
  const _DailyBreakdown({required this.cycleId, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeDailyAttendanceProvider(EmployeeDailyAttendanceKey(cycleId, employeeId)));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Text(friendlyPayrollError(e), style: AppTextStyles.caption.copyWith(color: AppColors.error)),
      data: (daily) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: daily.days.map((d) {
          final color = d.isFlagged ? AppColors.error : AppColors.textSecondary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text(d.day, style: AppTextStyles.caption.copyWith(fontSize: 10.5))),
                SizedBox(width: 56, child: Text(_fmtDate(d.date), style: AppTextStyles.caption.copyWith(fontSize: 10.5))),
                Expanded(child: Text(d.statusLabel, style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: color, fontWeight: d.isFlagged ? FontWeight.w700 : FontWeight.w400))),
                Text('${d.workingHours}h', style: AppTextStyles.caption.copyWith(fontSize: 10.5)),
              ],
            ),
          );
        }).toList(),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ApprovalStatusRow extends StatelessWidget {
  final String label;
  final bool done;
  final String? name;
  const _ApprovalStatusRow({required this.label, required this.done, this.name});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.hourglass_top_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Flexible(
            child: Text(done ? (name ?? 'Approved') : 'Pending',
                style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

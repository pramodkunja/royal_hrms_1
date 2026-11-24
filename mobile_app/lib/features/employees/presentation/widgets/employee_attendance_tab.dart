import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../data/models/employee_model.dart';
import 'employee_attendance_calendar.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

/// Employee Profile "Attendance" tab (HR/admin view of another employee's
/// attendance) — mirrors web's AttendanceTab.tsx in its read-only variant:
/// no clock-in/out, no Regularize action, since the viewer isn't the owner
/// of this attendance record.
class EmployeeAttendanceTab extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const EmployeeAttendanceTab({super.key, required this.employee});

  @override
  ConsumerState<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends ConsumerState<EmployeeAttendanceTab> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  EmployeeMonthYearKey get _key => (
        employeeId: widget.employee.employeeId,
        year: _month.year,
        month: _month.month,
      );

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1, 1));

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(employeeAttendanceStatsProvider(_key));
    final summaryAsync = ref.watch(employeeAttendanceSummaryProvider(_key));
    final calendarAsync = ref.watch(employeeAttendanceCalendarProvider(_key));

    return ListView(
      // See employee_profile_screen.dart's _ProfileTab for why this is
      // required (shared PrimaryScrollController from the enclosing
      // NestedScrollView across every kept-alive TabBarView child).
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCards(statsAsync),
        const SizedBox(height: 14),
        _buildMonthlySummary(summaryAsync),
        const SizedBox(height: 14),
        _buildCalendarCard(calendarAsync),
      ],
    );
  }

  // ── Stat cards (mirrors my_attendance_screen.dart's _StatCard style) ─────

  Widget _buildStatCards(AsyncValue<AttendanceStatsEntity> statsAsync) {
    return statsAsync.when(
      data: (stats) {
        // Web employees/[id]/_components/AttendanceTab.tsx:26-94: value,
        // sub-line and a progress bar per card; numbers shown as the server
        // sends them (not rounded).
        final wd = stats.workingDays;
        double pct(num part) => wd > 0 ? (part / wd * 100).clamp(0, 100).toDouble() : 0;
        final cards = [
          EmployeeStatCard(
            key: const Key('emp-att-present'),
            icon: Icons.person_outline,
            label: 'Days Present',
            value: '${stats.daysPresent}',
            sub: 'of $wd working days',
            progress: pct(stats.daysPresent),
            color: AppColors.success,
          ),
          EmployeeStatCard(
            key: const Key('emp-att-late'),
            icon: Icons.access_alarm_outlined,
            label: 'Late Arrivals',
            value: '${stats.lateArrivals}',
            sub: '${stats.lopPending} LOP pending',
            progress: pct(stats.lateArrivals),
            color: AppColors.warning,
          ),
          EmployeeStatCard(
            key: const Key('emp-att-hours'),
            icon: Icons.access_time_outlined,
            label: 'Avg Hours / Day',
            value: webNumber(stats.avgHoursPerDay),
            sub: 'Required: 9.0 hrs',
            progress: (stats.avgHoursPerDay / 9 * 100).clamp(0, 100).toDouble(),
            color: AppColors.info,
          ),
          EmployeeStatCard(
            key: const Key('emp-att-pct'),
            icon: Icons.bar_chart_outlined,
            label: 'Attendance %',
            value: '${webNumber(stats.attendancePercentage)}%',
            // Deliberate difference: web's "Above threshold" is hard-coded
            // (shown even at 10%), so it is left out here (reported WEB-2).
            sub: null,
            progress: stats.attendancePercentage.clamp(0, 100).toDouble(),
            color: AppColors.success,
          ),
        ];

        // One column at large text so labels keep whole words.
        if (MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3) {
          return Column(children: [
            for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 10), cards[i]],
          ]);
        }
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ]),
        ]);
      },
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => SizedBox(
        height: 60,
        child: Center(
          child: Text(friendlyAttendanceError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ),
      ),
    );
  }

  // ── Monthly summary (mirrors my_attendance_screen.dart's 6-cell grid) ────

  Widget _buildMonthlySummary(AsyncValue<MonthlySummaryEntity> summaryAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Monthly Summary', style: AppTextStyles.h4)),
            ],
          ),
          const SizedBox(height: 14),
          summaryAsync.when(
            data: (summary) {
              final cells = [
                _SummaryCell(label: 'Working Days', value: '${summary.workingDays}', color: AppColors.primary),
                _SummaryCell(label: 'Days Present', value: '${summary.daysPresent}', color: AppColors.success),
                _SummaryCell(label: 'Days Absent', value: '${summary.daysAbsent}', color: AppColors.error),
                _SummaryCell(label: 'Leave Days', value: '${summary.leaveDays}', color: AppColors.warning),
                _SummaryCell(label: 'Half Days', value: '${summary.halfDays}', color: AppColors.info),
                _SummaryCell(label: 'OT Hours', value: summary.otHours, color: AppColors.success),
              ];
              // Cells size to their content (a fixed height clipped them at large text); two
              // columns at large text so labels and values keep whole words.
              return LayoutBuilder(builder: (context, c) {
                final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
                final cols = large ? 2 : 3;
                const gap = 10.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [for (final cell in cells) SizedBox(width: w, child: cell)],
                );
              });
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) =>
                Text(friendlyAttendanceError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Calendar / History card (read-only: no Regularize action anywhere) ───

  Widget _buildCalendarCard(AsyncValue<AttendanceCalendarEntity> calendarAsync) {
    final now = DateTime.now();
    return EmployeeAttendanceCalendarCard(
      month: _month,
      calendar: calendarAsync,
      onPrev: _prevMonth,
      onNext: _isCurrentMonth ? null : _nextMonth,
      onToday: _isCurrentMonth ? null : () => setState(() => _month = DateTime(now.year, now.month, 1)),
      onRetry: () => ref.invalidate(employeeAttendanceCalendarProvider(_key)),
      historyBuilder: (cal) => _buildHistoryList(cal.history),
    );
  }

  Widget _buildHistoryList(List<AttendanceHistoryRowEntity> history) {
    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No attendance records for this month.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            _HistoryRow(
              row: history[i],
              statusColor: attendanceDayColor(history[i].status, null),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary cell (mirrors my_attendance_screen.dart's _SummaryCell) ──────────

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.2),
          ),
          const SizedBox(height: 4),
          _AnimatedCellValue(value: value, color: color),
        ],
      ),
    );
  }
}

// Counts up from 0 to the target value on first mount (e.g. Days Present:
// 0 → 18). Falls back to a plain static Text for values that aren't a clean
// integer (e.g. OT Hours is a formatted string like "12h 30m"), since those
// can't be meaningfully animated as a count.
class _AnimatedCellValue extends StatelessWidget {
  final String value;
  final Color color;
  const _AnimatedCellValue({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(value);
    final style = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.1,
    );
    if (target == null) {
      return Text(value, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text('${animated.round()}', style: style),
    );
  }
}

// ── Legend chip — a colored badge (dot + label) instead of a bare dot, to
// match the reference web calendar's legend chips ────────────────────────────

class _HistoryRow extends StatelessWidget {
  final AttendanceHistoryRowEntity row;
  final Color? statusColor;

  const _HistoryRow({required this.row, required this.statusColor});

  // The server's own verdict (status), not a clock-time guess: only a plain 'Late' day (not an
  // excused one) marks the clock-in time.
  bool get _isLateArrival => row.status == 'Late';

  @override
  Widget build(BuildContext context) {
    final color = statusColor ?? AppColors.textHint;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.date,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(row.day, style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      row.clockIn ?? '—',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isLateArrival ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                    Text(' → ', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    Text(row.clockOut ?? '—',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (row.hours != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('· ${row.hours}',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    row.status,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A number as web prints it (JavaScript): 8.0 → "8", 7.5 → "7.5".
String webNumber(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

class EmployeeStatCard extends StatelessWidget {
  const EmployeeStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  /// 0–100.
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.h3.copyWith(color: color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub ?? ' ', style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            Icon(icon, size: 18, color: color),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

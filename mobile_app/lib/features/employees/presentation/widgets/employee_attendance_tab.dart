import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../data/models/employee_model.dart';

// Matches my_attendance_screen.dart's day-status color legend exactly, so an
// HR admin sees the same color coding when looking at someone else's month.
const _kDayStatusColors = <String, Color>{
  'Present': Color(0xFF1B8A6B),
  'Late': Color(0xFFD97706),
  'Absent': Color(0xFFC0392B),
  'On Leave': Color(0xFF0E7C86),
  'Half Day': Color(0xFF1E4E8C),
  'Weekly Off': Color(0xFF7C8AA3),
  'Holiday': Color(0xFFB5651D),
  'Incomplete': Color(0xFF9333EA),
};

// Single/short letter codes shown top-right of each day cell — matches the
// reference web calendar's per-cell status badges exactly.
const _kStatusShortCode = <String, String>{
  'Present': 'P',
  'Late': 'L',
  'Absent': 'A',
  'On Leave': 'OL',
  'Half Day': 'H',
  'Weekly Off': 'W',
  'Holiday': 'Ho',
  'Incomplete': '!',
};

const _kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

// ── Widget ────────────────────────────────────────────────────────────────────

/// Employee Profile "Attendance" tab (HR/admin view of another employee's
/// attendance) — mirrors web's AttendanceTab.tsx in its read-only variant:
/// no clock-in/out, no Regularize action, since the viewer isn't the owner
/// of this attendance record.
class EmployeeAttendanceTab extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const EmployeeAttendanceTab({super.key, required this.employee});

  @override
  ConsumerState<EmployeeAttendanceTab> createState() =>
      _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends ConsumerState<EmployeeAttendanceTab> {
  late DateTime _month;
  int _calendarTab = 0; // 0 = Calendar, 1 = History

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

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1, 1));

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
        final cards = [
          StatCard(
            icon: Icons.person_outline,
            count: stats.daysPresent,
            label: 'Days Present',
            color: AppColors.success,
          ),
          StatCard(
            icon: Icons.access_alarm_outlined,
            count: stats.lateArrivals,
            label: 'Late Arrivals',
            color: AppColors.warning,
          ),
          StatCard(
            icon: Icons.access_time_outlined,
            count: stats.avgHoursPerDay.round(),
            valueText: stats.avgHoursPerDay.toStringAsFixed(1),
            label: 'Avg Hours / Day',
            color: AppColors.info,
          ),
          StatCard(
            icon: Icons.bar_chart_outlined,
            count: stats.attendancePercentage.round(),
            valueText: '${stats.attendancePercentage.round()}%',
            label: 'Attendance %',
            color: AppColors.success,
          ),
        ];

        return StatCardRow(cards: cards, padding: EdgeInsets.zero);
      },
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => SizedBox(
        height: 60,
        child: Center(
          child: Text(friendlyAttendanceError(e),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
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
              Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Monthly Summary', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 14),
          summaryAsync.when(
            data: (summary) {
              final cells = [
                _SummaryCell(
                    label: 'Working Days',
                    value: '${summary.workingDays}',
                    color: AppColors.primary),
                _SummaryCell(
                    label: 'Days Present',
                    value: '${summary.daysPresent}',
                    color: AppColors.success),
                _SummaryCell(
                    label: 'Days Absent',
                    value: '${summary.daysAbsent}',
                    color: AppColors.error),
                _SummaryCell(
                    label: 'Leave Days',
                    value: '${summary.leaveDays}',
                    color: AppColors.warning),
                _SummaryCell(
                    label: 'Half Days',
                    value: '${summary.halfDays}',
                    color: AppColors.info),
                _SummaryCell(
                    label: 'OT Hours',
                    value: summary.otHours,
                    color: AppColors.success),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // A fixed aspect ratio (GridView.count's childAspectRatio)
                // ties cell height to the column width, so on narrower
                // phones (3 columns leaves little width each) the cell
                // shrinks below what the label + value text needs and
                // overflows. mainAxisExtent instead gives every cell a fixed,
                // width-independent height that's always tall enough.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 64,
                ),
                itemCount: cells.length,
                itemBuilder: (_, i) => cells[i],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(friendlyAttendanceError(e),
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Calendar / History card (read-only: no Regularize action anywhere) ───

  Widget _buildCalendarCard(
      AsyncValue<AttendanceCalendarEntity> calendarAsync) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWd = DateTime(_month.year, _month.month, 1).weekday % 7;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Toggle + month nav share one header, matching web's single
          // consolidated bar (Calendar/History + legend + month nav) — split
          // across two rows here since mobile width can't fit it all inline.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(
                  child: _CalTabButton(
                    label: 'Calendar',
                    icon: Icons.calendar_month_outlined,
                    selected: _calendarTab == 0,
                    onTap: () => setState(() => _calendarTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CalTabButton(
                    label: 'History',
                    icon: Icons.list_alt_outlined,
                    selected: _calendarTab == 1,
                    onTap: () => setState(() => _calendarTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _prevMonth,
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_kMonthNames[_month.month - 1]} ${_month.year}',
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _isCurrentMonth ? null : _nextMonth,
                  color: _isCurrentMonth
                      ? AppColors.textHint.withValues(alpha: 0.4)
                      : AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (_calendarTab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _kDayStatusColors.entries
                    .map((e) => _LegendChip(e.key, e.value))
                    .toList(),
              ),
            ),
          const SizedBox(height: 10),
          if (_calendarTab == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
            calendarAsync.when(
              data: (calendar) => Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border)),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: firstWd + daysInMonth,
                    itemBuilder: (_, idx) {
                      if (idx < firstWd) {
                        return const _DayCell.blank();
                      }
                      final day = idx - firstWd + 1;
                      final isToday = day == today.day &&
                          _month.month == today.month &&
                          _month.year == today.year;
                      final dayRecord = calendar.days[day];
                      final statusColor = dayRecord != null
                          ? _kDayStatusColors[dayRecord.status]
                          : null;
                      final code = dayRecord != null
                          ? _kStatusShortCode[dayRecord.status]
                          : null;

                      return _DayCell(
                        day: day,
                        isToday: isToday,
                        statusColor: statusColor,
                        code: code,
                        onTap: dayRecord == null
                            ? null
                            : () => _showDayDetail(day, dayRecord),
                      );
                    },
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(friendlyAttendanceError(e),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ),
            ),
          ] else
            calendarAsync.when(
              data: (calendar) => _buildHistoryList(calendar.history),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(friendlyAttendanceError(e),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ),
            ),
        ],
      ),
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
              statusColor: _kDayStatusColors[history[i].status],
            ),
          ],
        ],
      ),
    );
  }

  // Info-only day detail — no Regularize action (read-only HR view).
  void _showDayDetail(int day, CalendarDayEntity record) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_kMonthNames[_month.month - 1]} $day, ${_month.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              'Status',
              (record.holidayName != null && record.holidayName!.isNotEmpty)
                  ? '${record.status} — ${record.holidayName}'
                  : record.status,
            ),
            if (record.clockIn != null) _DetailRow('Clock In', record.clockIn!),
            if (record.clockOut != null)
              _DetailRow('Clock Out', record.clockOut!),
            if (record.hours != null) _DetailRow('Hours', record.hours!),
            if (record.note != null && record.note!.isNotEmpty)
              _DetailRow('Note', record.note!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
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
  const _SummaryCell(
      {required this.label, required this.value, required this.color});

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
            style: TextStyle(
                fontSize: 10, color: AppColors.textSecondary, height: 1.2),
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
      builder: (context, animated, _) =>
          Text('${animated.round()}', style: style),
    );
  }
}

// ── Legend chip — a colored badge (dot + label) instead of a bare dot, to
// match the reference web calendar's legend chips ────────────────────────────

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Day cell — bordered grid cell with a status-color background tint and a
// short status-code badge top-right, matching the reference web calendar's
// spreadsheet-style day cells (replaces the old floating-circle + dot look).

class _DayCell extends StatelessWidget {
  final int? day;
  final bool isToday;
  final Color? statusColor;
  final String? code;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.statusColor,
    required this.code,
    required this.onTap,
  });

  const _DayCell.blank()
      : day = null,
        isToday = false,
        statusColor = null,
        code = null,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: statusColor?.withValues(alpha: 0.08),
          border: Border(
            right: BorderSide(color: AppColors.border, width: 0.5),
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: day == null
            ? const SizedBox.expand()
            : Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: isToday
                        ? Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                  ),
                  if (code != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Text(
                        code!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ── Calendar/History tab button (mirrors my_attendance_screen.dart's
// _CalTabButton) ──────────────────────────────────────────────────────────────

class _CalTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CalTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History row (mirrors my_attendance_screen.dart's _HistoryRow, minus the
// "Regularize" action — read-only for HR viewing another employee) ──────────

class _HistoryRow extends StatelessWidget {
  final AttendanceHistoryRowEntity row;
  final Color? statusColor;

  const _HistoryRow({required this.row, required this.statusColor});

  bool get _isLateArrival =>
      row.clockIn != null && row.clockIn!.compareTo('09:15') > 0;

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
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(row.day,
                    style: TextStyle(fontSize: 10, color: AppColors.textHint)),
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
                        color: _isLateArrival
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(' → ',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textHint)),
                    Text(row.clockOut ?? '—',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    if (row.hours != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('· ${row.hours}',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    row.status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color),
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

// ── Detail dialog row ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

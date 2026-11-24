import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/formatters/en_in_format.dart' show formatEnInDate;
import '../../../../shared/widgets/app_error_state.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';

/// Status → colour, the backend's own `_STATUS_COLOR` (services_attendance.py). A day normally
/// carries its own `color` (web draws with it); this is the legend and the fallback.
const kAttendanceStatusColors = <String, Color>{
  'Present': Color(0xFF22C55E),
  'Late': Color(0xFFF59E0B),
  'Late (Excused)': Color(0xFFF59E0B),
  'Absent': Color(0xFFEF4444),
  'Half Day': Color(0xFFF97316),
  'Weekly Off': Color(0xFF94A3B8),
  'Holiday': Color(0xFFA855F7),
  'On Leave': Color(0xFF3B82F6),
  'Incomplete': Color(0xFFF59E0B),
  'Missing Clock Out': Color(0xFFF59E0B),
};

/// The legend, in web's order (CalendarAndHistory.tsx LEGEND).
const kAttendanceLegend = <String>['Present', 'Late', 'Absent', 'On Leave', 'Half Day', 'Weekly Off', 'Holiday'];

/// Web STATUS_LABELS — the short code in a day cell.
const kAttendanceStatusCodes = <String, String>{
  'Present': 'P',
  'Late': 'L',
  'Late (Excused)': 'LE',
  'Absent': 'A',
  'Half Day': 'H',
  'Weekly Off': 'W',
  'Holiday': 'Ho',
  'On Leave': 'OL',
  'Incomplete': '!',
  'Missing Clock Out': '!',
};

/// Web NON_WORKING: no punches are expected, so no times are shown.
const _kNonWorking = {'Weekly Off', 'Holiday'};

/// Web LATE_STATUS_HINT.
const _kLateHint = {
  'pending': 'Reason pending',
  'l2_pending': 'Reason pending',
  'resubmit': 'Resubmit reason',
  'rejected': 'Reason rejected',
};

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _kWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// '#rrggbb' from the backend → a colour, or null when it is not one.
Color? attendanceColorFromHex(String? hex) {
  if (hex == null) return null;
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  return m == null ? null : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// The colour for a day: the backend's `color` when it sent one, else by status, else neutral.
Color attendanceDayColor(String status, String? hex) =>
    attendanceColorFromHex(hex) ?? kAttendanceStatusColors[status] ?? AppColors.textHint;

/// Text/icon colour with enough contrast against a light or dark card (the raw status colours are
/// too pale as text on white).
Color attendanceInk(Color c) {
  final hsl = HSLColor.fromColor(c);
  final dark = AppColors.background.computeLuminance() < 0.5;
  return hsl.withLightness(dark ? math.max(hsl.lightness, 0.68) : math.min(hsl.lightness, 0.34)).toColor();
}

/// The Attendance tab's calendar for ONE employee's month — read-only (web `readOnly`: no
/// Regularize / Explain, because a correction is always filed as the signed-in user).
///
/// Every value shown is what the server sent for that day (`clockIn` / `clockOut` are the
/// backend's plain "HH:MM" wall-clock strings; there is no date or timezone to convert, so none is
/// guessed): a missing clock-out is shown as such, never invented. The month is chosen by the
/// parent, which supplies that month's response — a response for another month can never appear
/// here.
class EmployeeAttendanceCalendarCard extends StatefulWidget {
  const EmployeeAttendanceCalendarCard({
    super.key,
    required this.month,
    required this.calendar,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onRetry,
    required this.historyBuilder,
    this.today,
  });

  /// The first day of the month shown.
  final DateTime month;
  final AsyncValue<AttendanceCalendarEntity> calendar;
  final VoidCallback onPrev;

  /// Null when the month cannot go forward.
  final VoidCallback? onNext;

  /// Null when already on the current month.
  final VoidCallback? onToday;
  final VoidCallback onRetry;
  final Widget Function(AttendanceCalendarEntity calendar) historyBuilder;

  /// Overridable "now" (tests).
  final DateTime? today;

  @override
  State<EmployeeAttendanceCalendarCard> createState() => _EmployeeAttendanceCalendarCardState();
}

class _EmployeeAttendanceCalendarCardState extends State<EmployeeAttendanceCalendarCard> {
  int _tab = 0; // 0 = Calendar, 1 = History
  int? _selected; // day of the shown month

  DateTime get _today => widget.today ?? DateTime.now();
  bool get _isCurrentMonth => widget.month.year == _today.year && widget.month.month == _today.month;

  @override
  void initState() {
    super.initState();
    _selected = _isCurrentMonth ? _today.day : null;
  }

  @override
  void didUpdateWidget(EmployeeAttendanceCalendarCard old) {
    super.didUpdateWidget(old);
    if (old.month.year != widget.month.year || old.month.month != widget.month.month) {
      // A new month: today when it is this month, otherwise nothing is selected — a day number
      // from the previous month never carries over onto a month that may not have it.
      _selected = _isCurrentMonth ? _today.day : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('emp-att-calendar-card'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _segment(),
        const SizedBox(height: 8),
        _monthBar(),
        if (_tab == 0) ...[const SizedBox(height: 8), _legend(), const SizedBox(height: 12), _body()] else
          _historyBody(),
      ]),
    );
  }

  // ── Calendar / History switch ───────────────────────────────────────────────

  Widget _segment() {
    Widget b(String label, IconData icon, int i) {
      final on = _tab == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            key: Key('emp-att-tab-${label.toLowerCase()}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _tab = i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: on ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? AppColors.primary : AppColors.border),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(icon, size: 16, color: on ? Colors.white : AppColors.textSecondary),
                  Text(label,
                      style: AppTextStyles.label
                          .copyWith(fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    if (large) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [b('Calendar', Icons.calendar_month_outlined, 0)]),
        const SizedBox(height: 8),
        Row(children: [b('History', Icons.list_alt_outlined, 1)]),
      ]);
    }
    return Row(children: [
      b('Calendar', Icons.calendar_month_outlined, 0),
      const SizedBox(width: 8),
      b('History', Icons.list_alt_outlined, 1),
    ]);
  }

  // ── Month navigation ────────────────────────────────────────────────────────

  Widget _monthBar() {
    final title = '${_kMonths[widget.month.month - 1]} ${widget.month.year}';
    final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
    final prev = IconButton(
      key: const Key('emp-att-prev'),
      tooltip: 'Previous month',
      icon: const Icon(Icons.chevron_left),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      color: AppColors.textSecondary,
      onPressed: widget.onPrev,
    );
    final next = IconButton(
      key: const Key('emp-att-next'),
      tooltip: 'Next month',
      icon: const Icon(Icons.chevron_right),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      color: AppColors.textSecondary,
      disabledColor: AppColors.textHint.withValues(alpha: 0.4),
      onPressed: widget.onNext,
    );
    final today = widget.onToday == null
        ? null
        : TextButton(
            key: const Key('emp-att-today'),
            onPressed: widget.onToday,
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 44), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('Today'),
          );
    final titleText =
        Text(title, key: const Key('emp-att-month'), textAlign: TextAlign.center, style: AppTextStyles.h4);
    if (large) {
      // The title keeps the full width (it wraps by words); the controls sit beneath it.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        titleText,
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [prev, if (today != null) today, next]),
      ]);
    }
    return Row(children: [
      prev,
      Expanded(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [titleText, if (today != null) today],
        ),
      ),
      next,
    ]);
  }

  // ── Legend ──────────────────────────────────────────────────────────────────

  Widget _legend() {
    return Wrap(
      key: const Key('emp-att-legend'),
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final s in kAttendanceLegend)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kAttendanceStatusColors[s]!.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: kAttendanceStatusColors[s], shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(s,
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.w600, color: attendanceInk(kAttendanceStatusColors[s]!))),
              ),
            ]),
          ),
      ],
    );
  }

  // ── Calendar + selected day ─────────────────────────────────────────────────

  Widget _body() {
    final cal = widget.calendar;
    if (cal.isLoading) {
      return const Padding(
        key: Key('emp-att-loading'),
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (cal.hasError) {
      return AppErrorState.forError(
        cal.error!,
        key: const Key('emp-att-error'),
        title: 'Could not load attendance',
        onRetry: widget.onRetry,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      );
    }
    final data = cal.requireValue;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 720;
      final grid = _grid(data);
      final details = _details(data);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: grid),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: details),
        ]);
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [grid, const SizedBox(height: 14), details]);
    });
  }

  Widget _grid(AttendanceCalendarEntity data) {
    final daysInMonth = DateUtils.getDaysInMonth(widget.month.year, widget.month.month);
    final lead = DateTime(widget.month.year, widget.month.month, 1).weekday % 7; // Sunday first, as web
    // The dense grid keeps its numbers readable at a fixed upper scale; the selected-day card below
    // shows everything at the user's own text size.
    final k = (MediaQuery.textScalerOf(context).scale(10) / 10).clamp(1.0, 1.3).toDouble();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (final d in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'])
            Expanded(
              child: Center(
                child: Text(d,
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textHint, letterSpacing: 0.4)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        GridView.builder(
          key: const Key('emp-att-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 52 * k,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: lead + daysInMonth,
          itemBuilder: (_, i) {
            if (i < lead) return const SizedBox.shrink();
            final day = i - lead + 1;
            return _DayCell(
              day: day,
              record: data.days[day],
              monthName: _kMonths[widget.month.month - 1],
              isToday: _isCurrentMonth && day == _today.day,
              selected: _selected == day,
              onTap: () => setState(() => _selected = day),
            );
          },
        ),
        if (data.days.isEmpty)
          Padding(
            key: const Key('emp-att-empty'),
            padding: const EdgeInsets.only(top: 10),
            child: Text('No attendance records for this month.',
                textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
          ),
      ]),
    );
  }

  // ── Selected-day details ────────────────────────────────────────────────────

  Widget _details(AttendanceCalendarEntity data) {
    final day = _selected;
    final month = widget.month;
    final record = day == null ? null : data.days[day];
    final date = day == null ? null : DateTime(month.year, month.month, day);
    final status = record?.status ?? '';
    final color = record == null ? AppColors.textHint : attendanceDayColor(status, record.color);
    final ink = attendanceInk(color);
    final nonWorking = _kNonWorking.contains(status);
    final noClockOut = record != null && record.clockIn != null && record.clockOut == null;

    Widget body;
    if (day == null) {
      body = Text('Select a day to see its clock in and clock out.',
          key: const Key('emp-att-select-hint'), style: AppTextStyles.bodySecondary);
    } else if (record == null) {
      body = Text('No attendance record for this day.',
          key: const Key('emp-att-no-record'), style: AppTextStyles.bodySecondary);
    } else {
      final hours = record.hours;
      final lateHint = _kLateHint[record.lateJustificationStatus];
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!nonWorking)
          LayoutBuilder(builder: (context, c) {
            final stacked = c.maxWidth < 240 || MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3;
            final tiles = [
              _TimeTile(
                key: const Key('emp-att-clock-in'),
                label: 'Clock In',
                icon: Icons.login_rounded,
                value: record.clockIn ?? '—',
                muted: record.clockIn == null,
              ),
              _TimeTile(
                key: const Key('emp-att-clock-out'),
                label: 'Clock Out',
                icon: Icons.logout_rounded,
                value: record.clockOut ?? (noClockOut ? 'Not clocked out' : '—'),
                muted: record.clockOut == null && !noClockOut,
                warn: noClockOut,
              ),
            ];
            return stacked
                ? Column(children: [tiles[0], const SizedBox(height: 8), tiles[1]])
                : Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 8), Expanded(child: tiles[1])]);
          }),
        if (!nonWorking && hours != null && hours.isNotEmpty && hours != '—') ...[
          const SizedBox(height: 8),
          _InfoRow(
              key: const Key('emp-att-day-hours'), icon: Icons.timer_outlined, label: 'Working hours', value: hours),
        ],
        if (status == 'Holiday' && (record.holidayName ?? '').isNotEmpty) ...[
          if (!nonWorking) const SizedBox(height: 8),
          _InfoRow(
              key: const Key('emp-att-holiday'),
              icon: Icons.celebration_outlined,
              label: 'Holiday',
              value: record.holidayName!),
        ],
        if (nonWorking && !(status == 'Holiday' && (record.holidayName ?? '').isNotEmpty))
          Text('No punches are expected on this day.', style: AppTextStyles.bodySecondary),
        if ((record.note ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoRow(
              key: const Key('emp-att-note'), icon: Icons.notes_outlined, label: 'Note', value: record.note!.trim()),
        ],
        if (lateHint != null) ...[
          const SizedBox(height: 8),
          _InfoRow(
              key: const Key('emp-att-late-hint'), icon: Icons.info_outline, label: 'Late arrival', value: lateHint),
        ],
      ]);
    }

    return Container(
      key: const Key('emp-att-details'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Attendance Details', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        if (date != null)
          Text('${_kWeekdays[date.weekday - 1]}, ${formatEnInDate(date)}',
              key: const Key('emp-att-date'), style: AppTextStyles.h4),
        if (record != null && status.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('emp-att-status'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(status, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: ink))),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        body,
      ]),
    );
  }

  // ── History ─────────────────────────────────────────────────────────────────

  Widget _historyBody() {
    final cal = widget.calendar;
    if (cal.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (cal.hasError) {
      return AppErrorState.forError(
        cal.error!,
        title: 'Could not load attendance',
        onRetry: widget.onRetry,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      );
    }
    return widget.historyBuilder(cal.requireValue);
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.record,
    required this.monthName,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });
  final int day;
  final CalendarDayEntity? record;
  final String monthName;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final status = r?.status ?? '';
    final color = r == null ? null : attendanceDayColor(status, r.color);
    final code = kAttendanceStatusCodes[status];
    final ink = color == null ? AppColors.textSecondary : attendanceInk(color);
    return Semantics(
      button: true,
      selected: selected,
      label: '$day $monthName, ${status.isEmpty ? 'no record' : status}${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: InkWell(
        key: Key('emp-att-day-$day'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color == null ? Colors.transparent : color.withValues(alpha: selected ? 0.26 : 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (color == null ? AppColors.border.withValues(alpha: 0.6) : Colors.transparent),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: isToday ? AppColors.primary : Colors.transparent, shape: BoxShape.circle),
              child: Text('$day',
                  style: AppTextStyles.label.copyWith(
                      fontSize: 12.5,
                      fontWeight: isToday || selected ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? Colors.white : (color == null ? AppColors.textSecondary : ink))),
            ),
            SizedBox(
              height: 14,
              child: code == null
                  ? null
                  : Text(code, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink, height: 1.4)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile(
      {super.key, required this.label, required this.icon, required this.value, this.muted = false, this.warn = false});
  final String label;
  final IconData icon;
  final String value;
  final bool muted;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AppColors.warning : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warn ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 6),
        Text(
          value,
          key: Key('${key is ValueKey ? (key as ValueKey).value : label}-value'),
          style: AppTextStyles.h3.copyWith(
            fontSize: warn ? 15 : 20,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: muted ? AppColors.textHint : (warn ? AppColors.warning : AppColors.textPrimary),
          ),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({super.key, required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
            Text(value, style: AppTextStyles.body),
          ]),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../providers/attendance_providers.dart' show attendanceRecordDetailProvider, friendlyAttendanceError;
import '../providers/month_view_providers.dart';

// Web EmployeeMonthView.tsx, laid out for a phone: (1) month navigator, (2) employee + overview,
// (3) one card per day (the web's calendar cells: day, status, clock in - out, hours, flagged).
// Data and labels are the web's; only the arrangement is adapted.

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthViewLabel(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';

/// A number as web prints it (JavaScript): 8.0 -> "8", 7.5 -> "7.5".
String monthViewNumber(num v) => v == v.truncate() ? '${v.truncate()}' : '$v';

bool _big(BuildContext c) => MediaQuery.textScalerOf(c).scale(10) / 10 > 1.3;

Color monthViewStatusColor(String status) => switch (status) {
      'present' => AppColors.success,
      'late' => AppColors.warning,
      'half_day' => AppColors.info,
      'on_leave' => AppColors.accentPurple,
      'absent' => AppColors.error,
      'incomplete' => AppColors.warning,
      _ => AppColors.textSecondary, // weekly_off, holiday, no_record
    };

/// Month navigator: previous / label / next (next is disabled at the current month, as on web).
class MonthViewMonthBar extends StatelessWidget {
  const MonthViewMonthBar({super.key, required this.month, required this.onPrev, required this.onNext});
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton.outlined(
          key: const Key('month-prev'),
          tooltip: 'Previous month',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        Expanded(
          child: Text(monthViewLabel(month),
              key: const Key('month-label'),
              textAlign: TextAlign.center,
              style: AppTextStyles.h4.copyWith(fontSize: 15)),
        ),
        IconButton.outlined(
          key: const Key('month-next'),
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ]);
}

/// Everything below the selection card for one employee + month.
class MonthViewPanel extends ConsumerWidget {
  const MonthViewPanel({super.key, required this.employee, required this.month});
  final String employee;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (employee: employee, month: monthViewIso(month));
    return ref.watch(employeeMonthViewProvider(key)).when(
          loading: () => const ApprovalsLoading(label: 'Loading attendance data…'),
          error: (e, _) => ApprovalsEmptyState.forError(e,
              what: 'attendance', onRetry: () => ref.invalidate(employeeMonthViewProvider(key))),
          data: (d) => Column(
            key: ValueKey('month-data-${d.month}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MonthViewOverview(data: d),
              const SizedBox(height: 16),
              const _Section('Monthly attendance records'),
              const SizedBox(height: 8),
              if (d.days.isEmpty)
                const ApprovalsEmptyState(
                    key: Key('month-empty'),
                    kind: ApprovalsStateKind.empty,
                    title: 'No attendance records for this month.',
                    icon: Icons.event_busy_outlined,
                    compact: true)
              else
                _DayGrid(days: d.days),
              const SizedBox(height: 12),
              const _Legend(),
            ],
          ),
        );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title,
      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12));
}

BoxDecoration _card() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    );

/// Employee header + the web's seven summary figures (Present, Late, Half Day, Absent, On Leave, LOP, Total Hrs).
class MonthViewOverview extends StatelessWidget {
  const MonthViewOverview({super.key, required this.data});
  final MonthViewData data;

  @override
  Widget build(BuildContext context) {
    final e = data.employee;
    final s = data.stats;
    final sub = [e.employeeId, e.designation, e.department].where((x) => x.isNotEmpty).join(' · ');
    final figures = <(String, String, Color)>[
      ('Present', monthViewNumber(s.present), AppColors.success),
      ('Late', monthViewNumber(s.late), AppColors.warning),
      ('Half Day', monthViewNumber(s.halfDay), AppColors.info),
      ('Absent', monthViewNumber(s.absent), AppColors.error),
      ('On Leave', monthViewNumber(s.onLeave), AppColors.accentPurple),
      ('LOP', monthViewNumber(s.lopDays), AppColors.error),
      ('Total Hrs', '${monthViewNumber(s.totalHours)}h', AppColors.textPrimary),
    ];
    return Container(
      key: const Key('month-overview'),
      decoration: _card(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.fullName.isEmpty ? '—' : e.fullName,
            style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final cols = _big(context) ? 2 : (c.maxWidth >= 560 ? 7 : (c.maxWidth >= 300 ? 4 : 3));
          const gap = 8.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final f in figures)
              SizedBox(
                width: w.floorToDouble(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.$1, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(f.$2,
                        key: Key('month-stat-${f.$1}'),
                        style: AppTextStyles.h4.copyWith(color: f.$3, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.days});
  final List<MonthViewDay> days;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 8.0;
        final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final d in days) SizedBox(width: w.floorToDouble(), child: MonthViewDayCard(day: d)),
        ]);
      });
}

/// One day: date + weekday, status, clock in - out, hours, and the web's "flagged" (absent / incomplete) mark.
class MonthViewDayCard extends ConsumerWidget {
  const MonthViewDayCard({super.key, required this.day});
  final MonthViewDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = monthViewStatusColor(day.status);
    final quiet = day.status == 'weekly_off' || day.status == 'holiday' || day.status == 'no_record';
    final hasTimes = day.clockIn != null;
    final tappable = day.recordId != null;
    return Semantics(
      container: true,
      button: tappable,
      label: '${day.date}, ${day.dayShort}, ${day.statusLabel}',
      child: Material(
        color: quiet ? AppColors.backgroundLow : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: day.isFlagged ? color : AppColors.border, width: day.isFlagged ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('month-day-${day.date}'),
          onTap: tappable ? () => showMonthViewRecordSheet(context, day) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 44,
                child: Column(children: [
                  Text('${day.dayNum}', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
                  Text(day.dayShort, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration:
                          BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(day.statusLabel,
                          style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                    if (day.isFlagged)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.flag_outlined, size: 13, color: color),
                        const SizedBox(width: 2),
                        Text('Flagged', style: AppTextStyles.caption.copyWith(color: color, fontSize: 11)),
                      ]),
                  ]),
                  if (hasTimes || day.totalHours > 0) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 10, runSpacing: 2, children: [
                      if (hasTimes)
                        Text('${day.clockIn}${day.clockOut != null ? ' – ${day.clockOut}' : ''}',
                            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                      if (day.totalHours > 0)
                        Text('${monthViewNumber(day.totalHours)}h',
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                    ]),
                  ],
                ]),
              ),
              if (tappable) Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const items = {
      'present': 'Present',
      'late': 'Late',
      'half_day': 'Half Day',
      'on_leave': 'On Leave',
      'absent': 'Absent',
      'incomplete': 'Incomplete',
      'weekly_off': 'Week Off',
      'holiday': 'Holiday',
    };
    return Wrap(spacing: 12, runSpacing: 6, children: [
      for (final e in items.entries)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: monthViewStatusColor(e.key).withValues(alpha: 0.15),
              border: Border.all(color: monthViewStatusColor(e.key)),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(e.value, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ]),
    ]);
  }
}

/// Read-only record detail for a day that has a record (web opens its detail drawer).
Future<void> showMonthViewRecordSheet(BuildContext context, MonthViewDay day) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => _RecordSheet(day: day),
    );

class _RecordSheet extends ConsumerWidget {
  const _RecordSheet({required this.day});
  final MonthViewDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendanceRecordDetailProvider((id: day.recordId!, isEmployeeId: false)));
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(l, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600))),
          ]),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Attendance — ${day.date}', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text(friendlyAttendanceError(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              row('Status', d.status),
              row('Clock In', d.clockIn),
              row('Clock Out', d.clockOut),
              row('Total Hours', d.totalHours),
              row('Overtime', d.overtime),
              if (d.note != null && d.note!.isNotEmpty) row('Note', d.note!),
              for (final p in d.punches) row(p.punchType, '${p.time} · ${p.mode}'),
            ]),
          ),
        ]),
      ),
    );
  }
}

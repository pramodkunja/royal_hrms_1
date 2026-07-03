import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  Timer? _timer;
  late DateTime _now;
  DateTime _calMonth = DateTime.now();
  int _localSessionSeconds = 0;
  bool _punching = false;

  // Keys are the backend's display labels (AttendanceRecord.STATUS_DISPLAY_MAP
  // values, e.g. "On Leave") — the calendar/history APIs return status as a
  // human label, not the raw lowercase status key.
  static const _dayStatusColors = <String, Color>{
    'Present': Color(0xFF1B8A6B),
    'Late': Color(0xFFD97706),
    'Absent': Color(0xFFC0392B),
    'On Leave': Color(0xFF0E7C86),
    'Half Day': Color(0xFF1E4E8C),
    'Weekly Off': Color(0xFF7C8AA3),
    'Holiday': Color(0xFFB5651D),
    'Incomplete': Color(0xFF9333EA),
  };

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _fullWeekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        final today = ref.read(todayAttendanceProvider).valueOrNull;
        if (today?.isClockedIn ?? false) _localSessionSeconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String get _clockStr =>
      '${_pad(_now.hour)}:${_pad(_now.minute)}:${_pad(_now.second)}';

  String _sessionStr(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${_pad(h)}:${_pad(m)}:${_pad(s)}';
  }

  String get _dateStr {
    final wd = _fullWeekdays[_now.weekday - 1];
    final m = _monthNames[_now.month - 1];
    return '$wd, ${_now.day} $m ${_now.year}';
  }

  MonthYearKey get _calKey => (year: _calMonth.year, month: _calMonth.month);

  Future<void> _toggleClock(TodayAttendanceEntity today) async {
    if (_punching) return;
    setState(() => _punching = true);

    final position = await ref.read(locationServiceProvider).getCurrentPosition();

    if (!mounted) return;
    final error = await ref.read(todayAttendanceProvider.notifier).punch(
          isCurrentlyClockedIn: today.isClockedIn,
          attendanceMode: 'office',
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
          // dart:io's Platform throws on web ("Unsupported operation:
          // _operatingSystem") — must guard with kIsWeb, same convention as
          // core/network/api_client.dart.
          deviceName: kIsWeb
              ? 'Web'
              : Platform.isAndroid
                  ? 'Android'
                  : Platform.isIOS
                      ? 'iOS'
                      : null,
          operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
        );

    if (!mounted) return;
    setState(() {
      _punching = false;
      _localSessionSeconds = 0;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  void _showCorrectionDialog() {
    showDialog(
      context: context,
      builder: (_) => const _CorrectionDialog(),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayAttendanceProvider);

    ref.listen(todayAttendanceProvider, (previous, next) {
      next.whenData((today) => _localSessionSeconds = today.sessionSeconds);
    });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayAttendanceProvider);
        ref.invalidate(attendanceStatsProvider);
        ref.invalidate(attendanceSummaryProvider);
        ref.invalidate(attendanceCalendarProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Attendance', style: AppTextStyles.h2),
            const SizedBox(height: 2),
            Text(
              'Clock in/out and view your personal attendance calendar',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildStatCards(),
            const SizedBox(height: 14),
            todayAsync.when(
              data: (today) => _buildClockPanel(today),
              loading: () => const _ClockPanelSkeleton(),
              error: (e, _) => _ErrorCard(
                message: friendlyAttendanceError(e),
                onRetry: () => ref.invalidate(todayAttendanceProvider),
              ),
            ),
            const SizedBox(height: 14),
            _buildMonthlySummary(),
            const SizedBox(height: 14),
            _buildCalendar(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Stat Cards ─────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final statsAsync = ref.watch(attendanceStatsProvider(_calKey));

    return statsAsync.when(
      data: (stats) {
        final workingDays = stats.workingDays > 0 ? stats.workingDays : 1;
        final cards = [
          _StatData(
            label: 'Days Present', value: '${stats.daysPresent}', sub: 'This month',
            icon: Icons.person_outline,
            iconColor: AppColors.success, iconBg: AppColors.successContainer,
            progress: (stats.daysPresent / workingDays).clamp(0.0, 1.0),
            progressColor: AppColors.success,
          ),
          _StatData(
            label: 'Late Arrivals', value: '${stats.lateArrivals}',
            sub: '${stats.lopPending} LOP pending',
            icon: Icons.access_alarm_outlined,
            iconColor: AppColors.warning, iconBg: AppColors.warningContainer,
            progress: (stats.lateArrivals / workingDays).clamp(0.0, 1.0),
            progressColor: AppColors.warning,
          ),
          _StatData(
            label: 'Avg Hours / Day', value: stats.avgHoursPerDay.toStringAsFixed(1),
            sub: 'This month',
            icon: Icons.access_time_outlined,
            iconColor: AppColors.info, iconBg: AppColors.infoContainer,
            progress: (stats.avgHoursPerDay / 10).clamp(0.0, 1.0),
            progressColor: AppColors.info,
          ),
          _StatData(
            label: 'Attendance %', value: '${stats.attendancePercentage.round()}%',
            sub: 'This month',
            icon: Icons.bar_chart_outlined,
            iconColor: AppColors.success, iconBg: AppColors.successContainer,
            progress: (stats.attendancePercentage / 100).clamp(0.0, 1.0),
            progressColor: AppColors.success,
          ),
        ];

        return SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _StatCard(data: cards[i]),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 115,
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

  // ── Clock Panel ────────────────────────────────────────────────────────────

  Widget _buildClockPanel(TodayAttendanceEntity today) {
    final sessionSeconds = today.isClockedIn ? _localSessionSeconds : today.sessionSeconds;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17355F), Color(0xFF1E4E8C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4E8C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _clockStr,
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              today.dateDisplay.isNotEmpty ? today.dateDisplay : _dateStr,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.75),
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    today.isClockedIn ? 'SESSION ACTIVE' : 'SESSION ENDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _sessionStr(sessionSeconds),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: today.isClockedIn
                          ? const Color(0xFF4ADE80)
                          : Colors.white60,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _StatusBadge(clockedIn: today.isClockedIn),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _punching ? null : () => _toggleClock(today),
              style: ElevatedButton.styleFrom(
                backgroundColor: today.isClockedIn
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF15803D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: (today.isClockedIn
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF15803D))
                    .withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _punching
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      today.isClockedIn ? 'Clock Out' : 'Clock In',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          if (today.punches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No punches recorded today.',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
              ),
            )
          else
            ...today.punches.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          p.type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.type == 'IN'
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFC8181),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.time,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          // Backend's `location` already includes the source label
                          // (e.g. "Chennai HQ · Mobile") — do not append attendanceMode again.
                          p.location.isNotEmpty ? p.location : '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.65),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: _showCorrectionDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined,
                    size: 15, color: Colors.white.withOpacity(0.75)),
                const SizedBox(width: 6),
                Text(
                  'Request Attendance Correction',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Monthly Summary ────────────────────────────────────────────────────────

  Widget _buildMonthlySummary() {
    final summaryAsync = ref.watch(attendanceSummaryProvider(_calKey));

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
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Monthly Summary', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 14),
          summaryAsync.when(
            data: (summary) => GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _SummaryCell(label: 'Working Days', value: '${summary.workingDays}', color: AppColors.primary),
                _SummaryCell(label: 'Days Present', value: '${summary.daysPresent}', color: AppColors.success),
                _SummaryCell(label: 'Days Absent', value: '${summary.daysAbsent}', color: AppColors.error),
                _SummaryCell(label: 'Leave Days', value: '${summary.leaveDays}', color: AppColors.warning),
                _SummaryCell(label: 'Half Days', value: '${summary.halfDays}', color: AppColors.info),
                _SummaryCell(label: 'OT Hours', value: summary.otHours, color: AppColors.success),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(friendlyAttendanceError(e),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Calendar ───────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final calendarAsync = ref.watch(attendanceCalendarProvider(_calKey));
    final daysInMonth = DateUtils.getDaysInMonth(_calMonth.year, _calMonth.month);
    final firstWd = DateTime(_calMonth.year, _calMonth.month, 1).weekday % 7;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: const [
                _LegendDot('Present', Color(0xFF1B8A6B)),
                _LegendDot('Late', Color(0xFFD97706)),
                _LegendDot('Absent', Color(0xFFC0392B)),
                _LegendDot('On Leave', Color(0xFF0E7C86)),
                _LegendDot('Half Day', Color(0xFF1E4E8C)),
                _LegendDot('Weekly Off', Color(0xFF7C8AA3)),
                _LegendDot('Holiday', Color(0xFFB5651D)),
                _LegendDot('Incomplete', Color(0xFF9333EA)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: () => setState(() {
                    _calMonth = DateTime(_calMonth.year, _calMonth.month - 1, 1);
                  }),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_monthNames[_calMonth.month - 1]} ${_calMonth.year}',
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: () => setState(() {
                    _calMonth = DateTime(_calMonth.year, _calMonth.month + 1, 1);
                  }),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
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
          const SizedBox(height: 4),

          calendarAsync.when(
            data: (calendar) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.05,
                ),
                itemCount: firstWd + daysInMonth,
                itemBuilder: (_, idx) {
                  if (idx < firstWd) return const SizedBox();
                  final day = idx - firstWd + 1;
                  final isToday = day == today.day &&
                      _calMonth.month == today.month &&
                      _calMonth.year == today.year;
                  final dayRecord = calendar.days[day];
                  final dotColor = dayRecord != null
                      ? _dayStatusColors[dayRecord.status]
                      : null;

                  return GestureDetector(
                    onTap: dayRecord == null
                        ? null
                        : () => _showDayDetail(day, dayRecord),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? AppColors.primary : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                              color: isToday ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (dotColor != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(friendlyAttendanceError(e),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDayDetail(int day, CalendarDayEntity record) {
    showDialog(
      context: context,
      // Must use the builder's own context, not the enclosing screen's —
      // popping with the screen's context resolves to GoRouter's root
      // Navigator and pops the current page/route instead of the dialog.
      builder: (dialogContext) => AlertDialog(
        title: Text('${_monthNames[_calMonth.month - 1]} $day, ${_calMonth.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Status', record.status),
            if (record.clockIn != null) _DetailRow('Clock In', record.clockIn!),
            if (record.clockOut != null) _DetailRow('Clock Out', record.clockOut!),
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

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _StatData {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final double progress;
  final Color progressColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.progress,
    required this.progressColor,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 15, color: data.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            data.sub,
            style: const TextStyle(fontSize: 10, color: AppColors.textHint, height: 1.2),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: data.progress,
              backgroundColor: AppColors.backgroundMid,
              valueColor: AlwaysStoppedAnimation(data.progressColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockPanelSkeleton extends StatelessWidget {
  const _ClockPanelSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 260,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17355F), Color(0xFF1E4E8C)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white70),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

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
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool clockedIn;
  const _StatusBadge({required this.clockedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: clockedIn
            ? const Color(0xFF166534).withOpacity(0.25)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: clockedIn
              ? const Color(0xFF4ADE80).withOpacity(0.45)
              : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: clockedIn ? const Color(0xFF4ADE80) : Colors.white38,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            clockedIn ? 'Clocked In' : 'Clocked Out',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: clockedIn ? const Color(0xFF4ADE80) : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

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
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Correction dialog ────────────────────────────────────────────────────────

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog();

  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  DateTime _date = DateTime.now();
  String _punchType = 'BOTH';
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  String _reason = CorrectionReasonCodes.forgotToPunch;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _punchTypeLabels = {
    'IN': 'Clock In (IN)',
    'OUT': 'Clock Out (OUT)',
    'BOTH': 'Both (Full Day)',
  };

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _needsIn => _punchType == 'IN' || _punchType == 'BOTH';
  bool get _needsOut => _punchType == 'OUT' || _punchType == 'BOTH';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _displayTime(TimeOfDay? t) => t == null ? 'Select time' : t.format(context);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isIn ? _inTime : _outTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => isIn ? _inTime = picked : _outTime = picked);
    }
  }

  Future<void> _submit() async {
    if (_needsIn && _inTime == null) {
      setState(() => _error = 'Correct In Time is required for this punch type.');
      return;
    }
    if (_needsOut && _outTime == null) {
      setState(() => _error = 'Correct Out Time is required for this punch type.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(attendanceCorrectionActionProvider).submit(
          date: _fmtDate(_date),
          punchType: _punchType,
          correctInTime: _needsIn && _inTime != null ? _fmtTime(_inTime!) : null,
          correctOutTime: _needsOut && _outTime != null ? _fmtTime(_outTime!) : null,
          reason: _reason,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Correction request submitted. Your manager will review it.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Attendance Correction Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Submit a correction for a missed or incorrect punch. Your manager will review and approve it.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Date',
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _FakeInput(value: _fmtDate(_date), icon: Icons.calendar_today_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    label: 'Punch Type',
                    child: DropdownButtonFormField<String>(
                      initialValue: _punchType,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      isExpanded: true,
                      items: _punchTypeLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _punchType = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                if (_needsIn)
                  Expanded(
                    child: _Field(
                      label: 'Correct In Time',
                      child: GestureDetector(
                        onTap: () => _pickTime(true),
                        child: _FakeInput(value: _displayTime(_inTime), icon: Icons.access_time_outlined),
                      ),
                    ),
                  ),
                if (_needsIn && _needsOut) const SizedBox(width: 10),
                if (_needsOut)
                  Expanded(
                    child: _Field(
                      label: 'Correct Out Time',
                      child: GestureDetector(
                        onTap: () => _pickTime(false),
                        child: _FakeInput(value: _displayTime(_outTime), icon: Icons.access_time_outlined),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            _Field(
              label: 'Reason',
              child: DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                isExpanded: true,
                items: CorrectionReasonCodes.labels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _reason = v!),
              ),
            ),
            const SizedBox(height: 12),

            _Field(
              label: 'Additional Notes (optional)',
              child: TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Describe the situation...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint),
                  isDense: true,
                  contentPadding: EdgeInsets.all(10),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_outlined, size: 15),
                    label: const Text('Submit Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _FakeInput extends StatelessWidget {
  final String value;
  final IconData icon;
  const _FakeInput({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          Icon(icon, size: 15, color: const Color(0xFF6B7280)),
        ]),
      );
}

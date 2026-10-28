import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/device_identifier.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../dashboard/presentation/widgets/dashboard_section.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_providers.dart';
import '../widgets/attendance_ring.dart';
import '../widgets/hr_correction_card.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen>
    with SingleTickerProviderStateMixin {
  DateTime _calMonth = DateTime.now();
  int _calendarTab =
      0; // 0 = Calendar, 1 = History — mirrors web's tab switcher

  // Top-level "Attendance" / "Attendance Corrections" tabs — mirrors web's
  // my-attendance page tab switcher (AttendanceTab / AttendanceCorrectionsTab).
  late final TabController _tabController;

  // Keys are the backend's display labels (AttendanceRecord.STATUS_DISPLAY_MAP
  // values, e.g. "On Leave") — the calendar/history APIs return status as a
  // human label, not the raw lowercase status key.
  //
  // Reads through AppColors (not `const` hex literals) so the calendar dots
  // and history badges flip to the dark palette instead of staying pinned to
  // their light-mode hues.
  static Map<String, Color> get _dayStatusColors => {
        'Present': AppColors.success,
        'Late': AppColors.warning,
        'Absent': AppColors.error,
        'On Leave': AppColors.info,
        'Half Day': AppColors.primary,
        'Weekly Off': AppColors.textHint,
        'Holiday': AppColors.warning,
        'Incomplete': AppColors.accentPurple,
      };

  static const _monthNames = [
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

  MonthYearKey get _calKey => (year: _calMonth.year, month: _calMonth.month);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: TabBar(
            controller: _tabController,
            // Evenly-split tabs (the TabBar default) don't leave "Attendance
            // Corrections" (icon + text) enough width on a phone screen —
            // isScrollable sizes each tab to its own content instead, which
            // also matches the screenshot's layout (tabs hug their content
            // with room left over, not stretched to fill the row).
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textPrimary,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle:
                AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Attendance'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Attendance Corrections'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAttendanceTab(),
              _buildCorrectionsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
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
            _buildStatCards(),
            const SizedBox(height: 14),
            // Owns its own todayAttendanceProvider watch, per-second clock
            // tick, punch state, and attendance-mode selection entirely
            // independently of this screen. Previously all of that lived
            // here as plain fields/methods, so the once-a-second Timer
            // driving the live clock display forced this whole screen's
            // build() — stat cards, monthly summary, calendar included — to
            // rerun every second even though none of those sections'
            // underlying data was actually changing. `const` means this
            // screen rebuilding for an unrelated reason (e.g. the month
            // navigation below) can't touch this widget either.
            const _ClockPanel(),
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

  Widget _buildCorrectionsTab() {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myCorrectionsProvider),
      child: const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: _MyCorrectionsSection(),
      ),
    );
  }

  // ── Stat Cards ─────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final statsAsync = ref.watch(attendanceStatsProvider(_calKey));

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
              // Fixed mainAxisExtent (not childAspectRatio) so cell height
              // never depends on column width — narrower screens no longer
              // squeeze the label + value text below the space it needs.
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 72,
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

  // ── Calendar ───────────────────────────────────────────────────────────────

  bool get _isCurrentCalendarMonth {
    final now = DateTime.now();
    return _calMonth.year == now.year && _calMonth.month == now.month;
  }

  Widget _buildCalendar() {
    final calendarAsync = ref.watch(attendanceCalendarProvider(_calKey));
    final daysInMonth =
        DateUtils.getDaysInMonth(_calMonth.year, _calMonth.month);
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
          // Calendar / History tab switcher — mirrors web's CalendarAndHistory.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Expanded(
                    child: _CalTabButton(
                        label: 'Calendar',
                        icon: Icons.calendar_month_outlined,
                        selected: _calendarTab == 0,
                        onTap: () => setState(() => _calendarTab = 0))),
                const SizedBox(width: 8),
                Expanded(
                    child: _CalTabButton(
                        label: 'History',
                        icon: Icons.list_alt_outlined,
                        selected: _calendarTab == 1,
                        onTap: () => setState(() => _calendarTab = 1))),
              ],
            ),
          ),

          if (_calendarTab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _LegendDot('Present', _dayStatusColors['Present']!),
                  _LegendDot('Late', _dayStatusColors['Late']!),
                  _LegendDot('Absent', _dayStatusColors['Absent']!),
                  _LegendDot('On Leave', _dayStatusColors['On Leave']!),
                  _LegendDot('Half Day', _dayStatusColors['Half Day']!),
                  _LegendDot('Weekly Off', _dayStatusColors['Weekly Off']!),
                  _LegendDot('Holiday', _dayStatusColors['Holiday']!),
                  _LegendDot('Incomplete', _dayStatusColors['Incomplete']!),
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
                    _calMonth =
                        DateTime(_calMonth.year, _calMonth.month - 1, 1);
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
                  // Matches web: cannot navigate the calendar into future months.
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: _isCurrentCalendarMonth
                      ? null
                      : () => setState(() {
                            _calMonth = DateTime(
                                _calMonth.year, _calMonth.month + 1, 1);
                          }),
                  color: _isCurrentCalendarMonth
                      ? AppColors.textHint.withValues(alpha: 0.4)
                      : AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          if (_calendarTab == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                              color: isToday
                                  ? AppColors.primary
                                  : dotColor != null
                                      ? dotColor.withValues(alpha: 0.15)
                                      : Colors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday || dotColor != null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isToday
                                    ? Colors.white
                                    : dotColor ?? AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (dotColor != null) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: dotColor),
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

  // ── History list (tab) ────────────────────────────────────────────────────
  // Renders AttendanceCalendarEntity.history — decoded from the same
  // /attendance/calendar/ response as the grid, matching web's
  // AttendanceHistoryTable (the tab alternative to the calendar grid).

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
              statusColor: _dayStatusColors[history[i].status],
              onRegularize: () {
                final day = int.tryParse(history[i].date.split(' ').first);
                if (day == null) return;
                _showCorrectionDialog(
                    context, DateTime(_calMonth.year, _calMonth.month, day));
              },
            ),
          ],
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
        title:
            Text('${_monthNames[_calMonth.month - 1]} $day, ${_calMonth.year}'),
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
          if (record.canRegularize)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showCorrectionDialog(
                    context, DateTime(_calMonth.year, _calMonth.month, day));
              },
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Regularize'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─── Clock panel ────────────────────────────────────────────────────────────
//
// Fully self-contained: owns its own todayAttendanceProvider watch, the
// once-a-second clock/session-timer tick, punch-in-flight state, and
// attendance-mode selection. Extracted out of _MyAttendanceScreenState so
// that ticking the clock display doesn't force the stat cards / monthly
// summary / calendar sections to rebuild every second — see the `const
// _ClockPanel()` call site in _MyAttendanceScreenState.build() for the
// rationale.
// Mirrors the Dashboard's "Today's Attendance" card (AttendanceRingCard) —
// same SectionCard chrome, segmented ring, punch stat tiles and punch log,
// built from the shared widgets in attendance_ring.dart — plus the
// Attendance Mode selector, which is unique to this screen (the Dashboard
// card always punches as 'office').
class _ClockPanel extends ConsumerStatefulWidget {
  const _ClockPanel();

  @override
  ConsumerState<_ClockPanel> createState() => _ClockPanelState();
}

class _ClockPanelState extends ConsumerState<_ClockPanel>
    with SingleTickerProviderStateMixin {
  bool _punching = false;
  String _attendanceMode = 'office';

  // Seeded from the backend's `totalSeconds` on every fresh fetch, then
  // ticked forward locally once a second while clocked in — avoids re-
  // polling the API every second just to animate the ring.
  int _liveTotalSeconds = 0;
  bool _ticking = false;
  Timer? _ticker;

  late final AnimationController _ringCtrl;
  Tween<double> _ringTween = Tween(begin: 0, end: 0);
  double _displayedFraction = 0;

  // easeOutCubic: fast start, gentle settle — reads as the fill gliding to
  // a stop rather than snapping linearly to its target every tick.
  static const _ringCurve = Curves.easeOutCubic;

  // Matches backend AttendancePunch.attendance_mode choices exactly
  // (apps/attendance/models.py) and web's ClockWidget mode <select>.
  static const _attendanceModeLabels = {
    'office': 'Office',
    'wfh': 'Work from Home',
    'field': 'Field Work',
    'client_location': 'Client Location',
    'remote_office': 'Remote Office',
  };

  static const _attendanceModeIcons = {
    'office': Icons.business_outlined,
    'wfh': Icons.home_outlined,
    'field': Icons.terrain_outlined,
    'client_location': Icons.location_on_outlined,
    'remote_office': Icons.wifi_outlined,
  };

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..addListener(() => setState(() => _displayedFraction =
          _ringTween.transform(_ringCurve.transform(_ringCtrl.value))));

    final today = ref.read(todayAttendanceProvider).valueOrNull;
    if (today != null) _syncWith(today);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }

  double get _targetFraction =>
      (_liveTotalSeconds / kFullShiftSeconds).clamp(0.0, 1.0);

  void _animateRingToTarget() {
    _ringTween = Tween<double>(begin: _displayedFraction, end: _targetFraction);
    _ringCtrl.forward(from: 0);
  }

  // Re-seeds the live counter from a fresh server snapshot (initial load,
  // post-punch response, or a manual refresh) and starts/stops the local
  // per-second ticker to match the real clocked-in state.
  void _syncWith(TodayAttendanceEntity today) {
    _liveTotalSeconds = today.totalSeconds;
    _animateRingToTarget();

    if (today.isClockedIn && !_ticking) {
      _ticking = true;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _liveTotalSeconds++;
        _animateRingToTarget();
      });
    } else if (!today.isClockedIn && _ticking) {
      _ticking = false;
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _toggleClock(TodayAttendanceEntity today) async {
    if (_punching) return;
    setState(() => _punching = true);

    // Location is captured best-effort for every mode, not just 'office' —
    // only 'office' punches are geofence-checked server-side, but wfh/field/
    // client_location/remote_office still record GPS for the audit trail
    // when it's available. getCurrentPosition() never throws and resolves to
    // null on any permission/timeout/service failure, so this never blocks
    // the punch.
    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();

    if (!mounted) return;
    final error = await ref.read(todayAttendanceProvider.notifier).punch(
          isCurrentlyClockedIn: today.isClockedIn,
          attendanceMode: _attendanceMode,
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
          deviceId: await ref.read(deviceIdProvider.future),
        );

    if (!mounted) return;
    setState(() => _punching = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayAttendanceProvider);

    // Side-effect only — reseeds the live ticker whenever a new snapshot
    // arrives (first load, after a punch, or a pull-to-refresh), rather
    // than every rebuild the ring's own 1s ticker triggers.
    ref.listen<AsyncValue<TodayAttendanceEntity>>(todayAttendanceProvider,
        (prev, next) {
      final today = next.valueOrNull;
      if (today != null) _syncWith(today);
    });

    return todayAsync.when(
      data: _buildPanel,
      loading: () => const _ClockPanelSkeleton(),
      error: (e, _) => SectionCard(
        title: "Today's Attendance",
        icon: Icons.access_time_outlined,
        accentColor: AppColors.success,
        child: SectionError(
          message: friendlyAttendanceError(e),
          onRetry: () => ref.invalidate(todayAttendanceProvider),
        ),
      ),
    );
  }

  Widget _buildPanel(TodayAttendanceEntity today) {
    return SectionCard(
      title: "Today's Attendance",
      icon: Icons.access_time_outlined,
      accentColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AttendanceRing(
                fraction: _displayedFraction,
                isClockedIn: today.isClockedIn,
                elapsedSeconds: _liveTotalSeconds,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE MODE',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    PopupMenuButton<String>(
                      enabled: !_punching,
                      offset: const Offset(0, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 200),
                      onSelected: (v) => setState(() => _attendanceMode = v),
                      itemBuilder: (_) =>
                          _attendanceModeLabels.entries.map((e) {
                        final selected = e.key == _attendanceMode;
                        return PopupMenuItem<String>(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(
                                _attendanceModeIcons[e.key],
                                size: 18,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check,
                                    size: 16, color: AppColors.primary),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundMid,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(_attendanceModeIcons[_attendanceMode],
                                color: AppColors.textSecondary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _attendanceModeLabels[_attendanceMode] ??
                                    'Office',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.expand_more,
                                color: AppColors.textHint, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _punching ? null : () => _toggleClock(today),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: today.isClockedIn
                              ? AppColors.error
                              : AppColors.success,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: (today.isClockedIn
                                  ? AppColors.error
                                  : AppColors.success)
                              .withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _punching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      today.isClockedIn
                                          ? Icons.logout
                                          : Icons.login,
                                      size: 16,
                                      color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    today.isClockedIn
                                        ? 'Clock Out'
                                        : 'Clock In',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          if (today.punches.isEmpty)
            Text('No punches recorded yet today.',
                style: AppTextStyles.bodySecondary)
          else ...[
            Row(
              children: [
                Expanded(
                    child: PunchStatTile(
                        label: 'First Punch', punch: today.punches.first)),
                const SizedBox(width: 10),
                Expanded(
                  // "Last Punch" means the last clock-*out*, mirroring the
                  // backend's own AttendanceRecord.last_punch_out — not just
                  // whatever punch happens to be last in the list, which
                  // would silently repeat the IN punch (and look like a
                  // fabricated second data point) on every day the
                  // employee hasn't clocked out yet.
                  child: switch (lastOutPunch(today.punches)) {
                    final out? =>
                      PunchStatTile(label: 'Last Punch', punch: out),
                    _ => const PunchStatPlaceholderTile(label: 'Last Punch'),
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Punch Log',
              style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...today.punches.map((p) => PunchLogRow(punch: p)),
          ],
        ],
      ),
    );
  }
}

// Shared by both the clock panel ("Request Attendance Correction" link) and
// the calendar section (tapping a past day) — a top-level function taking
// `context` explicitly so it doesn't tie either caller to the other's state.
void _showCorrectionDialog(BuildContext context, DateTime date) {
  showDialog(
    context: context,
    builder: (_) => _CorrectionDialog(lockedDate: date),
  );
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

// ── My Corrections — own correction-request history ────────────────────────
//
// Mirrors web's "Attendance Corrections" tab (AttendanceCorrectionsTab.tsx):
// pending/approved/rejected counts + a "Request Attendance Correction" quick
// action + the recent-requests list — condensed into one section here since
// this screen is a single scroll, not a tabbed layout like web's.

// Status as the backend/L1-L2 workflow tracks it (`pending`/`l2_pending`/
// `approved`/`rejected`) collapsed to the simpler 3-way status web's
// AttendanceCorrectionsTab shows (toDisplayStatus in my-requests/_data.ts) —
// the granular L1/L2 breakdown still shows in the detail sheet's Approval
// Trail, just not in the list row's status pill.
String _myCorrectionDisplayStatus(String status) => switch (status) {
      'approved' => 'approved',
      'rejected' => 'rejected',
      _ => 'pending', // 'pending' and 'l2_pending' both read as "Pending"
    };

Color _myCorrectionStatusColor(String displayStatus) => switch (displayStatus) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

String _myCorrectionStatusLabel(String displayStatus) =>
    switch (displayStatus) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };

String _punchTypeLabel(String punchType) => switch (punchType) {
      'IN' => 'Check-in Correction',
      'OUT' => 'Check-out Correction',
      'BOTH' => 'Check-in & Check-out Correction',
      _ => 'Attendance Correction',
    };

const _correctionMonthAbbr = [
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
  'Dec',
];

// Backend sends "HH:MM" (24h) for original/requested punch times.
String _fmtTime12h(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '—';
  final parts = hhmm.split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  if (h == null) return hhmm;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final m = parts.length > 1 ? parts[1] : '00';
  return '${h12.toString().padLeft(2, '0')}:$m $period';
}

// `date` is a plain "YYYY-MM-DD".
String _fmtCorrectionDate(String yyyyMmDd) {
  final d = DateTime.tryParse(yyyyMmDd);
  if (d == null) return yyyyMmDd;
  return '${d.day.toString().padLeft(2, '0')} ${_correctionMonthAbbr[d.month - 1]} ${d.year}';
}

// `createdAt` is "YYYY-MM-DD HH:MM:SS" (space-separated, not full ISO).
String _fmtCorrectionSubmitted(String raw) {
  if (raw.isEmpty) return '—';
  final iso = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final d = DateTime.tryParse(iso);
  if (d == null) return raw;
  return '${d.day.toString().padLeft(2, '0')} ${_correctionMonthAbbr[d.month - 1]} ${d.year}';
}

void _showMyCorrectionDetail(BuildContext context, MyCorrectionEntity record) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MyCorrectionDetailSheet(record: record),
  );
}

// ── My Corrections tab body — mirrors web's AttendanceCorrectionsTab.tsx:
// Pending/Approved/Rejected counts, a "Request Attendance Correction" quick
// action, and the correction-requests list (every field the web table +
// MyCorrectionDetailModal show, just laid out for a phone).

class _MyCorrectionsSection extends ConsumerWidget {
  const _MyCorrectionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correctionsAsync = ref.watch(myCorrectionsProvider);

    return correctionsAsync.when(
      data: (records) => _MyCorrectionsBody(records: records),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 26),
            const SizedBox(height: 8),
            Text(friendlyAttendanceError(e),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(myCorrectionsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCorrectionsBody extends StatelessWidget {
  final List<MyCorrectionEntity> records;
  const _MyCorrectionsBody({required this.records});

  @override
  Widget build(BuildContext context) {
    final pending = records
        .where((r) => _myCorrectionDisplayStatus(r.status) == 'pending')
        .length;
    final approved = records
        .where((r) => _myCorrectionDisplayStatus(r.status) == 'approved')
        .length;
    final rejected = records
        .where((r) => _myCorrectionDisplayStatus(r.status) == 'rejected')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: _CorrectionCountTile(
                    label: 'Pending',
                    count: pending,
                    color: AppColors.warning)),
            const SizedBox(width: 10),
            Expanded(
                child: _CorrectionCountTile(
                    label: 'Approved',
                    count: approved,
                    color: AppColors.success)),
            const SizedBox(width: 10),
            Expanded(
                child: _CorrectionCountTile(
                    label: 'Rejected',
                    count: rejected,
                    color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Quick Actions',
          icon: Icons.bolt_outlined,
          accentColor: AppColors.warning,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCorrectionDialog(context, DateTime.now()),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Request Attendance Correction'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Correction Requests',
          icon: Icons.receipt_long_outlined,
          accentColor: AppColors.primary,
          child: records.isEmpty
              ? const SectionMessage(
                  icon: Icons.receipt_long_outlined,
                  label: 'No correction requests yet.',
                )
              : Column(
                  children: [
                    for (final r in records) _MyCorrectionRow(record: r),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CorrectionCountTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CorrectionCountTile(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('$count',
              style: AppTextStyles.h3
                  .copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// One row of "Correction Requests" — Date, Check-In, Check-Out, Reason,
// Status, tap-to-view-detail — mirrors web's table row fields exactly
// (Date/Check-In/Check-Out/Reason/Status/Action columns).
class _MyCorrectionRow extends StatelessWidget {
  final MyCorrectionEntity record;
  const _MyCorrectionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final showIn = record.punchType != 'OUT';
    final showOut = record.punchType != 'IN';
    final checkIn = showIn
        ? _fmtTime12h(record.requestedInTime ?? record.originalInTime)
        : '—';
    final checkOut = showOut
        ? _fmtTime12h(record.requestedOutTime ?? record.originalOutTime)
        : '—';
    final displayStatus = _myCorrectionDisplayStatus(record.status);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showMyCorrectionDetail(context, record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundMid,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_fmtCorrectionDate(record.date),
                      style: AppTextStyles.label
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _myCorrectionStatusColor(displayStatus)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_myCorrectionStatusLabel(displayStatus),
                      style: AppTextStyles.labelSmall.copyWith(
                          color: _myCorrectionStatusColor(displayStatus),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _MiniKV(k: 'Check-In', v: checkIn)),
              Expanded(child: _MiniKV(k: 'Check-Out', v: checkOut)),
            ]),
            const SizedBox(height: 8),
            Text(record.reason,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('View',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniKV extends StatelessWidget {
  final String k;
  final String v;
  const _MiniKV({required this.k, required this.v});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textHint, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      );
}

// Full detail — mirrors web's MyCorrectionDetailModal.tsx exactly: date +
// status, Check-in/Check-out original→requested arrows, Reason + Notes, the
// L1 (Manager) / L2 (HR) Approval Trail, and the Submitted timestamp.
class _MyCorrectionDetailSheet extends StatelessWidget {
  final MyCorrectionEntity record;
  const _MyCorrectionDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final showIn = record.punchType != 'OUT';
    final showOut = record.punchType != 'IN';
    final displayStatus = _myCorrectionDisplayStatus(record.status);
    final hasL2 =
        record.l2ApproverName != null && record.l2ApproverName!.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.history_edu_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_punchTypeLabel(record.punchType),
                          style: AppTextStyles.h4)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DATE',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textHint,
                              letterSpacing: 0.6,
                              fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(_fmtCorrectionDate(record.date),
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _myCorrectionStatusColor(displayStatus)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_myCorrectionStatusLabel(displayStatus),
                        style: TextStyle(
                            color: _myCorrectionStatusColor(displayStatus),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              if (showIn)
                _TimeChangeRow(
                  label: 'Check-in',
                  from: _fmtTime12h(record.originalInTime),
                  to: _fmtTime12h(record.requestedInTime),
                ),
              if (showIn && showOut) const SizedBox(height: 10),
              if (showOut)
                _TimeChangeRow(
                  label: 'Check-out',
                  from: _fmtTime12h(record.originalOutTime),
                  to: _fmtTime12h(record.requestedOutTime),
                ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              Text('REASON',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint,
                      letterSpacing: 0.6,
                      fontSize: 10)),
              const SizedBox(height: 4),
              Text(record.reason.isNotEmpty ? record.reason : '—',
                  style: AppTextStyles.body),
              if ((record.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(record.notes!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              Text('APPROVAL TRAIL',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHint,
                      letterSpacing: 0.6,
                      fontSize: 10)),
              const SizedBox(height: 8),
              StageLine(
                level: 'Manager',
                approverName: record.l1ApproverName,
                status: record.l1Status,
                remarks: record.l1Remarks,
              ),
              if (hasL2) ...[
                const SizedBox(height: 8),
                StageLine(
                  level: 'HR',
                  approverName: record.l2ApproverName,
                  status: record.l2Status,
                  remarks: record.l2Remarks,
                ),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              Text('Submitted ${_fmtCorrectionSubmitted(record.createdAt)}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChangeRow extends StatelessWidget {
  final String label;
  final String from;
  final String to;
  const _TimeChangeRow(
      {required this.label, required this.from, required this.to});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          Text('$from → $to',
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        ],
      );
}

class _ClockPanelSkeleton extends StatelessWidget {
  const _ClockPanelSkeleton();

  @override
  Widget build(BuildContext context) => SectionCard(
        title: "Today's Attendance",
        icon: Icons.access_time_outlined,
        accentColor: AppColors.success,
        child: const SectionMessage(
            icon: Icons.access_time_outlined, label: 'Loading…'),
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
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

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

// History row — matches web's AttendanceHistoryTable, including the
// frontend-only late-arrival highlight (clockIn text turns red if the raw
// "HH:MM" string sorts after "09:15" — purely a display rule, independent of
// the backend's own `is_late` status classification).
class _HistoryRow extends StatelessWidget {
  final AttendanceHistoryRowEntity row;
  final Color? statusColor;
  final VoidCallback onRegularize;

  const _HistoryRow({
    required this.row,
    required this.statusColor,
    required this.onRegularize,
  });

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
          if (row.canRegularize) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onRegularize,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Regularize',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Correction dialog ────────────────────────────────────────────────────────

class _CorrectionDialog extends ConsumerStatefulWidget {
  final DateTime lockedDate;
  const _CorrectionDialog({required this.lockedDate});

  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
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

  String _displayTime(TimeOfDay? t) =>
      t == null ? 'Select time' : t.format(context);

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
      setState(
          () => _error = 'Correct In Time is required for this punch type.');
      return;
    }
    if (_needsOut && _outTime == null) {
      setState(
          () => _error = 'Correct Out Time is required for this punch type.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(attendanceCorrectionActionProvider).submit(
          date: _fmtDate(widget.lockedDate),
          punchType: _punchType,
          correctInTime:
              _needsIn && _inTime != null ? _fmtTime(_inTime!) : null,
          correctOutTime:
              _needsOut && _outTime != null ? _fmtTime(_outTime!) : null,
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
      SnackBar(
        content: const Text(
            'Correction request submitted. Your manager will review it.'),
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
                Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Attendance Correction Request',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Submit a correction for a missed or incorrect punch. Your manager will review and approve it.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.warning, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  // Matches web's CorrectionModal: the date is always fixed to
                  // whatever day triggered the dialog (today, or the tapped
                  // calendar/history day) — not freely editable.
                  child: _Field(
                    label: 'Date',
                    child: _FakeInput(
                        value: _fmtDate(widget.lockedDate),
                        icon: Icons.lock_outline),
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
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      isExpanded: true,
                      items: _punchTypeLabels.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
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
                        child: _FakeInput(
                            value: _displayTime(_inTime),
                            icon: Icons.access_time_outlined),
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
                        child: _FakeInput(
                            value: _displayTime(_outTime),
                            icon: Icons.access_time_outlined),
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
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                isExpanded: true,
                items: CorrectionReasonCodes.labels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
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
                decoration: InputDecoration(
                  hintText: 'Describe the situation...',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: const OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_outlined, size: 15),
                    label: const Text('Submit Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary),
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
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
              child: Text(value,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          Icon(icon, size: 15, color: AppColors.textSecondary),
        ]),
      );
}

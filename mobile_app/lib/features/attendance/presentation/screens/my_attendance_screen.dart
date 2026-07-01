import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _Punch {
  final String type; // 'IN' or 'OUT'
  final String time;
  final String location;
  final String method;
  const _Punch(this.type, this.time, this.location, this.method);
}

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

// ─── Screen ──────────────────────────────────────────────────────────────────

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  Timer? _timer;
  late DateTime _now;
  bool _isClockedIn = true;
  int _sessionSeconds = 26 * 60 + 24; // demo: 26m 24s
  DateTime _calMonth = DateTime(2026, 7);

  final List<_Punch> _punches = [
    const _Punch('IN', '09:00', 'Chennai HQ', 'Biometric'),
    const _Punch('OUT', '15:25', 'Chennai HQ', 'Biometric'),
  ];

  static const _dayStatusColors = <String, Color>{
    'present': Color(0xFF1B8A6B),
    'late': Color(0xFFD97706),
    'absent': Color(0xFFC0392B),
    'on_leave': Color(0xFF0E7C86),
    'half_day': Color(0xFF1E4E8C),
    'weekly_off': Color(0xFF7C8AA3),
    'holiday': Color(0xFFB5651D),
  };

  final Map<String, String> _dayStatuses = {
    '2026-7-1': 'present',
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
      if (mounted) {
        setState(() {
          _now = DateTime.now();
          if (_isClockedIn) _sessionSeconds++;
        });
      }
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

  String get _sessionStr {
    final h = _sessionSeconds ~/ 3600;
    final m = (_sessionSeconds % 3600) ~/ 60;
    final s = _sessionSeconds % 60;
    return '${_pad(h)}:${_pad(m)}:${_pad(s)}';
  }

  String get _dateStr {
    final wd = _fullWeekdays[_now.weekday - 1];
    final m = _monthNames[_now.month - 1];
    return '$wd, ${_now.day} $m ${_now.year}';
  }

  void _toggleClock() {
    setState(() {
      if (_isClockedIn) {
        _isClockedIn = false;
        _punches.add(_Punch(
          'OUT', '${_pad(_now.hour)}:${_pad(_now.minute)}', 'Chennai HQ', 'Mobile',
        ));
      } else {
        _isClockedIn = true;
        _sessionSeconds = 0;
        _punches.add(_Punch(
          'IN', '${_pad(_now.hour)}:${_pad(_now.minute)}', 'Chennai HQ', 'Mobile',
        ));
      }
    });
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
    return SingleChildScrollView(
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
          _buildClockPanel(),
          const SizedBox(height: 14),
          _buildMonthlySummary(),
          const SizedBox(height: 14),
          _buildCalendar(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Stat Cards ─────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final cards = [
      const _StatData(
        label: 'Days Present', value: '22', sub: 'This month',
        icon: Icons.person_outline,
        iconColor: AppColors.success, iconBg: AppColors.successContainer,
        progress: 0.88, progressColor: AppColors.success,
      ),
      const _StatData(
        label: 'Late Arrivals', value: '3', sub: '1 LOP pending',
        icon: Icons.access_alarm_outlined,
        iconColor: AppColors.warning, iconBg: AppColors.warningContainer,
        progress: 0.12, progressColor: AppColors.warning,
      ),
      const _StatData(
        label: 'Avg Hours / Day', value: '8.4', sub: 'Required: 9.0 hrs',
        icon: Icons.access_time_outlined,
        iconColor: AppColors.info, iconBg: AppColors.infoContainer,
        progress: 0.93, progressColor: AppColors.info,
      ),
      const _StatData(
        label: 'Attendance %', value: '96%', sub: 'Above threshold',
        icon: Icons.bar_chart_outlined,
        iconColor: AppColors.success, iconBg: AppColors.successContainer,
        progress: 0.96, progressColor: AppColors.success,
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
  }

  // ── Clock Panel ────────────────────────────────────────────────────────────

  Widget _buildClockPanel() {
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
          // Live clock
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
              _dateStr,
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

          // Session info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isClockedIn ? 'SESSION ACTIVE' : 'SESSION ENDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.55),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _sessionStr,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _isClockedIn
                          ? const Color(0xFF4ADE80)
                          : Colors.white60,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _StatusBadge(clockedIn: _isClockedIn),
            ],
          ),
          const SizedBox(height: 14),

          // Clock In / Out button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleClock,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isClockedIn
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF15803D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                _isClockedIn ? 'Clock Out' : 'Clock In',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Punch log
          ..._punches.map((p) => Padding(
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
                        '${p.location} · ${p.method}',
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

          // Correction request link
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
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: const [
              _SummaryCell(
                  label: 'Working Days', value: '25', color: AppColors.primary),
              _SummaryCell(
                  label: 'Days Present', value: '22', color: AppColors.success),
              _SummaryCell(
                  label: 'Days Absent', value: '1', color: AppColors.error),
              _SummaryCell(
                  label: 'Leave Days', value: '1', color: AppColors.warning),
              _SummaryCell(
                  label: 'Half Days', value: '1', color: AppColors.info),
              _SummaryCell(
                  label: 'OT Hours', value: '2h', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  // ── Calendar ───────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_calMonth.year, _calMonth.month);
    // Dart weekday: Mon=1..Sun=7; convert to Sun=0..Sat=6
    final firstWd =
        DateTime(_calMonth.year, _calMonth.month, 1).weekday % 7;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Legend
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
              ],
            ),
          ),

          // Month nav
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
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: () => setState(() {
                    _calMonth =
                        DateTime(_calMonth.year, _calMonth.month + 1, 1);
                  }),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Weekday headers
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

          // Day grid
          Padding(
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
                final key =
                    '${_calMonth.year}-${_calMonth.month}-$day';
                final status = _dayStatuses[key];
                final dotColor =
                    status != null ? _dayStatusColors[status] : null;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isToday
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (dotColor != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

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
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            data.sub,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textHint, height: 1.2),
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
              color: clockedIn
                  ? const Color(0xFF4ADE80)
                  : Colors.white38,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            clockedIn ? 'Clocked In' : 'Clocked Out',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: clockedIn
                  ? const Color(0xFF4ADE80)
                  : Colors.white60,
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
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary, height: 1.2),
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
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Correction dialog ────────────────────────────────────────────────────────

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog();

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  String _punchType = 'Clock In (IN)';
  String _reason = 'Device malfunction / biometric error';
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
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
            // Title
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Attendance Correction Request',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Submit a correction for a missed or incorrect punch. Your manager will review and approve within the regularization cutoff window (7 days after month end).',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date + Punch Type
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Date',
                    child: TextFormField(
                      initialValue: '24/06/2025',
                      decoration: const InputDecoration(
                        suffixIcon: Icon(
                            Icons.calendar_today_outlined, size: 16),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
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
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'Clock In (IN)',
                            child: Text('Clock In (IN)')),
                        DropdownMenuItem(
                            value: 'Clock Out (OUT)',
                            child: Text('Clock Out (OUT)')),
                      ],
                      onChanged: (v) =>
                          setState(() => _punchType = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Correct In / Out times
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Correct In Time',
                    child: TextFormField(
                      initialValue: '09:05 AM',
                      decoration: const InputDecoration(
                        suffixIcon:
                            Icon(Icons.access_time_outlined, size: 16),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    label: 'Correct Out Time',
                    child: TextFormField(
                      initialValue: '06:10 PM',
                      decoration: const InputDecoration(
                        suffixIcon:
                            Icon(Icons.access_time_outlined, size: 16),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reason
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
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'Device malfunction / biometric error',
                      child: Text('Device malfunction / biometric error')),
                  DropdownMenuItem(
                      value: 'Forgot to punch',
                      child: Text('Forgot to punch')),
                  DropdownMenuItem(
                      value: 'System error', child: Text('System error')),
                  DropdownMenuItem(
                      value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _reason = v!),
              ),
            ),
            const SizedBox(height: 12),

            // Additional notes
            _Field(
              label: 'Additional Notes (optional)',
              child: TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the situation...',
                  hintStyle: TextStyle(
                      fontSize: 13, color: AppColors.textHint),
                  isDense: true,
                  contentPadding: EdgeInsets.all(10),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.send_outlined, size: 15),
                    label: const Text('Submit Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

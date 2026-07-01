import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Static event data (mirrors TeamCalendar.tsx) ──────────────────────────────

class _CalEvent {
  final String employee;
  final String type;
  final Color color;
  final int from;
  final int to;
  const _CalEvent(this.employee, this.type, this.color, this.from, this.to);
}

const _kEvents = <String, List<_CalEvent>>{
  '2026-06': [
    _CalEvent('Arjun Mehta',  'Casual Leave', AppColors.primary, 25, 26),
    _CalEvent('Suresh Kumar', 'Sick Leave',   AppColors.warning, 20, 20),
    _CalEvent('Priya Sharma', 'Casual Leave', AppColors.primary, 28, 28),
  ],
  '2026-07': [
    _CalEvent('Meena Iyer',  'Earned Leave', AppColors.success, 1,  5),
    _CalEvent('Rahul Singh', 'Earned Leave', AppColors.success, 10, 14),
  ],
};

const _kMonths = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const _kDays   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

// ── Widget ────────────────────────────────────────────────────────────────────

class TeamCalendarTab extends StatefulWidget {
  const TeamCalendarTab({super.key});

  @override
  State<TeamCalendarTab> createState() => _TeamCalendarTabState();
}

class _TeamCalendarTabState extends State<TeamCalendarTab> {
  DateTime _month = DateTime(2026, 6);

  String get _key =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  List<_CalEvent> get _events => _kEvents[_key] ?? [];

  void _prev() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
  }

  void _next() {
    setState(() => _month = DateTime(_month.year, _month.month + 1));
  }

  List<int?> _buildCells() {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final offset       = firstWeekday == 7 ? 0 : firstWeekday; // Sun=0
    final daysInMonth  = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <int?>[...List<int?>.filled(offset, null), ...List.generate(daysInMonth, (i) => i + 1)];
    while (cells.length % 7 != 0) { cells.add(null); }
    return cells;
  }

  List<_CalEvent> _dayEvents(int day) =>
      _events.where((e) => day >= e.from && day <= e.to).toList();

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    final now   = DateTime.now();
    final isCurrentMonth =
        now.year == _month.year && now.month == _month.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Legend ─────────────────────────────────────────────────────────
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(label: 'Casual Leave',  color: AppColors.primary),
              _LegendDot(label: 'Earned Leave',  color: AppColors.success),
              _LegendDot(label: 'Sick Leave',    color: AppColors.warning),
              _LegendDot(label: 'Maternity',     color: Color(0xFFAD95CF)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Calendar card ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Month navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _NavBtn(icon: Icons.chevron_left, onTap: _prev),
                      Expanded(
                        child: Text(
                          '${_kMonths[_month.month - 1]} ${_month.year}',
                          style: AppTextStyles.label,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      _NavBtn(icon: Icons.chevron_right, onTap: _next),
                    ],
                  ),
                ),

                // Day headers
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLow,
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: _kDays
                        .map((d) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(d,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // Calendar grid — rows of 7
                for (int row = 0; row < cells.length ~/ 7; row++)
                  Container(
                    decoration: BoxDecoration(
                      border: row < cells.length ~/ 7 - 1
                          ? const Border(bottom: BorderSide(color: AppColors.border))
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(7, (col) {
                        final idx = row * 7 + col;
                        final day = cells[idx];
                        final ev  = day != null ? _dayEvents(day) : <_CalEvent>[];
                        final isToday = isCurrentMonth && day == now.day;
                        final isWeekend = col == 0 || col == 6;

                        return Expanded(
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 62),
                            decoration: BoxDecoration(
                              color: day == null
                                  ? AppColors.backgroundLow
                                  : isWeekend
                                      ? AppColors.background
                                      : AppColors.surface,
                              border: col < 6
                                  ? const Border(right: BorderSide(color: AppColors.border))
                                  : null,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: day == null
                                ? null
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 22, height: 22,
                                          decoration: isToday
                                              ? const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)
                                              : null,
                                          child: Center(
                                            child: Text('$day',
                                                style: AppTextStyles.caption.copyWith(
                                                    fontSize: 11,
                                                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                                    color: isToday
                                                        ? Colors.white
                                                        : isWeekend
                                                            ? AppColors.textHint
                                                            : AppColors.textPrimary)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ...ev.take(2).map((e) => Container(
                                            margin: const EdgeInsets.only(bottom: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: e.color,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              e.employee.split(' ').first,
                                              style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                      if (ev.length > 2)
                                        Text('+${ev.length - 2}',
                                            style: AppTextStyles.caption.copyWith(fontSize: 8)),
                                    ],
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // ── Events this month ──────────────────────────────────────────────
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_outlined, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Leaves this month', style: AppTextStyles.label),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  for (final e in _events)
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.employee,
                                    style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Text(e.type, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                              ],
                            ),
                          ),
                          Text(
                            '${_kMonths[_month.month - 1].substring(0, 3)} ${e.from}  –  ${_kMonths[_month.month - 1].substring(0, 3)} ${e.to}',
                            style: AppTextStyles.caption.copyWith(fontSize: 10),
                          ),
                          const SizedBox(width: 10),
                          Text('${e.to - e.from + 1}d',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

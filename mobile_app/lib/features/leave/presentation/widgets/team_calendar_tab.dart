import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';

const _kMonths = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const _kDays   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

// Stable display order for the legend, matching the web frontend's leave type list.
// Values are the backend's raw `leave_type` codes (lowercase full words), not
// the 'CL'/'EL'/'SL' abbreviations — those are only display short-labels.
const _kTypeOrder = ['casual', 'earned', 'sick', 'lwp', 'maternity', 'paternity'];

DateTime? _parseIso(String iso) {
  try {
    return DateTime.parse(iso);
  } catch (_) {
    return null;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class TeamCalendarTab extends ConsumerStatefulWidget {
  const TeamCalendarTab({super.key});

  @override
  ConsumerState<TeamCalendarTab> createState() => _TeamCalendarTabState();
}

class _TeamCalendarTabState extends ConsumerState<TeamCalendarTab> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

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

  List<LeaveCalendarEventEntity> _dayEvents(
      List<LeaveCalendarEventEntity> events, int day) {
    final d = DateTime(_month.year, _month.month, day);
    return events.where((e) {
      final start = _parseIso(e.startDate);
      final end   = _parseIso(e.endDate);
      if (start == null || end == null) return false;
      final s = DateTime(start.year, start.month, start.day);
      final en = DateTime(end.year, end.month, end.day);
      return !d.isBefore(s) && !d.isAfter(en);
    }).toList();
  }

  String _fmtShort(String iso) {
    final d = _parseIso(iso);
    if (d == null) return '—';
    return '${_kMonths[d.month - 1].substring(0, 3)} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final asyncEvents =
        ref.watch(leaveCalendarProvider((_month.year, _month.month)));
    final cells = _buildCells();
    final now   = DateTime.now();
    final isCurrentMonth =
        now.year == _month.year && now.month == _month.month;

    return asyncEvents.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32, color: AppColors.error),
              const SizedBox(height: 8),
              Text('Failed to load team calendar.',
                  style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ),
      data: (events) {
        final legendCodes = _kTypeOrder
            .where((code) => events.any((e) => e.leaveTypeCode == code))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Legend ─────────────────────────────────────────────────────
              if (legendCodes.isNotEmpty) ...[
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: legendCodes.map((code) {
                    final name = events
                        .firstWhere((e) => e.leaveTypeCode == code)
                        .leaveTypeName;
                    return _LegendDot(
                      label: name,
                      color: Color(LeaveTypeColors.colorValueForCode(code)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // ── Calendar card ──────────────────────────────────────────────
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
                            final ev  = day != null ? _dayEvents(events, day) : <LeaveCalendarEventEntity>[];
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
                                                  color: Color(LeaveTypeColors
                                                      .colorValueForCode(e.leaveTypeCode)),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  e.employeeName.split(' ').first,
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

              // ── Events this month ────────────────────────────────────────────
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
                    if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No approved leaves for ${_kMonths[_month.month - 1]} ${_month.year}.',
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      )
                    else
                      for (final e in events)
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: Color(LeaveTypeColors
                                      .colorValueForCode(e.leaveTypeCode)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.employeeName,
                                        style: AppTextStyles.caption.copyWith(
                                            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    Text(e.leaveTypeName, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                              Text(
                                '${_fmtShort(e.startDate)}  –  ${_fmtShort(e.endDate)}',
                                style: AppTextStyles.caption.copyWith(fontSize: 10),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${e.totalDays == e.totalDays.roundToDouble() ? e.totalDays.toInt() : e.totalDays}d',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

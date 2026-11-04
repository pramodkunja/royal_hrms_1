import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/clock/clock_punch_flow.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/attendance_ring.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'dashboard_section.dart';

/// Today's Attendance card — a segmented circular progress ring (left) that
/// fills as the work day progresses, plus Clock In/Out, Attendance, and
/// Apply Leave actions (right). Replaces the old plain icon+button
/// `ClockInCard` on every dashboard that showed it (HR, and the generic/
/// Manager fallback) — same real punch API underneath, just a fuller set of
/// actions and a richer visual for "how much of today is done".
class AttendanceRingCard extends ConsumerStatefulWidget {
  const AttendanceRingCard({super.key});

  @override
  ConsumerState<AttendanceRingCard> createState() => _AttendanceRingCardState();
}

class _AttendanceRingCardState extends ConsumerState<AttendanceRingCard>
    with SingleTickerProviderStateMixin {
  bool _punching = false;

  // Seeded from the backend's `totalSeconds` on every fresh fetch, then
  // ticked forward locally once a second while clocked in — avoids re-
  // polling the API every second just to animate a ring.
  int _liveTotalSeconds = 0;
  bool _ticking = false;
  Timer? _ticker;

  late final AnimationController _ringCtrl;
  Tween<double> _ringTween = Tween(begin: 0, end: 0);
  double _displayedFraction = 0;

  // easeOutCubic: fast start, gentle settle — reads as the fill gliding to
  // a stop rather than snapping linearly to its target every tick.
  static const _ringCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..addListener(() => setState(
          () => _displayedFraction = _ringTween.transform(_ringCurve.transform(_ringCtrl.value))));

    // Seed once from whatever's already cached (covers the common case
    // where this provider resolved before this card even mounted) — every
    // update after this is handled by the ref.listen registered in build().
    final today = ref.read(todayAttendanceProvider).valueOrNull;
    if (today != null) _syncWith(today);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }

  double get _targetFraction => (_liveTotalSeconds / kFullShiftSeconds).clamp(0.0, 1.0);

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
    // Completed day: nothing to punch — skip GPS/geofence/face capture too.
    if (_punching || today.dayCompleted) return;
    setState(() => _punching = true);

    // The shared clock flow (also used by My Attendance): GPS → mode from
    // today's approved WFH request → geofence pre-check → face check when
    // mandatory → punch. The server re-validates the punch independently.
    final error = await runClockPunch(ref, context, today);

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
    ref.listen<AsyncValue<TodayAttendanceEntity>>(todayAttendanceProvider, (prev, next) {
      final today = next.valueOrNull;
      if (today != null) _syncWith(today);
    });

    // This card stays mounted across goToDashboardSection push/pop
    // navigation (see dashboardRevisitProvider's doc comment), so without
    // this its punch data would only ever reflect whatever was true at
    // login. `prev != null` skips the initial subscription — only actual
    // increments (a real return-to-dashboard) should re-fetch.
    ref.listen<int>(dashboardRevisitProvider, (prev, next) {
      if (prev != null) ref.invalidate(todayAttendanceProvider);
    });

    return SectionCard(
      title: "Today's Attendance",
      icon: Icons.access_time_outlined,
      accentColor: AppColors.success,
      child: todayAsync.when(
        data: (today) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AttendanceRing(fraction: _displayedFraction, isClockedIn: today.isClockedIn, elapsedSeconds: _liveTotalSeconds),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        // Matches web's ClockInButton: a completed day shows a
                        // disabled "Attendance Completed" instead of Clock In.
                        today.dayCompleted
                            ? _ActionButton(
                                icon: Icons.check_circle_outline,
                                label: 'Attendance Completed',
                                color: AppColors.textHint,
                                onTap: null,
                              )
                            : _ActionButton(
                                icon: today.isClockedIn ? Icons.logout : Icons.login,
                                label: today.isClockedIn ? 'Clock Out' : 'Clock In',
                                color: today.isClockedIn ? AppColors.error : AppColors.success,
                                loading: _punching,
                                onTap: () => _toggleClock(today),
                              ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.event_note_outlined,
                          label: 'Attendance',
                          color: AppColors.info,
                          onTap: () => goToDashboardSection(context, AppRoutes.myAttendance),
                        ),
                        // Only for users who may open Leave (leave.view;
                        // route permissions in access_control.dart).
                        if (canAccessPath(ref.watch(authStateProvider).valueOrNull?.user, AppRoutes.leave)) ...[
                          const SizedBox(height: 8),
                          _ActionButton(
                            icon: Icons.beach_access_outlined,
                            label: 'Apply Leave',
                            color: AppColors.secondary,
                            onTap: () => goToDashboardSection(context, AppRoutes.leave),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              if (today.punches.isEmpty)
                Text('No punches recorded yet today.', style: AppTextStyles.bodySecondary)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: PunchStatTile(label: 'First Punch', punch: today.punches.first),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // "Last Punch" means the last clock-*out*, mirroring the
                      // backend's own AttendanceRecord.last_punch_out — not just
                      // whatever punch happens to be last in the list, which
                      // would silently repeat the IN punch (and look like a
                      // fabricated second data point) on every day the
                      // employee hasn't clocked out yet.
                      child: switch (lastOutPunch(today.punches)) {
                        final out? => PunchStatTile(label: 'Last Punch', punch: out),
                        _ => const PunchStatPlaceholderTile(label: 'Last Punch'),
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Punch Log',
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...today.punches.map((p) => PunchLogRow(punch: p)),
              ],
            ],
          );
        },
        loading: () => const SectionMessage(icon: Icons.access_time_outlined, label: 'Loading…'),
        error: (e, _) => SectionError(
          message: friendlyAttendanceError(e),
          onRetry: () => ref.invalidate(todayAttendanceProvider),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap; // null = disabled
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


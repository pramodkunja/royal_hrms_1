import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile_app/core/location/location_service.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/core/utils/device_identifier.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/facial_recognition/domain/entities/face_registration_entity.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';
import 'package:mobile_app/features/facial_recognition/presentation/providers/facial_recognition_providers.dart';
import 'package:mobile_app/features/facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
import 'dashboard_section.dart';

// No per-org "standard shift length" is exposed by any API this app calls —
// the ring needs *some* fixed reference to call "100%", so this is a plain
// 8-hour workday, same assumption a plain "hours today" stat elsewhere in
// the app would make implicitly. Working past it just holds the ring at a
// full 100% rather than wrapping or overflowing.
const _kFullShiftSeconds = 8 * 3600;

/// The most recent clock-*out* of the day, or null if the employee hasn't
/// punched out yet (still clocked in on a single IN, or a punch-mode day
/// with no OUT recorded at all). Deliberately not `punches.last` — that's
/// just whatever event happened most recently regardless of type, which on
/// a still-clocked-in day is the same IN punch as `punches.first`.
PunchEntryEntity? _lastOutPunch(List<PunchEntryEntity> punches) {
  for (final p in punches.reversed) {
    if (p.type == 'OUT') return p;
  }
  return null;
}

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

  double get _targetFraction => (_liveTotalSeconds / _kFullShiftSeconds).clamp(0.0, 1.0);

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

  /// Face ID capture, run before the punch call only when the org-wide
  /// toggle is mandatory — mirrors web's useClockWidget.ts gate (same logic
  /// the old ClockInCard used).
  Future<FaceCaptureUiState?> _runFaceCaptureIfRequired() async {
    final isMandatory = await ref.read(faceVerificationStatusProvider.future).then((s) => s.isMandatory);
    if (!isMandatory) return null;

    final registration = await ref.read(myFaceRegistrationProvider.future);
    if (registration?.status != FaceRegistrationStatus.approved) {
      throw 'Face ID registration is mandatory and you don\'t have one yet. '
          'Contact your HR representative or manager to get registered.';
    }

    if (!mounted) throw 'Face ID verification was cancelled.';
    // No consentNoticeText — clock-in verification never collects new
    // biometric data, so it never needs fresh consent (only self/HR
    // registration does).
    final result = await showFaceCaptureSheet(
      context,
      title: 'Face ID Verification',
      subtitle: 'Confirm it\'s you to clock in.',
    );
    if (result?.captured.embedding == null) throw 'Face ID verification was cancelled.';
    return result!.captured;
  }

  Future<void> _toggleClock(TodayAttendanceEntity today) async {
    if (_punching) return;
    setState(() => _punching = true);

    FaceCaptureUiState? faceCapture;
    try {
      faceCapture = await _runFaceCaptureIfRequired();
    } catch (e) {
      if (!mounted) return;
      setState(() => _punching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (!mounted) return;

    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;

    final error = await ref.read(todayAttendanceProvider.notifier).punch(
          isCurrentlyClockedIn: today.isClockedIn,
          attendanceMode: 'office',
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
          deviceName: kIsWeb
              ? 'Web'
              : Platform.isAndroid
                  ? 'Android'
                  : Platform.isIOS
                      ? 'iOS'
                      : null,
          operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
          deviceId: await ref.read(deviceIdProvider.future),
          faceEmbedding: faceCapture?.embedding,
          livenessPassed: faceCapture?.livenessPassed,
          livenessScore: faceCapture?.livenessScore,
          captureSessionId: faceCapture?.captureSessionId,
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
      accentColor: const Color(0xFF1B8A6B),
      child: todayAsync.when(
        data: (today) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AttendanceRing(fraction: _displayedFraction, isClockedIn: today.isClockedIn, elapsedSeconds: _liveTotalSeconds),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _ActionButton(
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
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.beach_access_outlined,
                          label: 'Apply Leave',
                          color: AppColors.secondary,
                          onTap: () => goToDashboardSection(context, AppRoutes.leave),
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
                Text('No punches recorded yet today.', style: AppTextStyles.bodySecondary)
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _PunchStat(label: 'First Punch', punch: today.punches.first),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // "Last Punch" means the last clock-*out*, mirroring the
                      // backend's own AttendanceRecord.last_punch_out — not just
                      // whatever punch happens to be last in the list, which
                      // would silently repeat the IN punch (and look like a
                      // fabricated second data point) on every day the
                      // employee hasn't clocked out yet.
                      child: switch (_lastOutPunch(today.punches)) {
                        final out? => _PunchStat(label: 'Last Punch', punch: out),
                        _ => const _PunchStatPlaceholder(label: 'Last Punch'),
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
                ...today.punches.map((p) => _PunchLogRow(punch: p)),
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

/// One of the two "First Punch" / "Last Punch" tiles below the ring — a
/// compact IN/OUT-colored summary of the earliest and most recent punch of
/// the day (same [PunchEntryEntity] list the full Punch Log renders below).
/// Styled after this card's own Clock In/Out button: same green-IN/red-OUT
/// colors and the same solid icon-on-color treatment, just as a static tile.
class _PunchStat extends StatelessWidget {
  final String label;
  final PunchEntryEntity punch;

  const _PunchStat({required this.label, required this.punch});

  @override
  Widget build(BuildContext context) {
    final isIn = punch.type == 'IN';
    final color = isIn ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(isIn ? Icons.login : Icons.logout, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  punch.time,
                  style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stand-in for [_PunchStat] when there's no last-OUT punch yet — same
/// shape and sizing so the two-tile row doesn't jump around, but neutral
/// (grey, dashed-style icon) rather than falsely repeating another value.
class _PunchStatPlaceholder extends StatelessWidget {
  final String label;

  const _PunchStatPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundMid,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle),
            child: const Icon(Icons.logout, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '—',
                  style: AppTextStyles.h4.copyWith(color: AppColors.textHint, fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the Punch Log — every punch event of the day, in order. Uses
/// the same colored icon-on-circle language as [_PunchStat] above it, just
/// smaller, so the whole punch section reads as one consistent design.
class _PunchLogRow extends StatelessWidget {
  final PunchEntryEntity punch;

  const _PunchLogRow({required this.punch});

  @override
  Widget build(BuildContext context) {
    final isIn = punch.type == 'IN';
    final color = isIn ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(isIn ? Icons.login : Icons.logout, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(punch.time, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              punch.location.isNotEmpty ? punch.location : '—',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
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

class _AttendanceRing extends StatelessWidget {
  final double fraction;
  final bool isClockedIn;
  final int elapsedSeconds;

  const _AttendanceRing({required this.fraction, required this.isClockedIn, required this.elapsedSeconds});

  // Not `static const`/`static final` — AppColors' fields are plain mutable
  // statics that get reassigned on a light/dark theme switch, so caching
  // them once would freeze this ring on whichever theme was active at
  // first build.
  List<Color> get _segmentColors => [
        AppColors.success,
        AppColors.info,
        AppColors.secondary,
        AppColors.warning,
      ];

  String get _elapsedLabel {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(108, 108),
            painter: _SegmentedRingPainter(fraction: fraction, segmentColors: _segmentColors, strokeWidth: 10),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isClockedIn ? Icons.timer_outlined : Icons.timer_off_outlined,
                size: 14,
                color: isClockedIn ? AppColors.success : AppColors.textHint,
              ),
              const SizedBox(height: 3),
              Text(_elapsedLabel, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
              Text(
                '${(fraction * 100).round()}%',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paints the ring as 4 separate quarter-arcs with a clear gap between each
/// — one distinct break per 25% — so it reads as 4 filled milestones of a
/// work day rather than one plain continuous circle. Each quadrant has its
/// own color and only starts filling once progress reaches its own 25%
/// band. The actively-filling segment gets a soft sheen along its arc and a
/// small glowing "head" at its leading tip, so the fill reads as motion
/// rather than a flat static bar snapping into place.
class _SegmentedRingPainter extends CustomPainter {
  final double fraction; // 0..1 overall progress toward a full shift.
  final List<Color> segmentColors; // one per quadrant, exactly 4.
  final double strokeWidth;

  _SegmentedRingPainter({required this.fraction, required this.segmentColors, required this.strokeWidth});

  // Widened from the original 8° so the break at every 25% mark (0/90/180/
  // 270°) reads clearly as 4 separate milestones rather than a thin seam.
  static const _gapDegrees = 16.0;
  static const _segmentSweepDegrees = 90.0 - _gapDegrees;

  double _deg2rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final startDeg = -90 + i * 90 + _gapDegrees / 2;
      final startRad = _deg2rad(startDeg);

      track.color = segmentColors[i].withValues(alpha: 0.15);
      canvas.drawArc(rect, startRad, _deg2rad(_segmentSweepDegrees), false, track);

      final segmentProgress = (fraction * 4 - i).clamp(0.0, 1.0);
      if (segmentProgress <= 0) continue;

      final sweepRad = _deg2rad(_segmentSweepDegrees * segmentProgress);

      // A light-to-base sheen along the fill, brightest at the leading
      // edge — reads as a beam of light traveling forward rather than a
      // flat color filling in.
      fill.shader = SweepGradient(
        startAngle: startRad,
        endAngle: startRad + sweepRad + 0.001, // avoid a zero-sweep shader
        colors: [segmentColors[i], Color.lerp(segmentColors[i], Colors.white, 0.4)!],
      ).createShader(rect);
      canvas.drawArc(rect, startRad, sweepRad, false, fill);
      fill.shader = null;

      // Glowing head at the tip of whichever segment is actively filling —
      // skipped once a segment is fully complete, since there's no motion
      // left to draw attention to there.
      if (segmentProgress < 1.0) {
        final tipAngle = startRad + sweepRad;
        final tip = center + Offset(math.cos(tipAngle), math.sin(tipAngle)) * radius;

        final glow = Paint()
          ..color = segmentColors[i].withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(tip, strokeWidth * 0.9, glow);
        canvas.drawCircle(tip, strokeWidth * 0.32, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedRingPainter oldDelegate) => oldDelegate.fraction != fraction;
}

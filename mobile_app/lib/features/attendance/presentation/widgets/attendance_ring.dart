import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attendance_entity.dart';

// No per-org "standard shift length" is exposed by any API this app calls —
// the ring needs *some* fixed reference to call "100%", so this is a plain
// 8-hour workday, same assumption a plain "hours today" stat elsewhere in
// the app would make implicitly. Working past it just holds the ring at a
// full 100% rather than wrapping or overflowing.
const kFullShiftSeconds = 8 * 3600;

/// The most recent clock-*out* of the day, or null if the employee hasn't
/// punched out yet (still clocked in on a single IN, or a punch-mode day
/// with no OUT recorded at all). Deliberately not `punches.last` — that's
/// just whatever event happened most recently regardless of type, which on
/// a still-clocked-in day is the same IN punch as `punches.first`.
PunchEntryEntity? lastOutPunch(List<PunchEntryEntity> punches) {
  for (final p in punches.reversed) {
    if (p.type == 'OUT') return p;
  }
  return null;
}

/// A segmented circular progress ring showing how much of today's shift is
/// done — shared by the Dashboard's "Today's Attendance" card and the My
/// Attendance screen's clock panel so both read the same visual language.
class AttendanceRing extends StatelessWidget {
  final double fraction;
  final bool isClockedIn;
  final int elapsedSeconds;

  const AttendanceRing({super.key, required this.fraction, required this.isClockedIn, required this.elapsedSeconds});

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
            painter: SegmentedRingPainter(fraction: fraction, segmentColors: _segmentColors, strokeWidth: 10),
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
class SegmentedRingPainter extends CustomPainter {
  final double fraction; // 0..1 overall progress toward a full shift.
  final List<Color> segmentColors; // one per quadrant, exactly 4.
  final double strokeWidth;

  SegmentedRingPainter({required this.fraction, required this.segmentColors, required this.strokeWidth});

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
  bool shouldRepaint(covariant SegmentedRingPainter oldDelegate) => oldDelegate.fraction != fraction;
}

/// One of the "First Punch" / "Last Punch" tiles — a compact IN/OUT-colored
/// summary of a single punch event.
class PunchStatTile extends StatelessWidget {
  final String label;
  final PunchEntryEntity punch;

  const PunchStatTile({super.key, required this.label, required this.punch});

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

/// Stand-in for [PunchStatTile] when there's no last-OUT punch yet — same
/// shape and sizing so the two-tile row doesn't jump around, but neutral
/// (grey icon) rather than falsely repeating another value.
class PunchStatPlaceholderTile extends StatelessWidget {
  final String label;

  const PunchStatPlaceholderTile({super.key, required this.label});

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
/// the same colored icon-on-circle language as [PunchStatTile], just
/// smaller, so the whole punch section reads as one consistent design.
class PunchLogRow extends StatelessWidget {
  final PunchEntryEntity punch;

  const PunchLogRow({super.key, required this.punch});

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

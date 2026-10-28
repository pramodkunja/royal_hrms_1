import 'dart:async';
import 'dart:io' show Platform;

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
import 'package:mobile_app/features/attendance/presentation/widgets/attendance_ring.dart';
import 'package:mobile_app/features/facial_recognition/domain/entities/face_registration_entity.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';
import 'package:mobile_app/features/facial_recognition/presentation/providers/facial_recognition_providers.dart';
import 'package:mobile_app/features/facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
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

    if (!mounted) throw 'Face ID check was cancelled.';
    // No consentNoticeText — clock-in verification never collects new
    // biometric data, so it never needs fresh consent (only self/HR
    // registration does).
    final result = await showFaceCaptureSheet(
      context,
      title: 'Face ID Check',
      subtitle: 'Quick face check before clocking in.',
    );
    if (result?.captured.embedding == null) throw 'Face ID check was cancelled.';
    return result!.captured;
  }

  Future<void> _toggleClock(TodayAttendanceEntity today) async {
    if (_punching) return;
    setState(() => _punching = true);

    // 1. GPS first — the geofence pre-check below needs it, and so does the
    //    real punch call later; fetching it once up front means both reuse
    //    the exact same reading instead of taking two separate fixes a few
    //    seconds apart.
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;

    // 2. Geofence pre-check — reject an out-of-geofence (or missing-GPS,
    //    for a branch that requires it) attempt immediately, before ever
    //    opening face capture or spending a round trip on the real punch
    //    call that would reject it a moment later anyway. Matches the
    //    ordering already fixed on web (commit db599c9: geofence before
    //    face capture) and already enforced by the voice clock-in flow
    //    (apps.voice_commands.conversation_clock_in_face). Run for every
    //    attempt, not only when face verification is mandatory — it's a
    //    cheap read-only check and every clock-in benefits from failing
    //    fast, not just the ones that would otherwise waste a capture cycle.
    final geofenceError = await ref.read(todayAttendanceProvider.notifier).checkGeofence(
          attendanceMode: 'office',
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
        );
    if (geofenceError != null) {
      if (!mounted) return;
      setState(() => _punching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(geofenceError), backgroundColor: AppColors.error),
      );
      return;
    }
    if (!mounted) return;

    // 3. Face capture — only now that location is confirmed valid, and
    //    only when the org-wide toggle actually requires it (unchanged gate).
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

    // 4. The real punch — still sends the same location and face data, and
    //    is still independently, authoritatively re-validated server-side
    //    (PunchService.record_punch runs the identical GeofencingService.
    //    validate() again) regardless of step 2 having already passed; this
    //    pre-check is a UX optimization only, never a substitute for it.
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


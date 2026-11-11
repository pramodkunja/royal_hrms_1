import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Face-verification lockout after repeated failed matches — web
// hooks/useClockWidget.ts (lockoutUntil / lockoutSecondsRemaining) and
// components/ClockInButton.tsx ("Try again in …", button disabled).
//
// The lockout is the SERVER's: production FaceAntiSpoofingGuard trips after
// MAX_FAILED_ATTEMPTS = 5 failed matches inside a sliding 15-minute window
// (ATTEMPT_CAP_WINDOW_SECONDS = 900), and POST /attendance/punch/ then answers
// 403 {message, data: {blocked: true, retry_after_seconds: N}} — N = seconds
// until the oldest failure in the window ages out. The app never counts
// attempts itself; it only turns N into a deadline (like web's epoch-ms
// lockoutUntil), shows the countdown, and sends no punch until it passes.
// Other terminal blocks (replay, low confidence, incompatible registration,
// insecure transport) also say blocked: true but carry no number — no
// countdown, exactly as web (`typeof retry_after_seconds === "number"`).
//
// Kept app-wide (not per screen) so the dashboard card and My Attendance agree
// and navigating away and back keeps it; computed from the wall clock, so time
// spent in the background counts. Not persisted across an app restart (web
// loses it on reload too) — the server re-blocks with a fresh N anyway.

/// The clock the lockout reads (tests substitute it).
final faceLockoutClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The lockout deadline, or null when not locked out.
final faceLockoutProvider = NotifierProvider<FaceLockoutNotifier, DateTime?>(FaceLockoutNotifier.new);

class FaceLockoutNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  DateTime _now() => ref.read(faceLockoutClockProvider)();

  /// Web: `setLockoutUntil(Date.now() + retry_after_seconds * 1000)`.
  void lockFor(int seconds) => state = _now().add(Duration(seconds: seconds));

  /// Seconds left (web Math.ceil), 0 when not locked out.
  int remainingSeconds() => faceLockoutRemaining(state, _now());

  /// Web tick(): clears the deadline once it has passed.
  void clearIfExpired() {
    if (state != null && remainingSeconds() <= 0) state = null;
  }
}

int faceLockoutRemaining(DateTime? until, DateTime now) {
  if (until == null) return 0;
  final ms = until.difference(now).inMilliseconds;
  return ms <= 0 ? 0 : (ms / 1000).ceil();
}

/// Web formatCountdown: "4m 5s", or "45s" under a minute.
String formatLockoutCountdown(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return m > 0 ? '${m}m ${s}s' : '${s}s';
}

/// Web punch() guard toast.
String faceLockoutMessage(int seconds) =>
    'Too many failed face verification attempts. Please wait ${formatLockoutCountdown(seconds)} before trying again.';

/// Web ClockInButton label while locked out.
String faceLockoutButtonLabel(int seconds) => 'Try again in ${formatLockoutCountdown(seconds)}';

/// `retry_after_seconds` from a blocked punch refusal, or null when the
/// error isn't one (or carries no number — then there is no countdown).
int? faceLockoutRetryAfter(Object error) {
  if (error is! DioException) return null;
  final body = error.response?.data;
  final data = body is Map ? body['data'] : null;
  if (data is! Map || data['blocked'] != true) return null;
  final n = data['retry_after_seconds'];
  return n is num ? n.toInt() : null;
}

/// Rebuilds every second while a lockout is active (and on returning to the
/// foreground), giving [builder] the seconds left — null when not locked out.
/// Clears the lockout when it expires, re-enabling the punch buttons.
class FaceLockoutBuilder extends ConsumerStatefulWidget {
  const FaceLockoutBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, int? secondsLeft) builder;

  @override
  ConsumerState<FaceLockoutBuilder> createState() => _FaceLockoutBuilderState();
}

class _FaceLockoutBuilderState extends ConsumerState<FaceLockoutBuilder> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: recompute at once from the wall clock.
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    if (!mounted) return;
    ref.read(faceLockoutProvider.notifier).clearIfExpired();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final until = ref.watch(faceLockoutProvider);
    final left = faceLockoutRemaining(until, ref.read(faceLockoutClockProvider)());
    if (until != null && left > 0) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _timer?.cancel();
      _timer = null;
      // Expired while not ticking (e.g. just rebuilt): clear after this frame.
      if (until != null) WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
    }
    return widget.builder(context, until != null && left > 0 ? left : null);
  }
}

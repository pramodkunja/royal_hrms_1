import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/location/location_service.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/presentation/clock/clock_punch_flow.dart';
import 'package:mobile_app/features/attendance/presentation/clock/face_lockout.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_mode_provider.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';

// Task 46 (D-B03): face-verification lockout countdown, as web
// hooks/useClockWidget.ts + components/ClockInButton.tsx against production
// POST /attendance/punch/ (my_attendance.AttendancePunchView): after
// MAX_FAILED_ATTEMPTS = 5 failed matches within ATTEMPT_CAP_WINDOW_SECONDS =
// 900 the server answers 403 {message, data: {blocked: true,
// retry_after_seconds: N}}. The app never counts attempts; it shows
// "Try again in …" on a disabled button and sends nothing until N passes.
// A stand-in server and a fictitious face capture — no real punch, no real
// descriptor; nothing is logged.

const _capMessage = 'Too many failed face verification attempts. Please wait a few minutes before trying again, '
    'or contact HR if this keeps happening.';
const _mismatch = 'Face verification failed. Please try again.';

ResponseBody _ok(Object data) =>
    ResponseBody.fromString(jsonEncode({'status': 'success', 'message': 'Clocked in successfully.', 'data': data}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

ResponseBody _err(int status, String message, [Map<String, dynamic> data = const {}]) =>
    ResponseBody.fromString(jsonEncode({'status': 'error', 'message': message, 'data': data}), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> _today({bool clockedIn = false}) => {
      'is_clocked_in': clockedIn,
      'day_completed': false,
      'punches': <Object>[],
      'total_seconds': 0,
      'session_seconds': 0,
      'date_display': 'Wednesday, 11 November 2026',
    };

/// A punch answer: ok, an ordinary mismatch, or a blocked refusal.
typedef PunchAnswer = ResponseBody Function();
ResponseBody okPunch() => _ok(_today(clockedIn: true));
ResponseBody mismatch() => _err(403, _mismatch);
PunchAnswer capped(int? seconds) => () => _err(403, _capMessage, {
      'blocked': true,
      if (seconds != null) 'retry_after_seconds': seconds,
    });

class _Backend implements HttpClientAdapter {
  _Backend(this.answers);
  final List<PunchAnswer> answers;
  int punches = 0;
  int geofenceChecks = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    switch (o.path) {
      case ApiConstants.attendanceToday:
        return _ok(_today());
      case ApiConstants.wfhRequests:
        return _ok({'count': 0, 'results': []});
      case ApiConstants.attendanceGeofenceCheck:
        geofenceChecks++;
        return _ok({'allowed': true});
      case ApiConstants.faceVerificationStatus:
        return _ok({'is_mandatory': true});
      case ApiConstants.faceRegistrationMe:
        return _ok({'id': 'r1', 'status': 'approved'});
      case ApiConstants.attendancePunch:
        final a = answers[punches < answers.length ? punches : answers.length - 1];
        punches++;
        return a();
    }
    return _ok({});
  }

  @override
  void close({bool force = false}) {}
}

class _FixedLocation extends LocationService {
  @override
  Future<Position?> getCurrentPosition() async => Position(
        latitude: 17.385,
        longitude: 78.4867,
        timestamp: DateTime(2026),
        accuracy: 12,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => 'device-1';
  @override
  Future<void> write(String key, String value) async {}
}

// Fictitious capture (not a real descriptor).
const _capture =
    FaceCaptureUiState(embedding: [0.1, 0.2, 0.3], livenessPassed: true, livenessScore: 0.9, captureSessionId: 's-1');

class _Face {
  int opened = 0;
  Future<FaceCaptureUiState?> call(BuildContext _) async {
    opened++;
    return _capture;
  }
}

/// The wall clock the lockout reads, moved by hand.
DateTime now = DateTime(2026, 11, 11, 9, 30);

List<Override> _overrides(_Backend backend, _Face face) => [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      locationServiceProvider.overrideWithValue(_FixedLocation()),
      attendanceClockProvider.overrideWithValue(() => now),
      faceCapturePresenterProvider.overrideWithValue(face.call),
      faceLockoutClockProvider.overrideWithValue(() => now),
    ];

DioException blockedError(Object? data) => DioException(
      requestOptions: RequestOptions(path: '/attendance/punch/'),
      response: Response(
        requestOptions: RequestOptions(path: '/attendance/punch/'),
        statusCode: 403,
        data: {'status': 'error', 'message': _capMessage, 'data': data},
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => now = DateTime(2026, 11, 11, 9, 30));

  group('rules', () {
    test('web formatCountdown', () {
      expect(formatLockoutCountdown(0), '0s');
      expect(formatLockoutCountdown(45), '45s');
      expect(formatLockoutCountdown(60), '1m 0s');
      expect(formatLockoutCountdown(125), '2m 5s');
      expect(formatLockoutCountdown(900), '15m 0s');
      expect(faceLockoutButtonLabel(125), 'Try again in 2m 5s');
      expect(faceLockoutMessage(9), 'Too many failed face verification attempts. Please wait 9s before trying again.');
    });

    test('remaining is web Math.ceil of the time left; 0 once passed', () {
      final t = DateTime(2026, 1, 1, 10);
      expect(faceLockoutRemaining(null, t), 0);
      expect(faceLockoutRemaining(t.add(const Duration(milliseconds: 1500)), t), 2);
      expect(faceLockoutRemaining(t.add(const Duration(milliseconds: 1)), t), 1);
      expect(faceLockoutRemaining(t, t), 0);
      expect(faceLockoutRemaining(t.subtract(const Duration(seconds: 3)), t), 0);
    });

    test('retry_after_seconds read only from a blocked refusal carrying a number (web typeof check)', () {
      expect(faceLockoutRetryAfter(blockedError({'blocked': true, 'retry_after_seconds': 600})), 600);
      expect(faceLockoutRetryAfter(blockedError({'blocked': true, 'retry_after_seconds': 12.0})), 12);
      expect(faceLockoutRetryAfter(blockedError({'blocked': true})), isNull, reason: 'replay / low confidence');
      expect(faceLockoutRetryAfter(blockedError({'blocked': true, 'retry_after_seconds': null})), isNull);
      expect(faceLockoutRetryAfter(blockedError({'retry_after_seconds': 600})), isNull, reason: 'not blocked');
      expect(faceLockoutRetryAfter(blockedError(<String, dynamic>{})), isNull);
      expect(faceLockoutRetryAfter(Exception('x')), isNull);
    });

    test('deadline from the server value; clears only once passed; a new block starts a fresh one', () {
      final c = ProviderContainer(overrides: [faceLockoutClockProvider.overrideWithValue(() => now)]);
      addTearDown(c.dispose);
      final n = c.read(faceLockoutProvider.notifier);
      n.lockFor(900);
      expect(c.read(faceLockoutProvider), now.add(const Duration(seconds: 900)));
      now = now.add(const Duration(seconds: 899));
      n.clearIfExpired();
      expect(n.remainingSeconds(), 1);
      now = now.add(const Duration(seconds: 1));
      n.clearIfExpired();
      expect(c.read(faceLockoutProvider), isNull);
      n.lockFor(30);
      expect(n.remainingSeconds(), 30);
    });

    test('during a lockout punch() sends nothing; a blocked refusal starts it; a mismatch does not', () async {
      final backend = _Backend([mismatch, capped(120), okPunch]);
      final c = ProviderContainer(overrides: _overrides(backend, _Face()));
      addTearDown(c.dispose);
      await c.read(todayAttendanceProvider.future);
      final notifier = c.read(todayAttendanceProvider.notifier);
      Future<String?> punch() =>
          notifier.punch(isCurrentlyClockedIn: false, attendanceMode: 'office', faceEmbedding: const [0.1]);

      expect(await punch(), _mismatch);
      expect(c.read(faceLockoutProvider), isNull, reason: 'an ordinary mismatch never locks (the app counts nothing)');
      expect(await punch(), _capMessage, reason: 'the server\'s own message for the refusal itself');
      expect(c.read(faceLockoutProvider.notifier).remainingSeconds(), 120);
      expect(await punch(), faceLockoutMessage(120));
      expect(await punch(), faceLockoutMessage(120));
      expect(backend.punches, 2, reason: 'no request while locked out');
      now = now.add(const Duration(seconds: 120));
      expect(await punch(), isNull);
      expect(backend.punches, 3);
    });
  });

  group('shared flow and builder', () {
    testWidgets('runClockPunch during a lockout: web message, no GPS/geofence, no face capture, no punch',
        (tester) async {
      final backend = _Backend([okPunch]);
      final face = _Face();
      late WidgetRef ref;
      late BuildContext ctx;
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(backend, face),
        child: MaterialApp(
          home: Consumer(builder: (c, r, _) {
            ref = r;
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));
      final today = await tester.runAsync(() => ref.read(todayAttendanceProvider.future));
      ref.read(faceLockoutProvider.notifier).lockFor(42);
      final msg = await tester.runAsync(() => runClockPunch(ref, ctx, today!));
      expect(msg, faceLockoutMessage(42));
      expect(backend.geofenceChecks, 0);
      expect(face.opened, 0);
      expect(backend.punches, 0);
    });

    testWidgets('FaceLockoutBuilder alone: returning from the background recomputes without waiting for a tick',
        (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [faceLockoutClockProvider.overrideWithValue(() => now)],
        child: MaterialApp(
          home: Consumer(builder: (c, r, _) {
            ref = r;
            return FaceLockoutBuilder(builder: (_, left) => Text(left == null ? 'free' : 'left $left'));
          }),
        ),
      ));
      ref.read(faceLockoutProvider.notifier).lockFor(100);
      await tester.pump();
      expect(find.text('left 100'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 70));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(); // no time passes: only the resume can refresh it
      expect(find.text('left 30'), findsOneWidget);
      now = now.add(const Duration(seconds: 31));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('free'), findsOneWidget);
      expect(ref.read(faceLockoutProvider), isNull, reason: 'cleared on expiry');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('clock surfaces', () {
    Future<void> pump(WidgetTester tester, Widget child, _Backend backend, _Face face) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(backend, face),
        child: MaterialApp(
          home: Scaffold(body: child is MyAttendanceScreen ? child : SingleChildScrollView(child: child)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> tapClock(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Moves the wall clock and lets the 1-second ticker run.
    Future<void> elapse(WidgetTester tester, int seconds) async {
      now = now.add(Duration(seconds: seconds));
      await tester.pump(const Duration(seconds: 1));
    }

    bool clockEnabled(WidgetTester tester) {
      final key = find.byKey(const Key('clock-lockout-button'));
      final inside = find.descendant(of: key, matching: find.byType(ElevatedButton));
      final around = find.ancestor(of: key, matching: find.byType(ElevatedButton));
      final b = inside.evaluate().isNotEmpty ? inside : around;
      return tester.widget<ElevatedButton>(b.first).onPressed != null;
    }

    final surfaces = <String, Widget>{
      'dashboard card': const AttendanceRingCard(),
      'My Attendance': const MyAttendanceScreen(),
    };

    surfaces.forEach((name, surface) {
      group(name, () {
        testWidgets('blocked refusal: server message, then a disabled "Try again in …" button; taps send nothing',
            (tester) async {
          final backend = _Backend([capped(125)]);
          final face = _Face();
          await pump(tester, surface, backend, face);
          await tapClock(tester, 'Clock In');
          expect(find.text(_capMessage), findsOneWidget);
          expect(find.text('Try again in 2m 5s'), findsOneWidget);
          expect(find.byIcon(Icons.lock_outline), findsOneWidget);
          expect(clockEnabled(tester), isFalse);
          await tester.tap(find.text('Try again in 2m 5s'), warnIfMissed: false);
          await tester.pump();
          expect(backend.punches, 1);
          expect(face.opened, 1, reason: 'no new face capture during the lockout');
          await unmount(tester);
        });

        testWidgets('countdown ticks every second and the button comes back when it ends', (tester) async {
          final backend = _Backend([capped(65), okPunch]);
          await pump(tester, surface, backend, _Face());
          await tapClock(tester, 'Clock In');
          expect(find.text('Try again in 1m 5s'), findsOneWidget);
          await elapse(tester, 1);
          expect(find.text('Try again in 1m 4s'), findsOneWidget);
          await elapse(tester, 4);
          expect(find.text('Try again in 1m 0s'), findsOneWidget);
          await elapse(tester, 59);
          expect(find.text('Try again in 1s'), findsOneWidget);
          await elapse(tester, 1);
          await tester.pump();
          expect(find.byKey(const Key('clock-lockout-button')), findsNothing);
          expect(find.text('Clock In'), findsOneWidget);
          await tapClock(tester, 'Clock In');
          expect(backend.punches, 2, reason: 'punching works again after the lockout');
          await unmount(tester);
        });

        testWidgets('blocked without retry_after_seconds (replay / low confidence): message only, no lockout',
            (tester) async {
          final backend = _Backend([capped(null), okPunch]);
          await pump(tester, surface, backend, _Face());
          await tapClock(tester, 'Clock In');
          expect(find.text(_capMessage), findsOneWidget);
          expect(find.byKey(const Key('clock-lockout-button')), findsNothing);
          expect(find.text('Clock In'), findsOneWidget);
          await unmount(tester);
        });

        testWidgets('background and resume: the countdown reflects the time spent away at once', (tester) async {
          final backend = _Backend([capped(300)]);
          await pump(tester, surface, backend, _Face());
          await tapClock(tester, 'Clock In');
          expect(find.text('Try again in 5m 0s'), findsOneWidget);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          now = now.add(const Duration(seconds: 200));
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();
          expect(find.text('Try again in 1m 40s'), findsOneWidget);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          now = now.add(const Duration(seconds: 500));
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pump();
          await tester.pump();
          expect(find.byKey(const Key('clock-lockout-button')), findsNothing, reason: 'expired while away');
          expect(find.text('Clock In'), findsOneWidget);
          await unmount(tester);
        });
      });
    });

    testWidgets('navigation: the lockout set on the dashboard still applies on My Attendance and back', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = _Backend([capped(90)]);
      final page = ValueNotifier<int>(0);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(backend, _Face()),
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: page,
              builder: (_, p, __) => p == 0
                  ? const SingleChildScrollView(child: AttendanceRingCard())
                  : p == 1
                      ? const MyAttendanceScreen()
                      : const SizedBox(),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tapClock(tester, 'Clock In');
      expect(find.text('Try again in 1m 30s'), findsOneWidget);
      page.value = 1; // to My Attendance
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Try again in 1m 30s'), findsOneWidget);
      page.value = 2; // somewhere without a clock button
      await tester.pump();
      now = now.add(const Duration(seconds: 30));
      page.value = 0; // back to the dashboard
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Try again in 1m 0s'), findsOneWidget);
      expect(backend.punches, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('threshold is the server\'s: four ordinary failures leave the button usable; the fifth locks',
        (tester) async {
      final backend = _Backend([mismatch, mismatch, mismatch, mismatch, capped(900)]);
      await pump(tester, const AttendanceRingCard(), backend, _Face());
      for (var i = 0; i < 4; i++) {
        await tapClock(tester, 'Clock In');
        expect(find.byKey(const Key('clock-lockout-button')), findsNothing, reason: 'attempt ${i + 1}');
        await tester.pump(const Duration(seconds: 5)); // let the snackbar go
      }
      await tapClock(tester, 'Clock In');
      expect(find.text('Try again in 15m 0s'), findsOneWidget);
      expect(backend.punches, 5);
      await unmount(tester);
    });
  });
}

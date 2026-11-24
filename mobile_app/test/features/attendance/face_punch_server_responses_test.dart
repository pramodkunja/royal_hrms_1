// Server-verified face attendance: the app captures, sends the face data with every punch
// when Face ID is required (clock-in AND clock-out), and shows the SERVER's answer — it never
// decides "matched" itself. Stand-in API only (nothing leaves the test); the descriptors below
// are made-up numbers used only as test fixtures.
import 'dart:convert';
import 'dart:io';

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
import 'package:mobile_app/features/attendance/presentation/providers/attendance_mode_provider.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_controller.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';

final _now = DateTime(2026, 11, 4, 9, 30);

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> _today({required bool clockedIn}) => {
      'is_clocked_in': clockedIn,
      'day_completed': false,
      'punches': <Object>[],
      'total_seconds': 0,
      'session_seconds': 0,
      'date_display': 'Wednesday, 4 November 2026',
    };

/// How the stand-in answers POST /attendance/punch/.
typedef PunchReply = ({int status, String? message, Map<String, dynamic> data});
const PunchReply _accepted = (status: 200, message: null, data: {});

class _Backend implements HttpClientAdapter {
  _Backend({this.clockedIn = false, this.statusFails = false, this.registrationFails = false});
  final bool clockedIn;
  final bool statusFails;
  final bool registrationFails;
  final replies = <PunchReply>[]; // consumed in order; empty → accepted
  final punches = <Map<String, dynamic>>[];
  final hits = <String, int>{}; // requests per path

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    hits[o.path] = (hits[o.path] ?? 0) + 1;
    switch (o.path) {
      case ApiConstants.attendanceToday:
        return _json(200, {'status': 'success', 'data': _today(clockedIn: clockedIn)});
      case ApiConstants.attendanceGeofenceCheck:
        return _json(200, {
          'status': 'success',
          'data': {'allowed': true}
        });
      case ApiConstants.faceVerificationStatus:
        if (statusFails) return _json(500, {'status': 'error', 'message': 'Server error.', 'data': {}});
        return _json(200, {
          'status': 'success',
          'data': {'is_mandatory': true}
        });
      case ApiConstants.faceRegistrationMe:
        if (registrationFails) return _json(500, {'status': 'error', 'message': 'Server error.', 'data': {}});
        return _json(200, {
          'status': 'success',
          'data': {'id': 'r1', 'status': 'approved'}
        });
      case ApiConstants.attendancePunch:
        punches.add(Map<String, dynamic>.from(o.data as Map));
        final r = replies.isEmpty ? _accepted : replies.removeAt(0);
        if (r.status == 200) return _json(200, {'status': 'success', 'data': _today(clockedIn: !clockedIn)});
        return _json(r.status, {
          'status': 'error',
          if (r.message != null) 'message': r.message,
          'data': r.data,
        });
    }
    return _json(200, {
      'status': 'success',
      'data': {'results': <Object>[]}
    });
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

class _Storage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => 'device-1';
  @override
  Future<void> write(String key, String value) async {}
}

/// Stands in for the camera sheet: every call is a NEW capture with its own session id and
/// numbers (a fixture, not a real descriptor).
class _Camera {
  int opened = 0;
  final sessions = <String>[];
  Future<FaceCaptureUiState?> call(BuildContext _) async {
    opened++;
    final id = 'session-$opened';
    sessions.add(id);
    return FaceCaptureUiState(
      embedding: List<double>.generate(128, (i) => (i + opened) / 1000),
      livenessPassed: true,
      livenessScore: 0.9,
      captureSessionId: id,
    );
  }
}

class _DeniedCameraController extends FaceCaptureController {
  @override
  FaceCaptureUiState build() => const FaceCaptureUiState(phase: FaceCapturePhase.cameraDenied);
  @override
  Future<void> start({int? framesToCapture, livenessMode}) async {}
}

List<Override> _overrides(_Backend backend, {_Camera? camera, bool deniedCamera = false}) => [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
      locationServiceProvider.overrideWithValue(_FixedLocation()),
      attendanceClockProvider.overrideWithValue(() => _now),
      if (camera != null) faceCapturePresenterProvider.overrideWithValue(camera.call),
      if (deniedCamera) faceCaptureControllerProvider.overrideWith(_DeniedCameraController.new),
    ];

Future<void> _pump(WidgetTester t, Widget surface, List<Override> overrides) async {
  t.view.physicalSize = const Size(1080, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: surface is MyAttendanceScreen ? surface : SingleChildScrollView(child: surface)),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await t.pumpAndSettle(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final surfaces = <String, Widget>{
    'dashboard card': const AttendanceRingCard(),
    'My Attendance': const MyAttendanceScreen(),
  };

  group('the face data is sent with every punch when Face ID is required', () {
    surfaces.forEach((name, surface) {
      for (final (type, button, clockedIn) in [('IN', 'Clock In', false), ('OUT', 'Clock Out', true)]) {
        testWidgets('$name — clock-${type == 'IN' ? 'in' : 'out'}', (t) async {
          final backend = _Backend(clockedIn: clockedIn);
          final camera = _Camera();
          await _pump(t, surface, _overrides(backend, camera: camera));
          await _tap(t, button);
          expect(camera.opened, 1);
          final body = backend.punches.single;
          expect(body['punch_type'], type);
          expect(body['source'], 'mobile');
          expect((body['face_embedding'] as List).length, 128);
          expect(body['liveness_passed'], isTrue);
          expect(body['liveness_score'], 0.9);
          expect(body['capture_session_id'], 'session-1');
          await _unmount(t);
        });
      }
    });
  });

  group('every server answer is shown as is; the app decides nothing', () {
    final cases = <(String, PunchReply)>[
      (
        '400 face data missing',
        (status: 400, message: 'Face verification is required to record attendance.', data: <String, dynamic>{})
      ),
      (
        '403 face does not match',
        (status: 403, message: 'Face verification failed. Please try again.', data: <String, dynamic>{})
      ),
      ('403 geofence', (status: 403, message: 'You are outside the allowed location.', data: <String, dynamic>{})),
      ('422 invalid field', (status: 422, message: 'A valid punch type is required.', data: <String, dynamic>{})),
      ('401 not signed in', (status: 401, message: null, data: <String, dynamic>{})),
    ];
    for (final (type, button, clockedIn) in [('IN', 'Clock In', false), ('OUT', 'Clock Out', true)]) {
      for (final (label, reply) in cases) {
        testWidgets('clock-${type.toLowerCase()} — $label: the message is shown, nothing else changes', (t) async {
          final backend = _Backend(clockedIn: clockedIn)..replies.add(reply);
          await _pump(t, const AttendanceRingCard(), _overrides(backend, camera: _Camera()));
          await _tap(t, button);
          final expected = reply.message ?? 'Session expired. Please log in again.';
          expect(find.text(expected), findsOneWidget);
          expect(backend.punches, hasLength(1));
          expect(find.text(button), findsOneWidget); // still offered; no lockout
          expect(find.textContaining('Try again in'), findsNothing);
          await _unmount(t);
        });
      }

      testWidgets(
          'clock-${type.toLowerCase()} — 403 blocked: the countdown shows, the button is disabled and sends nothing',
          (t) async {
        final backend = _Backend(clockedIn: clockedIn)
          ..replies.add((
            status: 403,
            message: 'Too many failed face verification attempts.',
            data: {'blocked': true, 'retry_after_seconds': 300},
          ));
        final camera = _Camera();
        await _pump(t, const AttendanceRingCard(), _overrides(backend, camera: camera));
        await _tap(t, button);
        expect(find.text('Too many failed face verification attempts.'), findsOneWidget);
        expect(find.text('Try again in 5m 0s'), findsOneWidget);
        expect(find.text(button), findsNothing);
        await t.tap(find.text('Try again in 5m 0s'), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 100));
        expect(camera.opened, 1);
        expect(backend.punches, hasLength(1));
        await _unmount(t);
      });
    }
  });

  group('a retry is a new capture', () {
    testWidgets('after a refused face, the next try opens the camera again with a new session id and new numbers',
        (t) async {
      final backend = _Backend()
        ..replies.addAll([
          (status: 403, message: 'Face verification failed. Please try again.', data: <String, dynamic>{}),
          (status: 403, message: 'Face verification failed. Please try again.', data: <String, dynamic>{}),
        ]);
      final camera = _Camera();
      await _pump(t, const AttendanceRingCard(), _overrides(backend, camera: camera));
      for (var i = 0; i < 3; i++) {
        await _tap(t, 'Clock In');
      }
      expect(camera.opened, 3);
      final ids = [for (final p in backend.punches) p['capture_session_id']];
      expect(ids, ['session-1', 'session-2', 'session-3']);
      expect(ids.toSet(), hasLength(3));
      // a different capture each time: the first number differs, so nothing is cached or reused
      expect({for (final p in backend.punches) (p['face_embedding'] as List).first}, hasLength(3));
      await _unmount(t);
    });
  });

  group('request sequence for a face punch', () {
    testWidgets('exactly one status lookup, one registration lookup, one geofence check and one punch', (t) async {
      final backend = _Backend();
      final camera = _Camera();
      await _pump(t, const AttendanceRingCard(), _overrides(backend, camera: camera));
      await _tap(t, 'Clock In');
      expect(backend.hits[ApiConstants.faceVerificationStatus], 1);
      expect(backend.hits[ApiConstants.faceRegistrationMe], 1);
      expect(backend.hits[ApiConstants.attendanceGeofenceCheck], 1);
      expect(backend.hits[ApiConstants.attendancePunch], 1);
      await _unmount(t);
    });
  });

  group('camera permission denied', () {
    testWidgets('the sheet says so; closing it sends no punch and says the check was cancelled', (t) async {
      final backend = _Backend();
      await _pump(t, const AttendanceRingCard(), _overrides(backend, deniedCamera: true));
      await t.tap(find.text('Clock In'));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Camera permission is required to continue.'), findsOneWidget);
      await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      expect(backend.punches, isEmpty);
      expect(find.text(kFaceCheckCancelledMessage), findsOneWidget);
      await _unmount(t);
    });
  });

  group('a failed Face ID status or registration lookup keeps the punch blocked', () {
    for (final (label, backend) in [
      ('status', () => _Backend(statusFails: true)),
      ('registration', () => _Backend(registrationFails: true)),
    ]) {
      testWidgets('$label lookup fails: a readable message, no camera, no punch (never a raw error)', (t) async {
        final b = backend();
        final camera = _Camera();
        await _pump(t, const AttendanceRingCard(), _overrides(b, camera: camera));
        await _tap(t, 'Clock In');
        expect(camera.opened, 0);
        expect(b.punches, isEmpty);
        expect(find.textContaining('couldn\'t check your Face ID status'), findsOneWidget);
        expect(find.textContaining('Server error.'), findsOneWidget);
        expect(find.textContaining('DioException'), findsNothing);
        await _unmount(t);
      });
    }
  });

  group('no way around the face check, and nothing logged', () {
    final dirs = [
      Directory('lib/features/attendance/presentation/clock'),
      Directory('lib/features/facial_recognition'),
    ];
    final files = [
      for (final d in dirs)
        for (final f in d.listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart')) f
    ];

    test('the face and clock code has no debug, release or build-flag switch and no fixed descriptor', () {
      expect(files, isNotEmpty);
      final pattern = RegExp(
          r'kDebugMode|kReleaseMode|fromEnvironment|skipFace|bypass|fakeEmbedding|fixedEmbedding|dummyEmbedding',
          caseSensitive: false);
      for (final f in files) {
        expect(pattern.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('the face and clock code never prints or logs (so a descriptor cannot leak into logs)', () {
      final pattern = RegExp(r'\bprint\(|debugPrint\(|developer\.log\(|\blog\(');
      for (final f in files) {
        expect(pattern.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });
  });
}

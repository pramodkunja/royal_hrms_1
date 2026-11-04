import 'dart:async';
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
import 'package:mobile_app/features/attendance/presentation/providers/attendance_mode_provider.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';
import 'package:mobile_app/features/wfh/data/models/wfh_models.dart';

// Phase 1 A: one clock flow for the dashboard card and My Attendance —
// attendance mode from today's approved WFH request (web ClockWidget.tsx),
// geofence pre-check with that mode, face check when mandatory, then punch.

final _now = DateTime(2026, 11, 4, 9, 30);

Map<String, dynamic> _wfh(String start, String end,
        {String status = 'approved'}) =>
    {
      'id': '$start-$end-$status',
      'start_date': start,
      'end_date': end,
      'status': status
    };

ResponseBody _ok(Object data) => ResponseBody.fromString(
        jsonEncode({'status': 'success', 'message': 'ok', 'data': data}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

ResponseBody _err(int status, String message) => ResponseBody.fromString(
        jsonEncode({'status': 'error', 'message': message, 'data': {}}), status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

Map<String, dynamic> _today({bool clockedIn = false, bool completed = false}) =>
    {
      'is_clocked_in': clockedIn,
      'day_completed': completed,
      'punches': <Object>[],
      'total_seconds': 0,
      'session_seconds': 0,
      'date_display': 'Wednesday, 4 November 2026',
    };

class _Backend implements HttpClientAdapter {
  _Backend({
    this.wfh = const [],
    this.wfhFails = false,
    this.mandatory = false,
    this.registration = 'approved',
    this.geofenceError,
    this.completed = false,
    this.calendarDays = const {},
  });

  final List<Map<String, dynamic>> wfh;
  final bool wfhFails;
  final bool mandatory;
  final String? registration; // null = never registered
  final String? geofenceError;
  final bool completed;
  final Map<String, Map<String, dynamic>> calendarDays;
  final calls = <({String method, String path, Object? body})>[];
  final calendarRequests = <(int?, int?)>[];

  List<Map<String, dynamic>> bodies(String path) => calls
      .where((c) => c.path == path)
      .map((c) => Map<String, dynamic>.from(c.body as Map))
      .toList();

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    switch (o.path) {
      case ApiConstants.attendanceToday:
        return _ok(_today(completed: completed));
      case ApiConstants.wfhRequests:
        if (wfhFails) return _err(500, 'Server error.');
        return _ok({'count': wfh.length, 'results': wfh});
      case ApiConstants.attendanceGeofenceCheck:
        return geofenceError == null
            ? _ok({'allowed': true})
            : _err(400, geofenceError!);
      case ApiConstants.faceVerificationStatus:
        return _ok({'is_mandatory': mandatory});
      case ApiConstants.faceRegistrationMe:
        return _ok(registration == null
            ? <String, dynamic>{}
            : {'id': 'r1', 'status': registration});
      case ApiConstants.attendancePunch:
        return _ok(_today(clockedIn: true));
      case ApiConstants.attendanceCalendar:
        calendarRequests.add((
          o.queryParameters['month'] as int?,
          o.queryParameters['year'] as int?
        ));
        return _ok({
          'month': o.queryParameters['month'],
          'year': o.queryParameters['year'],
          'calendar': {'days': calendarDays},
          'history': <Object>[],
        });
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

const _capture = FaceCaptureUiState(
    embedding: [0.1, 0.2, 0.3],
    livenessPassed: true,
    livenessScore: 0.92,
    captureSessionId: 'session-1');

class _Face {
  _Face(this.result);
  final FaceCaptureUiState? result;
  int opened = 0;
  Future<FaceCaptureUiState?> call(BuildContext _) async {
    opened++;
    return result;
  }
}

List<Override> _overrides(_Backend backend, _Face face) => [
      dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
            ..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      locationServiceProvider.overrideWithValue(_FixedLocation()),
      attendanceClockProvider.overrideWithValue(() => _now),
      faceCapturePresenterProvider.overrideWithValue(face.call),
    ];

void main() {
  group('attendanceModeFor (web ClockWidget isTodayWithin)', () {
    List<WfhRequestModel> reqs(List<Map<String, dynamic>> rows) =>
        rows.map(WfhRequestModel.fromJson).toList();

    test(
        'an approved request covering today means wfh; start and end days count',
        () {
      expect(attendanceModeFor(reqs([_wfh('2026-11-01', '2026-11-06')]), _now),
          kAttendanceModeWfh);
      expect(attendanceModeFor(reqs([_wfh('2026-11-04', '2026-11-10')]), _now),
          kAttendanceModeWfh);
      expect(attendanceModeFor(reqs([_wfh('2026-10-30', '2026-11-04')]), _now),
          kAttendanceModeWfh);
      expect(attendanceModeFor(reqs([_wfh('2026-11-04', '2026-11-04')]), _now),
          kAttendanceModeWfh);
    });

    test('ended, future, pending, rejected or no requests mean office', () {
      expect(attendanceModeFor(reqs([_wfh('2026-10-01', '2026-11-03')]), _now),
          kAttendanceModeOffice);
      expect(attendanceModeFor(reqs([_wfh('2026-11-05', '2026-11-09')]), _now),
          kAttendanceModeOffice);
      for (final s in ['pending', 'l2_pending', 'rejected', 'cancelled']) {
        expect(
            attendanceModeFor(
                reqs([_wfh('2026-11-01', '2026-11-06', status: s)]), _now),
            kAttendanceModeOffice,
            reason: s);
      }
      expect(attendanceModeFor(const [], _now), kAttendanceModeOffice);
    });

    test('uses the local calendar date, not the time of day', () {
      expect(
          attendanceModeFor(reqs([_wfh('2026-11-04', '2026-11-04')]),
              DateTime(2026, 11, 4, 23, 59)),
          kAttendanceModeWfh);
    });
  });

  group('todayAttendanceModeProvider', () {
    Future<String> resolve(_Backend backend) async {
      final c = ProviderContainer(overrides: _overrides(backend, _Face(null)));
      addTearDown(c.dispose);
      return c.read(todayAttendanceModeProvider.future);
    }

    test('asks the server for approved requests only', () async {
      final backend = _Backend(wfh: [_wfh('2026-11-01', '2026-11-06')]);
      expect(await resolve(backend), kAttendanceModeWfh);
      final call =
          backend.calls.singleWhere((c) => c.path == ApiConstants.wfhRequests);
      expect(call.method, 'GET');
    });

    test('a failed lookup falls back to office, as on web', () async {
      expect(await resolve(_Backend(wfhFails: true)), kAttendanceModeOffice);
    });
  });

  group('both clock surfaces share one flow', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pump(
        WidgetTester tester, Widget child, _Backend backend, _Face face) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(backend, face),
        child: MaterialApp(
          home: Scaffold(
              body: child is MyAttendanceScreen
                  ? child
                  : SingleChildScrollView(child: child)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> clockIn(WidgetTester tester) async {
      await tester.tap(find.text('Clock In'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }

    final surfaces = <String, Widget>{
      'dashboard card': const AttendanceRingCard(),
      'My Attendance': const MyAttendanceScreen(),
    };

    surfaces.forEach((name, surface) {
      group(name, () {
        testWidgets('approved WFH today: geofence check and punch both use wfh',
            (tester) async {
          final backend = _Backend(wfh: [_wfh('2026-11-03', '2026-11-05')]);
          await pump(tester, surface, backend, _Face(null));
          await clockIn(tester);
          expect(
              backend
                  .bodies(ApiConstants.attendanceGeofenceCheck)
                  .single['attendance_mode'],
              'wfh');
          final punch = backend.bodies(ApiConstants.attendancePunch).single;
          expect(punch['attendance_mode'], 'wfh');
          expect(punch['punch_type'], 'IN');
          expect(punch['source'], 'mobile');
          expect(punch.containsKey('face_embedding'), isFalse); // not mandatory
          await unmount(tester);
        });

        testWidgets('no approved WFH today: office', (tester) async {
          final backend = _Backend(
              wfh: [_wfh('2026-11-03', '2026-11-05', status: 'pending')]);
          await pump(tester, surface, backend, _Face(null));
          await clockIn(tester);
          expect(
              backend
                  .bodies(ApiConstants.attendancePunch)
                  .single['attendance_mode'],
              'office');
          await unmount(tester);
        });

        testWidgets(
            'mandatory face + approved registration: capture, then punch with the face data',
            (tester) async {
          final backend = _Backend(mandatory: true);
          final face = _Face(_capture);
          await pump(tester, surface, backend, face);
          await clockIn(tester);
          expect(face.opened, 1);
          final punch = backend.bodies(ApiConstants.attendancePunch).single;
          expect(punch['face_embedding'], [0.1, 0.2, 0.3]);
          expect(punch['liveness_passed'], isTrue);
          expect(punch['liveness_score'], 0.92);
          expect(punch['capture_session_id'], 'session-1');
          await unmount(tester);
        });

        for (final reg in [null, 'pending', 'rejected']) {
          testWidgets(
              'mandatory face with ${reg ?? 'no'} registration: no capture, no punch',
              (tester) async {
            final backend = _Backend(mandatory: true, registration: reg);
            final face = _Face(_capture);
            await pump(tester, surface, backend, face);
            await clockIn(tester);
            expect(face.opened, 0);
            expect(backend.bodies(ApiConstants.attendancePunch), isEmpty);
            expect(find.text(kFaceRegistrationMissingMessage), findsOneWidget);
            await unmount(tester);
          });
        }

        testWidgets('cancelled face capture: no punch', (tester) async {
          final backend = _Backend(mandatory: true);
          await pump(tester, surface, backend, _Face(null));
          await clockIn(tester);
          expect(backend.bodies(ApiConstants.attendancePunch), isEmpty);
          expect(find.text(kFaceCheckCancelledMessage), findsOneWidget);
          await unmount(tester);
        });

        testWidgets('geofence refusal: no face capture and no punch',
            (tester) async {
          final backend = _Backend(
              mandatory: true,
              geofenceError: 'You are outside the office geofence.');
          final face = _Face(_capture);
          await pump(tester, surface, backend, face);
          await clockIn(tester);
          expect(face.opened, 0);
          expect(backend.bodies(ApiConstants.attendancePunch), isEmpty);
          expect(find.text('You are outside the office geofence.'),
              findsOneWidget);
          await unmount(tester);
        });

        testWidgets(
            'a second tap while a punch is in flight sends nothing more',
            (tester) async {
          final backend = _Backend(mandatory: true);
          final gate = Completer<FaceCaptureUiState?>();
          var opened = 0;
          await tester.pumpWidget(const SizedBox());
          tester.view.physicalSize = const Size(1080, 3000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(ProviderScope(
            overrides: [
              ..._overrides(backend, _Face(null)),
              faceCapturePresenterProvider.overrideWithValue((_) {
                opened++;
                return gate.future;
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                  body: surface is MyAttendanceScreen
                      ? surface
                      : SingleChildScrollView(child: surface)),
            ),
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          // Never leave a capture pending if an expectation fails.
          addTearDown(() {
            if (!gate.isCompleted) gate.complete(null);
          });
          // Two taps before the frame rebuilds (the button then shows a
          // spinner): only one capture may open and only one punch go out.
          await tester.tap(find.text('Clock In'));
          await tester.tap(find.text('Clock In'));
          await tester.pump(const Duration(milliseconds: 50));
          expect(opened, 1);
          gate.complete(_capture);
          await tester.pumpAndSettle(const Duration(milliseconds: 50));
          expect(backend.bodies(ApiConstants.attendancePunch), hasLength(1));
          await unmount(tester);
        });

        testWidgets('a completed day sends nothing (existing guard)',
            (tester) async {
          final backend = _Backend(completed: true);
          await pump(tester, surface, backend, _Face(_capture));
          await tester.tap(find.text('Attendance Completed'),
              warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(milliseconds: 50));
          expect(backend.bodies(ApiConstants.attendanceGeofenceCheck), isEmpty);
          expect(backend.bodies(ApiConstants.attendancePunch), isEmpty);
          await unmount(tester);
        });
      });
    });
  });

  group('My Attendance screen', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pumpScreen(WidgetTester tester, _Backend backend) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(backend, _Face(null)),
        child: const MaterialApp(home: Scaffold(body: MyAttendanceScreen())),
      ));
      // The mode label waits on the WFH lookup; let it resolve.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
        'no manual mode picker; a read-only label shows the derived mode',
        (tester) async {
      await pumpScreen(
          tester, _Backend(wfh: [_wfh('2026-11-04', '2026-11-04')]));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Field Work'), findsNothing);
      expect(find.text('Work from Home: approved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      await pumpScreen(tester, _Backend());
      expect(find.text('Office'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'the calendar can move into future months; the server is asked for that month',
        (tester) async {
      final backend = _Backend();
      await pumpScreen(tester, backend);
      final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
      await tester.ensureVisible(next);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
      final now = DateTime.now();
      for (var i = 1; i <= 2; i++) {
        await tester.tap(next);
        for (var j = 0; j < 3; j++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final target = DateTime(now.year, now.month + i, 1);
        expect(backend.calendarRequests, contains((target.month, target.year)),
            reason: 'requested $target');
        expect(tester.widget<IconButton>(next).onPressed, isNotNull,
            reason: 'still enabled in $target');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Regularize is offered only where the server says canRegularize',
        (tester) async {
      await pumpScreen(
          tester,
          _Backend(calendarDays: {
            '10': {'status': 'absent', 'canRegularize': false},
            '11': {'status': 'absent', 'canRegularize': true},
          }));
      Future<void> openDay(String day) async {
        final cell = find.descendant(
            of: find.byType(GridView), matching: find.text(day));
        await tester.ensureVisible(cell.first);
        await tester.tap(cell.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      await openDay('10');
      expect(find.text('Regularize'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 300));

      await openDay('11');
      expect(find.text('Regularize'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

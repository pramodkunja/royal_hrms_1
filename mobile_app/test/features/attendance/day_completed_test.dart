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
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/attendance_ring_card.dart';

/// The backend's TodayAttendanceSerializer payload
/// (apps/attendance/services_attendance.py get_today_session).
Map<String, dynamic> _today({required bool clockedIn, bool? completed, bool omitCompleted = false, int punches = 0}) => {
      'is_clocked_in': clockedIn,
      if (!omitCompleted) 'day_completed': completed,
      'punches': [
        for (var i = 0; i < punches; i++)
          {
            'type': i.isEven ? 'IN' : 'OUT',
            'time': i.isEven ? '09:00 AM' : '06:00 PM',
            'location': 'Head Office',
            'attendance_mode': 'office',
            'is_inside_geofence': true,
            'calculated_distance': 12.0,
          },
      ],
      'total_seconds': punches >= 2 ? 32400 : 0,
      'session_seconds': 0,
      'date_display': 'Friday, 30 October 2026',
    };

final _notStarted = _today(clockedIn: false, completed: false);
final _clockedIn = _today(clockedIn: true, completed: false, punches: 1);
final _completed = _today(clockedIn: false, completed: true, punches: 2);

ResponseBody _ok(Object data) => ResponseBody.fromString(
      jsonEncode({'status': 'success', 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _error(int status, String message) => ResponseBody.fromString(
      jsonEncode({'status': 'error', 'message': message, 'data': {}}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Scripted backend. `today` and `punch` are queues of responders consumed
/// in order (the last one repeats); every other path gets an empty success.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend({required List<FutureOr<ResponseBody> Function()> today, List<FutureOr<ResponseBody> Function()>? punch})
      : _today = today,
        _punch = punch ?? [];

  final List<FutureOr<ResponseBody> Function()> _today;
  final List<FutureOr<ResponseBody> Function()> _punch;
  final List<({String method, String path, Object? body})> calls = [];

  int count(String path, {String? method}) =>
      calls.where((c) => c.path == path && (method == null || c.method == method)).length;

  FutureOr<ResponseBody> Function() _next(List<FutureOr<ResponseBody> Function()> queue) =>
      queue.length > 1 ? queue.removeAt(0) : queue.first;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: options.method, path: options.path, body: options.data));
    if (options.path == ApiConstants.attendanceToday) return _next(_today)();
    if (options.path == ApiConstants.attendancePunch) return _next(_punch)();
    return _ok({});
  }

  @override
  void close({bool force = false}) {}
}

class _CountingLocationService extends LocationService {
  int calls = 0;

  @override
  Future<Position?> getCurrentPosition() async {
    calls++;
    return null;
  }
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

List<Override> _overrides(_FakeBackend backend, {LocationService? location}) => [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      if (location != null) locationServiceProvider.overrideWithValue(location),
    ];

void main() {
  group('TodayAttendanceModel.day_completed', () {
    test('parses true and false', () {
      expect(TodayAttendanceModel.fromJson(_completed).dayCompleted, isTrue);
      expect(TodayAttendanceModel.fromJson(_clockedIn).dayCompleted, isFalse);
      expect(TodayAttendanceModel.fromJson(_notStarted).dayCompleted, isFalse);
    });

    test('null or absent is treated as not completed (web: `day_completed ?? false`)', () {
      expect(TodayAttendanceModel.fromJson(_today(clockedIn: false, completed: null)).dayCompleted, isFalse);
      expect(TodayAttendanceModel.fromJson(_today(clockedIn: false, omitCompleted: true)).dayCompleted, isFalse);
    });

    test('completion comes only from the server flag, never from other fields', () {
      // Two punches and not clocked in, but the server says not completed.
      final m = TodayAttendanceModel.fromJson(_today(clockedIn: false, completed: false, punches: 2));
      expect(m.dayCompleted, isFalse);
      expect(m.isClockedIn, isFalse);
    });
  });

  group('TodayAttendanceNotifier', () {
    late _FakeBackend backend;
    late ProviderContainer container;

    Future<ProviderContainer> start(_FakeBackend b) async {
      backend = b;
      container = ProviderContainer(overrides: _overrides(b));
      addTearDown(container.dispose);
      // Keep the autoDispose provider alive for the whole test.
      container.listen(todayAttendanceProvider, (_, __) {});
      await container.read(todayAttendanceProvider.future);
      return container;
    }

    TodayAttendanceNotifier notifier() => container.read(todayAttendanceProvider.notifier);

    test('a completed day blocks another clock-in without calling the server', () async {
      await start(_FakeBackend(today: [() => _ok(_completed)]));
      final err = await notifier().punch(isCurrentlyClockedIn: false, attendanceMode: 'office');
      expect(err, kDayCompletedMessage);
      expect(backend.count(ApiConstants.attendancePunch), 0);
    });

    test('a completed day blocks another clock-out without calling the server', () async {
      await start(_FakeBackend(today: [() => _ok(_completed)]));
      final err = await notifier().punch(isCurrentlyClockedIn: true, attendanceMode: 'office');
      expect(err, kDayCompletedMessage);
      expect(backend.count(ApiConstants.attendancePunch), 0);
    });

    test('an incomplete day still allows clock-in, then clock-out; the server response decides completion',
        () async {
      await start(_FakeBackend(
        today: [() => _ok(_notStarted)],
        punch: [() => _ok(_clockedIn), () => _ok(_completed)],
      ));

      expect(await notifier().punch(isCurrentlyClockedIn: false, attendanceMode: 'office'), isNull);
      expect((backend.calls.last.body as Map)['punch_type'], 'IN');
      var state = container.read(todayAttendanceProvider).requireValue;
      expect(state.isClockedIn, isTrue);
      expect(state.dayCompleted, isFalse);

      expect(await notifier().punch(isCurrentlyClockedIn: true, attendanceMode: 'office'), isNull);
      expect((backend.calls.last.body as Map)['punch_type'], 'OUT');
      state = container.read(todayAttendanceProvider).requireValue;
      expect(state.dayCompleted, isTrue);
      expect(backend.count(ApiConstants.attendancePunch), 2);
    });

    test('a submitted punch is not treated as completion until the server answers', () async {
      final gate = Completer<ResponseBody>();
      await start(_FakeBackend(today: [() => _ok(_clockedIn)], punch: [() => gate.future]));

      final pending = notifier().punch(isCurrentlyClockedIn: true, attendanceMode: 'office');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(todayAttendanceProvider).requireValue.dayCompleted, isFalse);

      gate.complete(_ok(_completed));
      expect(await pending, isNull);
      expect(container.read(todayAttendanceProvider).requireValue.dayCompleted, isTrue);
    });

    test('a rejected punch leaves the state as it was and shows the server message', () async {
      const serverMessage = 'You have already clocked out today. Please try again tomorrow.';
      await start(_FakeBackend(today: [() => _ok(_clockedIn)], punch: [() => _error(400, serverMessage)]));

      final err = await notifier().punch(isCurrentlyClockedIn: true, attendanceMode: 'office');
      expect(err, serverMessage);
      final state = container.read(todayAttendanceProvider).requireValue;
      expect(state.dayCompleted, isFalse);
      expect(state.isClockedIn, isTrue);
    });

    test('a network failure does not mark the day complete', () async {
      await start(_FakeBackend(
        today: [() => _ok(_clockedIn)],
        punch: [() => throw DioException.connectionError(requestOptions: RequestOptions(), reason: 'offline')],
      ));

      final err = await notifier().punch(isCurrentlyClockedIn: true, attendanceMode: 'office');
      expect(err, isNotNull);
      expect(container.read(todayAttendanceProvider).requireValue.dayCompleted, isFalse);
    });

    test('refresh picks up the latest completion state from the server', () async {
      await start(_FakeBackend(today: [() => _ok(_clockedIn), () => _ok(_completed)]));
      expect(container.read(todayAttendanceProvider).requireValue.dayCompleted, isFalse);

      await notifier().refresh();
      expect(container.read(todayAttendanceProvider).requireValue.dayCompleted, isTrue);
      expect(backend.count(ApiConstants.attendanceToday), 2);
    });

    test('a failed refresh never turns an incomplete day into a completed one', () async {
      await start(_FakeBackend(today: [() => _ok(_clockedIn), () => _error(500, 'Server error')]));

      await notifier().refresh();
      final state = container.read(todayAttendanceProvider);
      expect(state.hasError, isTrue);
      // Riverpod keeps the last server value alongside the error; it must
      // still be the incomplete one, never a guessed completion.
      expect(state.valueOrNull?.dayCompleted ?? false, isFalse);
    });
  });

  group('Clock buttons', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    late _FakeBackend backend;
    late _CountingLocationService location;

    // The dashboard card is a section, so it gets a scrollable host; the My
    // Attendance screen scrolls itself and, as in the app (where it sits in
    // DashboardShell's Scaffold), only needs a Scaffold around it.
    Future<void> pump(WidgetTester tester, Widget child, Map<String, dynamic> today) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      backend = _FakeBackend(today: [() => _ok(today)]);
      location = _CountingLocationService();
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(backend, location: location),
        child: MaterialApp(
          home: Scaffold(body: child is MyAttendanceScreen ? child : SingleChildScrollView(child: child)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Clock widgets tick once a second; unmount so no timer is left pending.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    ElevatedButton buttonWith(WidgetTester tester, String label) =>
        tester.widget<ElevatedButton>(find.ancestor(of: find.text(label), matching: find.byType(ElevatedButton)));

    testWidgets('dashboard card: a completed day shows a disabled "Attendance Completed"', (tester) async {
      await pump(tester, const AttendanceRingCard(), _completed);

      expect(find.text('Attendance Completed'), findsOneWidget);
      expect(find.text('Clock In'), findsNothing);
      expect(find.text('Clock Out'), findsNothing);
      expect(buttonWith(tester, 'Attendance Completed').onPressed, isNull);

      await tester.tap(find.text('Attendance Completed'), warnIfMissed: false);
      await tester.pump();
      expect(location.calls, 0);
      expect(backend.count(ApiConstants.attendancePunch), 0);
      await unmount(tester);
    });

    testWidgets('dashboard card: incomplete days keep Clock In / Clock Out enabled', (tester) async {
      await pump(tester, const AttendanceRingCard(), _notStarted);
      expect(buttonWith(tester, 'Clock In').onPressed, isNotNull);
      expect(find.text('Attendance Completed'), findsNothing);
      await unmount(tester);

      await pump(tester, const AttendanceRingCard(), _clockedIn);
      expect(buttonWith(tester, 'Clock Out').onPressed, isNotNull);
      expect(find.text('Attendance Completed'), findsNothing);
      await unmount(tester);
    });

    testWidgets('My Attendance: a completed day shows a disabled "Attendance Completed"', (tester) async {
      await pump(tester, const MyAttendanceScreen(), _completed);

      expect(find.text('Attendance Completed'), findsOneWidget);
      expect(buttonWith(tester, 'Attendance Completed').onPressed, isNull);
      await tester.tap(find.text('Attendance Completed'), warnIfMissed: false);
      await tester.pump();
      expect(location.calls, 0);
      expect(backend.count(ApiConstants.attendancePunch), 0);
      await unmount(tester);
    });

    testWidgets('My Attendance: incomplete days keep the punch button enabled', (tester) async {
      await pump(tester, const MyAttendanceScreen(), _clockedIn);
      expect(buttonWith(tester, 'Clock Out').onPressed, isNotNull);
      expect(find.text('Attendance Completed'), findsNothing);
      await unmount(tester);
    });
  });
}

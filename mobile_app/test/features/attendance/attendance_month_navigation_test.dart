import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart';

// Phase 11.8 (audit row 29): My Attendance month navigation, forward into
// future months included. Web (my-attendance AttendanceTab.tsx) leaves
// forward navigation unbounded so employees can see upcoming holidays; the
// app matches (my_attendance_screen.dart, "Next month").
//
// The screen starts at the device's current month (`DateTime.now()`, not
// injectable), so each test reads the starting month from the screen's own
// heading and derives every expectation from it — they hold on any date.
// Synthetic data only; a stand-in for GET /attendance/{stats,summary,calendar}/.

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

typedef Ym = ({int year, int month});

Ym _next(Ym m) => m.month == 12 ? (year: m.year + 1, month: 1) : (year: m.year, month: m.month + 1);
Ym _prev(Ym m) => m.month == 1 ? (year: m.year - 1, month: 12) : (year: m.year, month: m.month - 1);
String _heading(Ym m) => '${_monthNames[m.month - 1]} ${m.year}';

/// A value unique to each month (over any 90 consecutive months), sent as
/// attendance_percentage and shown as "Attendance %" (e.g. "47%"), so the
/// screen's data can be tied to the month it was requested for. Kept to a
/// realistic three characters: flutter_test's square test font is far wider
/// than the app's, and the stat tile's value has a fixed 68 px column.
int _percent(Ym m) => (m.year * 12 + m.month) % 90 + 10;
String _marker(Ym m) => '${_percent(m)}%';

ResponseBody _ok(Object data) => ResponseBody.fromString(
      jsonEncode({'status': 'success', 'message': 'ok', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

class FakeAttendanceBackend implements HttpClientAdapter {
  final requests = <({String path, int? year, int? month})>[];

  /// path|year|month → the response waits for this.
  final holds = <String, Completer<void>>{};

  static const monthly = [
    ApiConstants.attendanceStats,
    ApiConstants.attendanceSummary,
    ApiConstants.attendanceCalendar
  ];

  List<Ym> requested(String path) => [
        for (final r in requests)
          if (r.path == path && r.year != null && r.month != null) (year: r.year!, month: r.month!)
      ];

  int count(String path, Ym m) => requested(path).where((x) => x == m).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    int? q(String k) =>
        o.queryParameters[k] is int ? o.queryParameters[k] as int : int.tryParse('${o.queryParameters[k]}');
    final year = q('year'), month = q('month');
    requests.add((path: o.path, year: year, month: month));
    if (o.path == ApiConstants.attendanceToday) {
      return _ok({
        'is_clocked_in': false,
        'day_completed': false,
        'punches': [],
        'total_seconds': 0,
        'session_seconds': 0,
        'date_display': '',
      });
    }
    if (monthly.contains(o.path) && year != null && month != null) {
      final gate = holds['${o.path}|$year|$month'];
      if (gate != null) await gate.future;
      final m = (year: year, month: month);
      if (o.path == ApiConstants.attendanceStats) {
        return _ok({
          'days_present': 0,
          'late_arrivals': 0,
          'lop_pending': 0,
          'avg_hours_per_day': 0,
          'attendance_percentage': _percent(m),
          'working_days': 0,
        });
      }
      if (o.path == ApiConstants.attendanceCalendar) {
        return _ok({
          'calendar': {'days': <String, dynamic>{}},
          'history': [],
        });
      }
      return _ok({'working_days': 0});
    }
    return _ok({});
  }

  @override
  void close({bool force = false}) {}
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

late FakeAttendanceBackend backend;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = FakeAttendanceBackend();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
    ],
    child: const MaterialApp(home: Scaffold(body: MyAttendanceScreen())),
  ));
  await _settle(tester);
}

// The clock widget ticks once a second; unmount so no timer is left pending.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The month the screen shows, read from its heading.
Ym shownMonth(WidgetTester tester) {
  final pattern = RegExp('^(${_monthNames.join('|')}) (\\d{4})\$');
  final headings =
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().where(pattern.hasMatch).toSet();
  expect(headings, hasLength(1), reason: 'exactly one month heading: $headings');
  final m = pattern.firstMatch(headings.single)!;
  return (year: int.parse(m.group(2)!), month: _monthNames.indexOf(m.group(1)!) + 1);
}

Finder get _nextButton => find.byTooltip('Next month');
Finder get _prevButton => find.widgetWithIcon(IconButton, Icons.chevron_left);

Future<void> tapNext(WidgetTester tester) async {
  await tester.ensureVisible(_nextButton);
  await tester.tap(_nextButton);
  await _settle(tester);
}

Future<void> tapPrev(WidgetTester tester) async {
  await tester.ensureVisible(_prevButton);
  await tester.tap(_prevButton);
  await _settle(tester);
}

/// Attendance % shows this month's marker.
void expectDataFor(WidgetTester tester, Ym m) {
  expect(find.text(_marker(m)), findsOneWidget, reason: 'data for ${_heading(m)}');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('A: Next month advances exactly one calendar month, heading and data follow', (tester) async {
    await pumpScreen(tester);
    final start = shownMonth(tester);
    expect(_nextButton, findsOneWidget);
    expect(_prevButton, findsOneWidget);
    expectDataFor(tester, start);

    await tapNext(tester);
    final next = _next(start);
    expect(shownMonth(tester), next);
    expect(find.text(_heading(next)), findsOneWidget);
    expect(find.text(_heading(start)), findsNothing);
    expectDataFor(tester, next);
    expect(find.text(_marker(start)), findsNothing);
    await unmount(tester);
  });

  testWidgets('B: several future months in a row — one month per tap, no limit', (tester) async {
    await pumpScreen(tester);
    var expected = shownMonth(tester);
    for (var i = 1; i <= 14; i++) {
      await tapNext(tester);
      expected = _next(expected);
      expect(shownMonth(tester), expected, reason: 'after $i taps');
      expectDataFor(tester, expected);
      // Never disabled, however far ahead.
      expect(
          tester.widget<IconButton>(find.ancestor(of: _nextButton, matching: find.byType(IconButton)).first).onPressed,
          isNotNull);
    }
    await unmount(tester);
  });

  testWidgets('C: forward into the future, then Previous month steps back one at a time', (tester) async {
    await pumpScreen(tester);
    final start = shownMonth(tester);
    await tapNext(tester);
    await tapNext(tester);
    await tapNext(tester);
    final three = _next(_next(_next(start)));
    expect(shownMonth(tester), three);

    await tapPrev(tester);
    expect(shownMonth(tester), _prev(three));
    expectDataFor(tester, _prev(three));
    await tapPrev(tester);
    await tapPrev(tester);
    expect(shownMonth(tester), start);
    expectDataFor(tester, start);
    // And on into the past.
    await tapPrev(tester);
    expect(shownMonth(tester), _prev(start));
    await unmount(tester);
  });

  testWidgets('D: December → January of the next year, and back across the year', (tester) async {
    await pumpScreen(tester);
    var m = shownMonth(tester);
    while (m.month != 12) {
      await tapNext(tester);
      m = _next(m);
      expect(shownMonth(tester), m);
    }
    final december = m;
    expect(find.text('December ${december.year}'), findsOneWidget);

    await tapNext(tester);
    expect(shownMonth(tester), (year: december.year + 1, month: 1));
    expect(find.text('January ${december.year + 1}'), findsOneWidget);
    expectDataFor(tester, (year: december.year + 1, month: 1));

    await tapPrev(tester);
    expect(shownMonth(tester), (year: december.year, month: 12));
    expect(find.text('December ${december.year}'), findsOneWidget);

    // January → December of the previous year, going backwards.
    await tapNext(tester); // January next year
    await tapPrev(tester); // December
    for (var i = 0; i < 11; i++) {
      await tapPrev(tester);
    }
    expect(shownMonth(tester), (year: december.year, month: 1));
    await tapPrev(tester);
    expect(shownMonth(tester), (year: december.year - 1, month: 12));
    expect(find.text('December ${december.year - 1}'), findsOneWidget);
    expectDataFor(tester, (year: december.year - 1, month: 12));
    await unmount(tester);
  });

  testWidgets('E: each month is requested once with its own month and year; no stale figures', (tester) async {
    await pumpScreen(tester);
    final start = shownMonth(tester);
    for (final path in FakeAttendanceBackend.monthly) {
      expect(backend.requested(path), [start], reason: path);
    }

    // The next month's stats are held: while they load, the previous
    // month's figure is gone (not shown as if it were this month's).
    final next = _next(start);
    final gate = backend.holds['${ApiConstants.attendanceStats}|${next.year}|${next.month}'] = Completer<void>();
    await tester.ensureVisible(_nextButton);
    await tester.tap(_nextButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(shownMonth(tester), next);
    expect(find.text(_marker(start)), findsNothing);
    expect(find.text(_marker(next)), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    gate.complete();
    await _settle(tester);
    expectDataFor(tester, next);

    for (final path in FakeAttendanceBackend.monthly) {
      expect(backend.requested(path), [start, next], reason: path);
      expect(backend.count(path, next), 1, reason: 'no duplicate request for $path');
    }

    // Rebuilds and a month change elsewhere don't ask again for the
    // month on screen; the year in every request is the right one.
    await tester.pump(const Duration(milliseconds: 300));
    for (final path in FakeAttendanceBackend.monthly) {
      expect(backend.count(path, next), 1, reason: path);
    }
    var m = next;
    while (m.month != 1) {
      await tapNext(tester);
      m = _next(m);
    }
    for (final path in FakeAttendanceBackend.monthly) {
      final last = backend.requested(path).last;
      expect(last, m, reason: path);
      expect(last, (year: start.year + 1, month: 1), reason: 'January is in the next year');
    }
    await unmount(tester);
  });
}

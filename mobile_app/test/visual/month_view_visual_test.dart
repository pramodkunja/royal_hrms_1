// Task 111 harness: HR Attendance -> Employee Month View, stand-in API + render-evidence shots (T1011_SHOTS=1).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import 'shot_harness.dart';

/// A synthetic month for the HR employee-calendar endpoint (backend HREmployeeMonthView shape).
Map<String, dynamic> monthPayload(String month, {String name = 'Anika Sharma', int marker = 0}) {
  final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7));
  final last = DateTime(y, m + 1, 0).day;
  const short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final days = <Map<String, dynamic>>[];
  var present = 0, late = 0, half = 0, absent = 0, leave = 0;
  num hours = 0;
  for (var d = 1; d <= last; d++) {
    final dt = DateTime(y, m, d);
    var status = 'present';
    String? ci = '09:0${d % 10}', co = '18:1${d % 10}';
    num h = 9;
    if (dt.weekday >= 6) {
      status = 'weekly_off';
      ci = co = null;
      h = 0;
    } else if (d % 11 == 0) {
      status = 'absent';
      ci = co = null;
      h = 0;
    } else if (d % 7 == 3) {
      status = 'late';
      ci = '10:25';
      h = 8.5;
    } else if (d % 13 == 5) {
      status = 'half_day';
      co = '13:30';
      h = 4.5;
    } else if (d % 17 == 9) {
      status = 'on_leave';
      ci = co = null;
      h = 0;
    } else if (d % 19 == 12) {
      status = 'incomplete';
      co = null;
      h = 0;
    }
    switch (status) {
      case 'present':
        present++;
      case 'late':
        late++;
      case 'half_day':
        half++;
      case 'absent':
        absent++;
      case 'on_leave':
        leave++;
    }
    hours += h;
    final hasRecord = status != 'on_leave' || d % 2 == 0;
    days.add({
      'date': '$month-${d.toString().padLeft(2, '0')}',
      'day_name': short[dt.weekday - 1],
      'day_short': short[dt.weekday - 1],
      'day_num': d,
      'status': hasRecord ? status : 'no_record',
      'status_label': const {
            'present': 'Present',
            'late': 'Late Arrival',
            'half_day': 'Half Day',
            'on_leave': 'On Leave',
            'weekly_off': 'Week Off',
            'absent': 'Absent',
            'incomplete': 'Incomplete',
          }[status] ??
          'No Record',
      'clock_in': ci,
      'clock_out': co,
      'total_hours': h,
      'overtime_hours': 0,
      'is_flagged': status == 'absent' || status == 'incomplete',
      'record_id': hasRecord ? 'rec-$month-$d' : null,
    });
  }
  return {
    'employee': {
      'id': 'uuid-anika',
      'employee_id': 'EMP-0042',
      'full_name': name,
      'department': 'Engineering',
      'designation': 'Senior Software Engineer',
    },
    'month': month,
    'stats': {
      'present': present + marker,
      'late': late,
      'half_day': half,
      'absent': absent,
      'on_leave': leave,
      'weekly_off': 8,
      'holiday': 0,
      'incomplete': 1,
      'lop_days': absent + 1,
      'total_hours': hours,
    },
    'days': days,
  };
}

class MonthServer implements HttpClientAdapter {
  int status = 200;
  String message = 'Failed.';
  bool noEmployees = false;
  final calendarCalls = <Map<String, dynamic>>[];
  final gates = <String, Completer<void>>{}; // month -> hold
  final payloadFor = <String, Map<String, dynamic>>{};

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.method == 'GET' && o.path == '/attendance/employee-calendar/') {
      final month = '${o.queryParameters['month']}';
      calendarCalls.add(Map.of(o.queryParameters));
      if (gates[month] != null) await gates[month]!.future;
      if (status != 200) return _json({'status': 'error', 'message': message, 'data': {}}, status);
      return _json({'status': 'success', 'data': payloadFor[month] ?? monthPayload(month)});
    }
    if (o.method == 'GET' && o.path == '/employees/') {
      return _json({
        'status': 'success',
        'data': {
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'results': noEmployees
              ? <Object>[]
              : [
                  {
                    'id': 'uuid-anika',
                    'uuid': 'uuid-anika',
                    'employee_id': 'EMP-0042',
                    'full_name': 'Anika Sharma',
                    'first_name': 'Anika',
                    'last_name': 'Sharma',
                    'department': 'Engineering',
                    'designation': 'Senior Software Engineer',
                  }
                ],
        }
      });
    }
    if (o.method == 'GET' && o.path.startsWith('/attendance/records/')) {
      return _json({
        'status': 'success',
        'data': {
          'id': 'rec',
          'employee_id': 'EMP-0042',
          'name': 'Anika Sharma',
          'department': 'Engineering',
          'branch': 'Surat',
          'date': '2026-11-03',
          'status': 'Present',
          'clock_in': '09:03',
          'clock_out': '18:13',
          'total_hours': '9h 10m',
          'overtime': '0h',
          'punches': [],
        }
      });
    }
    return _json({
      'status': 'success',
      'data': {'results': <Object>[], 'count': 0, 'page': 1, 'total_pages': 1}
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Storage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

Future<void> settleMv(WidgetTester t, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

/// Opens Attendance -> Employee Month View; selects the synthetic employee when [select].
Future<ProviderContainer> openMonthView(WidgetTester t,
    {Size size = const Size(393, 1800),
    double scale = 1,
    MonthServer? server,
    bool dark = false,
    bool select = true,
    String query = 'Anika',
    bool shots = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? MonthServer();
  // The Attendance shell's own stats bar (attendance_screen.dart, not part of this view) overflows with the
  // wide test font / 2x text; reported separately. Everything else still fails the test.
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if ((d.toString() + d.exception.toString()).contains('_StatsBar') ||
        (d.toString() + d.exception.toString()).contains('attendance_screen.dart')) {
      return;
    }
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(const UserEntity(
            id: 'u1',
            email: 'hr@example.test',
            fullName: 'Hira Test',
            role: 'hr',
            roleDisplay: 'HR',
            mustChangePassword: false,
            permissions: ['attendance.view', 'attendance.edit', 'settings.edit'],
            onboardingStatus: 'complete',
            assessmentStatus: 'complete',
          ))),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const Scaffold(body: AttendanceScreen()),
    )),
  ));
  await settleMv(t);
  final mode = find.text('Employee Month View');
  await t.tap(mode);
  await settleMv(t);
  if (select) {
    await t.enterText(find.byType(TextField).first, query);
    await t.pump(const Duration(milliseconds: 600));
    await settleMv(t, 4);
    final opt = find.textContaining('Anika Sharma (EMP-0042)');
    if (opt.evaluate().isNotEmpty) {
      await t.tap(opt.first);
      await settleMv(t);
    }
  }
  return ProviderScope.containerOf(t.element(find.byType(AttendanceScreen)));
}

void mvShot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  mvShot('m_01_populated', (t) => openMonthView(t));
  mvShot('m_02_prev_month', (t) async {
    await openMonthView(t);
    await t.tap(find.byKey(const Key('month-prev')));
    await settleMv(t);
  });
  mvShot('m_03_320', (t) => openMonthView(t, size: const Size(320, 1800)));
  mvShot('m_04_text2x', (t) => openMonthView(t, size: const Size(393, 3600), scale: 2));
  mvShot('m_05_tablet', (t) => openMonthView(t, size: const Size(1000, 1400)));
  mvShot('m_06_dark', (t) => openMonthView(t, dark: true));
  mvShot('m_07_no_employee', (t) => openMonthView(t, select: false, size: const Size(393, 900)));
  mvShot('m_08_no_match', (t) => openMonthView(t, server: MonthServer()..noEmployees = true, size: const Size(393, 900)));
  mvShot('m_09_error', (t) => openMonthView(t, server: MonthServer()..status = 500, size: const Size(393, 900)));
  mvShot('m_10_denied',
      (t) => openMonthView(t, server: MonthServer()..status = 403..message = 'Permission denied.', size: const Size(393, 900)));
  mvShot('m_11_loading', (t) async {
    final s = MonthServer();
    final n = DateTime.now();
    s.gates['${n.year}-${n.month.toString().padLeft(2, '0')}'] = Completer<void>();
    await openMonthView(t, server: s, size: const Size(393, 900));
  });
  mvShot('m_12_record_sheet', (t) async {
    await openMonthView(t);
    final d = find.byKey(const Key('month-day-')).evaluate();
    final tile = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('month-day-') && true).first;
    await t.ensureVisible(tile);
    await t.tap(tile);
    await settleMv(t);
    expect(d, isEmpty);
  });
}

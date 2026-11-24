// Task 110 Part C harness: Employee Profile → Attendance → calendar, with a stand-in API (nothing
// leaves the test) and render-evidence shots (T1011_SHOTS=1).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_attendance_tab.dart';

import 'shot_harness.dart';

const _colors = {
  'Present': '#22c55e',
  'Late': '#f59e0b',
  'Late (Excused)': '#f59e0b',
  'Absent': '#ef4444',
  'Half Day': '#f97316',
  'Weekly Off': '#94a3b8',
  'Holiday': '#a855f7',
  'On Leave': '#3b82f6',
  'Missing Clock Out': '#f59e0b',
};

/// One backend `calendar.days[<day>]` record (services_attendance, day record).
Map<String, dynamic> day(String status,
        {String? clockIn,
        String? clockOut,
        String? hours,
        String? note,
        String? holiday,
        String? lateStatus,
        bool canReg = false}) =>
    {
      'status': status,
      'color': _colors[status] ?? '#94a3b8',
      'clockIn': clockIn,
      'clockOut': clockOut,
      'hours': hours,
      'note': note,
      'holiday_name': holiday,
      'canRegularize': canReg,
      'regularization_required': status == 'Missing Clock Out',
      'canExplainLate': false,
      'lateJustificationStatus': lateStatus,
    };

/// A believable month: weekdays present, a few specials. [daysIn] is the month length.
Map<String, Map<String, dynamic>> sampleMonth(int year, int month) {
  final dim = DateUtils.getDaysInMonth(year, month);
  final out = <String, Map<String, dynamic>>{};
  for (var d = 1; d <= dim; d++) {
    final wd = DateTime(year, month, d).weekday;
    if (wd == DateTime.sunday) {
      out['$d'] = day('Weekly Off');
    } else if (wd == DateTime.saturday && d % 2 == 0) {
      out['$d'] = day('Weekly Off');
    } else {
      out['$d'] = day('Present', clockIn: '09:0${d % 10}', clockOut: '18:1${d % 10}', hours: '9h ${10 + d % 40}m');
    }
  }
  if (dim >= 5) out['3'] = day('Late', clockIn: '09:47', clockOut: '18:30', hours: '8h 43m', canReg: true);
  if (dim >= 9) out['9'] = day('Absent', canReg: true);
  if (dim >= 12) out['12'] = day('Holiday', holiday: 'Founders Day');
  if (dim >= 14) out['14'] = day('On Leave', note: 'Casual Leave');
  if (dim >= 16) out['16'] = day('Half Day', clockIn: '09:05', clockOut: '13:20', hours: '4h 15m');
  if (dim >= 18) out['18'] = day('Missing Clock Out', clockIn: '09:12', canReg: true);
  if (dim >= 20) out['20'] = day('Present', clockIn: '22:00', clockOut: '06:05', hours: '8h 05m', note: 'Night shift');
  if (dim >= 22) out['22'] = day('Late (Excused)', clockIn: '10:10', clockOut: '18:40', hours: '8h 30m');
  return out;
}

class CalServer implements HttpClientAdapter {
  /// Days for a month; null → [sampleMonth].
  Map<String, Map<String, dynamic>> Function(int year, int month)? daysFor;
  int calendarStatus = 200;
  final gates = <String, Completer<void>>{}; // 'year-month' → hold the calendar reply
  final requests = <({String path, Map<String, dynamic> query})>[];

  List<({String path, Map<String, dynamic> query})> to(String path) => [
        for (final r in requests)
          if (r.path == path) r
      ];

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add((path: o.path, query: Map.of(o.queryParameters)));
    final q = o.queryParameters;
    final y = int.tryParse('${q['year']}') ?? 2026;
    final m = int.tryParse('${q['month']}') ?? 1;
    switch (o.path) {
      case ApiConstants.attendanceStats:
        return _json({
          'status': 'success',
          'data': {
            'days_present': 18,
            'late_arrivals': 2,
            'lop_pending': 0,
            'avg_hours_per_day': 8.9,
            'attendance_percentage': 94.7,
            'working_days': 21
          }
        });
      case ApiConstants.attendanceSummary:
        return _json({
          'status': 'success',
          'data': {
            'working_days': 21,
            'days_present': 18,
            'days_absent': 1,
            'leave_days': 1,
            'half_days': 1,
            'ot_hours': '2h'
          }
        });
      case ApiConstants.attendanceCalendar:
        final gate = gates['$y-$m'];
        if (gate != null) await gate.future;
        if (calendarStatus != 200) {
          return _json(
              {'status': 'error', 'message': calendarStatus == 403 ? 'You do not have permission.' : 'Server error.'},
              calendarStatus);
        }
        final days = (daysFor ?? sampleMonth)(y, m);
        return _json({
          'status': 'success',
          'data': {
            'month': m,
            'year': y,
            'calendar': {'days': days},
            'history': [
              for (final e in days.entries.toList().reversed.take(6))
                {
                  'date': '${e.key} ${_mon[m - 1]}',
                  'day': 'Mon',
                  'clockIn': e.value['clockIn'] ?? '—',
                  'clockOut': e.value['clockOut'] ?? '—',
                  'hours': e.value['hours'],
                  'status': e.value['status'],
                  'canRegularize': false,
                }
            ],
          }
        });
    }
    return _json({'status': 'success', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class _Storage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['employees.view', 'attendance.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

Map<String, dynamic> employeeJson() => {
      'id': 'u7',
      'employee_id': 'EMP-0007',
      'first_name': 'Pat',
      'last_name': 'Kumar',
      'full_name': 'Pat Kumar',
      'email': 'pat.kumar@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Surat',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'active',
      'date_of_joining': '2026-01-05',
      'documents': [],
      'profile': <String, dynamic>{},
    };

late CalServer last;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> openTab(WidgetTester t,
    {Size size = const Size(393, 2200),
    double scale = 1,
    CalServer? server,
    bool dark = false,
    bool shots = true,
    bool settleFirst = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? CalServer();
  last = s;
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Scaffold(body: EmployeeAttendanceTab(employee: EmployeeModel.fromJson(employeeJson()))),
    )),
  ));
  if (settleFirst) await settle(t);
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tapDay(WidgetTester t, int d) async {
  await t.ensureVisible(byKey('emp-att-day-$d'));
  await t.pump();
  await t.tap(byKey('emp-att-day-$d'));
  await settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Only meaningful against the pre-Task-110 tab (before-screenshots): plain text taps, no new keys.
  shot('b_01_old_calendar', (t) => openTab(t, size: const Size(393, 2300)));
  shot('b_02_old_day_dialog', (t) async {
    await openTab(t, size: const Size(393, 2300));
    await t.tap(find.text('3').first);
    await settle(t);
  });
  shot('b_03_old_320_2x', (t) => openTab(t, size: const Size(320, 4200), scale: 2));

  shot('c_01_calendar', (t) => openTab(t, size: const Size(393, 2300)));
  shot('c_02_selected_complete', (t) async {
    await openTab(t, size: const Size(393, 2300));
    await tapDay(t, 3);
  });
  shot('c_03_selected_overnight', (t) async {
    await openTab(t, size: const Size(393, 2300));
    await tapDay(t, 20);
  });
  shot('c_04_selected_missing_clock_out', (t) async {
    await openTab(t, size: const Size(393, 2300));
    await tapDay(t, 18);
  });
  shot('c_05_selected_holiday', (t) async {
    await openTab(t, size: const Size(393, 2300));
    await tapDay(t, 12);
  });
  shot('c_06_320_2x', (t) async {
    await openTab(t, size: const Size(320, 4200), scale: 2);
    await tapDay(t, 20);
  });
  shot('c_07_tablet_1000', (t) async {
    await openTab(t, size: const Size(1000, 1500));
    await tapDay(t, 3);
  });
  shot('c_08_dark', (t) async {
    await openTab(t, size: const Size(393, 2300), dark: true);
    await tapDay(t, 18);
  });
  shot('c_09_loading', (t) async {
    final s = CalServer();
    final now = DateTime.now();
    s.gates['${now.year}-${now.month}'] = Completer<void>();
    await openTab(t, size: const Size(393, 1500), server: s, settleFirst: false);
    await t.pump(const Duration(milliseconds: 300));
  });
  shot('c_10_error', (t) => openTab(t, size: const Size(393, 1500), server: CalServer()..calendarStatus = 500));
  shot('c_11_empty_month', (t) => openTab(t, size: const Size(393, 2000), server: CalServer()..daysFor = (y, m) => {}));
  shot('c_12_history_tab', (t) async {
    await openTab(t, size: const Size(393, 1800));
    await t.tap(byKey('emp-att-tab-history'));
    await settle(t);
  });
}

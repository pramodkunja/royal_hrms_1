// Task 111: Shift Management (Shift Assignment tab) render evidence with a
// stand-in API. Shots only when T1011_SHOTS=1.
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
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/attendance/presentation/providers/shift_assignment_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/shift_assignment_tab.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import 'shot_harness.dart';

const longName = 'Global Support Rotation Shift for International Customer Operations and Escalations';

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> _ok(Object d) => {'status': 'success', 'message': 'ok', 'data': d};

Map<String, dynamic> _shift(String id, String name,
        {String start = '09:00:00', String end = '18:00:00', bool def = false, int brk = 30, int grace = 15}) =>
    {
      'id': id,
      'name': name,
      'policy_code': 'WH-$id',
      'start_time': start,
      'end_time': end,
      'break_duration': brk,
      'grace_period': grace,
      'standard_working_hours': 8.5,
      'minimum_working_hours': '4.00',
      'maximum_working_hours': '9.00',
      'is_default': def,
      'is_active': true,
    };

class ShiftServer implements HttpClientAdapter {
  bool empty = false;
  bool failShifts = false;
  bool noRows = false;
  List<Map<String, dynamic>> get shifts => empty
      ? []
      : [
          _shift('s1', 'General 9-6', def: true),
          _shift('s2', 'Night 22-6', start: '22:00:00', end: '06:00:00', brk: 45, grace: 10),
          _shift('s3', longName, start: '13:30:00', end: '22:00:00', brk: 60, grace: 20),
        ];
  @override
  Future<ResponseBody> fetch(RequestOptions o, _, __) async {
    if (o.path == ApiConstants.attendanceWorkingHoursPolicies && o.method == 'GET') {
      if (failShifts && o.queryParameters['page_size'] == 5) {
        return _json({'status': 'error', 'message': 'Failed to load shifts.'}, 500);
      }
      return _json(_ok({'count': shifts.length, 'page': 1, 'total_pages': 1, 'results': shifts}));
    }
    if (o.path == ApiConstants.attendanceShiftAssignments && o.method == 'GET') {
      final rows = noRows
          ? []
          : [
              {
                'employee_id': 'EMP-7',
                'employee_name': 'Test Ann Longname-Surname',
                'department': 'Quality Assurance',
                'branch': 'North Wing',
                'shift_id': 's2',
                'shift_name': 'Night 22-6',
                'effective_from': '2026-10-01',
                'effective_to': null,
                'status': 'Assigned',
              },
              {
                'employee_id': 'EMP-9',
                'employee_name': 'Test Bob',
                'department': 'Ops',
                'branch': 'South Wing',
                'shift_id': null,
                'shift_name': null,
                'effective_from': null,
                'effective_to': null,
                'status': 'Not Assigned',
              },
            ];
      return _json(_ok({'count': rows.length, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': rows}));
    }
    if (o.path == ApiConstants.attendanceSettings) {
      return _json(_ok({
        'working_hours': {'shift_start': '09:30:00', 'shift_end': '18:30:00'}
      }));
    }
    return _json(_ok({'results': [], 'count': 0, 'summary_chips': <String, int>{}}));
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

UserEntity _user() => const UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: ['attendance.view', 'attendance.create', 'attendance.edit', 'attendance.delete', 'settings.edit'],
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> open(WidgetTester t,
    {Size size = const Size(393, 1500),
    double scale = 1,
    bool dark = false,
    ShiftServer? server,
    double keyboard = 0}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? ShiftServer();
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(_user())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
      shiftAssignmentClockProvider.overrideWithValue(() => DateTime(2026, 11, 6, 9)),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const Scaffold(body: ShiftAssignmentTab()),
    )),
  ));
  await settle(t);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
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
  const narrow = Size(320, 2600);

  shot('s01_list_phone', (t) => open(t));
  shot('s02_add_form', (t) async {
    await open(t, size: const Size(393, 852));
    await tapKey(t, 'shift-master-add');
  });
  shot('s03_edit_overnight_form', (t) async {
    await open(t, size: const Size(393, 852));
    await tapKey(t, 'shift-master-edit-s2');
  });
  shot('s04_list_320_2x', (t) => open(t, size: narrow, scale: 2));
  shot('s05_form_320_2x', (t) async {
    await open(t, size: const Size(320, 568), scale: 2);
    await tapKey(t, 'shift-master-add');
  });
  shot('s06_list_tablet_1000', (t) => open(t, size: const Size(1000, 1300)));
  shot('s07_list_dark', (t) => open(t, dark: true));
  shot(
      's08_empty',
      (t) => open(t,
          server: ShiftServer()
            ..empty = true
            ..noRows = true));
  shot('s09_error', (t) => open(t, server: ShiftServer()..failShifts = true));
  shot('s10_deactivate_dialog', (t) async {
    await open(t, size: const Size(393, 852));
    await tapKey(t, 'shift-master-delete-s2');
  });
  shot('s11_form_dark_keyboard', (t) async {
    await open(t, size: const Size(393, 852), dark: true, keyboard: 300);
    await tapKey(t, 'shift-master-add');
  });
  shot('s12_assign_sheet', (t) async {
    await open(t, size: const Size(393, 852));
    await t.scrollUntilVisible(find.byKey(const Key('shift-assign-EMP-9')), 300,
        scrollable: find.byType(Scrollable).first);
    await tapKey(t, 'shift-assign-EMP-9');
  });
}

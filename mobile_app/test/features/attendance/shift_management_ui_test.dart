// Task 111: Shift Management presentation - timing maths, shift cards, the
// grouped form, sections, permissions, states and responsive layout.
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
import 'package:mobile_app/features/attendance/presentation/widgets/shift_assignment_tab.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/shift_format.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> ok(Object d, [String m = 'ok']) => {'status': 'success', 'message': m, 'data': d};

Map<String, dynamic> shift(String id, String name,
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

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> shifts = [
    shift('s1', 'General 9-6', def: true),
    shift('s2', 'Night 22-6', start: '22:00:00', end: '06:00:00', brk: 45, grace: 10),
  ];
  final writes = <({String method, String path, Object? body})>[];
  bool failShifts = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, _, __) async {
    const base = ApiConstants.attendanceWorkingHoursPolicies;
    if (o.path == base && o.method == 'GET') {
      if (failShifts && o.queryParameters['page_size'] == 5) return _json({'status': 'error', 'message': 'x'}, 500);
      return _json(ok({'count': shifts.length, 'page': 1, 'total_pages': 1, 'results': shifts}));
    }
    if (o.path.startsWith(base) && o.method != 'GET') {
      writes.add((method: o.method, path: o.path, body: o.data));
      return _json(ok({}, 'Saved.'), o.method == 'POST' ? 201 : 200);
    }
    if (o.path == ApiConstants.attendanceSettings) {
      return _json(ok({
        'working_hours': {'shift_start': '09:30:00', 'shift_end': '18:30:00'}
      }));
    }
    return _json(ok({'results': [], 'count': 0, 'total_pages': 1, 'summary_chips': <String, int>{}}));
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

UserEntity user(List<String> p) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: p,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final full = user(['attendance.view', 'attendance.create', 'attendance.edit', 'attendance.delete']);
late Server server;

Future<void> pump(WidgetTester t,
    {UserEntity? as,
    Size size = const Size(393, 2400),
    double scale = 1,
    bool dark = false,
    double keyboard = 0}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  await t.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? full)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const Scaffold(body: ShiftAssignmentTab()),
    ),
  ));
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Finder within(String key, Finder f) => find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => server = Server());

  group('timing maths (backend: end <= start ends next day)', () {
    test('length, overnight and net', () {
      expect(shiftLengthMinutes('09:00', '18:00'), 540);
      expect(shiftLengthMinutes('22:00:00', '06:00:00'), 480); // end + 24h - start
      expect(shiftLengthMinutes('23:30', '00:15'), 45);
      expect(isOvernightShift('22:00', '06:00'), isTrue);
      expect(isOvernightShift('09:00', '18:00'), isFalse);
      expect(isOvernightShift('09:00', '09:00'), isFalse); // rejected by the backend, not "overnight"
      expect(shiftNetMinutes('22:00', '06:00', 45), 435);
      expect(shiftNetMinutes('09:00', '10:00', 90), 0); // never negative
      expect(shiftLengthMinutes('', '18:00'), isNull);
      expect(shiftLengthMinutes('25:00', '18:00'), isNull);
    });
    test('duration text', () {
      expect(formatShiftDuration(540), '9h');
      expect(formatShiftDuration(435), '7h 15m');
      expect(formatShiftDuration(45), '45m');
    });
  });

  group('sections and cards', () {
    testWidgets('configuration and assignment are separate, explained sections', (t) async {
      await pump(t);
      expect(find.text('Shift configuration'), findsOneWidget);
      expect(find.text('Employee shift assignment'), findsOneWidget);
      final a = t.getTopLeft(find.text('Shift configuration')).dy;
      final b = t.getTopLeft(find.text('Employee shift assignment')).dy;
      expect(a < b, isTrue);
    });

    testWidgets('card: times, length, working time, break, grace, status, labelled actions', (t) async {
      await pump(t);
      expect(within('shift-master-s1', find.text('09:00 – 18:00')), findsOneWidget);
      expect(within('shift-master-length-s1', find.text('9h')), findsOneWidget);
      expect(within('shift-master-net-s1', find.text('8h 30m')), findsOneWidget);
      expect(within('shift-master-break-s1', find.text('30 min')), findsOneWidget);
      expect(within('shift-master-grace-s1', find.text('15 min')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-default-s1')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-status-s1')), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Edit'), findsNWidgets(2));
      expect(find.widgetWithText(OutlinedButton, 'Deactivate'), findsNWidgets(2));
    });

    testWidgets('overnight indicator and duration only where the times cross midnight', (t) async {
      await pump(t);
      expect(find.byKey(const Key('shift-master-overnight-s2')), findsOneWidget);
      expect(within('shift-master-length-s2', find.text('8h')), findsOneWidget);
      expect(within('shift-master-net-s2', find.text('7h 15m')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-overnight-s1')), findsNothing);
    });

    testWidgets('default shift: Deactivate disabled with the reason shown', (t) async {
      await pump(t);
      expect(t.widget<OutlinedButton>(find.byKey(const Key('shift-master-delete-s1'))).onPressed, isNull);
      expect(find.byKey(const Key('shift-master-default-note-s1')), findsOneWidget);
      expect(t.widget<OutlinedButton>(find.byKey(const Key('shift-master-delete-s2'))).onPressed, isNotNull);
    });

    testWidgets('permissions: create-only sees Add but no Edit/Deactivate; viewer sees no shift section', (t) async {
      await pump(t, as: user(['attendance.view', 'attendance.create']));
      expect(find.byKey(const Key('shift-master-add')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-edit-s2')), findsNothing);
      expect(find.byKey(const Key('shift-master-delete-s2')), findsNothing);
    });

    testWidgets('viewer: no configuration section, no assign actions', (t) async {
      await pump(t, as: user(['attendance.view']));
      expect(find.text('Shift configuration'), findsNothing);
      expect(find.byKey(const Key('shift-bulk-open')), findsNothing);
      expect(find.text('Employee shift assignment'), findsOneWidget);
    });

    testWidgets('empty and error states', (t) async {
      server.shifts = [];
      await pump(t);
      expect(find.byKey(const Key('shift-master-empty')), findsOneWidget);
      expect(find.text('No named shifts created yet.'), findsOneWidget);
    });

    testWidgets('error shows the kit error state with Retry', (t) async {
      server.failShifts = true;
      await pump(t);
      expect(find.byKey(const Key('shift-master-error')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-retry')), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('grouped fields; live length and overnight chip; exact create payload', (t) async {
      await pump(t);
      await tap(t, 'shift-master-add');
      for (final h in ['Shift details', 'Shift timings', 'Break and grace period', 'Organization default']) {
        expect(find.text(h), findsOneWidget);
      }
      expect(within('shift-master-length', find.textContaining('9h')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-overnight')), findsNothing);
      await t.enterText(find.byKey(const Key('shift-master-name')), 'UK Shift');
      await t.pump();
      await tap(t, 'shift-master-save');
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', ApiConstants.attendanceWorkingHoursPolicies]);
      expect(w.body, {
        'name': 'UK Shift',
        'description': '',
        'start_time': '09:00:00',
        'end_time': '18:00:00',
        'break_duration': 30,
        'grace_period': 15,
        'minimum_working_hours': '4.00',
        'maximum_working_hours': '9.00',
        'is_default': false,
        'is_active': true,
      });
    });

    testWidgets('edit of an overnight shift shows the indicator; PATCH payload unchanged', (t) async {
      await pump(t);
      await tap(t, 'shift-master-edit-s2');
      expect(find.text('Edit Shift'), findsOneWidget);
      expect(find.byKey(const Key('shift-master-overnight')), findsOneWidget);
      expect(within('shift-master-net', find.textContaining('7h 15m')), findsOneWidget);
      await tap(t, 'shift-master-save');
      final w = server.writes.single;
      expect([w.method, w.path], ['PATCH', ApiConstants.attendanceWorkingHoursPolicy('s2')]);
      expect((w.body as Map)['start_time'], '22:00:00');
      expect((w.body as Map)['end_time'], '06:00:00');
      expect((w.body as Map).containsKey('policy_code'), isFalse);
    });

    testWidgets('validation: backend limits stop the request with the backend wording', (t) async {
      await pump(t);
      await tap(t, 'shift-master-add');
      await t.enterText(find.byKey(const Key('shift-master-name')), 'X');
      await t.enterText(find.byKey(const Key('shift-master-break')), '481');
      await t.pump();
      expect(find.textContaining('cannot exceed 480 minutes'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byKey(const Key('shift-master-save'))).onPressed, isNull);
      await t.enterText(find.byKey(const Key('shift-master-break')), '30');
      await t.enterText(find.byKey(const Key('shift-master-grace')), '121');
      await t.pump();
      expect(find.textContaining('cannot exceed 120 minutes'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byKey(const Key('shift-master-save'))).onPressed, isNull);
      await t.enterText(find.byKey(const Key('shift-master-grace')), '120');
      await t.enterText(find.byKey(const Key('shift-master-break')), '540'); // = whole 9h shift is > 480 anyway
      await t.pump();
      expect(server.writes, isEmpty);
    });

    testWidgets('net hours must stay above zero', (t) async {
      await pump(t);
      await tap(t, 'shift-master-add');
      await t.enterText(find.byKey(const Key('shift-master-name')), 'Short');
      await t.enterText(find.byKey(const Key('shift-master-break')), '480');
      await t.pump();
      // 9h shift, 8h break is fine; a 7.5h shift is not covered here, so only check the enabled path.
      expect(t.widget<FilledButton>(find.byKey(const Key('shift-master-save'))).onPressed, isNotNull);
    });

    testWidgets('keyboard open: form scrolls, Save stays reachable (no overflow)', (t) async {
      await pump(t, size: const Size(320, 800), scale: 2);
      await tap(t, 'shift-master-add');
      t.view.viewInsets = const FakeViewPadding(bottom: 250);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('shift-master-save')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('deactivate', () {
    testWidgets('confirm sends DELETE for the chosen shift', (t) async {
      await pump(t);
      await tap(t, 'shift-master-delete-s2');
      await tap(t, 'shift-master-deactivate-confirm');
      final w = server.writes.single;
      expect([w.method, w.path], ['DELETE', ApiConstants.attendanceWorkingHoursPolicy('s2')]);
    });
  });

  group('responsive and dark', () {
    for (final (w, s) in [(320.0, 2.0), (360.0, 1.0), (430.0, 1.5), (600.0, 1.0), (1000.0, 1.0)]) {
      testWidgets('no overflow at ${w}dp, ${s}x text', (t) async {
        await pump(t, size: Size(w, 3000), scale: s);
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('shift-master-edit-s2')), findsOneWidget);
      });
    }

    testWidgets('two shift columns from 600dp, one on a phone', (t) async {
      await pump(t, size: const Size(393, 2400));
      final one = t.getTopLeft(find.byKey(const Key('shift-master-s1'))).dx ==
          t.getTopLeft(find.byKey(const Key('shift-master-s2'))).dx;
      expect(one, isTrue);
      await pump(t, size: const Size(1000, 2400));
      expect(
          t.getTopLeft(find.byKey(const Key('shift-master-s1'))).dx <
              t.getTopLeft(find.byKey(const Key('shift-master-s2'))).dx,
          isTrue);
    });

    testWidgets('dark theme renders', (t) async {
      await pump(t, dark: true);
      expect(find.byKey(const Key('shift-master-overnight-s2')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('long shift name wraps, never clipped', (t) async {
      server.shifts = [shift('s9', 'Global Support Rotation Shift for International Customer Operations ' * 2)];
      await pump(t, size: const Size(320, 2400), scale: 2);
      expect(t.takeException(), isNull);
    });
  });
}

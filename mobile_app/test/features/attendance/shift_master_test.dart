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
import 'package:mobile_app/features/attendance/data/models/shift_master_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/shift_master_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 14: Shift Masters ("Shifts" card at the top of HR Attendance → Shift
// Assignment) — web ShiftMasterCard.tsx over /attendance/working-hours/
// (views/working_hours.py): list active shifts 5 per page; POST create
// (attendance.create), PATCH edit (attendance.edit), DELETE = deactivate
// (attendance.delete; 409 for the default). Stand-in server, synthetic shifts.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> ok(Object data, [String message = 'ok']) =>
    {'status': 'success', 'message': message, 'data': data};

Map<String, dynamic> shift(String id, String name,
        {String start = '09:00:00', String end = '18:00:00', bool isDefault = false, int brk = 30, int grace = 15}) =>
    {
      'id': id,
      'name': name,
      'policy_code': 'WH-${id.toUpperCase()}',
      'start_time': start,
      'end_time': end,
      'break_duration': brk,
      'grace_period': grace,
      'standard_working_hours': 8.5,
      'minimum_working_hours': '4.00',
      'maximum_working_hours': '9.00',
      'is_default': isDefault,
      'is_active': true,
      'created_at': '2026-11-01T00:00:00Z',
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> shifts = [
    shift('s1', 'General 9-6', isDefault: true),
    shift('s2', 'Night 22-6', start: '22:00:00', end: '06:00:00', brk: 45, grace: 10),
  ];
  final cardGets = <Map<String, dynamic>>[];
  final optionGets = <Map<String, dynamic>>[];
  final writes = <({String method, String path, Object? body})>[];
  Completer<void>? hold;
  ({int status, String message})? refuseNext;
  bool failList = false;
  int totalPages = 1;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    const base = ApiConstants.attendanceWorkingHoursPolicies;
    if (o.path == base && o.method == 'GET') {
      final card = o.queryParameters['page_size'] == 5;
      (card ? cardGets : optionGets).add(Map.of(o.queryParameters));
      if (card && failList) return _json({'status': 'error', 'message': 'Failed to load.'}, 500);
      return _json(ok({
        'count': shifts.length,
        'page': o.queryParameters['page'] ?? 1,
        'page_size': o.queryParameters['page_size'],
        'total_pages': card ? totalPages : 1,
        'results': shifts,
      }));
    }
    if (o.path.startsWith(base) && o.method != 'GET') {
      writes.add((method: o.method, path: o.path, body: o.data));
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message, 'data': {}}, r.status);
      }
      if (o.method == 'POST') {
        final body = Map<String, dynamic>.from(o.data as Map);
        shifts = [
          ...shifts,
          {...shift('s9', body['name'] as String), ...body, 'id': 's9'}
        ];
        return _json(ok(shifts.last, 'Working hours policy created successfully.'), 201);
      }
      final id = o.path.split('/').where((p) => p.isNotEmpty).last;
      if (o.method == 'PATCH') {
        shifts = [
          for (final s in shifts) s['id'] == id ? {...s, ...Map<String, dynamic>.from(o.data as Map)} : s
        ];
        return _json(ok(shifts.firstWhere((s) => s['id'] == id), 'Working hours policy updated successfully.'));
      }
      shifts = shifts.where((s) => s['id'] != id).toList();
      return _json({'status': 'success', 'message': 'Working hours policy deactivated successfully.'});
    }
    if (o.path == ApiConstants.attendanceSettings) {
      return _json(ok({
        'working_hours': {'shift_start': '09:30:00', 'shift_end': '18:30:00'},
      }));
    }
    return _json(ok({'results': [], 'count': 0, 'summary_chips': <String, int>{}}));
  }

  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
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

UserEntity user(List<String> perms) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      branch: 'North Wing',
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final full = user(['attendance.view', 'attendance.create', 'attendance.edit', 'attendance.delete', 'settings.view']);
final creatorOnly = user(['attendance.view', 'attendance.create']);
final viewer = user(['attendance.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1600, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? full),
    child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Shift Assignment'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(Key(key)));
  return w is ButtonStyleButton ? w.onPressed != null : (w as IconButton).onPressed != null;
}

Finder inCard(Finder f) => find.descendant(of: find.byKey(const Key('shift-master-card')), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and payload', () {
    test('parsing, HH:MM display, and the create payload with web defaults', () {
      final s = ShiftMaster.fromJson(shift('s2', 'Night', start: '22:00:00', end: '06:00:00'));
      expect([s.name, toHHMM(s.startTime), toHHMM(s.endTime), s.isDefault, s.minimumWorkingHours],
          ['Night', '22:00', '06:00', false, '4.00']);
      final f = ShiftMasterForm()..name = 'UK Shift';
      expect(f.toJson(), {
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
      expect(ShiftMasterForm().canSave, isFalse);
    });

    test('edit payload: prefilled from the shift, no description, no policy_code, min/max kept', () {
      final f =
          ShiftMasterForm.fromShift(ShiftMaster.fromJson(shift('s2', 'Night', start: '22:00:00', end: '06:00:00')));
      final j = f.toJson();
      expect(j.containsKey('description'), isFalse);
      expect(j.containsKey('policy_code'), isFalse);
      expect([j['start_time'], j['end_time'], j['minimum_working_hours'], j['is_active']],
          ['22:00:00', '06:00:00', '4.00', true]);
    });

    test('below the UI: each action needs its server permission; nothing is sent otherwise', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(creatorOnly));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final s = c.read(shiftMasterServiceProvider);
      await expectLater(s.update('s2', ShiftMasterForm()..name = 'X'), throwsA(isA<ShiftMasterDenied>()));
      await expectLater(s.deactivate('s2'), throwsA(isA<ShiftMasterDenied>()));
      expect(server.writes, isEmpty);
      final v = ProviderContainer(overrides: overrides(viewer));
      addTearDown(v.dispose);
      await v.read(authStateProvider.future);
      await expectLater(
          v.read(shiftMasterServiceProvider).create(ShiftMasterForm()..name = 'X'), throwsA(isA<ShiftMasterDenied>()));
      expect(server.writes, isEmpty);
    });
  });

  group('card', () {
    testWidgets('top of the Shift Assignment tab: active shifts, 5 per page, Default badge, global default',
        (tester) async {
      await pump(tester);
      expect(server.cardGets.first, {'page': 1, 'page_size': 5, 'is_active': 'true'});
      final cardTop = tester.getTopLeft(find.byKey(const Key('shift-master-card'))).dy;
      expect(cardTop < tester.getTopLeft(find.byKey(const Key('shift-filter-branch'))).dy, isTrue);
      expect(inCard(find.text('General 9-6')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-default-s1')), findsOneWidget);
      expect(inCard(find.text('22:00 – 06:00')), findsOneWidget);
      expect(inCard(find.text('Break 45 min · Grace Period 10 min')), findsOneWidget);
      expect(inCard(find.text('General / Default — 09:30 to 18:30')), findsOneWidget);
      expect(enabled(tester, 'shift-master-delete-s1'), isFalse); // default can't be deactivated
      expect(enabled(tester, 'shift-master-delete-s2'), isTrue);
    });

    testWidgets('no attendance.create: no card at all', (tester) async {
      await pump(tester, as: viewer);
      expect(find.byKey(const Key('shift-master-card')), findsNothing);
      expect(server.cardGets, isEmpty);
    });

    testWidgets('attendance.create only: Add Shift, but no Edit / Deactivate', (tester) async {
      await pump(tester, as: creatorOnly);
      expect(find.byKey(const Key('shift-master-add')), findsOneWidget);
      expect(find.byKey(const Key('shift-master-edit-s2')), findsNothing);
      expect(find.byKey(const Key('shift-master-delete-s2')), findsNothing);
    });

    testWidgets('empty, error with Retry, paging', (tester) async {
      await pump(tester, setup: (s) => s.failList = true);
      expect(find.byKey(const Key('shift-master-error')), findsOneWidget);
      server
        ..failList = false
        ..shifts = []
        ..totalPages = 1;
      await tap(tester, 'shift-master-retry');
      expect(find.text('No named shifts created yet.'), findsOneWidget);
    });

    testWidgets('paging: 1 / 2 → next asks for page 2', (tester) async {
      await pump(tester, setup: (s) => s.totalPages = 2);
      expect(find.text('1 / 2'), findsOneWidget);
      await tap(tester, 'shift-master-next');
      expect(server.cardGets.last, {'page': 2, 'page_size': 5, 'is_active': 'true'});
    });
  });

  group('create', () {
    testWidgets('defaults; Save needs a name; exact POST; message; card and assignment shifts reload', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-add');
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(enabled(tester, 'shift-master-save'), isFalse);
      await tester.enterText(find.byKey(const Key('shift-master-name')), 'UK Shift');
      await tester.enterText(find.byKey(const Key('shift-master-break')), '');
      await tester.pump();
      await tap(tester, 'shift-master-default');
      final cardGets = server.cardGets.length, optionGets = server.optionGets.length;
      await tap(tester, 'shift-master-save');
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', ApiConstants.attendanceWorkingHoursPolicies]);
      expect(w.body, {
        'name': 'UK Shift',
        'description': '',
        'start_time': '09:00:00',
        'end_time': '18:00:00',
        'break_duration': 0, // empty = 0, as web Number('')
        'grace_period': 15,
        'minimum_working_hours': '4.00',
        'maximum_working_hours': '9.00',
        'is_default': true,
        'is_active': true,
      });
      expect(find.byKey(const Key('shift-master-form')), findsNothing);
      expect(find.text('Working hours policy created successfully.'), findsOneWidget);
      expect(server.cardGets.length, cardGets + 1);
      expect(server.optionGets.length, greaterThan(optionGets)); // Shift Assignment's list of shifts
      expect(inCard(find.text('UK Shift')), findsOneWidget);
    });

    testWidgets('a refusal keeps the form and values and shows the server message', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-add');
      await tester.enterText(find.byKey(const Key('shift-master-name')), 'general 9-6');
      await tester.enterText(find.byKey(const Key('shift-master-grace')), '20');
      await tester.pump();
      server.refuseNext = (status: 422, message: 'A working hours policy named "general 9-6" already exists.');
      await tap(tester, 'shift-master-save');
      expect(find.text('A working hours policy named "general 9-6" already exists.'), findsOneWidget);
      expect(find.byKey(const Key('shift-master-form')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('shift-master-name'))).controller!.text, 'general 9-6');
      expect(tester.widget<TextField>(find.byKey(const Key('shift-master-grace'))).controller!.text, '20');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Save can\'t be sent twice', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-add');
      await tester.enterText(find.byKey(const Key('shift-master-name')), 'UK Shift');
      await tester.pump();
      server.hold = Completer();
      await tester.tap(find.byKey(const Key('shift-master-save')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shift-master-save')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.writes, hasLength(1));
    });
  });

  group('edit', () {
    testWidgets('prefilled (overnight shift kept), PATCH with the shift\'s other values', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-edit-s2');
      expect(find.text('Edit Shift'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('shift-master-name'))).controller!.text, 'Night 22-6');
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('shift-master-break')), '60');
      await tester.pump();
      await tap(tester, 'shift-master-save');
      final w = server.writes.single;
      expect([w.method, w.path], ['PATCH', ApiConstants.attendanceWorkingHoursPolicy('s2')]);
      expect(w.body, {
        'name': 'Night 22-6',
        'start_time': '22:00:00',
        'end_time': '06:00:00',
        'break_duration': 60,
        'grace_period': 10,
        'minimum_working_hours': '4.00',
        'maximum_working_hours': '9.00',
        'is_default': false,
        'is_active': true,
      });
      expect(find.text('Working hours policy updated successfully.'), findsOneWidget);
      expect(inCard(find.text('Break 60 min · Grace Period 10 min')), findsOneWidget);
    });

    testWidgets('a refused edit keeps the sheet and the value', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-edit-s2');
      await tester.enterText(find.byKey(const Key('shift-master-break')), '600');
      await tester.pump();
      server.refuseNext = (status: 422, message: 'Break duration cannot exceed 480 minutes (8 hours).');
      await tap(tester, 'shift-master-save');
      expect(find.text('Break duration cannot exceed 480 minutes (8 hours).'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('shift-master-break'))).controller!.text, '600');
    });
  });

  group('deactivate', () {
    testWidgets('confirm, DELETE, then the list reloads without it', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-delete-s2');
      expect(find.textContaining('"Night 22-6" will be deactivated.'), findsOneWidget);
      expect(server.writes, isEmpty); // nothing before confirming
      await tap(tester, 'shift-master-deactivate-confirm');
      expect([server.writes.single.method, server.writes.single.path],
          ['DELETE', ApiConstants.attendanceWorkingHoursPolicy('s2')]);
      expect(find.text('Working hours policy deactivated successfully.'), findsOneWidget);
      expect(inCard(find.text('Night 22-6')), findsNothing);
    });

    testWidgets('a refusal stays in the dialog and the shift stays listed', (tester) async {
      await pump(tester);
      await tap(tester, 'shift-master-delete-s2');
      server.refuseNext = (status: 409, message: 'Working hours policy is already inactive.');
      await tap(tester, 'shift-master-deactivate-confirm');
      expect(find.text('Working hours policy is already inactive.'), findsOneWidget);
      expect(find.byKey(const Key('shift-master-deactivate')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(inCard(find.text('Night 22-6')), findsOneWidget);
    });

    testWidgets('the last shift on a later page moves back a page', (tester) async {
      await pump(tester, setup: (s) {
        s.totalPages = 2;
        s.shifts = [shift('s7', 'Only One')];
      });
      await tap(tester, 'shift-master-next');
      await tap(tester, 'shift-master-delete-s7');
      await tap(tester, 'shift-master-deactivate-confirm');
      expect(server.cardGets.last['page'], 1);
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/data/models/weekly_off_assignment_models.dart';
import 'package:mobile_app/features/attendance/data/models/weekly_off_pattern_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/weekly_off_assignment_providers.dart';
import 'package:mobile_app/features/attendance/presentation/providers/weekly_off_pattern_providers.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/attendance_rules/attendance_rules_screen.dart';

// Task 15: Weekly Off Patterns card on Settings → Attendance Rules — web
// WeeklyOffPatternsCard.tsx over /attendance/weekly-days/ (views/weekly_days.py):
// every pattern (default first, then name) three per page; POST create
// (attendance.create), PATCH edit (attendance.edit), DELETE = deactivate
// (attendance.delete; 409 for the default, an assigned or an inactive pattern).
// Stand-in server, synthetic patterns; nothing is sent anywhere.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> ok(Object data, [String message = 'ok']) =>
    {'status': 'success', 'message': message, 'data': data};

Map<String, dynamic> pattern(String id, String name,
        {Map<String, String> days = const {}, int assigned = 0, bool isDefault = false, bool active = true}) =>
    {
      'id': id,
      'name': name,
      'policy_code': 'WD-${id.toUpperCase()}',
      for (final d in kWeekdayKeys) d: days[d] ?? ((d == 'saturday' || d == 'sunday') ? 'off' : 'working'),
      'working_days_count': 5,
      'assigned_employee_count': assigned,
      'is_default': isDefault,
      'is_active': active,
      'created_at': '2026-11-01T00:00:00Z',
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> patterns = [
    pattern('p1', 'Weekend Off', isDefault: true, assigned: 40),
    pattern('p2', 'Sunday Only', days: {'saturday': 'half_day'}, assigned: 1),
    pattern('p3', 'Old Pattern', active: false),
  ];
  final cardGets = <Map<String, dynamic>>[];
  final activeGets = <Map<String, dynamic>>[];
  final writes = <({String method, String path, Object? body})>[];
  Completer<void>? hold;
  ({int status, String message})? refuseNext;
  bool failList = false;
  int totalPages = 1;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    const base = ApiConstants.attendanceWeeklyDayPolicies;
    if (o.path == base && o.method == 'GET') {
      final active = o.queryParameters['is_active'] == 'true';
      (active ? activeGets : cardGets).add(Map.of(o.queryParameters));
      if (!active && failList) return _json({'status': 'error', 'message': 'Failed to load.'}, 500);
      final rows = active ? patterns.where((p) => p['is_active'] == true).toList() : patterns;
      return _json(ok({
        'count': rows.length,
        'page': o.queryParameters['page'] ?? 1,
        'total_pages': active ? 1 : totalPages,
        'results': rows,
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
        patterns = [
          ...patterns,
          {...pattern('p9', body['name'] as String), ...body, 'id': 'p9'}
        ];
        return _json(ok(patterns.last, 'Weekly day policy created successfully.'), 201);
      }
      final id = o.path.split('/').where((p) => p.isNotEmpty).last;
      if (o.method == 'PATCH') {
        patterns = [
          for (final p in patterns) p['id'] == id ? {...p, ...Map<String, dynamic>.from(o.data as Map)} : p
        ];
        return _json(ok(patterns.firstWhere((p) => p['id'] == id), 'Weekly day policy updated successfully.'));
      }
      patterns = [
        for (final p in patterns) p['id'] == id ? {...p, 'is_active': false} : p
      ];
      return _json({'status': 'success', 'message': 'Weekly day policy deactivated successfully.'});
    }
    return _json(ok(<String, dynamic>{}));
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
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final full = user(['settings.view', 'attendance.view', 'attendance.create', 'attendance.edit', 'attendance.delete']);
final viewOnly = user(['settings.view', 'attendance.view']);
final noAttendance = user(['settings.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? full),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
                ? const SizedBox()
                : const AttendanceRulesScreen(),
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String key, String option) async {
  await tap(tester, key);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(Key(key)));
  return w is ButtonStyleButton ? w.onPressed != null : (w as IconButton).onPressed != null;
}

Finder inCard(Finder f) => find.descendant(of: find.byKey(const Key('weekly-off-patterns-card')), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and payload', () {
    test('parsing, web day summary, deactivate reasons', () {
      final p = WeeklyOffPattern.fromJson(pattern('p2', 'Sunday Only', days: {'saturday': 'half_day'}, assigned: 1));
      expect([p.days['saturday'], p.days['sunday'], p.assignedEmployeeCount, p.isActive], ['half_day', 'off', 1, true]);
      expect(weeklyOffDaysSummary(p), 'Sun • Sat (half-day)');
      expect(
          weeklyOffDaysSummary(
              WeeklyOffPattern.fromJson(pattern('x', 'X', days: {'saturday': 'working', 'sunday': 'working'}))),
          'No off days');
      expect(deactivateBlockedReason(p), 'Currently assigned to 1 employee — reassign them first.');
      expect(deactivateBlockedReason(WeeklyOffPattern.fromJson(pattern('d', 'D', isDefault: true))),
          'Assign another pattern as default before removing this one.');
      expect(deactivateBlockedReason(WeeklyOffPattern.fromJson(pattern('f', 'F'))), isNull);
      // Assignment's minimal shape still parses.
      final bare = WeeklyOffPattern.fromJson({'id': 'p1', 'name': 'A', 'policy_code': 'WD-1'});
      expect([bare.days, bare.isActive, bare.assignedEmployeeCount], [isEmpty, true, 0]);
    });

    test('create payload with web defaults; edit payload from the pattern', () {
      final f = WeeklyOffPatternForm()..name = 'Weekend Off';
      expect(f.toJson(), {
        'name': 'Weekend Off',
        'monday': 'working',
        'tuesday': 'working',
        'wednesday': 'working',
        'thursday': 'working',
        'friday': 'working',
        'saturday': 'off',
        'sunday': 'off',
        'is_default': false,
        'is_active': true,
      });
      expect(WeeklyOffPatternForm().canSave, isFalse);
      final e = WeeklyOffPatternForm.fromPattern(
          WeeklyOffPattern.fromJson(pattern('p2', 'Sunday Only', days: {'saturday': 'half_day'}, isDefault: true)));
      expect([e.name, e.days['saturday'], e.isDefault, e.toJson().containsKey('policy_code')],
          ['Sunday Only', 'half_day', true, false]);
    });

    test('below the UI: each action needs its server permission; nothing is sent otherwise', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewOnly));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final s = c.read(weeklyOffPatternServiceProvider);
      await expectLater(s.create(WeeklyOffPatternForm()..name = 'X'), throwsA(isA<WeeklyOffPatternDenied>()));
      await expectLater(s.update('p2', WeeklyOffPatternForm()..name = 'X'), throwsA(isA<WeeklyOffPatternDenied>()));
      await expectLater(s.deactivate('p2'), throwsA(isA<WeeklyOffPatternDenied>()));
      expect(server.writes, isEmpty);
    });

    test('a confirmed save reloads Weekly Off Assignment\'s active patterns (inactive ones never offered)', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(full));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final sub = c.listen(weeklyOffPatternsProvider, (_, __) {});
      addTearDown(sub.close);
      final before = await c.read(weeklyOffPatternsProvider.future);
      expect(before.map((p) => p.name), ['Weekend Off', 'Sunday Only']); // inactive 'Old Pattern' not offered
      expect(server.activeGets.last, {'page_size': 50, 'is_active': 'true'}); // assignment contract unchanged
      await c.read(weeklyOffPatternServiceProvider).create(WeeklyOffPatternForm()..name = 'Fri Off');
      final after = await c.read(weeklyOffPatternsProvider.future);
      expect(after.map((p) => p.name), contains('Fri Off'));
      expect(server.activeGets, hasLength(2));
      await c.read(weeklyOffPatternServiceProvider).deactivate('p9');
      final afterDelete = await c.read(weeklyOffPatternsProvider.future);
      expect(afterDelete.map((p) => p.name), isNot(contains('Fri Off')));
    });
  });

  group('card on Attendance Rules', () {
    testWidgets('all patterns 3 per page: badges, days, usage; blocked deactivation', (tester) async {
      await pump(tester);
      expect(server.cardGets.first, {'page': 1, 'page_size': 3});
      expect(inCard(find.text('Weekend Off')), findsOneWidget);
      expect(find.byKey(const Key('wop-default-p1')), findsOneWidget);
      expect(find.byKey(const Key('wop-inactive-p3')), findsOneWidget);
      expect(inCard(find.text('Sun • Sat (half-day)')), findsOneWidget);
      expect(inCard(find.text('40 employees')), findsOneWidget);
      expect(inCard(find.text('1 employee')), findsOneWidget);
      expect(enabled(tester, 'wop-delete-p1'), isFalse); // default
      expect(enabled(tester, 'wop-delete-p2'), isFalse); // assigned
      expect(enabled(tester, 'wop-delete-p3'), isTrue); // server decides (already inactive → 409)
    });

    testWidgets('placed after Working Hours (the old Weekly Off grid is gone, as on web)', (tester) async {
      await pump(tester);
      final y = tester.getTopLeft(find.byKey(const Key('weekly-off-patterns-card'))).dy;
      expect(y, greaterThan(tester.getTopLeft(find.text('Working Hours').first).dy));
    });

    testWidgets('attendance.view only: list but no Add / Edit / Deactivate; no attendance.view: no card',
        (tester) async {
      await pump(tester, as: viewOnly);
      expect(inCard(find.text('Weekend Off')), findsOneWidget);
      expect(find.byKey(const Key('wop-add')), findsNothing);
      expect(find.byKey(const Key('wop-edit-p2')), findsNothing);
      expect(find.byKey(const Key('wop-delete-p3')), findsNothing);
    });

    testWidgets('no attendance.view: no card and no request', (tester) async {
      await pump(tester, as: noAttendance);
      expect(find.byKey(const Key('weekly-off-patterns-card')), findsNothing);
      expect(server.cardGets, isEmpty);
    });

    testWidgets('error with Retry, empty, and paging', (tester) async {
      await pump(tester, setup: (s) => s.failList = true);
      expect(find.byKey(const Key('wop-error')), findsOneWidget);
      server
        ..failList = false
        ..patterns = [];
      await tap(tester, 'wop-retry');
      expect(find.text('No patterns created yet.'), findsOneWidget);
    });

    testWidgets('paging: next asks for page 2', (tester) async {
      await pump(tester, setup: (s) => s.totalPages = 2);
      expect(find.text('1 / 2'), findsOneWidget);
      await tap(tester, 'wop-next');
      expect(server.cardGets.last, {'page': 2, 'page_size': 3});
    });
  });

  group('create / edit', () {
    testWidgets('create: defaults, name required, exact POST, server message, card reloads', (tester) async {
      await pump(tester);
      await tap(tester, 'wop-add');
      expect(find.text('Add Weekly Off Pattern'), findsOneWidget);
      expect(enabled(tester, 'wop-save'), isFalse);
      await tester.enterText(find.byKey(const Key('wop-name')), 'Fri Half');
      await tester.pump();
      await pick(tester, 'wop-day-friday', 'Half Day');
      await tap(tester, 'wop-default');
      final gets = server.cardGets.length;
      await tap(tester, 'wop-save');
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', ApiConstants.attendanceWeeklyDayPolicies]);
      expect(w.body, {
        'name': 'Fri Half',
        'monday': 'working',
        'tuesday': 'working',
        'wednesday': 'working',
        'thursday': 'working',
        'friday': 'half_day',
        'saturday': 'off',
        'sunday': 'off',
        'is_default': true,
        'is_active': true,
      });
      expect(find.byKey(const Key('wop-form')), findsNothing);
      expect(find.text('Weekly day policy created successfully.'), findsOneWidget);
      expect(server.cardGets.length, gets + 1);
    });

    testWidgets('a refusal keeps the form and values (e.g. no working day)', (tester) async {
      await pump(tester);
      await tap(tester, 'wop-add');
      await tester.enterText(find.byKey(const Key('wop-name')), 'All Off');
      await tester.pump();
      await pick(tester, 'wop-day-monday', 'Off');
      server.refuseNext = (
        status: 422,
        message:
            'At least one day must be marked as a working day. A week with zero working days is not a valid work schedule.'
      );
      await tap(tester, 'wop-save');
      expect(find.textContaining('At least one day must be marked as a working day.'), findsOneWidget);
      expect(find.byKey(const Key('wop-form')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('wop-name'))).controller!.text, 'All Off');
      expect(server.writes.single.body, containsPair('monday', 'off'));
    });

    testWidgets('Save can\'t be sent twice', (tester) async {
      await pump(tester);
      await tap(tester, 'wop-add');
      await tester.enterText(find.byKey(const Key('wop-name')), 'Fri Off');
      await tester.pump();
      server.hold = Completer();
      await tester.tap(find.byKey(const Key('wop-save')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wop-save')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.writes, hasLength(1));
    });

    testWidgets('edit: prefilled, exact PATCH, refusal keeps values', (tester) async {
      await pump(tester);
      await tap(tester, 'wop-edit-p2');
      expect(find.text('Edit Pattern'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('wop-name'))).controller!.text, 'Sunday Only');
      expect(find.text('Half Day'), findsOneWidget); // Saturday prefilled
      await tester.enterText(find.byKey(const Key('wop-name')), 'weekend off');
      await tester.pump();
      server.refuseNext = (status: 422, message: 'A weekly day policy named "weekend off" already exists.');
      await tap(tester, 'wop-save');
      expect(find.text('A weekly day policy named "weekend off" already exists.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('wop-name'))).controller!.text, 'weekend off');
      await tester.enterText(find.byKey(const Key('wop-name')), 'Sun Off + Sat Half');
      await tester.pump();
      await tap(tester, 'wop-save');
      final w = server.writes.last;
      expect([w.method, w.path], ['PATCH', ApiConstants.attendanceWeeklyDayPolicy('p2')]);
      expect(w.body, containsPair('saturday', 'half_day'));
      expect(w.body, containsPair('name', 'Sun Off + Sat Half'));
      expect(find.text('Weekly day policy updated successfully.'), findsOneWidget);
      expect(inCard(find.text('Sun Off + Sat Half')), findsOneWidget);
    });
  });

  group('deactivate', () {
    testWidgets('confirm, DELETE, refreshed list shows it inactive', (tester) async {
      await pump(tester, setup: (s) => s.patterns = [pattern('p4', 'Spare Pattern')]);
      await tap(tester, 'wop-delete-p4');
      expect(find.textContaining('"Spare Pattern" will be deactivated.'), findsOneWidget);
      expect(server.writes, isEmpty);
      await tap(tester, 'wop-deactivate-confirm');
      expect([server.writes.single.method, server.writes.single.path],
          ['DELETE', ApiConstants.attendanceWeeklyDayPolicy('p4')]);
      expect(find.text('Weekly day policy deactivated successfully.'), findsOneWidget);
      expect(find.byKey(const Key('wop-inactive-p4')), findsOneWidget);
    });

    testWidgets('server refusal stays in the dialog; nothing changes locally', (tester) async {
      await pump(tester);
      await tap(tester, 'wop-delete-p3');
      server.refuseNext = (status: 409, message: 'Weekly day policy is already inactive.');
      await tap(tester, 'wop-deactivate-confirm');
      expect(find.text('Weekly day policy is already inactive.'), findsOneWidget);
      expect(find.byKey(const Key('wop-deactivate')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(inCard(find.text('Old Pattern')), findsOneWidget);
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/attendance/data/models/weekly_off_assignment_models.dart';
import 'package:mobile_app/features/attendance/data/models/weekly_off_pattern_models.dart';
import 'package:mobile_app/features/settings/presentation/attendance_rules/attendance_rules_screen.dart';

// P1-5: Settings → Attendance Rules no longer shows the old flat "Weekly Off
// Days" grid — web AttendanceSettings.tsx removed it in favour of Weekly Off
// Patterns. The setting itself (AttendanceSettings.weekly_off) still exists on
// the server as the last fallback when no pattern is Default
// (core.cache_service.WeeklyOffCacheService), so Save All must keep sending
// it back unchanged, as web's buildPutPayload does. Synthetic data only.

const settingsPath = '/attendance/settings/';
const patternsPath = ApiConstants.attendanceWeeklyDayPolicies;

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> settings({Map<String, bool>? weeklyOff}) => {
      'working_hours': {
        'shift_start': '09:00:00',
        'shift_end': '18:00:00',
        'grace_period_minutes': 15,
        'break_duration_minutes': 30,
      },
      'weekly_off': weeklyOff ??
          {
            'monday': false,
            'tuesday': false,
            'wednesday': false,
            'thursday': false,
            'friday': true,
            'saturday': false,
            'sunday': true,
          },
      'punch_rules': {
        'min_hours_full_day': '8.00',
        'min_hours_half_day': '4.00',
        'early_exit_grace_minutes': 30,
        'missing_punch_action': 'mark_half_day',
        'early_leave_allowance_per_month': 2,
        'wfh_daily_report_required': true,
      },
      'overtime_rules': {
        'ot_threshold_hours': '9.00',
        'ot_multiplier_regular': '1.50',
        'ot_multiplier_holiday': '2.00'
      },
      'late_mark_rules': {'late_marks_per_lop': 3, 'lop_deduction_unit': 'full_day', 'late_mark_mode': 'every_n'},
      'absence_alert': {'is_enabled': true, 'alert_after_days': 3, 'notify_whom': 'manager_and_hr'},
      'face_verification': {'is_mandatory': false},
    };

Map<String, dynamic> pat(String id, String name, {bool isDefault = false, bool active = true}) => {
      'id': id,
      'name': name,
      'policy_code': 'WD-${id.toUpperCase()}',
      'monday': 'working',
      'tuesday': 'working',
      'wednesday': 'working',
      'thursday': 'working',
      'friday': 'working',
      'saturday': 'off',
      'sunday': 'off',
      'working_days_count': 5,
      'assigned_employee_count': 0,
      'is_default': isDefault,
      'is_active': active,
      'created_at': '2026-11-01T00:00:00Z',
    };

class Server implements HttpClientAdapter {
  Server(this.state);
  Map<String, dynamic> state;
  // Server order: -is_default, name. Default: one active default.
  List<Map<String, dynamic>> patterns = [pat('p1', 'Weekend Off', isDefault: true)];
  int totalPages = 1;
  bool failPatterns = false;
  Completer<void>? holdPatterns;
  ({int status, String message})? refusePut;
  final calls = <({String method, String path, Object? body})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.path == settingsPath && o.method == 'GET') {
      return _json(200, {'status': 'success', 'message': 'ok', 'data': state});
    }
    if (o.path == settingsPath && o.method == 'PUT') {
      final r = refusePut;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      state = jsonDecode(jsonEncode(o.data)) as Map<String, dynamic>;
      return _json(200, {'status': 'success', 'message': 'Attendance settings saved.', 'data': state});
    }
    if (o.path == patternsPath && o.method == 'GET') {
      final gate = holdPatterns;
      if (gate != null) await gate.future;
      if (failPatterns) return _json(500, {'status': 'error', 'message': 'Failed to load.', 'data': {}});
      final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
      final rows = page == 1 ? patterns : [pat('p7', 'Zeta Pattern')];
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {'count': rows.length, 'page': page, 'total_pages': totalPages, 'results': rows},
      });
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthNotifier {
  _Auth(this.perms);
  final List<String> perms;
  @override
  Future<AuthState> build() async => AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'HR Tester',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: perms,
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late Server server;

Future<void> pump(WidgetTester tester,
    {Map<String, dynamic>? state, List<String>? perms, void Function(Server)? setup, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(state ?? settings());
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      authStateProvider.overrideWith(() => _Auth(perms ?? const ['settings.view', 'settings.edit', 'attendance.view'])),
    ],
    child: MaterialApp.router(
        routerConfig: GoRouter(
            initialLocation: '/settings/attendance-rules',
            routes: [GoRoute(path: '/settings/attendance-rules', builder: (_, __) => const AttendanceRulesScreen())])),
  ));
  if (settle) await tester.pumpAndSettle();
}

final warning = find.byKey(const Key('wop-no-default-warning'));

Future<void> saveAll(WidgetTester tester) async {
  await tester.tap(find.text('Save All'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('1–3. Weekly Off Patterns and every other section stay; the old grid is gone', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('weekly-off-patterns-card')), findsOneWidget);
    expect(find.text('Weekend Off'), findsOneWidget);
    for (final title in [
      'Working Hours',
      'Punch Rules',
      'Overtime Rules',
      'Late Mark & LOP Rule',
      'Absence Alert',
      'Face ID Verification',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
    expect(find.text('Weekly Off Days'), findsNothing);
    expect(find.text('Select off days — excluded from attendance calculations'), findsNothing);
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(d), findsNothing, reason: d);
    }
    // Patterns sit right after Working Hours, as on web.
    expect(tester.getTopLeft(find.byKey(const Key('weekly-off-patterns-card'))).dy,
        greaterThan(tester.getTopLeft(find.text('Working Hours').first).dy));
  });

  testWidgets('6. opening the screen makes no weekly-off settings write and no other grid request', (tester) async {
    await pump(tester);
    expect(server.calls.map((c) => '${c.method} ${c.path}').toSet(), {'GET $settingsPath', 'GET $patternsPath'});
  });

  testWidgets('Save All sends the stored weekly_off back unchanged (the server fallback is preserved)', (tester) async {
    await pump(tester);
    await saveAll(tester);
    final put = server.calls.singleWhere((c) => c.method == 'PUT');
    final body = jsonDecode(jsonEncode(put.body)) as Map<String, dynamic>;
    expect(body['weekly_off'], {
      'monday': false,
      'tuesday': false,
      'wednesday': false,
      'thursday': false,
      'friday': true,
      'saturday': false,
      'sunday': true,
    });
    expect(find.text('All settings saved.'), findsOneWidget);
  });

  testWidgets(
      'Save All is no longer blocked on the client by a weekly_off value there is no grid to fix; the '
      'server decides, as on web', (tester) async {
    final allOff = {
      for (final d in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']) d: true
    };
    await pump(tester, state: settings(weeklyOff: allOff));
    server.refusePut = (status: 400, message: 'At least one day must be a working day.');
    await saveAll(tester);
    expect(server.calls.where((c) => c.method == 'PUT'), hasLength(1));
    expect(find.text('At least one day must be a working day.'), findsOneWidget);
  });

  testWidgets('without attendance.view the Patterns card hides as before; the other sections remain', (tester) async {
    await pump(tester, perms: const ['settings.view', 'settings.edit']);
    expect(find.byKey(const Key('weekly-off-patterns-card')), findsNothing);
    expect(find.text('Working Hours'), findsWidgets);
    expect(find.text('Weekly Off Days'), findsNothing);
    expect(server.calls.where((c) => c.path == patternsPath), isEmpty);
  });

  group('no default pattern warning', () {
    test('decision: only a loaded page 1 decides; an inactive default does not count', () {
      WeeklyOffPatternPage page(List<Map<String, dynamic>> rows) =>
          WeeklyOffPatternPage.fromJson({'count': rows.length, 'page': 1, 'total_pages': 1, 'results': rows});
      expect(noActiveDefaultPattern(requestedPage: 1, page: page([pat('p1', 'A', isDefault: true)])), isFalse);
      expect(noActiveDefaultPattern(requestedPage: 1, page: page([pat('p1', 'A')])), isTrue);
      expect(noActiveDefaultPattern(requestedPage: 1, page: page([])), isTrue);
      expect(noActiveDefaultPattern(requestedPage: 1, page: page([pat('p1', 'A', isDefault: true, active: false)])),
          isTrue);
      expect(noActiveDefaultPattern(requestedPage: 2, page: page([pat('p1', 'A')])), isNull);
      expect(noActiveDefaultPattern(requestedPage: 1, page: null), isNull);
      expect(WeeklyOffPattern.fromJson(pat('p1', 'A', isDefault: true, active: false)).isActive, isFalse);
    });

    testWidgets('shown when patterns load but none is the default', (tester) async {
      await pump(tester, setup: (s) => s.patterns = [pat('p1', 'Night Shift Off'), pat('p2', 'Weekend Off')]);
      expect(warning, findsOneWidget);
      final text =
          tester.widget<Text>(find.descendant(of: warning, matching: find.byType(Text))).textSpan!.toPlainText();
      expect(
          text,
          'No default Weekly Off Pattern is configured. Employees without an individual assignment may continue '
          'using the legacy company weekly-off setting. Set a pattern as Default to manage weekly offs here.');
      // Inside the Patterns card, above its list.
      expect(find.descendant(of: find.byKey(const Key('weekly-off-patterns-card')), matching: warning), findsOneWidget);
    });

    testWidgets('shown when there are no patterns at all', (tester) async {
      await pump(tester, setup: (s) => s.patterns = []);
      expect(find.byKey(const Key('wop-empty')), findsOneWidget);
      expect(warning, findsOneWidget);
    });

    testWidgets('hidden when an active default exists', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('wop-default-p1')), findsOneWidget);
      expect(warning, findsNothing);
    });

    testWidgets('an inactive default does not suppress it', (tester) async {
      await pump(tester,
          setup: (s) => s.patterns = [pat('p1', 'Old Default', isDefault: true, active: false), pat('p2', 'Weekend')]);
      expect(find.byKey(const Key('wop-inactive-p1')), findsOneWidget);
      expect(warning, findsOneWidget);
    });

    testWidgets('not shown while loading, and not shown when the request fails', (tester) async {
      final gate = Completer<void>();
      await pump(tester, settle: false, setup: (s) {
        s.patterns = [pat('p2', 'Weekend')];
        s.holdPatterns = gate;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('wop-loading')), findsOneWidget);
      expect(warning, findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(warning, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pump(tester, setup: (s) {
        s.patterns = [pat('p2', 'Weekend')];
        s.failPatterns = true;
      });
      expect(find.byKey(const Key('wop-error')), findsOneWidget);
      expect(warning, findsNothing);
    });

    testWidgets('a later page cannot tell, so no warning there; back on page 1 it returns; no extra request',
        (tester) async {
      await pump(tester, setup: (s) {
        s.patterns = [pat('p1', 'Alpha'), pat('p2', 'Beta'), pat('p3', 'Gamma')];
        s.totalPages = 2;
      });
      expect(warning, findsOneWidget);
      await tester.tap(find.byKey(const Key('wop-next')));
      await tester.pumpAndSettle();
      expect(find.text('Zeta Pattern'), findsOneWidget);
      expect(warning, findsNothing);
      await tester.tap(find.byKey(const Key('wop-prev')));
      await tester.pumpAndSettle();
      expect(warning, findsOneWidget);
      // Only the card's own page requests — no separate "is there a default?" call.
      final gets = server.calls.where((c) => c.path == patternsPath).toList();
      expect(gets, hasLength(3));
    });

    testWidgets('returning to page 1 with an active default: no flash while it reloads or if the reload fails',
        (tester) async {
      Future<void> toPage2(Server s) async {
        await tester.tap(find.byKey(const Key('wop-next')));
        await tester.pumpAndSettle();
        expect(find.text('Zeta Pattern'), findsOneWidget);
      }

      // Reload held: page 2's rows (no default) are still around while page 1 loads.
      await pump(tester, setup: (s) => s.totalPages = 2);
      expect(warning, findsNothing);
      await toPage2(server);
      server.holdPatterns = Completer();
      await tester.tap(find.byKey(const Key('wop-prev')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(warning, findsNothing);
      server.holdPatterns!.complete();
      await tester.pumpAndSettle();
      expect(warning, findsNothing);

      // Reload fails: still no warning from the stale page.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, setup: (s) => s.totalPages = 2);
      await toPage2(server);
      server.failPatterns = true;
      await tester.tap(find.byKey(const Key('wop-prev')));
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
    });

    testWidgets('informational only: Save All still sends weekly_off unchanged while the warning shows',
        (tester) async {
      await pump(tester, setup: (s) => s.patterns = [pat('p2', 'Weekend')]);
      expect(warning, findsOneWidget);
      await saveAll(tester);
      final put = server.calls.singleWhere((c) => c.method == 'PUT');
      final body = jsonDecode(jsonEncode(put.body)) as Map<String, dynamic>;
      expect(body['weekly_off'], settings()['weekly_off']);
      expect(server.calls.where((c) => c.path.startsWith(patternsPath) && c.method != 'GET'), isEmpty);
      expect(find.text('All settings saved.'), findsOneWidget);
    });
  });
}

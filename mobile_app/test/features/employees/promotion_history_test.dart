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
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/data/models/promotion_record_model.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/widgets/promotion_tab.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';

// P1-9: Employee → Promotion history, as web PromotionTab.tsx (local web
// branch): GET /employees/<id>/promotions/ (EmployeePromotionHistoryView —
// employees.view, branch-scoped 404, read-only, server-ordered newest
// first); rows show designation change (+Promotion) and/or role change
// (+Role change), effective date "05 Nov 2026", updated by, "Applied";
// empty "No promotions yet". Promote (employees.edit): PUT /employees/<id>/
// {designation, role} (+ effective_date / remarks, which the backend stores
// on the PromotionRecord it creates). Mocked Dio; nothing is written.

const code = 'EMP-7';

Map<String, dynamic> rec(String id, String fromD, String toD, String fromR, String toR, String date,
        {String by = 'Test HR', bool? roleChanged}) =>
    {
      'id': id,
      'previous_designation': fromD,
      'new_designation': toD,
      'previous_role': fromR,
      'new_role': toR,
      'role_changed': roleChanged ?? fromR != toR,
      'effective_date': date,
      'remarks': '',
      'promoted_by': by,
      'created_at': '${date}T10:00:00Z',
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> history = [
    rec('3', 'Engineer', 'Senior Engineer', 'employee', 'manager_team_lead', '2026-11-05'),
    rec('2', 'Engineer', 'Engineer', 'employee', 'employee', '2026-06-01', roleChanged: false), // edge: no change
    rec('1', 'Associate', 'Engineer', 'employee', 'employee', '2025-01-02', by: '—'),
  ];
  int historyStatus = 200;
  int historyGets = 0;
  final puts = <Map<String, dynamic>>[];
  ({int status, String message})? refusePut;
  Completer<void>? holdPut;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.employeePromotions(code)) {
      historyGets++;
      if (historyStatus != 200) {
        return _json(historyStatus, {'status': 'error', 'message': 'Employee not found.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'message': 'Promotion history retrieved.', 'data': history});
    }
    if (o.method == 'PUT' && o.path == ApiConstants.employeeDetail(code)) {
      puts.add(Map<String, dynamic>.from(o.data as Map));
      final gate = holdPut;
      if (gate != null) await gate.future;
      final r = refusePut;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      return _json(200, {'status': 'success', 'message': 'Employee updated.', 'data': {}});
    }
    if (o.path == ApiConstants.roles) {
      return _json(200, {
        'status': 'success',
        'data': {
          'count': 2,
          'results': [
            {'id': 1, 'name': 'employee', 'display_name': 'Employee', 'permissions': []},
            {'id': 2, 'name': 'manager_team_lead', 'display_name': 'Team Lead', 'permissions': []},
          ]
        }
      });
    }
    if (o.path == ApiConstants.departments) {
      return _json(200, {
        'status': 'success',
        'data': [
          {'id': 1, 'name': 'Engineering'}
        ]
      });
    }
    if (o.path == ApiConstants.designations) {
      return _json(200, {
        'status': 'success',
        'data': [
          {'name': 'Engineer'},
          {'name': 'Senior Engineer'}
        ]
      });
    }
    return _json(200, {'status': 'success', 'data': []});
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

UserEntity hrUser(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = hrUser(['employees.view', 'employees.edit', 'settings.view']);
final viewer = hrUser(['employees.view', 'settings.view']);

final employee = EmployeeModel.fromJson(const {
  'id': code,
  'employee_id': code,
  'full_name': 'Pat Kumar',
  'department': 'Engineering',
  'designation': 'Engineer',
  'role': 'employee',
  'role_display': 'Employee',
  'profile': <String, dynamic>{},
});

late Server server;

String today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

Future<void> pumpTab(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return PromotionTab(employee: employee);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
String text(WidgetTester tester, String key) => tester.widget<Text>(byKey(key)).data!;

Future<void> openPromote(WidgetTester tester) async {
  await tester.tap(find.text('Promote'));
  await tester.pumpAndSettle();
}

Future<void> chooseDesignation(WidgetTester tester, String name) async {
  await tester.tap(find.text('Engineer').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Submit Promotion'));
  await tester.tap(find.text('Submit Promotion'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and formatting', () {
    test('parses the API record; designationChanged is derived, role_changed is read', () {
      final r = PromotionRecordModel.fromJson(
          rec('3', 'Engineer', 'Senior Engineer', 'employee', 'manager_team_lead', '2026-11-05'));
      expect([r.id, r.previousDesignation, r.newDesignation, r.previousRole, r.newRole],
          ['3', 'Engineer', 'Senior Engineer', 'employee', 'manager_team_lead']);
      expect([r.designationChanged, r.roleChanged], [true, true]);
      expect([r.effectiveDate, r.promotedBy], ['2026-11-05', 'Test HR']);
      final noFlag = PromotionRecordModel.fromJson(const {'id': 9, 'previous_role': 'a', 'new_role': 'b'});
      expect([noFlag.id, noFlag.roleChanged, noFlag.designationChanged], ['9', true, false]);
    });

    test('dates read like web (en-IN): "05 Nov 2026"; empty → "—"; unparsable kept', () {
      expect(formatPromotionDate('2026-11-05'), '05 Nov 2026');
      expect(formatPromotionDate('2025-01-02'), '02 Jan 2025');
      expect(formatPromotionDate(''), '—');
      expect(formatPromotionDate('soon'), 'soon');
    });
  });

  group('history', () {
    testWidgets('shows the server\'s records in the server\'s order with web\'s fields and badges', (tester) async {
      await pumpTab(tester);
      final cards = tester.widgetList<Container>(find.byWidgetPredicate(
          (w) => w is Container && w.key is ValueKey<String> && RegExp(r'^promotion-\d+$').hasMatch((w.key as ValueKey<String>).value)));
      expect(cards.map((c) => (c.key as ValueKey<String>).value), ['promotion-3', 'promotion-2', 'promotion-1']);

      // record 3: designation + role change, role slugs shown as role names
      expect(find.descendant(of: byKey('promotion-3-designation'), matching: find.text('Engineer → Senior Engineer')),
          findsOneWidget);
      expect(find.descendant(of: byKey('promotion-3-designation'), matching: find.text('Promotion')), findsOneWidget);
      expect(find.descendant(of: byKey('promotion-3-role'), matching: find.text('Employee → Team Lead')), findsOneWidget);
      expect(find.descendant(of: byKey('promotion-3-role'), matching: find.text('Role change')), findsOneWidget);
      expect(text(tester, 'promotion-3-date'), '05 Nov 2026');
      expect(text(tester, 'promotion-3-by'), 'Test HR');
      // record 1: designation only
      expect(byKey('promotion-1-designation'), findsOneWidget);
      expect(byKey('promotion-1-role'), findsNothing);
      expect(text(tester, 'promotion-1-by'), '—');
      // record 2: neither changed → no change line is invented
      expect(byKey('promotion-2-designation'), findsNothing);
      expect(byKey('promotion-2-role'), findsNothing);
      expect(find.text('Applied'), findsNWidgets(3));
    });

    testWidgets('no records → web\'s empty state', (tester) async {
      await pumpTab(tester, with_: Server()..history = []);
      expect(byKey('promotion-history-empty'), findsOneWidget);
      expect(find.text('No promotions yet'), findsOneWidget);
      expect(find.text('Designation and role changes for this employee will be listed here.'), findsOneWidget);
    });

    testWidgets('a failed load (e.g. out-of-branch 404) shows an error with Retry, which reloads', (tester) async {
      final s = Server()..historyStatus = 404;
      await pumpTab(tester, with_: s);
      expect(byKey('promotion-history-error'), findsOneWidget);
      expect(find.text('Could not load promotion history.'), findsOneWidget);
      expect(find.text('No promotions yet'), findsNothing);
      expect(byKey('promotion-history-empty'), findsNothing, reason: 'a failure is not shown as "no promotions"');
      s.historyStatus = 200;
      await tester.tap(byKey('promotion-history-retry'));
      await tester.pumpAndSettle();
      expect(byKey('promotion-3'), findsOneWidget);
    });

    testWidgets('without employees.edit: history visible, no Promote', (tester) async {
      await pumpTab(tester, as: viewer);
      expect(byKey('promotion-3'), findsOneWidget);
      expect(find.text('Promote'), findsNothing);
    });

    testWidgets('history is read-only: no edit or delete actions on records', (tester) async {
      await pumpTab(tester);
      expect(find.descendant(of: byKey('promotion-3'), matching: find.byType(IconButton)), findsNothing);
      expect(find.descendant(of: byKey('promotion-3'), matching: find.byType(TextButton)), findsNothing);
    });
  });

  group('promote', () {
    testWidgets('sends only designation, role, effective_date and remarks; reloads history; web message',
        (tester) async {
      await pumpTab(tester);
      final gets = server.historyGets;
      await openPromote(tester);
      await chooseDesignation(tester, 'Senior Engineer');
      await tester.enterText(find.widgetWithText(TextField, 'Reason for promotion'), 'Great work');
      await submit(tester);

      expect(server.puts.single, {
        'designation': 'Senior Engineer',
        'role': 'employee',
        'effective_date': today(),
        'remarks': 'Great work',
      });
      expect(server.historyGets, greaterThan(gets), reason: 'history re-fetched after the promotion');
      expect(find.text('Designation updated successfully.'), findsOneWidget);
    });

    testWidgets('no change → web\'s message and no request', (tester) async {
      await pumpTab(tester);
      await openPromote(tester);
      await submit(tester);
      expect(find.text(kPromotionNoChange), findsOneWidget);
      expect(server.puts, isEmpty);
    });

    testWidgets('a role change needs the confirmation; then it is sent with the elevated message', (tester) async {
      await pumpTab(tester);
      await openPromote(tester);
      await tester.tap(find.text('Employee').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team Lead').last);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(find.text('Confirm the role change before submitting.'), findsOneWidget);
      expect(server.puts, isEmpty);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await submit(tester);
      expect(server.puts.single['role'], 'manager_team_lead');
      expect(server.puts.single['designation'], 'Engineer');
      expect(server.puts.single.containsKey('remarks'), isFalse, reason: 'empty remarks are not sent');
      expect(find.text("Designation and role updated. New access applies at the employee's next login."),
          findsOneWidget);
    });

    testWidgets('a server error keeps the sheet and choices; retry succeeds', (tester) async {
      final s = Server()..refusePut = (status: 400, message: 'Designation "Senior Engineer" does not exist.');
      await pumpTab(tester, with_: s);
      await openPromote(tester);
      await chooseDesignation(tester, 'Senior Engineer');
      await submit(tester);
      expect(find.text('Designation "Senior Engineer" does not exist.'), findsOneWidget);
      expect(find.text('Submit Promotion'), findsOneWidget, reason: 'sheet still open');
      s.refusePut = null;
      await submit(tester);
      expect(s.puts, hasLength(2));
      expect(s.puts.last['designation'], 'Senior Engineer');
      expect(find.text('Submit Promotion'), findsNothing);
    });

    testWidgets('a second tap while submitting sends nothing more', (tester) async {
      final s = Server()..holdPut = Completer();
      await pumpTab(tester, with_: s);
      await openPromote(tester);
      await chooseDesignation(tester, 'Senior Engineer');
      await tester.ensureVisible(find.text('Submit Promotion'));
      await tester.tap(find.text('Submit Promotion'));
      await tester.pump();
      expect(find.text('Submit Promotion'), findsNothing, reason: 'loading indicator while submitting');
      await tester.tap(find.byType(AppButton).last, warnIfMissed: false);
      await tester.pump();
      s.holdPut!.complete();
      await tester.pumpAndSettle();
      expect(s.puts, hasLength(1));
    });

    testWidgets('the action refuses without employees.edit, before any request', (tester) async {
      server = Server();
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(viewer)),
          dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: MaterialApp(home: Consumer(builder: (context, r, _) {
          ref = r;
          r.watch(authStateProvider);
          return const SizedBox();
        })),
      ));
      await tester.pumpAndSettle();
      final result = await tester.runAsync(() => promoteEmployeeAction(ref, code,
          fromDesignation: 'Engineer',
          fromRole: 'employee',
          designation: 'Senior Engineer',
          role: 'employee',
          effectiveDate: '2026-11-09'));
      expect(result, kPromotionDenied);
      expect(server.puts, isEmpty);
    });
  });
}

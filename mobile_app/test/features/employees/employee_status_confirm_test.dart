import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';

// Task 35 (gap C-E04): activating / deactivating an employee asks first, as
// web employees/page.tsx (confirm modal → PATCH /employees/<code>/
// {is_active}; EmployeeDetailView.patch: employees.edit + branch scope).
// On mobile the only status control is the profile header's switch.
// Synthetic data on a stand-in server; nobody's status really changes.

const code = 'EMP-7';
const detailPath = '/employees/$code/';

Map<String, dynamic> employee({required bool active, String onboarding = 'complete'}) => {
      'id': code,
      'uuid': '11111111-0000-0000-0000-000000000007',
      'employee_id': code,
      'first_name': 'Nia',
      'last_name': 'Test',
      'full_name': 'Nia Test',
      'email': 'nia.test@example.test',
      'phone': '9000000007',
      'department': 'QA',
      'designation': 'Analyst',
      'branch': 'North',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': active,
      'status': active ? 'active' : 'inactive',
      'onboarding_status': onboarding,
      'date_of_joining': '2026-11-01',
      'hr': <String, dynamic>{'id': null, 'uuid': null, 'name': null},
      'documents': <Object>[],
      'profile': <String, dynamic>{},
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  Server({required this.active});
  bool active;
  int patchStatus = 200;
  String patchMessage = 'You cannot deactivate your own account.';
  Completer<void>? holdPatch;
  final calls = <RequestOptions>[];

  List<RequestOptions> get patches => calls.where((c) => c.method == 'PATCH' && c.path == detailPath).toList();
  int get detailGets => calls.where((c) => c.method == 'GET' && c.path == detailPath).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    if (o.path == detailPath && o.method == 'GET') {
      return _json(200, {'status': 'success', 'message': 'Employee retrieved.', 'data': employee(active: active)});
    }
    if (o.path == detailPath && o.method == 'PATCH') {
      final gate = holdPatch;
      if (gate != null) await gate.future;
      if (patchStatus != 200) return _json(patchStatus, {'status': 'error', 'message': patchMessage, 'data': {}});
      active = (o.data as Map)['is_active'] as bool;
      return _json(200, {
        'status': 'success',
        'message': 'Employee ${active ? 'activated' : 'deactivated'} successfully.',
        'data': employee(active: active),
      });
    }
    if (o.method == 'GET') return _json(200, {'status': 'success', 'data': []});
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
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

final editor = hrUser(['employees.view', 'employees.edit']);
final viewer = hrUser(['employees.view']);

late Server server;

Future<void> pumpProfile(WidgetTester tester, {required bool active, UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server(active: active);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  // Plain pumps for the first load (as the other profile tests do).
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
  await container.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

final toggle = find.byType(Switch);
final dialog = find.byKey(const Key('employee-status-confirm'));
final cancel = find.byKey(const Key('employee-status-cancel'));
final confirm = find.byKey(const Key('employee-status-confirm-button'));

Future<void> tapToggle(WidgetTester tester) async {
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

bool switchValue(WidgetTester tester) => tester.widget<Switch>(toggle).value;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('active employee: "Deactivate Employee" confirmation in web\'s wording, red Deactivate', (tester) async {
    await pumpProfile(tester, active: true);
    expect(switchValue(tester), isTrue);
    await tapToggle(tester);
    expect(dialog, findsOneWidget);
    expect(find.text('Deactivate Employee'), findsOneWidget);
    expect(find.text('Are you sure you want to deactivate Nia Test?', findRichText: true), findsOneWidget);
    expect(find.descendant(of: confirm, matching: find.text('Deactivate')), findsOneWidget);
    expect(find.descendant(of: cancel, matching: find.text('Cancel')), findsOneWidget);
    expect(server.patches, isEmpty, reason: 'nothing sent before confirming');
    expect(switchValue(tester), isTrue, reason: 'the switch does not move yet');
  });

  testWidgets('inactive employee: "Activate Employee" confirmation', (tester) async {
    await pumpProfile(tester, active: false);
    expect(switchValue(tester), isFalse);
    await tapToggle(tester);
    expect(find.text('Activate Employee'), findsOneWidget);
    expect(find.text('Are you sure you want to activate Nia Test?', findRichText: true), findsOneWidget);
    expect(find.descendant(of: confirm, matching: find.text('Activate')), findsOneWidget);
  });

  testWidgets('Cancel (or dismissing) sends nothing and leaves the status as it was', (tester) async {
    await pumpProfile(tester, active: true);
    await tapToggle(tester);
    await tester.tap(cancel);
    await settle(tester);
    expect(dialog, findsNothing);
    expect(server.patches, isEmpty);
    expect(switchValue(tester), isTrue);
    // Tapping outside the dialog cancels too.
    await tapToggle(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(dialog, findsNothing);
    expect(server.patches, isEmpty);
  });

  testWidgets('Confirm deactivate → exactly one PATCH {is_active: false}; status refreshed', (tester) async {
    await pumpProfile(tester, active: true);
    final getsBefore = server.detailGets;
    await tapToggle(tester);
    await tester.tap(confirm);
    await settle(tester);
    expect(server.patches, hasLength(1));
    expect(server.patches.single.data, {'is_active': false});
    expect(switchValue(tester), isFalse);
    expect(find.text('Inactive Employee'), findsOneWidget);
    expect(server.detailGets, greaterThan(getsBefore), reason: 'employee re-fetched after the change');
  });

  testWidgets('Confirm activate → exactly one PATCH {is_active: true}', (tester) async {
    await pumpProfile(tester, active: false);
    await tapToggle(tester);
    await tester.tap(confirm);
    await settle(tester);
    expect(server.patches.single.data, {'is_active': true});
    expect(switchValue(tester), isTrue);
    expect(find.text('Active Employee'), findsOneWidget);
  });

  testWidgets('double-tapping Confirm still sends one request; the switch is locked while it runs', (tester) async {
    final s = Server(active: true)..holdPatch = Completer();
    await pumpProfile(tester, active: true, with_: s);
    await tapToggle(tester);
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(toggle, findsNothing, reason: 'progress indicator replaces the switch while saving');
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    s.holdPatch!.complete();
    await settle(tester);
    expect(s.patches, hasLength(1));
    // And the next change asks again.
    await tapToggle(tester);
    expect(dialog, findsOneWidget);
  });

  testWidgets('two switch events while the dialog is open → one dialog, one request', (tester) async {
    await pumpProfile(tester, active: true);
    final onChanged = tester.widget<Switch>(toggle).onChanged!;
    onChanged(false);
    onChanged(false);
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    await tester.tap(confirm);
    await settle(tester);
    expect(dialog, findsNothing);
    expect(server.patches, hasLength(1));
  });

  testWidgets('Confirm handled once even if its handler fires twice (does not pop the page underneath)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(body: Text('HOME')),
      routes: {
        '/page': (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      results.add(await confirmEmployeeStatusChange(context, fullName: 'Nia Test', activate: false)),
                  child: const Text('ask'),
                ),
              ),
            ),
      },
    ));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/page');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    final press = tester.widget<FilledButton>(confirm).onPressed!;
    press();
    press();
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.text('ask'), findsOneWidget, reason: 'the page under the dialog is still there');
  });

  testWidgets('a refused change: server message shown, status restored; confirming again retries', (tester) async {
    final s = Server(active: true)..patchStatus = 400;
    await pumpProfile(tester, active: true, with_: s);
    await tapToggle(tester);
    await tester.tap(confirm);
    await settle(tester);
    expect(find.text('You cannot deactivate your own account.'), findsOneWidget);
    expect(switchValue(tester), isTrue, reason: 'restored after the failure');
    s.patchStatus = 200;
    await tapToggle(tester);
    expect(dialog, findsOneWidget, reason: 'retry asks again');
    await tester.tap(confirm);
    await settle(tester);
    expect(s.patches, hasLength(2));
    expect(switchValue(tester), isFalse);
  });

  testWidgets('without employees.edit the switch is read-only: no dialog, no request', (tester) async {
    await pumpProfile(tester, active: true, as: viewer);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);
    await tester.tap(toggle, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(server.patches, isEmpty);
  });
}

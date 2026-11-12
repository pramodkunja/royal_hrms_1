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
import 'package:mobile_app/features/auth/data/models/user_model.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_assets_tab.dart';

// Task 62: Employee Profile → Assets, as web employees/[id]/_components/
// AssetsTab.tsx over backend apps/assets (EmployeeAssetsView: self or
// assets.view + scope; AssignAssetView / ReturnAssetView: assets.edit; 409 on
// an assignment conflict; ReturnAssetSerializer: reason required, date not
// before the assignment). The tab shows when the company has the "assets"
// module (login `enabled_modules`; unknown → shown) and replaces the old
// Benefit placeholder. Synthetic people and assets; nothing real is changed.

const code = 'EMP-62';
const empUuid = '62626262-0000-4000-8000-000000000062';
final today = DateTime.now();
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> assignment(String id, String tag, String name,
        {bool returned = false, String type = 'Laptop', String serial = 'SN-1'}) =>
    {
      'id': id,
      'asset': 'asset-$id',
      'asset_tag': tag,
      'asset_name': name,
      'asset_type': type,
      'serial_number': serial,
      'employee': empUuid,
      'employee_name': 'Ravi Test',
      'status': returned ? 'returned' : 'assigned',
      'status_display': returned ? 'Returned' : 'Assigned',
      'assigned_date': '2026-03-05',
      'condition_at_assignment': 'good',
      'expected_return_date': null,
      'assign_remarks': '',
      'assigned_by': null,
      'assigned_by_name': null,
      'return_date': returned ? '2026-06-10' : null,
      'return_condition': returned ? 'fair' : '',
      'return_reason': returned ? 'Upgrade' : '',
      'return_remarks': '',
      'returned_by': null,
      'returned_by_name': null,
      'created_at': '2026-03-05T10:00:00Z',
      'updated_at': '2026-03-05T10:00:00Z',
    };

/// Stand-in for the backend, applying its rules for [me].
class Api implements HttpClientAdapter {
  Api(this.me);
  final UserEntity me;
  final calls = <RequestOptions>[];
  List<Map<String, dynamic>> current = [assignment('a1', 'AST-001', 'Dell Latitude')];
  List<Map<String, dynamic>> history = [assignment('a0', 'AST-000', 'Old Phone', returned: true, type: 'Phone')];
  List<Map<String, dynamic>> available = [
    {'id': 'av-1', 'asset_tag': 'AST-101', 'asset_name': 'MacBook Air', 'status': 'available'},
    {'id': 'taken', 'asset_tag': 'AST-102', 'asset_name': 'Monitor', 'status': 'available'},
  ];
  int listStatus = 200;
  Completer<void>? holdList;
  int listGets = 0;
  final posts = <(String, Map<String, dynamic>)>[];

  bool _perm(String p) => me.isSuperuser || me.permissions.contains(p);

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  ResponseBody _err(int status, String message, [Map<String, dynamic>? data]) =>
      _json(status, {'status': 'error', 'message': message, 'data': data ?? {}});

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add(o);
    final path = o.uri.path;
    if (o.method == 'GET' && path == '/api/employees/$code/') {
      return _json(200, {
        'status': 'success',
        'data': {
          'id': code,
          'uuid': empUuid,
          'employee_id': code,
          'first_name': 'Ravi',
          'last_name': 'Test',
          'full_name': 'Ravi Test',
          'email': 'ravi.test@example.test',
          'department': 'QA',
          'designation': 'Analyst',
          'branch': 'North',
          'role': 'employee',
          'is_active': true,
          'status': 'active',
          'onboarding_status': 'complete',
          'documents': <Object>[],
          'profile': {'custom_field_values': <String, dynamic>{}},
        },
      });
    }
    if (o.method == 'GET' && path == '/api/assets/employees/$empUuid/') {
      listGets++;
      final gate = holdList;
      if (gate != null) await gate.future;
      if (listStatus != 200) return _err(listStatus, 'Server error. Please try again later.');
      if (me.id != empUuid && !_perm('assets.view')) {
        return _err(403, 'You do not have permission to view assets.');
      }
      return _json(200, {
        'status': 'success',
        'message': 'Employee assets retrieved.',
        'data': {'current': current, 'history': history},
      });
    }
    if (o.method == 'GET' && path == '/api/assets/') {
      return _json(200, {
        'status': 'success',
        'data': {'count': available.length, 'page': 1, 'results': available},
      });
    }
    if (o.method == 'POST' && path == '/api/assets/employees/$empUuid/assign/') {
      final body = Map<String, dynamic>.from(o.data as Map);
      posts.add((path, body));
      if (!_perm('assets.edit')) return _err(403, 'You do not have permission to assign assets.');
      if (body['asset'] == 'taken') return _err(409, '"AST-102" was just assigned to someone else.');
      final expected = body['expected_return_date'];
      if (expected is String && expected.compareTo(body['assigned_date'] as String) < 0) {
        return _err(400, 'Expected return date cannot be before the assigned date.');
      }
      final a = available.firstWhere((x) => x['id'] == body['asset']);
      available.remove(a);
      current = [...current, assignment('a9', a['asset_tag'] as String, a['asset_name'] as String)];
      return _json(201, {'status': 'success', 'message': 'Asset assigned successfully.', 'data': current.last});
    }
    final ret = RegExp(r'^/api/assets/assignments/([^/]+)/return/$').firstMatch(path);
    if (o.method == 'POST' && ret != null) {
      final body = Map<String, dynamic>.from(o.data as Map);
      posts.add((path, body));
      if (!_perm('assets.edit')) return _err(403, 'You do not have permission to return assets.');
      final row = current.where((x) => x['id'] == ret.group(1)).firstOrNull;
      if (row == null) return _err(404, 'Active assignment not found.');
      current = current.where((x) => x != row).toList();
      history = [
        ...history,
        {
          ...row,
          'status': 'returned',
          'status_display': 'Returned',
          'return_date': body['return_date'],
          'return_condition': body['return_condition'],
          'return_reason': body['return_reason'],
        },
      ];
      return _json(200, {'status': 'success', 'message': 'Asset returned successfully.', 'data': {}});
    }
    return _json(200, {'status': 'success', 'data': <Object>[]});
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

UserEntity user(List<String> perms, {String id = 'hr1', bool superuser = false, List<String>? modules}) => UserEntity(
      id: id,
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(['employees.view', 'employees.edit', 'assets.view', 'assets.edit']);
final viewer = user(['employees.view', 'assets.view']);
final noAssets = user(['employees.view']);

late Api api;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pumpProfile(WidgetTester tester, UserEntity as, {void Function(Api)? setup, bool openTab = true}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  api = Api(as);
  setup?.call(api);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = api),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Consumer(
          builder: (_, ref, child) {
            ref.watch(authStateProvider); // the signed-in user is loaded, as in the app
            return child!;
          },
          child: const EmployeeProfileScreen(employeeId: code)),
    ),
  ));
  await tester.pumpAndSettle();
  if (openTab) await openAssets(tester);
}

Future<void> openAssets(WidgetTester tester) async {
  final tab = find.text('Assets').first;
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String dropdownKey, String option) async {
  await tester.tap(byKey(dropdownKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

String? sheetError(WidgetTester tester) {
  final f = find.descendant(of: byKey('asset-sheet-error'), matching: find.byType(Text));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f.first).data;
}

List<String> tabLabels(WidgetTester tester) =>
    tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text ?? '').toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('user modules', () {
    test('enabled_modules is read from the login user and kept in the cache; missing = unknown', () {
      final u = UserModel.fromJson({
        'id': 'u1',
        'email': 'a@b.test',
        'permissions': <String>[],
        'enabled_modules': ['leave', 'assets', 7],
      });
      expect(u.enabledModules, ['leave', 'assets']);
      expect(u.hasModule('assets'), isTrue);
      expect(u.hasModule('payroll'), isFalse);
      expect(UserModel.fromJson(u.toJson()).enabledModules, ['leave', 'assets']);
      final old = UserModel.fromJson({'id': 'u1', 'email': 'a@b.test', 'permissions': <String>[]});
      expect(old.enabledModules, isNull);
      expect(old.hasModule('assets'), isTrue, reason: 'unknown list → shown (web hasModule)');
      expect(u.copyWith(onboardingStatus: 'complete').enabledModules, ['leave', 'assets']);
    });

    test('Assign/Return permission is web usePermission: superuser flag or assets.edit (settings.edit alone is not)',
        () {
      expect(canEditAssets(editor), isTrue);
      expect(canEditAssets(viewer), isFalse);
      expect(canEditAssets(user(const [], superuser: true)), isTrue);
      expect(canEditAssets(user(['settings.edit'])), isFalse);
      expect(canEditAssets(null), isFalse);
    });
  });

  group('tab', () {
    testWidgets('1/13. Assets sits between Promotion and Send Wishes; Benefit is gone; other tabs kept',
        (tester) async {
      await pumpProfile(tester, editor, openTab: false);
      expect(tabLabels(tester),
          ['Profile', 'Leave', 'Attendance', 'Approval Matrix', 'Promotion', 'Assets', 'Send Wishes']);
      expect(find.text('Benefit'), findsNothing);
      expect(find.textContaining('coming soon'), findsNothing);
      expect(api.listGets, 0, reason: 'nothing fetched until the tab is opened');
    });

    testWidgets('2. company without the assets module: no Assets tab, the rest unchanged', (tester) async {
      await pumpProfile(tester, user(editor.permissions, modules: ['leave', 'attendance']), openTab: false);
      expect(tabLabels(tester), ['Profile', 'Leave', 'Attendance', 'Approval Matrix', 'Promotion', 'Send Wishes']);
      final wishes = find.text('Send Wishes').first;
      await tester.ensureVisible(wishes);
      await tester.tap(wishes);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.calls.where((c) => c.uri.path.startsWith('/api/assets/')), isEmpty);
    });

    testWidgets('2. company with the module listed: shown', (tester) async {
      await pumpProfile(tester, user(editor.permissions, modules: ['assets']), openTab: false);
      expect(tabLabels(tester), contains('Assets'));
    });
  });

  group('list', () {
    testWidgets('5/11. current and returned assets from GET /assets/employees/<user uuid>/', (tester) async {
      await pumpProfile(tester, editor);
      expect(api.calls.where((c) => c.uri.path == '/api/assets/employees/$empUuid/'), hasLength(1),
          reason: 'by the user uuid, not the employee code');
      final cur = byKey('asset-current-a1');
      for (final t in ['Dell Latitude', 'AST-001', 'Laptop', 'SN-1', '05 Mar 2026', 'good', 'Assigned']) {
        expect(find.descendant(of: cur, matching: find.text(t)), findsOneWidget, reason: t);
      }
      final hist = byKey('asset-history-a0');
      for (final t in ['Old Phone', 'AST-000', '05 Mar 2026', '10 Jun 2026', 'fair', 'Upgrade']) {
        expect(find.descendant(of: hist, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(byKey('assets-assign'), findsOneWidget);
      expect(byKey('asset-return-a1'), findsOneWidget);
    });

    testWidgets('6. empty: web texts for both cards', (tester) async {
      await pumpProfile(tester, editor, setup: (a) {
        a.current = [];
        a.history = [];
      });
      expect(find.text('No assets assigned'), findsOneWidget);
      expect(find.text('Company equipment assigned to this employee will be listed here.'), findsOneWidget);
      expect(find.text('No returned assets yet'), findsOneWidget);
    });

    testWidgets('6. loading, then a failure with Retry; Retry loads it', (tester) async {
      await pumpProfile(tester, editor, openTab: false, setup: (a) => a.holdList = Completer());
      await openAssetsNoSettle(tester);
      expect(find.text('Loading assets…'), findsOneWidget);
      api.listStatus = 500;
      api.holdList!.complete();
      await tester.pumpAndSettle();
      expect(byKey('assets-error'), findsOneWidget);
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
      api.listStatus = 200;
      api.holdList = null;
      await tapKey(tester, 'assets-retry');
      expect(byKey('asset-current-a1'), findsOneWidget);
    });

    testWidgets('3. view-only (assets.view): list, but no Assign or Return', (tester) async {
      await pumpProfile(tester, viewer);
      expect(byKey('asset-current-a1'), findsOneWidget);
      expect(byKey('assets-assign'), findsNothing);
      expect(byKey('asset-return-a1'), findsNothing);
    });

    testWidgets('3/10. no assets.view and not themself: the server refusal is shown, no actions', (tester) async {
      await pumpProfile(tester, noAssets);
      expect(find.text('You do not have permission to view assets.'), findsOneWidget);
      expect(byKey('assets-assign'), findsNothing);
    });

    testWidgets('4. the employee themself (no asset permissions): their own assets load', (tester) async {
      await pumpProfile(tester, user(['employees.view'], id: empUuid));
      expect(byKey('asset-current-a1'), findsOneWidget);
      expect(byKey('assets-assign'), findsNothing);
    });

    testWidgets('3. superuser flag shows the actions; settings.edit alone does not', (tester) async {
      await pumpProfile(tester, user(['employees.view'], superuser: true));
      expect(byKey('assets-assign'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpProfile(tester, user(['employees.view', 'assets.view', 'settings.edit']));
      expect(byKey('asset-current-a1'), findsOneWidget);
      expect(byKey('assets-assign'), findsNothing);
    });
  });

  group('assign', () {
    testWidgets('7/12. assign: web payload, success banner, list refreshed', (tester) async {
      await pumpProfile(tester, editor);
      final gets = api.listGets;
      await tapKey(tester, 'assets-assign');
      expect(find.text('Assign Asset'), findsWidgets);
      await pick(tester, 'assign-asset', 'AST-101 — MacBook Air');
      await tapKey(tester, 'asset-sheet-submit');
      expect(api.posts.single.$1, '/api/assets/employees/$empUuid/assign/');
      expect(api.posts.single.$2, {
        'asset': 'av-1',
        'assigned_date': ymd(today),
        'condition_at_assignment': 'new',
        'expected_return_date': null,
        'remarks': '',
      });
      expect(find.text('Asset assigned successfully.'), findsOneWidget);
      expect(api.listGets, gets + 1);
      expect(find.text('MacBook Air'), findsOneWidget);
      // Web clears the banner after 5 s.
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Asset assigned successfully.'), findsNothing);
    });

    testWidgets('7. condition, expected return date and remarks are sent as chosen', (tester) async {
      await pumpProfile(tester, editor);
      await tapKey(tester, 'assets-assign');
      await pick(tester, 'assign-asset', 'AST-101 — MacBook Air');
      await pick(tester, 'assign-condition', 'Fair');
      await tester.tap(byKey('assign-expected-return'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('assign-remarks'), 'For the field team');
      await tapKey(tester, 'asset-sheet-submit');
      final body = api.posts.single.$2;
      expect((body['condition_at_assignment'], body['expected_return_date'], body['remarks']),
          ('fair', ymd(today), 'For the field team'));
    });

    testWidgets('7. no asset chosen: "Select an asset to assign." and nothing sent', (tester) async {
      await pumpProfile(tester, editor);
      await tapKey(tester, 'assets-assign');
      await tapKey(tester, 'asset-sheet-submit');
      expect(sheetError(tester), 'Select an asset to assign.');
      expect(api.posts, isEmpty);
      // Cleared assigned date: web's second check.
      await pick(tester, 'assign-asset', 'AST-101 — MacBook Air');
      await tester.tap(find.descendant(of: byKey('assign-date'), matching: find.byTooltip('Clear')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'asset-sheet-submit');
      expect(sheetError(tester), 'Assigned date is required.');
      expect(api.posts, isEmpty);
      await tapKey(tester, 'asset-sheet-cancel');
      expect(api.posts, isEmpty, reason: 'Cancel sends nothing');
    });

    testWidgets('7. nothing available: the web note', (tester) async {
      await pumpProfile(tester, editor, setup: (a) => a.available = []);
      await tapKey(tester, 'assets-assign');
      expect(find.text('No available assets in scope right now.'), findsOneWidget);
    });

    testWidgets('8. conflict (409): the server message, the form stays open, no refresh', (tester) async {
      await pumpProfile(tester, editor);
      final gets = api.listGets;
      await tapKey(tester, 'assets-assign');
      await pick(tester, 'assign-asset', 'AST-102 — Monitor');
      await tapKey(tester, 'asset-sheet-submit');
      expect(sheetError(tester), '"AST-102" was just assigned to someone else.');
      expect(byKey('asset-sheet-submit'), findsOneWidget);
      expect(api.listGets, gets);
    });

    testWidgets('10. the server refuses (no assets.edit after all): its message is shown', (tester) async {
      // A stale cached superuser flag: the UI offers Assign, the API says no.
      final stale = user(['employees.view', 'assets.view'], superuser: true);
      await pumpProfile(tester, stale);
      await tapKey(tester, 'assets-assign');
      await pick(tester, 'assign-asset', 'AST-101 — MacBook Air');
      // Make the server treat this user as lacking assets.edit.
      api.posts.clear();
      await tapKeyWithServerUser(tester, user(['employees.view', 'assets.view']));
      expect(sheetError(tester), 'You do not have permission to assign assets.');
    });
  });

  group('return', () {
    testWidgets('9/12. return: payload, banner, refreshed, moved to history', (tester) async {
      await pumpProfile(tester, editor);
      await tapKey(tester, 'asset-return-a1');
      expect(find.text('Return Asset — AST-001'), findsOneWidget);
      await pick(tester, 'return-condition', 'Damaged');
      await tester.enterText(byKey('return-reason'), 'Screen cracked');
      await tapKey(tester, 'asset-sheet-submit');
      expect(api.posts.single.$1, '/api/assets/assignments/a1/return/');
      expect(api.posts.single.$2,
          {'return_date': ymd(today), 'return_condition': 'damaged', 'return_reason': 'Screen cracked', 'remarks': ''});
      expect(find.text('Asset returned successfully.'), findsOneWidget);
      expect(byKey('asset-current-a1'), findsNothing);
      expect(byKey('asset-history-a1'), findsOneWidget);
      expect(find.text('No assets assigned'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('9. blank reason: "Return reason is required."; cleared date: "Return date is required."',
        (tester) async {
      await pumpProfile(tester, editor);
      await tapKey(tester, 'asset-return-a1');
      await tester.enterText(byKey('return-reason'), '   ');
      await tapKey(tester, 'asset-sheet-submit');
      expect(sheetError(tester), 'Return reason is required.');
      await tester.tap(find.descendant(of: byKey('return-date'), matching: find.byTooltip('Clear')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'asset-sheet-submit');
      expect(sheetError(tester), 'Return date is required.');
      expect(api.posts, isEmpty);
    });

    testWidgets('9. already returned elsewhere (404): the server message', (tester) async {
      await pumpProfile(tester, editor);
      await tapKey(tester, 'asset-return-a1');
      api.current = [];
      await tester.enterText(byKey('return-reason'), 'Offboarding');
      await tapKey(tester, 'asset-sheet-submit');
      expect(sheetError(tester), 'Active assignment not found.');
    });
  });
}

Future<void> openAssetsNoSettle(WidgetTester tester) async {
  final tab = find.text('Assets').first;
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Submits the open sheet while the stand-in server judges the request as
/// [serverUser] (the UI's cached user may be stale).
Future<void> tapKeyWithServerUser(WidgetTester tester, UserEntity serverUser) async {
  final server = Api(serverUser)
    ..current = api.current
    ..history = api.history
    ..available = api.available;
  final container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
  container.read(dioProvider).httpClientAdapter = server;
  api = server;
  await tapKey(tester, 'asset-sheet-submit');
}

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
import 'package:mobile_app/features/branches/data/datasources/branch_remote_datasource.dart';
import 'package:mobile_app/features/branches/data/models/branch_model.dart';
import 'package:mobile_app/features/branches/domain/branch_admin_leader.dart';
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_form_dialog.dart';
import 'package:mobile_app/features/settings/data/models/roles_model.dart';

// Task 44 (audit C-B04): Add Branch → "Assign Branch Admin (optional)" and
// the transfer counts, as web BranchManagement.tsx (LeaderFields,
// validateLeaders, handleSave's transfer check, doSave → applyLeaderRole).
// Backend contract (read-only reference): GET /roles/ (RoleSerializer:
// can_manage_branch, permissions = codenames); GET /employees/?page_size=50
// &status=active (items: id = employee code, uuid = user pk);
// GET /employees/?reporting_manager_id=<uuid>|hr_id=<uuid>&page_size=1 → count;
// PUT /employees/<code>/ {role: <name>, branch}; POST /employees/
// {first_name, last_name, email, role: <id>, designation, branch,
// date_of_joining}. A stand-in server; fictitious data; nothing real changes.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> role(int id, String name, {bool branch = false, List<String> perms = const []}) => {
      'id': id,
      'name': name,
      'display_name': name,
      'can_manage_branch': branch,
      'can_manage_team': false,
      'permissions': perms,
      'is_active': true,
    };

Map<String, dynamic> emp(String code, String name, String email, String branch, {String role = 'employee'}) => {
      'id': code,
      'uuid': 'uuid-$code',
      'employee_id': code,
      'full_name': name,
      'email': email,
      'branch': branch,
      'role': role,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> roles = [
    role(1, 'system_admin', branch: true, perms: ['settings.edit', 'employees.view']), // company-wide: never used
    role(2, 'employee'),
    role(3, 'branch_admin', branch: true, perms: ['employees.view']),
  ];
  List<Map<String, dynamic>> employees = [
    emp('EMP-1', 'Asha Rao', 'asha@example.test', 'North'),
    emp('EMP-2', 'Bilal Khan', 'bilal@example.test', ''),
    emp('ADM-1', 'Sys Admin', 'sys@example.test', '', role: 'system_admin'),
  ];
  Map<String, int> reportsBy = {'uuid-EMP-1': 3};
  Map<String, int> hrFor = {'uuid-EMP-1': 1};
  int? rolesStatus;
  int? employeesStatus;
  bool countsFail = false;
  ({int status, String message})? refuseBranch;
  ({int status, String message})? refuseLeader;
  Completer<void>? holdCounts;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  Iterable<({String method, String path, Map<String, dynamic> query, Object? body})> of(String m, String p) =>
      calls.where((c) => c.method == m && c.path == p);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    final q = o.queryParameters;
    switch ((o.method, o.path)) {
      case ('GET', '/branch/states/'):
        return _json(200, {
          'status': 'success',
          'data': [
            {'id': 1, 'name': 'Test State', 'code': 'TS'}
          ]
        });
      case ('GET', '/branch/states/1/cities/'):
        return _json(200, {
          'status': 'success',
          'data': [
            {'id': 5, 'name': 'Test City', 'state': 1, 'state_name': 'Test State'}
          ]
        });
      case ('GET', '/branch/branches/preview-code/'):
        return _json(200, {
          'status': 'success',
          'data': {'branch_code': 'TC-001'}
        });
      case ('GET', '/branch/branches/'):
        return _json(200, {
          'status': 'success',
          'data': {'count': 0, 'results': []}
        });
      case ('POST', '/branch/branches/'):
        final r = refuseBranch;
        if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
        final b = Map<String, dynamic>.from(o.data as Map);
        return _json(201, {
          'status': 'success',
          'data': {
            'id': 9,
            'branch_code': 'TC-001',
            'branch_name': b['branch_name'],
            'address': b['address'],
            'state': 1,
            'state_name': 'Test State',
            'city': 5,
            'city_name': 'Test City',
            'status': 'active',
            'is_headquarter': false,
            'employees_count': 0,
          }
        });
      case ('GET', '/roles/'):
        if (rolesStatus != null) return _json(rolesStatus!, {'status': 'error', 'message': 'x', 'data': {}});
        return _json(200, {
          'status': 'success',
          'data': {'count': roles.length, 'results': roles}
        });
      case ('GET', '/employees/'):
        if (q.containsKey('reporting_manager_id') || q.containsKey('hr_id')) {
          if (holdCounts != null) await holdCounts!.future;
          if (countsFail) return _json(500, {'status': 'error', 'message': 'boom', 'data': {}});
          final n =
              q.containsKey('hr_id') ? hrFor['${q['hr_id']}'] ?? 0 : reportsBy['${q['reporting_manager_id']}'] ?? 0;
          return _json(200, {
            'status': 'success',
            'data': {'count': n, 'results': []}
          });
        }
        if (employeesStatus != null) return _json(employeesStatus!, {'status': 'error', 'message': 'x', 'data': {}});
        return _json(200, {
          'status': 'success',
          'data': {'count': employees.length, 'results': employees}
        });
      case ('POST', '/employees/'):
      case ('PUT', _) when o.path.startsWith('/employees/'):
        final r = refuseLeader;
        if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
        return _json(o.method == 'POST' ? 201 : 200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    return _json(200, {'status': 'success', 'data': <String, dynamic>{}});
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
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final admin = user(['settings.view', 'settings.edit', 'branches.create', 'employees.view']);
final viewer = user(['settings.view', 'branches.view']);

late Server server;
Finder byKey(String k) => find.byKey(Key(k));
Dio _dio(Server s) => Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s;

Future<void> pumpAdd(WidgetTester tester, {Server? with_, UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? admin)),
      dioProvider.overrideWithValue(_dio(server)),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
          return TextButton(
            key: const Key('open-add'),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Dialog(child: BranchFormDialog()),
            ),
            child: const Text('Add'),
          );
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(byKey('open-add'));
  await tester.pumpAndSettle();
}

Future<void> fillBranch(WidgetTester tester, {String name = 'Test Branch'}) async {
  await tester.tap(find.text('Select state'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test State').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select city'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test City').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), name);
  await tester.enterText(find.widgetWithText(TextFormField, 'Address *'), '1 Test Road');
  await tester.pump();
}

Future<void> useExisting(WidgetTester tester) async {
  await tester.ensureVisible(byKey('branch-leader-existing-toggle'));
  await tester.tap(byKey('branch-leader-existing-toggle'));
  await tester.pumpAndSettle();
}

Future<void> pickEmployee(WidgetTester tester, String label) async {
  final f = find
      .byWidgetPredicate((w) => w is DropdownButtonFormField<String> && '${w.key}'.contains('branch-leader-employee'));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(byKey('branch-form-submit'));
  await tester.tap(byKey('branch-form-submit'));
  await tester.pumpAndSettle();
}

String? errorOf(WidgetTester tester, String key) => tester.widget<TextField>(byKey(key)).decoration!.errorText;

List<String> pickerItems(WidgetTester tester) => tester
    .widget<DropdownButton<String>>(find.descendant(
        of: find.byWidgetPredicate(
            (w) => w is DropdownButtonFormField<String> && '${w.key}'.contains('branch-leader-employee')),
        matching: find.byType(DropdownButton<String>)))
    .items!
    .map((i) => (i.child as Text).data!)
    .toList();

Map<String, dynamic> bodyOf(Object? b) => Map<String, dynamic>.from(b as Map);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules', () {
    RoleModel r(Map<String, dynamic> j) => RoleModel.fromJson(j);

    test('isActive and validation: untouched row skipped; web messages', () {
      const blank = BranchLeaderForm();
      expect(blank.isActive, isFalse, reason: 'designation is pre-filled but does not count');
      expect(validateBranchLeader(blank), isEmpty);
      expect(validateBranchLeader(blank.copyWith(name: 'A')), {'email': 'Email is required.'});
      expect(validateBranchLeader(blank.copyWith(email: 'bad', designation: ' ')), {
        'name': 'Name is required.',
        'email': 'Enter a valid email.',
        'designation': 'Designation is required.',
      });
      expect(validateBranchLeader(blank.copyWith(name: 'A B', email: 'a.b@example.test')), isEmpty);
      const ex = BranchLeaderForm(mode: BranchLeaderMode.existing);
      expect(ex.isActive, isFalse);
      expect(validateBranchLeader(ex), isEmpty);
      expect(ex.copyWith(employeeCode: 'EMP-1').isActive, isTrue);
    });

    test('Branch Admin role by capability, never a settings.edit role', () {
      final s = Server();
      final roles = s.roles.map(r).toList();
      expect(branchAdminRole(roles)!.name, 'branch_admin');
      expect(
          branchAdminRole([
            r(role(1, 'system_admin', branch: true, perms: ['settings.edit']))
          ]),
          isNull);
      expect(branchAdminRole([r(role(2, 'employee'))]), isNull);
    });

    test('payloads: invite (single-word name keeps a blank last name) and transfer', () {
      final ba = RoleModel.fromJson(role(3, 'branch_admin', branch: true));
      final today = DateTime(2026, 11, 11);
      expect(
          newBranchAdminPayload(
              const BranchLeaderForm(
                  name: '  Asha  Rao Iyer ', email: ' asha@example.test ', designation: ' Branch Manager '),
              ba,
              'Test Branch',
              today),
          {
            'first_name': 'Asha',
            'last_name': 'Rao Iyer',
            'email': 'asha@example.test',
            'role': 3,
            'designation': 'Branch Manager',
            'branch': 'Test Branch',
            'date_of_joining': '2026-11-11',
          });
      expect(
          newBranchAdminPayload(const BranchLeaderForm(name: 'Asha', email: 'a@x.test'), ba, 'B', today)['last_name'],
          '');
      expect(existingBranchAdminPayload(ba, 'Test Branch'), {'role': 'branch_admin', 'branch': 'Test Branch'});
    });

    test('search by name, email or employee ID; transfer texts', () {
      final all = Server().employees.map(BranchAdminCandidate.fromJson).toList();
      expect(filterBranchLeaderCandidates(all, 'asha').map((e) => e.code), ['EMP-1']);
      expect(filterBranchLeaderCandidates(all, 'BILAL@').map((e) => e.code), ['EMP-2']);
      expect(filterBranchLeaderCandidates(all, 'emp-2').map((e) => e.code), ['EMP-2']);
      expect(filterBranchLeaderCandidates(all, ' ').length, 3);
      expect(transferConfirmBody(all[1]),
          'Bilal Khan currently belongs to no branch. This will move them to the new branch and change their role to Branch Admin.');
      expect(reportsWarning(0), isNull);
      expect(reportsWarning(1), contains('manage 1 employee —'));
      expect(hrForWarning(2), contains('HR for 2 employees —'));
    });

    test('data source: candidates without system admins (uuid kept); counts by uuid', () async {
      final s = Server();
      final ds = BranchRemoteDataSource(_dio(s));
      final c = await ds.fetchBranchLeaderCandidates();
      expect(c.map((e) => (e.code, e.uuid)), [('EMP-1', 'uuid-EMP-1'), ('EMP-2', 'uuid-EMP-2')]);
      expect(s.of('GET', '/employees/').first.query, {'page_size': 50, 'status': 'active'});
      expect(await branchLeaderTransferCounts(ds, 'uuid-EMP-1'), (reports: 3, hrFor: 1));
      final countQs = s.calls.where((x) => x.query.containsKey('reporting_manager_id') || x.query.containsKey('hr_id'));
      expect(countQs.map((x) => x.query), [
        {'reporting_manager_id': 'uuid-EMP-1', 'page_size': 1},
        {'hr_id': 'uuid-EMP-1', 'page_size': 1},
      ]);
      s.countsFail = true;
      expect(await branchLeaderTransferCounts(ds, 'uuid-EMP-1'), (reports: 0, hrFor: 0), reason: 'never blocks');
      expect((await ds.fetchRolesForBranchAdmin()).length, 3);
      expect(s.of('GET', '/roles/').single.query, {'page_size': 100});
    });
  });

  group('Add Branch form', () {
    testWidgets('1. section shown on Add with web defaults; existing-employee switch offered', (tester) async {
      await pumpAdd(tester);
      expect(find.text('Branch Admin'), findsOneWidget);
      expect(byKey('branch-leader-section'), findsOneWidget);
      expect(tester.widget<TextField>(byKey('branch-leader-designation')).controller!.text, 'Branch Manager');
      expect(find.text('Assign an existing employee instead'), findsOneWidget);
      await useExisting(tester);
      expect(
          pickerItems(tester),
          [
            '— Select employee —',
            'Asha Rao (EMP-1) — North',
            'Bilal Khan (EMP-2) — no branch',
          ],
          reason: 'system admin never offered');
    });

    testWidgets('2. untouched section: only the branch is created, no admin calls', (tester) async {
      await pumpAdd(tester);
      await fillBranch(tester);
      await submit(tester);
      expect(server.of('POST', '/branch/branches/'), hasLength(1));
      expect(server.of('POST', '/employees/'), isEmpty);
      expect(server.calls.where((c) => c.method == 'PUT'), isEmpty);
      expect(byKey('branch-leader-result'), findsNothing);
    });

    testWidgets('3. new person: validation first (nothing sent); then invite with web payload and message',
        (tester) async {
      await pumpAdd(tester);
      await fillBranch(tester);
      await tester.enterText(byKey('branch-leader-name'), 'Nia');
      await tester.enterText(byKey('branch-leader-email'), 'not-an-email');
      await tester.pump();
      await submit(tester);
      expect(errorOf(tester, 'branch-leader-email'), 'Enter a valid email.');
      expect(server.of('POST', '/branch/branches/'), isEmpty, reason: 'branch not created while the row is invalid');
      await tester.enterText(byKey('branch-leader-email'), 'nia@example.test');
      await tester.pump();
      await submit(tester);
      expect(server.of('POST', '/branch/branches/'), hasLength(1));
      final body = bodyOf(server.of('POST', '/employees/').single.body);
      expect(body['first_name'], 'Nia');
      expect(body['last_name'], '');
      expect(body['email'], 'nia@example.test');
      expect(body['role'], 3);
      expect(body['designation'], 'Branch Manager');
      expect(body['branch'], 'Test Branch');
      expect(
          body.keys.toSet(), {'first_name', 'last_name', 'email', 'role', 'designation', 'branch', 'date_of_joining'});
      expect(find.text('Test Branch was created and its Branch Admin was invited by email.'), findsOneWidget);
    });

    testWidgets('4. existing employee: counts looked up by uuid, confirm with warnings, then PUT role + branch',
        (tester) async {
      await pumpAdd(tester);
      await fillBranch(tester);
      await useExisting(tester);
      await pickEmployee(tester, 'Asha Rao (EMP-1) — North');
      await submit(tester);
      expect(byKey('branch-transfer-confirm'), findsOneWidget);
      expect(find.text('Move Asha Rao?'), findsOneWidget);
      expect(tester.widget<Text>(byKey('branch-transfer-body')).data,
          'Asha Rao currently belongs to North. This will move them to the new branch and change their role to Branch Admin.');
      expect(find.textContaining('They currently manage 3 employees'), findsOneWidget);
      expect(find.textContaining("They're the assigned HR for 1 employee —"), findsOneWidget);
      expect(server.of('POST', '/branch/branches/'), isEmpty, reason: 'nothing created before the confirm');
      await tester.tap(byKey('branch-transfer-confirm-yes'));
      await tester.pumpAndSettle();
      expect(server.of('POST', '/branch/branches/'), hasLength(1));
      final put = server.calls.where((c) => c.method == 'PUT').single;
      expect(put.path, '/employees/EMP-1/');
      expect(bodyOf(put.body), {'role': 'branch_admin', 'branch': 'Test Branch'});
      expect(find.text('Test Branch was created and its Branch Admin was assigned.'), findsOneWidget);
    });

    testWidgets('5. no counts: no warning box; Cancel keeps every entered value and sends nothing', (tester) async {
      await pumpAdd(tester);
      await fillBranch(tester, name: 'Kept Branch');
      await useExisting(tester);
      await pickEmployee(tester, 'Bilal Khan (EMP-2) — no branch');
      await submit(tester);
      expect(byKey('branch-transfer-warning'), findsNothing);
      await tester.tap(byKey('branch-transfer-cancel'));
      await tester.pumpAndSettle();
      expect(server.of('POST', '/branch/branches/'), isEmpty);
      expect(find.byType(BranchFormDialog), findsOneWidget);
      expect(find.text('Kept Branch'), findsOneWidget);
      expect(pickerItems(tester), contains('Bilal Khan (EMP-2) — no branch'));
      final picker = tester.widget<DropdownButtonFormField<String>>(find.byWidgetPredicate(
          (w) => w is DropdownButtonFormField<String> && '${w.key}'.contains('branch-leader-employee')));
      expect(picker.initialValue, 'EMP-2');
    });

    testWidgets('6. checking state while counts load; a failed check still confirms (0, 0)', (tester) async {
      final s = Server()
        ..holdCounts = Completer<void>()
        ..countsFail = true;
      await pumpAdd(tester, with_: s);
      await fillBranch(tester);
      await useExisting(tester);
      await pickEmployee(tester, 'Asha Rao (EMP-1) — North');
      await tester.ensureVisible(byKey('branch-form-submit'));
      await tester.tap(byKey('branch-form-submit'));
      await tester.pump();
      expect(find.text('Checking…'), findsOneWidget);
      s.holdCounts!.complete();
      await tester.pumpAndSettle();
      expect(byKey('branch-transfer-confirm'), findsOneWidget);
      expect(byKey('branch-transfer-warning'), findsNothing);
    });

    testWidgets('7. existing mode with nobody picked: the row is untouched, branch alone is created', (tester) async {
      await pumpAdd(tester);
      await fillBranch(tester);
      await useExisting(tester);
      await submit(tester);
      expect(server.of('POST', '/branch/branches/'), hasLength(1));
      expect(server.calls.where((c) => c.method == 'PUT'), isEmpty);
      expect(byKey('branch-transfer-confirm'), findsNothing);
    });

    testWidgets('8. entered admin values survive switching modes and a branch save error', (tester) async {
      final s = Server()..refuseBranch = (status: 400, message: 'branch_name: Branch already exists.');
      await pumpAdd(tester, with_: s);
      await fillBranch(tester);
      await tester.enterText(byKey('branch-leader-name'), 'Nia Test');
      await tester.enterText(byKey('branch-leader-email'), 'nia@example.test');
      await tester.pump();
      await useExisting(tester);
      await useExisting(tester); // back to "new person"
      expect(tester.widget<TextField>(byKey('branch-leader-name')).controller!.text, 'Nia Test');
      await submit(tester);
      expect(find.text('branch_name: Branch already exists.'), findsOneWidget);
      expect(s.of('POST', '/employees/'), isEmpty, reason: 'admin step only after the branch exists');
      expect(tester.widget<TextField>(byKey('branch-leader-email')).controller!.text, 'nia@example.test');
      s.refuseBranch = null;
      await submit(tester);
      expect(s.of('POST', '/employees/'), hasLength(1));
    });

    testWidgets('9. assignment refused by the server: branch kept, web warning with the server message',
        (tester) async {
      final s = Server()..refuseLeader = (status: 400, message: 'A user with this email already exists.');
      await pumpAdd(tester, with_: s);
      await fillBranch(tester);
      await tester.enterText(byKey('branch-leader-name'), 'Nia Test');
      await tester.enterText(byKey('branch-leader-email'), 'nia@example.test');
      await tester.pump();
      await submit(tester);
      expect(s.of('POST', '/branch/branches/'), hasLength(1));
      expect(find.byType(BranchFormDialog), findsNothing);
      expect(
          find.text('Test Branch was created, but assigning its Branch Admin failed: A user with this email already '
              'exists. — use the Employees page instead.'),
          findsOneWidget);
    });

    testWidgets('10. no Branch Admin role (or roles failed to load): web\'s message, nothing sent', (tester) async {
      final s = Server()..rolesStatus = 500;
      await pumpAdd(tester, with_: s);
      await fillBranch(tester);
      await tester.enterText(byKey('branch-leader-name'), 'Nia Test');
      await tester.enterText(byKey('branch-leader-email'), 'nia@example.test');
      await tester.pump();
      await submit(tester);
      expect(s.of('POST', '/employees/'), isEmpty);
      expect(find.textContaining('No Branch Admin role is set up for this company yet.'), findsOneWidget);
    });

    testWidgets('11. employee list unavailable (e.g. no employees.view): no existing-employee switch', (tester) async {
      await pumpAdd(tester, with_: Server()..employeesStatus = 403);
      expect(byKey('branch-leader-existing-toggle'), findsNothing);
      expect(byKey('branch-leader-name'), findsOneWidget);
    });

    testWidgets('12. Edit Branch has no Assign Branch Admin section (web: add only)', (tester) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server();
      final b = BranchModel.fromJson(const {
        'id': 4,
        'branch_code': 'TC-004',
        'branch_name': 'Existing',
        'address': 'x',
        'state': 1,
        'state_name': 'Test State',
        'city': 5,
        'city_name': 'Test City',
        'status': 'active',
        'is_headquarter': false,
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(admin)),
          dioProvider.overrideWithValue(_dio(server)),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: MaterialApp(home: Scaffold(body: Dialog(child: BranchFormDialog(branch: b)))),
      ));
      await tester.pumpAndSettle();
      expect(byKey('branch-leader-section'), findsNothing);
      expect(server.of('GET', '/roles/'), isEmpty);
    });

    test('13. without settings.edit the branch create itself is refused before any request', () async {
      final s = Server();
      final c = ProviderContainer(overrides: [
        authStateProvider.overrideWith(() => _Auth(viewer)),
        dioProvider.overrideWithValue(_dio(s)),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_NullStorage()),
      ]);
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final r = await c
          .read(branchListProvider.notifier)
          .create(cityId: 5, stateId: 1, branchName: 'X', address: 'A', status: 'active', isHeadquarter: false);
      expect(r, kBranchEditDenied);
      expect(s.of('POST', '/branch/branches/'), isEmpty);
    });
  });
}

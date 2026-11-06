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
import 'package:mobile_app/features/branches/data/models/branch_model.dart';
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_details_sheet.dart';

// P2: Branch Management → View branch → Branch Admin, as web
// BranchManagement.tsx (openReassign / doReassign) over production
// BranchReassignAdminView (POST /branch/branches/<pk>/reassign-admin/
// {employee_id: <employee code>}, branches.edit + branch scope; inactive,
// onboarding-incomplete, Company Admin, same admin, or admin of another active
// branch are refused). Stand-in server, synthetic employees; nothing is sent anywhere.

Map<String, dynamic> branch(int id, String name, {String? admin, String? adminEmail}) => {
      'id': id,
      'branch_code': 'BR-00$id',
      'branch_name': name,
      'address': '1 Test Road',
      'state': 1,
      'state_name': 'Test State',
      'city': 1,
      'city_name': 'Test City',
      'hr': admin == null ? null : 'pk-$id',
      'hr_name': admin,
      'hr_email': adminEmail,
      'employees_count': 4,
      'status': 'active',
      'is_headquarter': false,
    };

Map<String, dynamic> emp(String code, String name, {String role = 'employee', String branch = 'North'}) => {
      'id': code,
      'uuid': 'uuid-$code',
      'employee_id': code,
      'full_name': name,
      'email': '${code.toLowerCase()}@example.test',
      'branch': branch,
      'role': role,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> branches = [
    branch(1, 'North', admin: 'Asha Rao', adminEmail: 'tst001@example.test'),
    branch(2, 'South'),
  ];
  List<Map<String, dynamic>> employees = [
    emp('TST001', 'Asha Rao', role: 'branch_admin'),
    emp('TST002', 'Ravi Menon'),
    emp('TST003', 'Neha Iyer', branch: ''),
    emp('ADM001', 'Root Admin', role: 'system_admin'),
  ];
  int employeesStatus = 200;
  Completer<void>? holdEmployees;
  Completer<void>? holdPost;
  ({int status, String message})? refuseNext;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  List<({String method, String path, Map<String, dynamic> query, Object? body})> of(String m, String p) =>
      calls.where((c) => c.method == m && c.path == p).toList();
  int get writes => calls.where((c) => c.method != 'GET').length;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    if (o.method == 'GET' && o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {'count': branches.length, 'results': branches}
      });
    }
    if (o.method == 'GET' && o.path == ApiConstants.employees) {
      if (holdEmployees != null) await holdEmployees!.future;
      if (employeesStatus != 200) return _json({'status': 'error', 'message': 'Nope'}, employeesStatus);
      return _json({
        'status': 'success',
        'data': {'count': employees.length, 'results': employees}
      });
    }
    if (o.method == 'POST' && o.path.endsWith('/reassign-admin/')) {
      if (holdPost != null) await holdPost!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message}, r.status);
      }
      final id = int.parse(o.path.split('/').where((p) => p.isNotEmpty).elementAt(2));
      final code = (o.data as Map)['employee_id'] as String;
      final e = employees.firstWhere((x) => x['id'] == code);
      branches = [
        for (final b in branches)
          b['id'] == id ? {...b, 'hr': 'pk-$code', 'hr_name': e['full_name'], 'hr_email': e['email']} : b
      ];
      final updated = branches.firstWhere((b) => b['id'] == id);
      return _json({
        'status': 'success',
        'message': 'Branch Admin for "${updated['branch_name']}" reassigned to ${e['full_name']}.',
        'data': updated,
      });
    }
    return _json({'status': 'success', 'data': {}});
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final admin = user(['settings.view', 'settings.edit', 'branches.view', 'branches.edit']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

/// A list that stays alive (so refreshes are observable) with a "View" per
/// branch opening the real details sheet.
Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? admin),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
          final list = ref.watch(branchListProvider).valueOrNull ?? const [];
          return ListView(children: [
            for (final b in list)
              ListTile(
                key: Key('open-${b.id}'),
                title: Text('${b.branchName} · ${b.hrName ?? 'none'}'),
                onTap: () => showBranchDetailsSheet(context, b),
              ),
          ]);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k));
  await tester.tap(byKey(k));
  await tester.pumpAndSettle();
}

Future<void> openDetails(WidgetTester tester, int id) async {
  await tapKey(tester, 'open-$id');
  await tester.ensureVisible(byKey('branch-admin-section'));
  await tester.pumpAndSettle();
}

String confirmText(WidgetTester tester) => tester
    .widget<RichText>(find.descendant(of: byKey('reassign-confirm-text'), matching: find.byType(RichText)))
    .text
    .toPlainText();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('models and rules', () {
    test('branch reads the admin name and email', () {
      final b = BranchModel.fromJson(branch(1, 'North', admin: 'Asha Rao', adminEmail: 'a@example.test'));
      expect([b.hrName, b.hrEmail, b.hasHr], ['Asha Rao', 'a@example.test', true]);
      final none = BranchModel.fromJson(branch(2, 'South'));
      expect([none.hrName, none.hrEmail, none.hasHr], [null, null, false]);
    });

    test('candidates: id is the employee code; label and search as web', () {
      final c = BranchAdminCandidate.fromJson(emp('TST003', 'Neha Iyer', branch: ''));
      expect(c.code, 'TST003');
      expect(c.label, 'Neha Iyer (TST003) — no branch');
      expect(c.matches('neha'), isTrue);
      expect(c.matches('tst003@'), isTrue);
      expect(c.matches('TST00'), isTrue);
      expect(c.matches('zzz'), isFalse);
      expect(c.matches(''), isTrue);
    });

    test('permission: settings.edit (web) and branches.edit (server) are both needed', () {
      expect(canReassignBranchAdmin(admin), isTrue);
      expect(canReassignBranchAdmin(user(['settings.edit'])), isFalse);
      expect(canReassignBranchAdmin(user(['branches.edit'])), isFalse);
      expect(canReassignBranchAdmin(user([], superuser: true)), isTrue);
      expect(canReassignBranchAdmin(null), isFalse);
    });

    test('the provider refuses without permission or without an employee, before any request', () async {
      for (final u in [
        user(['settings.edit', 'branches.view']),
        user(['branches.edit'])
      ]) {
        server = Server();
        final c = ProviderContainer(overrides: overrides(u));
        addTearDown(c.dispose);
        await c.read(authStateProvider.future);
        await c.read(branchListProvider.future);
        expect(await c.read(branchListProvider.notifier).reassignAdmin(1, 'TST002'), kBranchEditDenied);
        expect(server.writes, 0);
      }
      server = Server();
      final c = ProviderContainer(overrides: overrides(admin));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      expect(await c.read(branchListProvider.notifier).reassignAdmin(1, ' '), 'employee_id is required.');
      expect(server.writes, 0);
    });

    test('one reassignment at a time', () async {
      server = Server()..holdPost = Completer();
      final c = ProviderContainer(overrides: overrides(admin));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      await c.read(branchListProvider.future);
      final n = c.read(branchListProvider.notifier);
      final first = n.reassignAdmin(1, 'TST002');
      await Future<void>.delayed(Duration.zero);
      expect(await n.reassignAdmin(2, 'TST003'), isNotNull);
      server.holdPost!.complete();
      expect(await first, isNull);
      expect(server.of('POST', ApiConstants.branchReassignAdmin(1)), hasLength(1));
      expect(server.writes, 1);
    });
  });

  group('details sheet', () {
    testWidgets('shows the current admin (name + email) and "Change Branch Admin"', (tester) async {
      await pump(tester);
      await openDetails(tester, 1);
      expect(tester.widget<Text>(byKey('branch-admin-name')).data, 'Asha Rao');
      expect(tester.widget<Text>(byKey('branch-admin-email')).data, 'tst001@example.test');
      expect(find.text('Change Branch Admin'), findsOneWidget);
      expect(find.text('HR Manager'), findsNothing);
    });

    testWidgets('no admin: "No Branch Admin assigned" and "Assign Branch Admin"', (tester) async {
      await pump(tester);
      await openDetails(tester, 2);
      expect(byKey('branch-admin-none'), findsOneWidget);
      expect(find.text('Assign Branch Admin'), findsOneWidget);
    });

    testWidgets('without the permission: admin shown, no Change/Assign; other details unchanged', (tester) async {
      await pump(tester, as: user(['settings.view', 'branches.view']));
      await openDetails(tester, 1);
      expect(tester.widget<Text>(byKey('branch-admin-name')).data, 'Asha Rao');
      expect(byKey('branch-admin-reassign'), findsNothing);
      expect(find.text('Branch Code'), findsOneWidget);
      expect(find.text('Employees'), findsOneWidget);
    });
  });

  group('reassignment', () {
    testWidgets('candidates: active only (status=active, page_size=50), no system admin, not the current admin',
        (tester) async {
      await pump(tester);
      await openDetails(tester, 1);
      await tapKey(tester, 'branch-admin-reassign');
      expect(server.of('GET', ApiConstants.employees).single.query, {'page_size': 50, 'status': 'active'});
      expect(find.text('Change Branch Admin — North'), findsOneWidget);
      expect(byKey('reassign-option-TST002'), findsOneWidget);
      expect(find.text('Neha Iyer (TST003) — no branch'), findsOneWidget);
      expect(byKey('reassign-option-TST001'), findsNothing); // current admin
      expect(byKey('reassign-option-ADM001'), findsNothing); // system_admin
      expect(tester.widget<FilledButton>(byKey('reassign-continue')).onPressed, isNull);
      await tester.enterText(byKey('reassign-search'), 'neha');
      await tester.pump();
      expect(byKey('reassign-option-TST002'), findsNothing);
      expect(byKey('reassign-option-TST003'), findsOneWidget);
    });

    testWidgets('change: pick → confirm (web wording) → POST {employee_id: code}; sheets close, list refreshes',
        (tester) async {
      await pump(tester);
      await openDetails(tester, 1);
      await tapKey(tester, 'branch-admin-reassign');
      await tapKey(tester, 'reassign-option-TST002');
      await tapKey(tester, 'reassign-continue');
      expect(find.text('Confirm Reassignment'), findsOneWidget);
      expect(
          confirmText(tester),
          'This will remove Branch Admin access from Asha Rao (their attendance, leave, payroll, and other '
          'historical records will not be affected) and assign it to Ravi Menon for North.');
      expect(server.writes, 0);
      final listGets = server.of('GET', ApiConstants.branches).length;
      await tapKey(tester, 'reassign-confirm');
      final post = server.of('POST', ApiConstants.branchReassignAdmin(1)).single;
      expect(post.body, {'employee_id': 'TST002'});
      expect(byKey('reassign-sheet'), findsNothing);
      expect(byKey('branch-admin-section'), findsNothing); // details closed, as web closes the View modal
      expect(find.text('Branch Admin for North was reassigned successfully.'), findsOneWidget);
      expect(server.of('GET', ApiConstants.branches).length, greaterThan(listGets));
      expect(find.text('North · Ravi Menon'), findsOneWidget);
    });

    testWidgets('assign (no current admin): web\'s assign wording', (tester) async {
      await pump(tester);
      await openDetails(tester, 2);
      await tapKey(tester, 'branch-admin-reassign');
      await tapKey(tester, 'reassign-option-TST003');
      await tapKey(tester, 'reassign-continue');
      expect(confirmText(tester), 'This will assign Neha Iyer as Branch Admin for South.');
      await tapKey(tester, 'reassign-confirm');
      expect(server.of('POST', ApiConstants.branchReassignAdmin(2)).single.body, {'employee_id': 'TST003'});
    });

    testWidgets('Back returns to the list; Cancel sends nothing', (tester) async {
      await pump(tester);
      await openDetails(tester, 1);
      await tapKey(tester, 'branch-admin-reassign');
      await tapKey(tester, 'reassign-option-TST002');
      await tapKey(tester, 'reassign-continue');
      await tapKey(tester, 'reassign-back');
      expect(byKey('reassign-search'), findsOneWidget);
      await tapKey(tester, 'reassign-cancel');
      expect(byKey('reassign-sheet'), findsNothing);
      expect(byKey('branch-admin-section'), findsOneWidget);
      expect(server.writes, 0);
    });

    testWidgets('a server refusal (eligibility) is shown and nothing closes or refreshes', (tester) async {
      await pump(tester,
          setup: (s) => s.refuseNext = (
                status: 400,
                message: 'Ravi Menon has not completed onboarding yet and cannot be assigned as Branch Admin.'
              ));
      await openDetails(tester, 1);
      await tapKey(tester, 'branch-admin-reassign');
      await tapKey(tester, 'reassign-option-TST002');
      await tapKey(tester, 'reassign-continue');
      final listGets = server.of('GET', ApiConstants.branches).length;
      await tapKey(tester, 'reassign-confirm');
      expect(
          find.descendant(of: byKey('reassign-error'), matching: find.textContaining('has not completed onboarding')),
          findsOneWidget);
      expect(byKey('reassign-sheet'), findsOneWidget);
      expect(server.of('GET', ApiConstants.branches).length, listGets);
      server.refuseNext = (status: 403, message: 'You do not have permission to perform this action.');
      await tapKey(tester, 'reassign-confirm');
      expect(find.text('You do not have permission to perform this action.'), findsOneWidget);
    });

    testWidgets('loading, then the empty message; a failed list load also shows it (web)', (tester) async {
      final gate = Completer<void>();
      await pump(tester, setup: (s) {
        s.holdEmployees = gate;
        s.employees = [emp('ADM001', 'Root Admin', role: 'system_admin')];
      });
      await openDetails(tester, 1);
      await tester.tap(byKey('branch-admin-reassign'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(byKey('reassign-loading'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('No eligible employees found.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, setup: (s) => s.employeesStatus = 500);
      await openDetails(tester, 1);
      await tapKey(tester, 'branch-admin-reassign');
      expect(byKey('reassign-empty'), findsOneWidget);
    });

    testWidgets('double-tapping "Yes, Reassign" sends one request; Reassigning… and Back disabled', (tester) async {
      await pump(tester, setup: (s) => s.holdPost = Completer());
      await openDetails(tester, 1);
      await tapKey(tester, 'branch-admin-reassign');
      await tapKey(tester, 'reassign-option-TST002');
      await tapKey(tester, 'reassign-continue');
      await tester.tap(byKey('reassign-confirm'));
      await tester.pump();
      expect(find.text('Reassigning…'), findsOneWidget);
      expect(tester.widget<FilledButton>(byKey('reassign-confirm')).onPressed, isNull);
      expect(tester.widget<TextButton>(byKey('reassign-back')).onPressed, isNull);
      await tester.tap(byKey('reassign-confirm'), warnIfMissed: false);
      server.holdPost!.complete();
      await tester.pumpAndSettle();
      expect(server.of('POST', ApiConstants.branchReassignAdmin(1)), hasLength(1));
    });
  });
}

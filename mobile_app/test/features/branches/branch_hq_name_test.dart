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
import 'package:mobile_app/features/branches/data/models/branch_model.dart';
import 'package:mobile_app/features/branches/domain/branch_form_rules.dart';
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_form_dialog.dart';

// Task 45: Add / Edit Branch — web BranchManagement.tsx "Change Headquarter?"
// confirm (shown when saving this branch as HQ while ANOTHER loaded branch
// already is; Cancel sends nothing; "Yes, Change HQ" saves) and the branch
// name rule (BRANCH_NAME_RE, > 200 refused, trimmed; = backend
// BranchSerializer.validate_branch_name). A stand-in server; fictitious
// branches; nothing real changes.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> branchJson(int id, String name, {bool hq = false}) => {
      'id': id,
      'branch_code': 'TC-00$id',
      'branch_name': name,
      'address': '1 Test Road',
      'state': 1,
      'state_name': 'Test State',
      'city': 5,
      'city_name': 'Test City',
      'status': 'active',
      'is_headquarter': hq,
      'employees_count': 2,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> branches = [branchJson(1, 'Head Office', hq: true), branchJson(2, 'North Wing')];
  ({int status, String message})? refuse;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  Iterable<({String method, String path, Map<String, dynamic> query, Object? body})> writes() =>
      calls.where((c) => c.method != 'GET');

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
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
          'data': {'branch_code': 'TC-009'}
        });
      case ('GET', '/branch/branches/'):
        return _json(200, {
          'status': 'success',
          'data': {'count': branches.length, 'results': branches}
        });
      case ('GET', '/roles/'):
        return _json(200, {
          'status': 'success',
          'data': {
            'results': [
              {'id': 3, 'name': 'branch_admin', 'can_manage_branch': true, 'permissions': <String>[]}
            ]
          }
        });
      case ('GET', '/employees/'):
        if (o.queryParameters.containsKey('reporting_manager_id') || o.queryParameters.containsKey('hr_id')) {
          return _json(200, {
            'status': 'success',
            'data': {'count': 0, 'results': []}
          });
        }
        return _json(200, {
          'status': 'success',
          'data': {
            'results': [
              {
                'id': 'EMP-1',
                'uuid': 'uuid-EMP-1',
                'employee_id': 'EMP-1',
                'full_name': 'Asha Rao',
                'email': 'asha@example.test',
                'branch': 'North Wing',
                'role': 'employee'
              }
            ]
          }
        });
    }
    if (o.method == 'POST' || o.method == 'PATCH' || o.method == 'PUT') {
      final r = refuse;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      if (o.path == '/branch/branches/') {
        final b = Map<String, dynamic>.from(o.data as Map);
        return _json(201, {
          'status': 'success',
          'data': {...branchJson(9, '${b['branch_name']}'), ...b}
        });
      }
      if (o.path.startsWith('/branch/branches/')) {
        final id = int.parse(o.path.split('/').where((p) => p.isNotEmpty).last);
        final b = Map<String, dynamic>.from(o.data as Map);
        final cur = branches.firstWhere((x) => x['id'] == id);
        return _json(200, {
          'status': 'success',
          'data': {...cur, ...b}
        });
      }
      return _json(200, {'status': 'success', 'data': {}});
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
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'admin@example.test',
          fullName: 'Test Admin',
          role: 'system_admin',
          roleDisplay: 'Admin',
          mustChangePassword: false,
          permissions: ['settings.view', 'settings.edit', 'branches.create', 'branches.edit', 'employees.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Server server;
Finder byKey(String k) => find.byKey(Key(k));

/// The branch list screen stand-in: "Add" and one "Edit" per branch, so the
/// form reads the same loaded list the real screen does.
Future<void> pumpList(WidgetTester tester, {Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
          final list = ref.watch(branchListProvider).valueOrNull ?? const [];
          void open(BranchModel? b) => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => Dialog(child: BranchFormDialog(branch: b)),
              );
          return ListView(children: [
            TextButton(key: const Key('open-add'), onPressed: () => open(null), child: const Text('Add')),
            for (final b in list)
              TextButton(
                  key: Key('edit-${b.id}'),
                  onPressed: () => open(b as BranchModel),
                  child: Text('Edit ${b.branchName}')),
          ]);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openAdd(WidgetTester tester) async {
  await tester.tap(byKey('open-add'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select state'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test State').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select city'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test City').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'New Branch');
  await tester.enterText(find.widgetWithText(TextFormField, 'Address *'), '2 Test Road');
  await tester.pump();
}

Future<void> openEdit(WidgetTester tester, int id) async {
  await tester.tap(byKey('edit-$id'));
  await tester.pumpAndSettle();
}

Future<void> toggleHq(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Mark as Headquarter'));
  await tester.tap(find.text('Mark as Headquarter'));
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(byKey('branch-form-submit'));
  await tester.tap(byKey('branch-form-submit'));
  await tester.pumpAndSettle();
}

String? nameError(WidgetTester tester) => tester
    .widget<TextField>(
        find.descendant(of: find.widgetWithText(TextFormField, 'Branch Name *'), matching: find.byType(TextField)))
    .decoration!
    .errorText;

Map<String, dynamic> bodyOf(Object? b) => Map<String, dynamic>.from(b as Map);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('branch name rule (web BRANCH_NAME_RE = backend)', () {
    test('valid names', () {
      for (final n in [
        'A',
        '9',
        'Head Office',
        'R&D Centre',
        'Sector-21',
        'St. Mary 2',
        'a.b-c&d e',
        '  Trimmed Name  ',
        'x' * 200,
      ]) {
        expect(validateBranchName(n), isNull, reason: n);
      }
    });

    test('required, length and character messages, in web order', () {
      expect(validateBranchName(''), 'Branch name is required.');
      expect(validateBranchName('   '), 'Branch name is required.');
      expect(validateBranchName('x' * 201), 'Branch name must be under 200 characters.');
      expect(validateBranchName('  ${'x' * 200}  '), isNull, reason: 'length is checked after trimming');
      const bad = 'Branch name may only contain letters, numbers, spaces, & - and . characters.';
      for (final n in [
        '-North', // must start with a letter/digit
        'North.', // must end with a letter/digit
        '&Co',
        'North_Wing',
        "O'Brien",
        'North/South',
        'Café', // ASCII letters only
        'North (Main)',
        'North,Wing',
        'A\tB',
      ]) {
        expect(validateBranchName(n), bad, reason: n);
      }
      // Too long and badly formed: the length message comes first (web).
      expect(validateBranchName('_' * 201), 'Branch name must be under 200 characters.');
    });

    test('otherHeadquarter: only when marking HQ and a DIFFERENT branch is HQ', () {
      final list =
          [branchJson(1, 'Head Office', hq: true), branchJson(2, 'North Wing')].map(BranchModel.fromJson).toList();
      expect(otherHeadquarter(list, markingHq: true)!.id, 1, reason: 'Add');
      expect(otherHeadquarter(list, markingHq: true, editingId: 2)!.id, 1);
      expect(otherHeadquarter(list, markingHq: true, editingId: 1), isNull, reason: 'editing the HQ itself');
      expect(otherHeadquarter(list, markingHq: false, editingId: 2), isNull);
      expect(otherHeadquarter(const [], markingHq: true), isNull, reason: 'list not loaded');
      final noHq = [branchJson(2, 'North Wing')].map(BranchModel.fromJson).toList();
      expect(otherHeadquarter(noHq, markingHq: true), isNull);
    });
  });

  group('Add Branch', () {
    testWidgets('1. HQ with another HQ: web confirm; Cancel sends nothing and keeps the form', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await toggleHq(tester);
      await submit(tester);
      expect(byKey('branch-hq-confirm'), findsOneWidget);
      expect(find.text(kChangeHqTitle), findsOneWidget);
      expect(find.text(kChangeHqBody), findsOneWidget);
      expect(find.text('Yes, Change HQ'), findsOneWidget);
      await tester.tap(byKey('branch-hq-cancel'));
      await tester.pumpAndSettle();
      expect(server.writes(), isEmpty);
      expect(find.byType(BranchFormDialog), findsOneWidget);
      expect(find.text('New Branch'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).first).value, isTrue);
    });

    testWidgets('2. "Yes, Change HQ" creates the branch as HQ; nothing is sent for the other branch', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await toggleHq(tester);
      await submit(tester);
      await tester.tap(byKey('branch-hq-confirm-yes'));
      await tester.pumpAndSettle();
      final w = server.writes().toList();
      expect(w.map((c) => '${c.method} ${c.path}'), ['POST /branch/branches/']);
      expect(bodyOf(w.single.body)['is_headquarter'], isTrue);
      expect(find.byType(BranchFormDialog), findsNothing);
    });

    testWidgets('3. not HQ, or no other HQ: no confirm', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await submit(tester);
      expect(byKey('branch-hq-confirm'), findsNothing);
      expect(server.writes(), hasLength(1));

      await pumpList(tester, with_: Server()..branches = [branchJson(2, 'North Wing')]);
      await openAdd(tester);
      await toggleHq(tester);
      await submit(tester);
      expect(byKey('branch-hq-confirm'), findsNothing);
      expect(bodyOf(server.writes().single.body)['is_headquarter'], isTrue);
    });

    testWidgets('4. invalid name: web message on the field, no confirm, nothing sent', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await toggleHq(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'North_Wing');
      await submit(tester);
      expect(nameError(tester), 'Branch name may only contain letters, numbers, spaces, & - and . characters.');
      expect(byKey('branch-hq-confirm'), findsNothing);
      expect(server.writes(), isEmpty);
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), '   ');
      await submit(tester);
      expect(nameError(tester), 'Branch name is required.');
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), '  North-Wing  ');
      await tester.tap(find.text('Mark as Headquarter'));
      await tester.pump();
      await submit(tester);
      expect(bodyOf(server.writes().single.body)['branch_name'], 'North-Wing', reason: 'sent trimmed');
    });

    testWidgets('5. backend validation error is shown in the form; values kept', (tester) async {
      final s = Server()..refuse = (status: 400, message: 'branch_name: Branch name must not be blank.');
      await pumpList(tester, with_: s);
      await openAdd(tester);
      await submit(tester);
      expect(byKey('branch-form-error'), findsOneWidget);
      expect(find.text('branch_name: Branch name must not be blank.'), findsOneWidget);
      expect(find.text('New Branch'), findsOneWidget);
    });

    Future<void> pickExisting(WidgetTester tester) async {
      await tester.ensureVisible(byKey('branch-leader-existing-toggle'));
      await tester.tap(byKey('branch-leader-existing-toggle'));
      await tester.pumpAndSettle();
      final picker = find.byWidgetPredicate(
          (w) => w is DropdownButtonFormField<String> && '${w.key}'.contains('branch-leader-employee'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha Rao (EMP-1) — North Wing').last);
      await tester.pumpAndSettle();
    }

    Iterable<Object> countRequests() =>
        server.calls.where((c) => c.query.containsKey('reporting_manager_id') || c.query.containsKey('hr_id'));

    testWidgets(
        '6. HQ confirm → "Yes, Change HQ": branch saved at once, no transfer confirm or count lookup; '
        'the chosen Branch Admin is still applied after the save (web doSave)', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await toggleHq(tester);
      await pickExisting(tester);
      await submit(tester);
      expect(byKey('branch-hq-confirm'), findsOneWidget);
      await tester.tap(byKey('branch-hq-confirm-yes'));
      await tester.pumpAndSettle();
      expect(byKey('branch-transfer-confirm'), findsNothing);
      expect(countRequests(), isEmpty);
      final w = server.writes().toList();
      expect(w.map((c) => '${c.method} ${c.path}'), ['POST /branch/branches/', 'PUT /employees/EMP-1/'],
          reason: 'exactly one branch save; nothing sent to the old HQ branch');
      expect(bodyOf(w.first.body)['is_headquarter'], isTrue);
      expect(bodyOf(w.last.body), {'role': 'branch_admin', 'branch': 'New Branch'});
      expect(find.text('New Branch was created and its Branch Admin was assigned.'), findsOneWidget);
    });

    testWidgets('7. HQ confirm → Cancel: no save, no transfer confirm, no count lookup, values kept', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await toggleHq(tester);
      await pickExisting(tester);
      await submit(tester);
      await tester.tap(byKey('branch-hq-cancel'));
      await tester.pumpAndSettle();
      expect(byKey('branch-transfer-confirm'), findsNothing);
      expect(countRequests(), isEmpty);
      expect(server.writes(), isEmpty);
      expect(find.byType(BranchFormDialog), findsOneWidget);
      expect(find.text('New Branch'), findsOneWidget);
      final picker = tester.widget<DropdownButtonFormField<String>>(find.byWidgetPredicate(
          (w) => w is DropdownButtonFormField<String> && '${w.key}'.contains('branch-leader-employee')));
      expect(picker.initialValue, 'EMP-1');
    });

    testWidgets('7b. no HQ confirm needed: Task 44 transfer confirm runs as before → POST → PUT', (tester) async {
      await pumpList(tester);
      await openAdd(tester); // not marked HQ
      await pickExisting(tester);
      await submit(tester);
      expect(byKey('branch-hq-confirm'), findsNothing);
      expect(byKey('branch-transfer-confirm'), findsOneWidget);
      expect(countRequests(), hasLength(2));
      expect(server.writes(), isEmpty, reason: 'nothing saved before the move is confirmed');
      await tester.tap(byKey('branch-transfer-confirm-yes'));
      await tester.pumpAndSettle();
      expect(server.writes().map((c) => '${c.method} ${c.path}'), ['POST /branch/branches/', 'PUT /employees/EMP-1/']);
    });

    testWidgets('7c. HQ with no other HQ branch: no HQ confirm, so the transfer confirm still runs', (tester) async {
      await pumpList(tester, with_: Server()..branches = [branchJson(2, 'North Wing')]);
      await openAdd(tester);
      await toggleHq(tester);
      await pickExisting(tester);
      await submit(tester);
      expect(byKey('branch-hq-confirm'), findsNothing);
      expect(byKey('branch-transfer-confirm'), findsOneWidget);
      await tester.tap(byKey('branch-transfer-cancel'));
      await tester.pumpAndSettle();
      expect(server.writes(), isEmpty);
    });
  });

  group('Edit Branch', () {
    testWidgets('8. marking a non-HQ branch as HQ: confirm; Cancel sends no PATCH', (tester) async {
      await pumpList(tester);
      await openEdit(tester, 2);
      await toggleHq(tester);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(byKey('branch-hq-confirm'), findsOneWidget);
      await tester.tap(byKey('branch-hq-cancel'));
      await tester.pumpAndSettle();
      expect(server.writes(), isEmpty);
      expect(find.byType(BranchFormDialog), findsOneWidget);
    });

    testWidgets('9. confirm: one PATCH for this branch only, with is_headquarter true', (tester) async {
      await pumpList(tester);
      await openEdit(tester, 2);
      await toggleHq(tester);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('branch-hq-confirm-yes'));
      await tester.pumpAndSettle();
      final w = server.writes().single;
      expect('${w.method} ${w.path}', 'PATCH /branch/branches/2/');
      expect(bodyOf(w.body)['is_headquarter'], isTrue);
    });

    testWidgets('10. saving the current HQ itself (still HQ): no confirm', (tester) async {
      await pumpList(tester);
      await openEdit(tester, 1);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(byKey('branch-hq-confirm'), findsNothing);
      expect(server.writes().single.path, '/branch/branches/1/');
    });

    testWidgets('11. Edit uses the same name rule; a valid rename saves', (tester) async {
      await pumpList(tester);
      await openEdit(tester, 2);
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'North (Main)');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(nameError(tester), 'Branch name may only contain letters, numbers, spaces, & - and . characters.');
      expect(server.writes(), isEmpty);
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'North & Main');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(bodyOf(server.writes().single.body)['branch_name'], 'North & Main');
    });
  });
}

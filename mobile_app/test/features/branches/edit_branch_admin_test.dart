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
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_details_sheet.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_form_dialog.dart';

// Edit Branch → "Branch Admin" (web BranchManagement.tsx edit form: current
// admin or "No Branch Admin assigned" with Change / Assign Branch Admin,
// opening the same reassign flow; the edit form stays open and shows the new
// admin from the reloaded list). Same API as the details sheet:
// POST /branch/branches/<pk>/reassign-admin/ {employee_id: <code>}.
// Synthetic data only; nothing is sent anywhere.

Map<String, dynamic> branch(int id, String name, {String? admin, String? adminEmail}) => {
      'id': id,
      'branch_code': 'BR-00$id',
      'branch_name': name,
      'address': '1 Test Road',
      'state': 1,
      'state_name': 'Test State',
      'city': 1,
      'city_name': 'Test City',
      'hr_name': admin,
      'hr_email': adminEmail,
      'employees_count': 4,
      'status': 'active',
      'is_headquarter': false,
    };

Map<String, dynamic> emp(String code, String name) => {
      'id': code,
      'employee_id': code,
      'full_name': name,
      'email': '${code.toLowerCase()}@example.test',
      'branch': 'North',
      'role': 'employee',
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> branches = [
    branch(1, 'North', admin: 'Asha Rao', adminEmail: 'tst001@example.test'),
    branch(2, 'South'),
  ];
  ({int status, String message})? refuseNext;
  final calls = <({String method, String path, Object? body})>[];

  int count(String m, String p) => calls.where((c) => c.method == m && c.path == p).length;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.method == 'GET' && o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {'count': branches.length, 'results': branches}
      });
    }
    if (o.method == 'GET' && o.path == ApiConstants.employees) {
      return _json({
        'status': 'success',
        'data': {
          'results': [emp('TST001', 'Asha Rao'), emp('TST002', 'Ravi Menon')]
        }
      });
    }
    if (o.method == 'POST' && o.path.endsWith('/reassign-admin/')) {
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message}, r.status);
      }
      final id = int.parse(o.path.split('/').where((p) => p.isNotEmpty).elementAt(2));
      final code = (o.data as Map)['employee_id'];
      branches = [
        for (final b in branches)
          b['id'] == id ? {...b, 'hr_name': 'Ravi Menon', 'hr_email': '${'$code'.toLowerCase()}@example.test'} : b
      ];
      return _json({'status': 'success', 'message': 'reassigned', 'data': branches.firstWhere((b) => b['id'] == id)});
    }
    if (o.path == ApiConstants.branchStates) return _json({'status': 'success', 'data': []});
    return _json({'status': 'success', 'data': []});
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

/// A list that stays alive, with "Edit" and "View" per branch opening the
/// real Edit Branch dialog / details sheet.
Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? admin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
          final list = ref.watch(branchListProvider).valueOrNull ?? const [];
          return ListView(children: [
            for (final b in list) ...[
              TextButton(
                key: Key('edit-${b.id}'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Dialog(child: BranchFormDialog(branch: b)),
                ),
                child: Text('Edit ${b.branchName}'),
              ),
              TextButton(
                key: Key('view-${b.id}'),
                onPressed: () => showBranchDetailsSheet(context, b),
                child: Text('View ${b.branchName}'),
              ),
            ],
          ]);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
final editBlock = byKey('edit-branch-admin');
Finder inEdit(Finder f) => find.descendant(of: editBlock, matching: f);

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k).last);
  await tester.tap(byKey(k).last);
  await tester.pumpAndSettle();
}

Future<void> openEdit(WidgetTester tester, int id) async {
  await tapKey(tester, 'edit-$id');
  expect(find.byType(BranchFormDialog), findsOneWidget);
  await tester.ensureVisible(editBlock);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('existing admin: name, email and "Change Branch Admin" in the Edit form', (tester) async {
    await pump(tester);
    await openEdit(tester, 1);
    expect(inEdit(find.text('Branch Admin')), findsOneWidget);
    expect(inEdit(find.text('Asha Rao')), findsOneWidget);
    expect(inEdit(find.text('tst001@example.test')), findsOneWidget);
    expect(inEdit(find.text('Change Branch Admin')), findsOneWidget);
  });

  testWidgets('no admin: "No Branch Admin assigned" and "Assign Branch Admin"', (tester) async {
    await pump(tester);
    await openEdit(tester, 2);
    expect(inEdit(find.text('No Branch Admin assigned')), findsOneWidget);
    expect(inEdit(find.text('Assign Branch Admin')), findsOneWidget);
  });

  testWidgets('permission: the action needs settings.edit and branches.edit (superuser passes)', (tester) async {
    await pump(tester, as: user(['settings.view', 'settings.edit', 'branches.view']));
    await openEdit(tester, 1);
    expect(inEdit(find.text('Asha Rao')), findsOneWidget); // still shown
    expect(inEdit(byKey('branch-admin-reassign')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, as: user([], superuser: true));
    await openEdit(tester, 1);
    expect(inEdit(byKey('branch-admin-reassign')), findsOneWidget);
  });

  testWidgets('not in Add Branch', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox()); // a fresh scope for the Add form
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(() => _Auth(admin)),
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      ],
      child: const MaterialApp(home: Scaffold(body: Dialog(child: BranchFormDialog()))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add New Branch'), findsOneWidget);
    expect(editBlock, findsNothing);
  });

  testWidgets('Change from Edit: same flow and request; the form stays open and shows the new admin', (tester) async {
    await pump(tester);
    await openEdit(tester, 1);
    await tapKey(tester, 'branch-admin-reassign');
    expect(find.text('Change Branch Admin — North'), findsOneWidget);
    await tapKey(tester, 'reassign-option-TST002');
    await tapKey(tester, 'reassign-continue');
    expect(find.textContaining('This will remove Branch Admin access from'), findsOneWidget);
    final gets = server.count('GET', ApiConstants.branches);
    await tapKey(tester, 'reassign-confirm');
    expect(server.calls.singleWhere((c) => c.method == 'POST').body, {'employee_id': 'TST002'});
    expect(server.calls.singleWhere((c) => c.method == 'POST').path, ApiConstants.branchReassignAdmin(1));
    expect(byKey('reassign-sheet'), findsNothing);
    expect(find.byType(BranchFormDialog), findsOneWidget); // web keeps the edit form open
    expect(server.count('GET', ApiConstants.branches), greaterThan(gets));
    expect(inEdit(find.text('Ravi Menon')), findsOneWidget);
    expect(inEdit(find.text('Asha Rao')), findsNothing);
    expect(find.text('Branch Admin for North was reassigned successfully.'), findsOneWidget);
    // Nothing else in the form was saved.
    expect(server.calls.where((c) => c.method == 'PUT' || c.method == 'PATCH'), isEmpty);
  });

  testWidgets('a server refusal stays in the reassign sheet; the form and admin are unchanged', (tester) async {
    await pump(tester,
        setup: (s) => s.refuseNext = (status: 400, message: 'Ravi Menon is already the Branch Admin for "South".'));
    await openEdit(tester, 1);
    await tapKey(tester, 'branch-admin-reassign');
    await tapKey(tester, 'reassign-option-TST002');
    await tapKey(tester, 'reassign-continue');
    await tapKey(tester, 'reassign-confirm');
    expect(find.textContaining('is already the Branch Admin for'), findsOneWidget);
    expect(byKey('reassign-sheet'), findsOneWidget);
    await tapKey(tester, 'reassign-back');
    await tapKey(tester, 'reassign-cancel');
    expect(find.byType(BranchFormDialog), findsOneWidget);
    expect(inEdit(find.text('Asha Rao')), findsOneWidget);
  });

  testWidgets('regression: the details sheet still reassigns and then closes, as before', (tester) async {
    await pump(tester);
    await tapKey(tester, 'view-1');
    await tester.ensureVisible(byKey('branch-admin-section'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'branch-admin-reassign');
    await tapKey(tester, 'reassign-option-TST002');
    await tapKey(tester, 'reassign-continue');
    await tapKey(tester, 'reassign-confirm');
    expect(byKey('branch-admin-section'), findsNothing); // details closed
    expect(find.text('Branch Admin for North was reassigned successfully.'), findsOneWidget);
  });
}

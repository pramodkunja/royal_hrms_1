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
import 'package:mobile_app/features/employees/data/datasources/employees_remote_datasource.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';

// Task 50: Employee Profile → Approval Matrix, as web ApprovalMatrixTab.tsx
// against production GET /employees/<code>/approval-matrix/
// (EmployeeApprovalMatrixView: employees.view + branch scope → list of
// _build_matrix_row dicts whose l1/l2_approver_role are Role pks — integers —
// or null). Root cause of the device failure: those integers were read
// `as String?`, which threw, so the tab never loaded. A stand-in server;
// synthetic people; nothing real changes.

const code = 'EMP-50';
const matrixPath = '/employees/$code/approval-matrix/';

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> row(String type, String label, {int? l1 = 4, int? l2 = 2, bool override = false}) => {
      'workflow_type': type,
      'workflow_label': label,
      'l1_approver_role': l1,
      'l1_approver_label': 'Reporting Manager',
      'l1_approver_id': 'uuid-m1',
      'l1_approver_name': 'Test Manager',
      'l1_is_override': override,
      'l2_approver_role': l2,
      'l2_approver_label': l2 == null ? '' : 'HR',
      'l2_approver_id': l2 == null ? null : 'uuid-h1',
      'l2_approver_name': l2 == null ? null : 'Test HR',
      'l2_is_override': false,
    };

final productionRows = [
  row('leave', 'Leave'),
  row('expense', 'Expense', l2: null), // single level
  row('attendance_correction', 'Attendance Correction', override: true),
];

class Server implements HttpClientAdapter {
  /// What the matrix endpoint answers, in order (the last one repeats).
  List<({int status, Object body})> answers = [
    (status: 200, body: {'status': 'success', 'message': 'Approval matrix retrieved.', 'data': productionRows}),
  ];
  int matrixGets = 0;
  String employeeBranch = 'North';

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == matrixPath && o.method == 'GET') {
      final a = answers[matrixGets < answers.length ? matrixGets : answers.length - 1];
      matrixGets++;
      return _json(a.status, a.body);
    }
    if (o.path == '/employees/$code/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {
          'id': code,
          'uuid': 'uuid-e50',
          'employee_id': code,
          'first_name': 'Ria',
          'last_name': 'Test',
          'full_name': 'Ria Test',
          'email': 'ria@example.test',
          'branch': employeeBranch,
          'department': 'QA',
          'designation': 'Analyst',
          'role': 'employee',
          'is_active': true,
          'status': 'active',
          'onboarding_status': 'complete',
          'documents': <Object>[],
          'profile': <String, dynamic>{},
        },
      });
    }
    if (o.method == 'GET') return _json(200, {'status': 'success', 'data': <Object>[]});
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

UserEntity user(List<String> perms, {String? branch}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      branch: branch,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final branchHr = user(['employees.view', 'employees.edit'], branch: 'North');
final otherBranchHr = user(['employees.view', 'employees.edit'], branch: 'South');
final orgAdmin = user(['employees.view', 'employees.edit', 'settings.edit'], branch: 'South');
final viewer = user(['employees.view'], branch: 'North');

late Server server;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> openMatrix(WidgetTester tester, {Server? with_, UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? branchHr)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  final tab = find.text('Approval Matrix');
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Map<String, dynamic> envelope(Object data) => {'status': 'success', 'message': 'ok', 'data': data};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('parsing', () {
    test('real backend rows: integer role ids (the device crash), null L2 = single level', () {
      final r = EmployeeApprovalMatrixRow.fromJson(row('leave', 'Leave', l1: 4, l2: 2));
      expect((r.workflowType, r.l1ApproverRole, r.l2ApproverRole, r.isSingleLevel), ('leave', 4, 2, false));
      final single = EmployeeApprovalMatrixRow.fromJson(row('expense', 'Expense', l2: null));
      expect((single.l2ApproverRole, single.isSingleLevel), (null, true));
      final textual = EmployeeApprovalMatrixRow.fromJson({...row('leave', 'Leave'), 'l1_approver_role': '7'});
      expect(textual.l1ApproverRole, 7);
      final sparse = EmployeeApprovalMatrixRow.fromJson(const {'workflow_type': 'leave'});
      expect((sparse.l1ApproverRole, sparse.l1ApproverLabel, sparse.l1IsOverride), (null, '', false));
    });

    test('datasource: list → rows (web ACTIVE_WORKFLOWS only); a non-list is an error, not "empty"', () async {
      Future<List<EmployeeApprovalMatrixRow>> load(Object data) {
        final s = Server()..answers = [(status: 200, body: envelope(data))];
        return EmployeesRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://t.invalid'))..httpClientAdapter = s)
            .fetchApprovalMatrix(code);
      }

      expect((await load([...productionRows, row('loan', 'Loan'), row('travel', 'Travel')])).map((r) => r.workflowType),
          ['leave', 'expense', 'attendance_correction']);
      expect(await load([]), isEmpty);
      await expectLater(load({'rows': productionRows}), throwsA(isA<FormatException>()));
      await expectLater(load(['not a row']), throwsA(isA<FormatException>()));
    });

    test('edit rule = web canEditEmployeeScoped: employees.edit + own branch, or org-wide', () {
      expect(canEditEmployeeApprovals(branchHr, 'North'), isTrue);
      expect(canEditEmployeeApprovals(otherBranchHr, 'North'), isFalse);
      expect(canEditEmployeeApprovals(orgAdmin, 'North'), isTrue);
      expect(canEditEmployeeApprovals(viewer, 'North'), isFalse);
      expect(canEditEmployeeApprovals(null, 'North'), isFalse);
    });
  });

  group('tab', () {
    testWidgets('1. production-shaped response loads: one card per workflow, single-level shown', (tester) async {
      await openMatrix(tester);
      expect(server.matrixGets, 1);
      expect(find.text('Leave'), findsWidgets);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Attendance Correction'), findsWidgets);
      expect(find.text('Test Manager'), findsWidgets);
      expect(byKey('approval-matrix-error-other'), findsNothing);
      expect(find.text('Failed to load approval matrix.'), findsNothing);
    });

    testWidgets('2. empty list: the empty state, not an error', (tester) async {
      await openMatrix(tester, with_: Server()..answers = [(status: 200, body: envelope([]))]);
      expect(byKey('approval-matrix-empty'), findsOneWidget);
      expect(find.text('No approval workflows configured.'), findsOneWidget);
    });

    testWidgets('3. malformed response: an error with Retry, never shown as empty', (tester) async {
      await openMatrix(tester,
          with_: Server()
            ..answers = [
              (status: 200, body: envelope({'unexpected': true}))
            ]);
      expect(byKey('approval-matrix-error-malformed'), findsOneWidget);
      expect(find.text('Unexpected response from the server.'), findsOneWidget);
      expect(byKey('approval-matrix-empty'), findsNothing);
      expect(byKey('approval-matrix-retry'), findsOneWidget);
    });

    testWidgets('4. permission denied (403): the server message, no Retry', (tester) async {
      await openMatrix(tester,
          with_: Server()
            ..answers = [
              (
                status: 403,
                body: {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}}
              )
            ]);
      expect(byKey('approval-matrix-error-forbidden'), findsOneWidget);
      expect(find.text('You do not have permission to perform this action.'), findsOneWidget);
      expect(byKey('approval-matrix-retry'), findsNothing);
    });

    testWidgets('5. outside branch scope (404): "Employee not found." shown distinctly', (tester) async {
      await openMatrix(tester,
          with_: Server()
            ..answers = [
              (status: 404, body: {'status': 'error', 'message': 'Employee not found.', 'data': {}})
            ]);
      expect(byKey('approval-matrix-error-notFound'), findsOneWidget);
      expect(find.text('Employee not found.'), findsOneWidget);
    });

    testWidgets('6. server failure then Retry loads the matrix', (tester) async {
      final s = Server()
        ..answers = [
          (status: 500, body: {'status': 'error', 'message': 'Server error. Please try again later.', 'data': {}}),
          (status: 200, body: envelope(productionRows)),
        ];
      await openMatrix(tester, with_: s);
      expect(byKey('approval-matrix-error-other'), findsOneWidget);
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
      await tester.tap(byKey('approval-matrix-retry'));
      await tester.pumpAndSettle();
      expect(s.matrixGets, 2);
      expect(byKey('approval-matrix-error-other'), findsNothing);
      expect(find.text('Attendance Correction'), findsWidgets);
    });

    testWidgets(
        '7. branch-scoped editing: own-branch HR and org-wide admin may override; other branch or '
        'view-only may not', (tester) async {
      for (final (u, can) in [(branchHr, true), (orgAdmin, true), (otherBranchHr, false), (viewer, false)]) {
        await openMatrix(tester, as: u);
        expect(find.byTooltip('Override'), can ? findsWidgets : findsNothing, reason: '${u.permissions} ${u.branch}');
        expect(find.text('Leave'), findsWidgets, reason: 'everyone who may view sees the matrix');
      }
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/payroll/data/models/payslip_query_model.dart';

// HR payslip-query resolution in Team Approvals — web TeamApprovalsSection +
// payroll/_components/ResolveQueryModal, against a stand-in for production
// PayslipQueryListView (GET /payroll/queries/: the open queries in scope for
// payroll.view) and PayslipQueryResolveView (POST .../resolve/, payroll.edit,
// {resolution_note}). Synthetic data only.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object? data, [String message = 'ok']) =>
    _json(200, {'status': 'success', 'message': message, 'data': data});
ResponseBody _fail(int status, String message) => _json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> query(String id, String name,
        {String? code, String description = 'HRA looks wrong this month.'}) =>
    {
      'id': id,
      'payslip': 'ps-$id',
      'raised_by': 'u-$id',
      'raised_by_name': name,
      'employee_id_code': code,
      'cycle_start': '2026-10-01',
      'description': description,
      'status': 'open',
      'resolved_by': null,
      'resolved_by_name': null,
      'resolution_note': '',
      'resolved_at': null,
      'created_at': '2026-11-03T10:15:00+05:30',
      'updated_at': '2026-11-03T10:15:00+05:30',
    };

class FakePayslipQueryServer implements HttpClientAdapter {
  FakePayslipQueryServer(List<Map<String, dynamic>> open) : open = [...open];

  final List<Map<String, dynamic>> open;

  /// The caller's own queries — what GET /payroll/queries/ returns to a user
  /// without payroll.view (must never reach the team inbox).
  final own = <Map<String, dynamic>>[query('own-1', 'Myself')];

  bool callerHasPayrollView = true;
  bool callerHasPayrollEdit = true;
  int listStatus = 200;
  Completer<void>? holdList;
  Completer<void>? holdResolve;
  ({int status, String message})? refuseNextResolve;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  int count(String method, String path) => calls.where((c) => c.method == method && c.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: o.queryParameters, body: o.data));
    final p = o.path;
    if (p == '/payroll/queries/' && o.method == 'GET') {
      final gate = holdList;
      if (gate != null) await gate.future;
      if (listStatus != 200) return _fail(listStatus, 'Server error.');
      final mine = '${o.queryParameters['mine'] ?? ''}' == '1';
      return _ok(callerHasPayrollView && !mine ? open : own, 'Queries retrieved.');
    }
    final resolve = RegExp(r'^/payroll/queries/([^/]+)/resolve/$').firstMatch(p);
    if (resolve != null && o.method == 'POST') {
      final gate = holdResolve;
      if (gate != null) await gate.future;
      final refusal = refuseNextResolve;
      if (refusal != null) {
        refuseNextResolve = null;
        return _fail(refusal.status, refusal.message);
      }
      if (!callerHasPayrollEdit) return _fail(403, 'Only HR admin can resolve queries.');
      final id = resolve.group(1)!;
      final q = open.where((x) => x['id'] == id).firstOrNull;
      final note = '${(o.data as Map?)?['resolution_note'] ?? ''}'.trim();
      if (q == null) return _fail(404, 'Query not found.');
      if (note.isEmpty) return _fail(400, 'resolution_note is required.');
      open.remove(q);
      return _ok({
        ...q,
        'status': 'resolved',
        'resolution_note': note,
        'resolved_by_name': 'Hema HR',
        'resolved_at': '2026-11-05T12:00:00+05:30',
      }, 'Query resolved.');
    }
    if (p == '/separation/requests/' && o.method == 'GET') {
      return _ok({'count': 0, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': []});
    }
    return _fail(404, 'Not found: ${o.method} $p');
  }

  @override
  void close({bool force = false}) {}
}

class _NullSecureStorage extends SecureStorageService {
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

/// An HR user who opens Team Approvals through separation.approve (one of
/// web's gate permissions) plus the given payroll permissions.
UserEntity hr(List<String> payroll) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Hema HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: ['separation.approve', ...payroll],
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hrEditor = hr(['payroll.view', 'payroll.edit']);
final hrViewer = hr(['payroll.view']);
final noPayroll = hr(const []);

late FakePayslipQueryServer server;
late ProviderContainer container;

Future<void> pumpApprovals(WidgetTester tester, UserEntity u,
    {List<Map<String, dynamic>>? open, void Function(FakePayslipQueryServer)? setup, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakePayslipQueryServer(open ?? [query('q1', 'Asha Rao', code: 'EMP-2'), query('q2', 'Ravi Kumar')])
    ..callerHasPayrollView = u.permissions.contains('payroll.view')
    ..callerHasPayrollEdit = u.permissions.contains('payroll.edit');
  setup?.call(server);
  final router = GoRouter(initialLocation: AppRoutes.approvals, routes: [
    GoRoute(path: AppRoutes.approvals, builder: (_, __) => const Scaffold(body: ApprovalsScreen())),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullSecureStorage()),
      authStateProvider.overrideWith(() => _Auth(u)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  container = ProviderScope.containerOf(tester.element(find.byType(ApprovalsScreen)));
}

Finder resolveButton(String id) => find.byKey(Key('approval-resolve-$id'));

Future<void> openResolve(WidgetTester tester, String id) async {
  await tester.ensureVisible(resolveButton(id));
  await tester.tap(resolveButton(id));
  await tester.pumpAndSettle();
}

Future<void> enterNote(WidgetTester tester, String note) async {
  await tester.enterText(find.byKey(const Key('resolve-note-field')), note);
  await tester.pump();
}

FilledButton submitButton(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('resolve-submit')));

Map<String, dynamic> lastResolveBody() =>
    (server.calls.lastWhere((c) => c.method == 'POST').body as Map).cast<String, dynamic>();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('reads the HR-queue fields; employee-side fields unchanged', () {
      final q = PayslipQueryModel.fromJson(query('q1', 'Asha Rao', code: 'EMP-2'));
      expect(q.raisedByName, 'Asha Rao');
      expect(q.employeeIdCode, 'EMP-2');
      expect(q.cycleStart, '2026-10-01');
      expect(q.isResolved, isFalse);
      final bare = PayslipQueryModel.fromJson({'id': 'x', 'description': 'd'});
      expect(bare.raisedByName, '');
      expect(bare.employeeIdCode, isNull);
    });

    test('a queue row: open → pending; resolvable only with payroll.edit; never bulk-selectable', () {
      final q = PayslipQueryModel.fromJson(query('q1', 'Asha Rao', code: 'EMP-2', description: 'Line one\nline two'));
      final editable = UnifiedApprovalItem.fromPayslipQuery(q, canResolve: true);
      expect(editable.kind, UnifiedApprovalKind.payslip);
      expect(editable.typeLabel, 'Payslip Request');
      expect(editable.status, 'pending');
      expect(editable.canAction, isTrue);
      expect(editable.selectable, isFalse);
      expect(editable.secondaryLine, 'Line one line two');
      expect(editable.tertiaryLine, 'Raised 2026-11-03');
      expect(UnifiedApprovalItem.fromPayslipQuery(q, canResolve: false).canAction, isFalse);
      final long = PayslipQueryModel.fromJson(query('q9', 'X', description: 'a' * 400));
      expect(UnifiedApprovalItem.fromPayslipQuery(long, canResolve: true).secondaryLine.length, 141);
    });
  });

  group('listing', () {
    testWidgets('1. HR sees the open queries from GET /payroll/queries/ (no mine)', (tester) async {
      await pumpApprovals(tester, hrEditor);
      final listCalls = server.calls.where((c) => c.path == '/payroll/queries/' && c.method == 'GET').toList();
      expect(listCalls, hasLength(1));
      expect(listCalls.single.query, isEmpty);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('EMP-2'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Payslip Request'), findsNWidgets(2));
      expect(find.text('HRA looks wrong this month.'), findsNWidgets(2));
      expect(find.text('Raised 2026-11-03'), findsNWidgets(2));
      expect(find.text('Payslip Query · pay period from 2026-10-01'), findsNWidgets(2));
      expect(resolveButton('q1'), findsOneWidget);
      // The type tab counts them, and filters to them.
      await tester.tap(find.text('Payslip Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
    });

    testWidgets('2. no open queries: nothing listed, and the tab says so', (tester) async {
      await pumpApprovals(tester, hrEditor, open: []);
      expect(find.text('Payslip Request'), findsNothing);
      await tester.tap(find.text('Payslip Requests'));
      await tester.pumpAndSettle();
      expect(find.text('No requests match the current filters.'), findsOneWidget);
    });

    testWidgets('3. while loading: a spinner, no stale rows', (tester) async {
      await pumpApprovals(tester, hrEditor, setup: (s) => s.holdList = Completer<void>(), settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Asha Rao'), findsNothing);
      server.holdList!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
    });

    testWidgets('4. a failed load shows the error; pulling to refresh loads it', (tester) async {
      await pumpApprovals(tester, hrEditor, setup: (s) => s.listStatus = 500);
      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
      server.listStatus = 200;
      await tester.fling(find.text('Server error.'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(server.count('GET', '/payroll/queries/'), 2);
    });
  });

  group('resolving', () {
    testWidgets('5. the dialog shows the query; an empty or blank note cannot be sent', (tester) async {
      await pumpApprovals(tester, hrEditor);
      await openResolve(tester, 'q1');
      expect(find.byKey(const Key('resolve-payslip-query-dialog')), findsOneWidget);
      expect(find.text('Raised by Asha Rao'), findsOneWidget);
      expect(find.byKey(const Key('resolve-query-text')), findsOneWidget);
      expect(submitButton(tester).onPressed, isNull);
      await enterNote(tester, '    ');
      expect(submitButton(tester).onPressed, isNull);
      expect(server.count('POST', '/payroll/queries/q1/resolve/'), 0);
      // The provider refuses a blank note too, without a request.
      final item = container.read(unifiedTeamApprovalsProvider).requireValue.firstWhere((i) => i.sourceId == 'q1');
      expect(await container.read(unifiedTeamApprovalsProvider.notifier).resolvePayslipQuery(item, '  '),
          kResolutionNoteRequired);
      expect(server.count('POST', '/payroll/queries/q1/resolve/'), 0);
      // Cancel sends nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resolve-payslip-query-dialog')), findsNothing);
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('6 & 9. resolving sends {resolution_note}, then the list reloads without it', (tester) async {
      await pumpApprovals(tester, hrEditor);
      final listsBefore = server.count('GET', '/payroll/queries/');
      await openResolve(tester, 'q1');
      await enterNote(tester, '  Corrected HRA; revised payslip re-sent.  ');
      await tester.tap(find.byKey(const Key('resolve-submit')));
      await tester.pumpAndSettle();
      expect(server.count('POST', '/payroll/queries/q1/resolve/'), 1);
      expect(lastResolveBody(), {'resolution_note': 'Corrected HRA; revised payslip re-sent.'});
      expect(find.byKey(const Key('resolve-payslip-query-dialog')), findsNothing);
      expect(find.text('Payslip query resolved.'), findsOneWidget);
      expect(server.count('GET', '/payroll/queries/'), listsBefore + 1);
      expect(find.text('Asha Rao'), findsNothing);
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('7. a refusal keeps the dialog, the note and the query as it was', (tester) async {
      await pumpApprovals(tester, hrEditor);
      for (final (status, message) in [
        (404, 'Query not found.'),
        (500, 'Server error.'),
      ]) {
        server.refuseNextResolve = (status: status, message: message);
        await openResolve(tester, 'q1');
        await enterNote(tester, 'Fixed.');
        await tester.tap(find.byKey(const Key('resolve-submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('resolve-error')), findsOneWidget);
        expect(find.text(message), findsWidgets);
        expect(find.byKey(const Key('resolve-payslip-query-dialog')), findsOneWidget);
        expect(find.text('Fixed.'), findsOneWidget); // note kept
        expect(find.text('Payslip query resolved.'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Asha Rao'), findsOneWidget); // still pending in the list
        expect(resolveButton('q1'), findsOneWidget);
      }
      expect(server.open.map((q) => q['id']), ['q1', 'q2']);
    });

    testWidgets('8. repeated taps while sending send once', (tester) async {
      await pumpApprovals(tester, hrEditor);
      await openResolve(tester, 'q1');
      await enterNote(tester, 'Fixed.');
      final gate = server.holdResolve = Completer<void>();
      await tester.tap(find.byKey(const Key('resolve-submit')));
      await tester.pump();
      expect(submitButton(tester).onPressed, isNull); // disabled while sending
      await tester.tap(find.byKey(const Key('resolve-submit')), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', '/payroll/queries/q1/resolve/'), 1);
    });

    testWidgets('12. a 403 from the server is shown, never reported as resolved', (tester) async {
      await pumpApprovals(tester, hrEditor);
      server.refuseNextResolve = (status: 403, message: 'Only HR admin can resolve queries.');
      await openResolve(tester, 'q1');
      await enterNote(tester, 'Fixed.');
      await tester.tap(find.byKey(const Key('resolve-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Only HR admin can resolve queries.'), findsOneWidget);
      expect(find.text('Payslip query resolved.'), findsNothing);
      expect(server.open, hasLength(2));
    });

    testWidgets('the detail sheet shows the query and resolves it too', (tester) async {
      await pumpApprovals(tester, hrEditor);
      await tester.tap(find.text('Ravi Kumar'));
      await tester.pumpAndSettle();
      expect(find.text('Payslip Request Request'), findsNothing);
      expect(find.text('Payslip Query'), findsOneWidget); // web detailPrimary
      expect(find.text('QUERY'), findsOneWidget);
      expect(find.text('Pay period from'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detail-resolve')));
      await tester.pumpAndSettle();
      await enterNote(tester, 'Explained the deduction.');
      await tester.tap(find.byKey(const Key('resolve-submit')));
      await tester.pumpAndSettle();
      expect(lastResolveBody(), {'resolution_note': 'Explained the deduction.'});
      expect(find.text('QUERY'), findsNothing); // sheet closed
      expect(find.text('Ravi Kumar'), findsNothing);
    });

    testWidgets('payslip queries are not bulk-selectable', (tester) async {
      await pumpApprovals(tester, hrEditor);
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(boxes, isNotEmpty);
      expect(boxes.every((b) => b.onChanged == null), isTrue);
    });
  });

  group('permissions', () {
    testWidgets('10. payroll.view without payroll.edit: the queue is visible, nothing can be resolved', (tester) async {
      await pumpApprovals(tester, hrViewer);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(resolveButton('q1'), findsNothing);
      await tester.tap(find.text('Asha Rao'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-resolve')), findsNothing);
      expect(server.calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('11. without payroll.view the queue is never requested (own queries never leak in)', (tester) async {
      await pumpApprovals(tester, noPayroll);
      expect(find.byType(ApprovalsScreen), findsOneWidget);
      expect(server.count('GET', '/payroll/queries/'), 0);
      expect(find.text('Myself'), findsNothing);
      expect(find.text('Payslip Request'), findsNothing);
    });

    testWidgets('payroll.view alone does not open Team Approvals (web gate)', (tester) async {
      const payrollOnly = UserEntity(
        id: 'p1',
        email: 'p@example.test',
        fullName: 'Payroll Viewer',
        role: 'hr',
        roleDisplay: 'HR',
        mustChangePassword: false,
        permissions: ['payroll.view', 'payroll.edit'],
        onboardingStatus: 'complete',
        assessmentStatus: 'complete',
      );
      await pumpApprovals(tester, payrollOnly);
      expect(find.text('Team Approvals'), findsNothing);
      expect(server.count('GET', '/payroll/queries/'), 0);
    });
  });
}

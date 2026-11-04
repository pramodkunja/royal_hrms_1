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
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/separation/data/models/separation_models.dart';
import 'package:mobile_app/features/separation/presentation/screens/separation_detail_screen.dart';

// Phase 6 (A): separation approvals — requests join the Team Approvals
// inbox for separation.approve holders (web TeamApprovalsSection, GET
// /separation/requests/?scope=team&page_size=100), and each stage is decided
// on the detail screen (POST .../stages/<id>/action/ {action, remarks}).
// The fake applies the production view's rules (separation_workflow.py
// SeparationApprovalStageActionView): stage already decided → 400, an
// earlier stage pending → 400, not this user's stage → 403.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object? data, [String message = 'ok']) =>
    _json(200, {'status': 'success', 'message': message, 'data': data});
ResponseBody _fail(int status, String message) => _json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> stage(String id, String key, int seq,
        {String status = 'pending', bool canAction = false, String approver = '', String remarks = ''}) =>
    {
      'id': id,
      'stage': key,
      'stage_display': {'manager': 'Department Manager', 'hr': 'HR', 'branch_admin': 'Branch Admin'}[key],
      'sequence': seq,
      'status': status,
      'status_display': status[0].toUpperCase() + status.substring(1),
      'approver_name': approver,
      'remarks': remarks,
      'actioned_at': status == 'pending' ? null : '2026-11-02T10:00:00Z',
      'can_action': canAction,
    };

Map<String, dynamic> request(String id, String name,
        {required List<Map<String, dynamic>> stages, String status = 'pending'}) =>
    {
      'id': id,
      'request_ref': 'SEP-$id',
      'separation_type': 'resignation',
      'separation_type_display': 'Resignation',
      'reason': 'better_opportunity',
      'reason_display': 'Better opportunity',
      'request_date': '2026-11-01',
      'proposed_last_working_day': '2026-12-01',
      'notice_period_days': 30,
      'comments': '',
      'status': status,
      'status_display': status,
      'employee_name': name,
      'employee_code': 'EMP-$id',
      'employee_department': 'Engineering',
      'employee_designation': 'Engineer',
      'reporting_manager': null,
      'document_url': null,
      'created_by_name': name,
      'approval_stages': stages,
      'can_approve': stages.any((s) => s['can_action'] == true),
      'can_cancel': false,
      'can_edit': false,
      'can_delete': false,
      'is_own': false,
      'created_at': '2026-11-01T09:00:00Z',
      'assigned_notice_period_days': 30,
      'expected_last_working_day': '2026-12-01',
    };

class FakeSeparationServer implements HttpClientAdapter {
  FakeSeparationServer(this.requests);
  final List<Map<String, dynamic>> requests;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  /// Stage ids this user may act on once they are the open stage.
  final actionable = <String>{};
  Completer<void>? holdAction;
  bool dropNextAction = false;
  bool failList = false;

  int count(String method, String pathPart) =>
      calls.where((c) => c.method == method && c.path.contains(pathPart)).length;

  Map<String, dynamic>? _find(String id) => requests.where((r) => r['id'] == id).firstOrNull;

  /// What the serializer would say now (can_action / can_approve).
  void _refreshFlags(Map<String, dynamic> r) {
    final stages = (r['approval_stages'] as List).cast<Map<String, dynamic>>();
    for (final s in stages) {
      final earlier = stages.any((o) => (o['sequence'] as int) < (s['sequence'] as int) && o['status'] == 'pending');
      s['can_action'] = s['status'] == 'pending' && !earlier && actionable.contains(s['id']);
    }
    r['can_approve'] =
        (r['status'] == 'pending' || r['status'] == 'stage2_pending') && stages.any((s) => s['can_action'] == true);
  }

  /// Someone else decides a stage meanwhile (the user's screen goes stale).
  void decideElsewhere(String requestId, String stageId) {
    final r = _find(requestId)!;
    final s = (r['approval_stages'] as List).cast<Map<String, dynamic>>().firstWhere((s) => s['id'] == stageId);
    s['status'] = 'approved';
    s['approver_name'] = 'Another Approver';
    r['status'] = 'stage2_pending';
    _refreshFlags(r);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: o.queryParameters, body: o.data));
    final p = o.path;
    if (p == '/separation/requests/' && o.method == 'GET') {
      if (failList) return _fail(500, 'Server error.');
      for (final r in requests) {
        _refreshFlags(r);
      }
      return _ok({'count': requests.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': requests});
    }
    final action = RegExp(r'^/separation/requests/([^/]+)/stages/([^/]+)/action/$').firstMatch(p);
    if (action != null && o.method == 'POST') {
      if (holdAction != null) await holdAction!.future;
      if (dropNextAction) {
        dropNextAction = false;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      }
      final r = _find(action.group(1)!);
      final stages = (r?['approval_stages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final s = stages.where((s) => s['id'] == action.group(2)).firstOrNull;
      if (r == null || s == null) return _fail(404, 'Approval stage not found.');
      if (s['status'] != 'pending') return _fail(400, 'This stage has already been ${s['status']}.');
      if (stages.any((o) => (o['sequence'] as int) < (s['sequence'] as int) && o['status'] == 'pending')) {
        return _fail(400, 'An earlier approval stage is still pending.');
      }
      if (!actionable.contains(s['id'])) return _fail(403, 'Permission denied.');
      final body = (o.data as Map).cast<String, dynamic>();
      final act = body['action'];
      if (act != 'approve' && act != 'reject') return _fail(400, 'Action must be "approve" or "reject".');
      s['status'] = act == 'approve' ? 'approved' : 'rejected';
      s['approver_name'] = 'Morgan Manager';
      s['remarks'] = '${body['remarks'] ?? ''}'.trim();
      r['status'] =
          act == 'reject' ? 'rejected' : (stages.any((x) => x['status'] == 'pending') ? 'stage2_pending' : 'approved');
      _refreshFlags(r);
      return _ok(r, '${s['stage_display']} ${act}d.');
    }
    final detail = RegExp(r'^/separation/requests/([^/]+)/$').firstMatch(p);
    if (detail != null && o.method == 'GET') {
      final r = _find(detail.group(1)!);
      if (r == null) return _fail(404, 'Separation request not found.');
      _refreshFlags(r);
      return _ok(r);
    }
    // Handover tasks, clearances, documents, activity — empty here.
    if (p.startsWith('/separation/requests/') && o.method == 'GET') return _ok(<Object>[]);
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

UserEntity user(List<String> perms, {bool manager = false}) => UserEntity(
    id: 'me',
    email: 'm@example.com',
    fullName: 'Morgan Manager',
    role: 'manager',
    roleDisplay: 'Manager',
    mustChangePassword: false,
    permissions: perms,
    canManageTeam: manager,
    onboardingStatus: 'complete',
    assessmentStatus: 'complete');

/// A regular employee's request: Department Manager, then HR.
Map<String, dynamic> twoStage(String id, String name, {String status = 'pending'}) =>
    request(id, name, status: status, stages: [stage('$id-m', 'manager', 1), stage('$id-h', 'hr', 2)]);

late FakeSeparationServer server;

Future<void> pumpApp(WidgetTester tester, UserEntity u, {String start = AppRoutes.approvals}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(path: AppRoutes.approvals, builder: (_, __) => const Scaffold(body: ApprovalsScreen())),
    GoRoute(
        path: '/dashboard/separation/:requestId',
        builder: (_, s) => SeparationDetailScreen(requestId: s.pathParameters['requestId']!)),
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
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester, {String? remarks}) async {
  if (remarks != null) await tester.enterText(find.byKey(const Key('separation-decision-remarks')), remarks);
  await tester.pump();
  await tester.tap(find.byKey(const Key('separation-decision-confirm')));
  await tester.pumpAndSettle();
}

Map<String, dynamic> lastAction() =>
    (server.calls.lastWhere((c) => c.method == 'POST').body as Map).cast<String, dynamic>();

final approver = user(['separation.approve'], manager: true);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('access', () {
    test('Approvals opens for separation.approve alone; not without it', () {
      String? go(UserEntity u) => resolveAuthRedirect(authState: AuthState(user: u), path: AppRoutes.approvals);
      expect(go(user(['separation.approve'])), isNull);
      expect(go(user(const [])), AppRoutes.dashboard);
      final nav = kAllNav.whereType<NavItem>().firstWhere((i) => i.id == 'approvals');
      expect(nav.anyOfPermissions, contains('separation.approve'));
      expect(canAccessPath(user(['separation.approve']), AppRoutes.approvals), isTrue);
    });

    test('inbox item: open stages are pending, can_approve decides the action', () {
      final item = UnifiedApprovalItem.fromSeparation(
          SeparationRequestModel.fromJson(twoStage('1', 'Asha', status: 'stage2_pending')));
      expect(item.status, 'pending');
      expect(item.canAction, isFalse);
      expect(item.opensDetailScreen, isTrue);
      expect(item.primaryLine, 'Resignation');
    });
  });

  group('Team Approvals inbox', () {
    testWidgets('lists the team queue (scope=team, page_size=100) with a review action', (tester) async {
      server = FakeSeparationServer([twoStage('1', 'Asha'), twoStage('2', 'Ravi')])..actionable.add('1-m');
      await pumpApp(tester, approver);
      final list = server.calls.firstWhere((c) => c.path == '/separation/requests/');
      expect(list.query, {'page': 1, 'scope': 'team', 'page_size': 100});
      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('Ravi'), findsOneWidget);
      // Asha's manager stage is this user's; Ravi's is someone else's.
      expect(find.byKey(const Key('approval-review-1')), findsOneWidget);
      expect(find.byKey(const Key('approval-review-2')), findsNothing);
      // No quick approve/reject or bulk select for separation.
      expect(find.text('Approve'), findsNothing);
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(boxes.every((b) => b.onChanged == null), isTrue);
      // Only the separation source was asked for.
      expect(server.calls.where((c) => !c.path.startsWith('/separation/')), isEmpty);
    });

    testWidgets('without separation.approve the team queue is never requested', (tester) async {
      server = FakeSeparationServer([twoStage('1', 'Asha')]);
      await pumpApp(tester, user(['wfh.approve']));
      expect(server.count('GET', '/separation/requests/'), 0);
    });

    testWidgets('empty queue says so', (tester) async {
      server = FakeSeparationServer([]);
      await pumpApp(tester, approver);
      expect(find.text('Asha'), findsNothing);
      expect(find.textContaining('No'), findsWidgets);
    });

    testWidgets('a failed load shows the server message', (tester) async {
      server = FakeSeparationServer([])..failList = true;
      await pumpApp(tester, approver);
      expect(find.textContaining('Server error.'), findsOneWidget);
    });

    testWidgets('opening a request goes to its detail; returning reloads the inbox', (tester) async {
      server = FakeSeparationServer([twoStage('1', 'Asha')])..actionable.add('1-m');
      await pumpApp(tester, approver);
      await tapKey(tester, 'approval-review-1');
      expect(find.byType(SeparationDetailScreen), findsOneWidget);
      await tapKey(tester, 'stage-approve-1-m');
      await confirm(tester);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(server.count('GET', '/separation/requests/'), greaterThanOrEqualTo(2));
      expect(find.byKey(const Key('approval-review-1')), findsNothing); // no longer this user's turn
    });
  });

  group('deciding a stage', () {
    Future<void> openDetail(WidgetTester tester, {Set<String> mine = const {'1-m'}}) async {
      server = FakeSeparationServer([twoStage('1', 'Asha')])..actionable.addAll(mine);
      await pumpApp(tester, approver, start: AppRoutes.separationDetailPath('1'));
    }

    testWidgets('history shows each stage in order with its state', (tester) async {
      server = FakeSeparationServer([
        request('1', 'Asha', status: 'stage2_pending', stages: [
          stage('1-m', 'manager', 1, status: 'approved', approver: 'Dee Manager', remarks: 'Fine by me'),
          stage('1-h', 'hr', 2),
        ]),
      ]);
      await pumpApp(tester, approver, start: AppRoutes.separationDetailPath('1'));
      expect(find.text('Department Manager'), findsWidgets);
      expect(find.textContaining('Dee Manager'), findsWidgets);
      expect(find.textContaining('Fine by me'), findsOneWidget);
      // Not this user's stage: nothing to decide.
      expect(find.byKey(const Key('stage-approve-1-h')), findsNothing);
    });

    testWidgets('only the assigned, open stage offers actions', (tester) async {
      await openDetail(tester);
      expect(find.byKey(const Key('stage-approve-1-m')), findsOneWidget);
      expect(find.byKey(const Key('stage-approve-1-h')), findsNothing); // later stage, someone else's
    });

    testWidgets('approve: confirmed, sent with optional notes, then the server state is shown', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'stage-approve-1-m');
      expect(find.textContaining('Approve this stage'), findsOneWidget);
      await confirm(tester, remarks: 'Good handover plan');
      expect(lastAction(), {'action': 'approve', 'remarks': 'Good handover plan'});
      expect(find.text('Stage approved.'), findsOneWidget);
      expect(server.count('GET', '/separation/requests/1/'), greaterThanOrEqualTo(2)); // refreshed
      expect(find.byKey(const Key('stage-approve-1-m')), findsNothing);
      expect(find.textContaining('Good handover plan'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'stage-approve-1-m');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.count('POST', '/action/'), 0);
    });

    testWidgets('reject needs a reason before it can be sent', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'stage-reject-1-m');
      final button = find.byKey(const Key('separation-decision-confirm'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await confirm(tester, remarks: '   ');
      expect(server.count('POST', '/action/'), 0);
      await confirm(tester, remarks: 'Notice period not served');
      expect(lastAction(), {'action': 'reject', 'remarks': 'Notice period not served'});
      expect(find.text('Stage rejected.'), findsOneWidget);
      expect(server.requests.single['status'], 'rejected');
    });

    testWidgets('a refusal (403) is shown, never reported as success', (tester) async {
      await openDetail(tester);
      server.actionable.clear(); // the server no longer allows it
      await tapKey(tester, 'stage-approve-1-m');
      await confirm(tester);
      expect(find.text('Permission denied.'), findsOneWidget);
      expect(find.text('Stage approved.'), findsNothing);
      expect(server.requests.single['status'], 'pending');
    });

    testWidgets('a stale screen: the server says already decided, and the screen reloads', (tester) async {
      await openDetail(tester);
      server.decideElsewhere('1', '1-m');
      await tapKey(tester, 'stage-approve-1-m');
      await confirm(tester);
      expect(find.text('This stage has already been approved.'), findsOneWidget);
      expect(find.textContaining('Another Approver'), findsOneWidget); // reloaded
      expect(find.byKey(const Key('stage-approve-1-m')), findsNothing);
    });

    testWidgets('one request at a time — repeat taps send once', (tester) async {
      await openDetail(tester);
      server.holdAction = Completer<void>();
      await tapKey(tester, 'stage-approve-1-m');
      await tester.tap(find.byKey(const Key('separation-decision-confirm')));
      await tester.pump();
      final approve = find.byKey(const Key('stage-approve-1-m'));
      expect(tester.widget<FilledButton>(approve).onPressed, isNull); // disabled while sending
      await tester.tap(approve, warnIfMissed: false);
      await tester.pump();
      server.holdAction!.complete();
      await tester.pumpAndSettle();
      expect(server.count('POST', '/action/'), 1);
    });

    testWidgets('connection failure: reported, and it can be tried again', (tester) async {
      await openDetail(tester);
      server.dropNextAction = true;
      await tapKey(tester, 'stage-approve-1-m');
      await confirm(tester);
      expect(find.text('No internet connection. Check your connection and try again.'), findsOneWidget);
      expect(server.requests.single['status'], 'pending');
      ScaffoldMessenger.of(tester.element(find.byType(SeparationDetailScreen))).clearSnackBars();
      await tester.pumpAndSettle();
      await tapKey(tester, 'stage-approve-1-m');
      await confirm(tester);
      expect(find.text('Stage approved.'), findsOneWidget);
    });
  });
}

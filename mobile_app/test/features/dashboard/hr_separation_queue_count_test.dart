import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/data/models/hr_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/hr_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';
import 'package:mobile_app/features/separation/data/datasources/separation_remote_datasource.dart';

// Task 12: HR dashboard Action Queue → "Separation Requests". The dashboard
// endpoint (HRActionQueueView) hard-codes separation_requests: 0 and leaves it
// out of total_pending; web HrActionQueue instead reads
// GET /separation/requests/?scope=team&page_size=1 → `count` (only for
// separation.approve / settings.edit holders) and adds it to the total.
// Synthetic data; a stand-in server; read-only.

Map<String, dynamic> queue({int separation = 0}) => {
      'total_pending': 15,
      'candidate_reviews': 1,
      'leave_approvals': 2,
      'attendance_corrections': 3,
      'expense_claims': 4,
      'onboarding_reviews': 5,
      'separation_requests': separation,
    };

class Server implements HttpClientAdapter {
  Map<String, dynamic> queueBody = queue();
  // What the separation list answers: a full envelope by default.
  Object? separationData = {'count': 7, 'page': 1, 'page_size': 1, 'total_pages': 7, 'results': [<String, dynamic>{}]};
  int separationStatus = 200;
  Completer<void>? holdSeparation;
  final requests = <RequestOptions>[];

  List<RequestOptions> get separationCalls => requests.where((r) => r.path == ApiConstants.separationRequests).toList();

  ResponseBody _json(Object? b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add(o);
    if (o.path == ApiConstants.separationRequests) {
      final gate = holdSeparation;
      if (gate != null) await gate.future;
      if (separationStatus != 200) {
        return _json({'status': 'error', 'message': 'An unexpected error occurred. Please try again later.', 'data': {}},
            separationStatus);
      }
      return _json({'status': 'success', 'message': 'Separation requests retrieved.', 'data': separationData});
    }
    if (o.path == ApiConstants.dashboardHrActionQueue) {
      return _json({'status': 'success', 'data': queueBody});
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
      id: 'h1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

const _base = ['recruitment.view', 'employees.view', 'leave.view', 'leave.approve', 'expenses.view'];
final approver = user(const [..._base, 'separation.approve']);
final nonApprover = user(_base);

late Server server;
String? openedPath;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pumpHr(WidgetTester tester, {Server? with_, UserEntity? as, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  openedPath = null;
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? approver),
    child: MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Consumer(builder: (context, ref, _) {
            if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
            return const Scaffold(body: HrDashboardView());
          }),
        ),
        GoRoute(
          path: '/dashboard/separation',
          builder: (_, s) {
            openedPath = s.uri.path;
            return const Scaffold(body: Text('Separation screen'));
          },
        ),
      ]),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Finder get separationRow => find.byKey(const Key('hr-queue-separation'));
String separationText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: separationRow, matching: find.byType(Text)))
    .map((t) => t.data)
    .last!;

/// "Total Pending" figure shown at the top of the Action Queue card.
int totalPending(WidgetTester tester) {
  final card = find.ancestor(of: find.text('Action Queue'), matching: find.byType(SectionCard));
  final label = find.descendant(of: card, matching: find.text('Total Pending'));
  final column = find.ancestor(of: label, matching: find.byType(Column)).first;
  final texts = tester.widgetList<Text>(find.descendant(of: column, matching: find.byType(Text))).map((t) => t.data);
  return int.parse(texts.firstWhere((t) => t != null && int.tryParse(t) != null)!);
}

Future<int> countFrom(Object? data, {int status = 200}) {
  server = Server()
    ..separationData = data
    ..separationStatus = status;
  final ds = SeparationRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server);
  return ds.fetchTeamRequestCount();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('count fetch (web: ?scope=team&page_size=1 → count)', () {
    test('asks exactly what web asks and returns the server total, not the page size', () async {
      expect(await countFrom({'count': 42, 'page': 1, 'page_size': 1, 'total_pages': 42, 'results': [<String, dynamic>{}]}), 42);
      final call = server.separationCalls.single;
      expect(call.method, 'GET');
      expect(call.queryParameters, {'scope': 'team', 'page_size': 1});
    });

    test('zero is a real zero', () async {
      expect(await countFrom({'count': 0, 'page': 1, 'page_size': 1, 'total_pages': 1, 'results': <Object>[]}), 0);
    });

    test('a missing or invalid count is an error — never the one-row page length', () async {
      for (final bad in <Object?>[
        {'results': [<String, dynamic>{}]}, // no count: must NOT become 1
        {'count': null, 'results': <Object>[]},
        {'count': '7'},
        {'count': -1},
        {'count': 2.5},
        <Object>[<String, dynamic>{}], // a bare list
        null,
      ]) {
        await expectLater(countFrom(bad), throwsA(isA<FormatException>()), reason: '$bad');
      }
    });

    test('a server error propagates', () async {
      await expectLater(countFrom({}, status: 500), throwsA(isA<DioException>()));
    });
  });

  group('permission gate (web: separation.approve or settings.edit)', () {
    Future<(int, int)> read(UserEntity u) async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(u));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final v = await c.read(hrSeparationQueueCountProvider.future);
      return (v, server.separationCalls.length);
    }

    test('separation.approve → the team count is fetched', () async {
      expect(await read(approver), (7, 1));
    });
    test('settings.edit and superusers count as holding it (backend has_perm)', () async {
      expect(await read(user(const ['settings.edit'])), (7, 1));
      expect(await read(user(const [], superuser: true)), (7, 1));
    });
    test('without it → 0 and no request (the backend would return own requests)', () async {
      expect(await read(nonApprover), (0, 0));
    });
    test('retry after an error fetches again and recovers', () async {
      server = Server()..separationStatus = 500;
      final c = ProviderContainer(overrides: overrides(approver));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(hrSeparationQueueCountProvider, (_, __) {});
      await expectLater(c.read(hrSeparationQueueCountProvider.future), throwsA(anything));
      server.separationStatus = 200;
      c.invalidate(hrSeparationQueueCountProvider);
      expect(await c.read(hrSeparationQueueCountProvider.future), 7);
      expect(server.separationCalls, hasLength(2));
    });
  });

  group('Action Queue card', () {
    testWidgets('shows the team count and adds it to Total Pending', (tester) async {
      await pumpHr(tester);
      expect(separationText(tester), '7');
      expect(totalPending(tester), 15 + 7);
      expect(server.separationCalls, hasLength(1));
    });

    testWidgets('the dashboard endpoint\'s own separation_requests is not used', (tester) async {
      final s = Server()..queueBody = queue(separation: 99);
      await pumpHr(tester, with_: s);
      expect(separationText(tester), '7');
      expect(totalPending(tester), 22);
    });

    testWidgets('no separation requests in scope → 0', (tester) async {
      final s = Server()..separationData = {'count': 0, 'page': 1, 'page_size': 1, 'total_pages': 1, 'results': <Object>[]};
      await pumpHr(tester, with_: s);
      expect(separationText(tester), '0');
      expect(totalPending(tester), 15);
    });

    testWidgets('while loading the row shows "…" (not 0); then the server count', (tester) async {
      final s = Server()..holdSeparation = Completer();
      await pumpHr(tester, with_: s, settle: false);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(separationText(tester), '…');
      expect(totalPending(tester), 15);
      s.holdSeparation!.complete();
      await tester.pumpAndSettle();
      expect(separationText(tester), '7');
      expect(totalPending(tester), 22);
    });

    testWidgets('a failed count shows "—" and the other rows are unaffected', (tester) async {
      final s = Server()..separationStatus = 500;
      await pumpHr(tester, with_: s);
      expect(separationText(tester), '—');
      expect(totalPending(tester), 15);
      final leave = find.ancestor(of: find.text('Leave Approvals'), matching: find.byType(ActionRow));
      expect(tester.widget<ActionRow>(leave).count, 2);
    });

    testWidgets('a response without a count shows "—", not the page length', (tester) async {
      final s = Server()..separationData = {'results': [<String, dynamic>{}]};
      await pumpHr(tester, with_: s);
      expect(separationText(tester), '—');
      expect(totalPending(tester), 15);
    });

    testWidgets('without separation.approve: 0, no request, total unchanged', (tester) async {
      await pumpHr(tester, as: nonApprover);
      expect(separationText(tester), '0');
      expect(server.separationCalls, isEmpty);
      expect(totalPending(tester), 15);
    });

    testWidgets('tapping the row opens Separation', (tester) async {
      await pumpHr(tester);
      final title = find.descendant(of: separationRow, matching: find.text('Separation Requests'));
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(openedPath, '/dashboard/separation');
    });
  });

  group('regression', () {
    test('HrActionQueue still parses every dashboard field', () {
      final q = HrActionQueue.fromJson(queue(separation: 3));
      expect([q.totalPending, q.candidateReviews, q.leaveApprovals, q.attendanceCorrections, q.expenseClaims, q.onboardingReviews, q.separationRequests],
          [15, 1, 2, 3, 4, 5, 3]);
      final empty = HrActionQueue.fromJson(const {});
      expect([empty.totalPending, empty.separationRequests], [0, 0]);
    });

    testWidgets('other Action Queue rows keep their dashboard counts', (tester) async {
      await pumpHr(tester);
      for (final (title, n) in [
        ('Candidate Reviews', '1'),
        ('Leave Approvals', '2'),
        ('Attendance Corrections', '3'),
        ('Expense Claims', '4'),
        ('Onboarding Reviews', '5'),
      ]) {
        final row = find.ancestor(of: find.text(title), matching: find.byType(ActionRow));
        expect(tester.widget<ActionRow>(row).count.toString(), n, reason: title);
        expect(tester.widget<ActionRow>(row).countText, isNull, reason: title);
      }
    });
  });
}

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
import 'package:mobile_app/features/interview_list/data/datasources/interview_datasource.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/screens/interview_list_screen.dart';

// Interview List search + pagination, as web interview-list/page.tsx
// (RECRUITMENT_API.list → GET /recruitment/candidates/?search&status&page,
// 350 ms search debounce, page 1 on every filter change) over production
// CandidateListCreateView (search on name/email/position, status only
// pending/selected/rejected, page_size default 10, get_page clamps).
// Synthetic candidates; nothing is written.

Map<String, dynamic> cand(int id, String name, {String status = 'pending', String position = 'Analyst'}) => {
      'id': id,
      'name': name,
      'email': 'c$id@example.test',
      'phone': '9000000000',
      'position_applied': position,
      'branch': 1,
      'branch_name': 'North',
      'interview_date': '2026-11-20',
      'interview_mode': 'in_person',
      'status': status,
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': [],
    };

class Server implements HttpClientAdapter {
  Server(this.all);
  List<Map<String, dynamic>> all;
  int pageSize = 10;
  int failPage = 0; // a page number that fails once
  int listStatus = 200;
  final holds = <String, Completer<void>>{}; // keyed by "search|page"
  final listCalls = <Map<String, dynamic>>[];

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.candidateStats) {
      return _json({
        'status': 'success',
        'data': {'total': all.length, 'pending': 0, 'selected': 0, 'rejected': 0}
      });
    }
    if (o.path == ApiConstants.candidates && o.method == 'GET') {
      final q = Map<String, dynamic>.from(o.queryParameters);
      listCalls.add(q);
      final search = (q['search'] ?? '').toString().toLowerCase();
      final page = q['page'] as int;
      final hold = holds['$search|$page'];
      if (hold != null) await hold.future;
      if (listStatus != 200) return _json({'status': 'error', 'message': 'Server error.'}, listStatus);
      if (failPage == page) {
        failPage = 0;
        return _json({'status': 'error', 'message': 'Failed to load candidates.'}, 500);
      }
      var rows = all;
      final status = q['status'];
      if (status != null) rows = rows.where((c) => c['status'] == status).toList();
      if (search.isNotEmpty) {
        rows = rows
            .where((c) =>
                '${c['name']}'.toLowerCase().contains(search) ||
                '${c['email']}'.toLowerCase().contains(search) ||
                '${c['position_applied']}'.toLowerCase().contains(search))
            .toList();
      }
      final totalPages = rows.isEmpty ? 1 : (rows.length / pageSize).ceil();
      final p = page > totalPages ? totalPages : page; // Django get_page clamps
      return _json({
        'status': 'success',
        'data': {
          'count': rows.length,
          'page': p,
          'page_size': pageSize,
          'total_pages': totalPages,
          'status_choices': [],
          'results': rows.skip((p - 1) * pageSize).take(pageSize).toList(),
        }
      });
    }
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
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['recruitment.view', 'recruitment.edit', 'recruitment.create'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late Server server;
late ProviderContainer container;

List<Map<String, dynamic>> many(int n, {String prefix = 'Cand'}) =>
    [for (var i = 1; i <= n; i++) cand(i, '$prefix $i')];

Future<void> pump(WidgetTester tester, Server s, {double height = 1200, bool settle = true}) async {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      authStateProvider.overrideWith(_Auth.new),
    ],
    child: const MaterialApp(home: InterviewListScreen()),
  ));
  container = ProviderScope.containerOf(tester.element(find.byType(InterviewListScreen)));
  if (settle) await tester.pumpAndSettle();
}

Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('candidate-search')), text);
  await tester.pump();
}

CandidateListState listState() => container.read(candidateListProvider).requireValue;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('parsing', () {
    test('page envelope: count / page / total_pages / results', () {
      final p = CandidatePage.fromData({
        'count': 23,
        'page': 2,
        'page_size': 10,
        'total_pages': 3,
        'results': [cand(11, 'A'), cand(12, 'B')],
      });
      expect([p.count, p.page, p.totalPages, p.results.length, p.hasMore], [23, 2, 3, 2, true]);
      final bare = CandidatePage.fromData([cand(1, 'A')]);
      expect([bare.page, bare.totalPages, bare.count, bare.hasMore], [1, 1, 1, false]);
      expect(CandidatePage.fromData({'results': null}, requestedPage: 4).page, 4);
    });
  });

  group('requests', () {
    testWidgets('first load: page 1, no search/status, server default page size (no page_size)', (tester) async {
      await pump(tester, Server(many(3)));
      expect(server.listCalls.first, {'page': 1});
      expect(find.text('Cand 1'), findsOneWidget);
      expect(find.text('3 total'), findsOneWidget);
    });

    testWidgets('search is sent to the server after 350 ms (one request), resetting to page 1', (tester) async {
      await pump(
          tester, Server([cand(1, 'Asha Rao'), cand(2, 'Ravi Menon'), cand(3, 'Neha', position: 'Ravioli Chef')]));
      final before = server.listCalls.length;
      await typeSearch(tester, 'r');
      await typeSearch(tester, 'ra');
      await typeSearch(tester, ' ravi ');
      await tester.pump(const Duration(milliseconds: 300));
      expect(server.listCalls.length, before); // still debouncing
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(server.listCalls.length, before + 1);
      expect(server.listCalls.last, {'search': 'ravi', 'page': 1});
      // Server-side matching (name / email / position) replaces the list.
      expect(find.text('Ravi Menon'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    testWidgets('status tab is sent as status (All sends none) and restarts at page 1', (tester) async {
      await pump(tester, Server([cand(1, 'P One'), cand(2, 'S Two', status: 'selected')]));
      await tester.tap(find.text('Selected').first); // the tab (stats also say "Selected")
      await tester.pumpAndSettle();
      expect(server.listCalls.last, {'status': 'selected', 'page': 1});
      expect(find.text('S Two'), findsOneWidget);
      expect(find.text('P One'), findsNothing);
      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();
      expect(server.listCalls.last, {'page': 1});
    });
  });

  group('pagination', () {
    testWidgets('scrolling to the end loads the next page (page=2, same search), appended once', (tester) async {
      await pump(tester, Server(many(23)), height: 900);
      expect(server.listCalls, [
        {'page': 1}
      ]);
      expect(listState().items.length, 10);
      await tester.scrollUntilVisible(find.byKey(const Key('candidates-count')), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(server.listCalls[1], {'page': 2});
      expect(listState().items.length, 20);
      expect(listState().items.map((c) => c.id).toSet().length, 20); // no duplicates
    });

    testWidgets('end of list: no request beyond total_pages; "N total" shown', (tester) async {
      await pump(tester, Server(many(12)), height: 6000); // tall: everything comes into view
      expect(server.listCalls.map((q) => q['page']), [1, 2]);
      expect(listState().hasMore, isFalse);
      expect(listState().items.length, 12);
      expect(find.text('12 total'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(server.listCalls.length, 2);
    });

    test('loadMore: one at a time, ignored at the end', () async {
      server = Server(many(30))..holds['|2'] = Completer();
      final c = ProviderContainer(overrides: [
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(candidateListProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(candidateListProvider.future);
      final n = c.read(candidateListProvider.notifier);
      final first = n.loadMore();
      await n.loadMore(); // refused: one already loading
      server.holds['|2']!.complete();
      await first;
      expect(server.listCalls.map((q) => q['page']), [1, 2]);
      await n.loadMore();
      expect(server.listCalls.map((q) => q['page']), [1, 2, 3]);
      await n.loadMore(); // page 3 was the last
      expect(server.listCalls.length, 3);
      expect(c.read(candidateListProvider).requireValue.items.length, 30);
    });

    test('a page answered with an earlier page (server clamp) stops paging', () async {
      server = Server(many(15));
      final c = ProviderContainer(overrides: [
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(candidateListProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(candidateListProvider.future);
      server.all = many(5); // shrank meanwhile: page 2 now clamps to page 1
      await c.read(candidateListProvider.notifier).loadMore();
      final s = c.read(candidateListProvider).requireValue;
      expect(s.hasMore, isFalse);
      expect(s.items.length, 10); // nothing duplicated
    });

    testWidgets('a failed page keeps the list and offers Retry', (tester) async {
      final s = Server(many(23))..failPage = 2;
      await pump(tester, s, height: 6000);
      expect(find.byKey(const Key('candidates-more-error')), findsOneWidget);
      expect(listState().items.length, 10);
      await tester.tap(find.byKey(const Key('candidates-more-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('candidates-more-error')), findsNothing);
      expect(listState().items.length, 23);
    });
  });

  group('stale results', () {
    testWidgets('a slower older search never overwrites the newer one', (tester) async {
      final s = Server([cand(1, 'Asha Rao'), cand(2, 'Ravi Menon')]);
      s.holds['asha|1'] = Completer();
      await pump(tester, s);
      await typeSearch(tester, 'asha');
      await tester.pump(const Duration(milliseconds: 400)); // "asha" request now pending
      await typeSearch(tester, 'ravi');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Ravi Menon'), findsOneWidget);
      s.holds['asha|1']!.complete(); // the old answer arrives late
      await tester.pumpAndSettle();
      expect(find.text('Ravi Menon'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    test('a page load started before the search changed is discarded', () async {
      server = Server([...many(15), cand(99, 'Zed Unique')])..holds['|2'] = Completer();
      final c = ProviderContainer(overrides: [
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(candidateListProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(candidateListProvider.future);
      final pending = c.read(candidateListProvider.notifier).loadMore(); // page 2 of the old query
      c.read(candidateAppliedSearchProvider.notifier).state = 'zed';
      final fresh = await c.read(candidateListProvider.future);
      expect(fresh.items.map((x) => x.name), ['Zed Unique']);
      server.holds['|2']!.complete();
      await pending;
      expect(c.read(candidateListProvider).requireValue.items.map((x) => x.name), ['Zed Unique']);
    });
  });

  group('states', () {
    testWidgets('loading spinner, then empty view for no matches', (tester) async {
      final s = Server([])..holds['|1'] = Completer();
      await pump(tester, s, settle: false);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      s.holds['|1']!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('candidates-count')), findsNothing);
      expect(listState().items, isEmpty);
    });

    testWidgets('a failed first load shows the error state with Retry', (tester) async {
      final s = Server(many(2))..listStatus = 500;
      await pump(tester, s);
      expect(find.text('Cand 1'), findsNothing);
      expect(find.textContaining('Retry'), findsWidgets);
      s.listStatus = 200;
      await tester.tap(find.textContaining('Retry').first);
      await tester.pumpAndSettle();
      expect(find.text('Cand 1'), findsOneWidget);
    });

    testWidgets('pull-to-refresh reloads page 1 with the current search', (tester) async {
      await pump(tester, Server([cand(1, 'Asha Rao'), cand(2, 'Ravi Menon')]));
      await typeSearch(tester, 'asha');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      // Not awaited: the request completes as the test pumps.
      unawaited(container.read(candidateListProvider.notifier).refresh());
      await tester.pumpAndSettle();
      expect(server.listCalls.last, {'search': 'asha', 'page': 1});
      expect(find.text('Asha Rao'), findsOneWidget);
    });
  });
}

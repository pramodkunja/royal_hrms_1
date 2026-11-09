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
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/settings/data/models/audit_model.dart';
import 'package:mobile_app/features/settings/presentation/audit/audit_screen.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

// P1-2: Audit Log paging + module filter against production AuditLogListView
// (GET /settings/audit/?module&search&date_from&date_to&page&page_size;
// module matched exactly; search on actor name/email; newest first;
// page_size default 25; Django get_page clamps past-the-end to the last page
// while echoing the requested page). Synthetic entries only; read-only.

Map<String, dynamic> entry(int id, String module, {String? actor, String date = '2026-11-01'}) => {
      'id': id,
      'actor_name': actor ?? 'Actor $id',
      'actor_email': 'actor$id@example.test',
      'actor_role': 'HR',
      'module': module,
      'action': '${module}_updated',
      'object_id': '$id',
      'ip_address': '10.0.0.1',
      'created_at': '${date}T10:00:00Z',
    };

class Server implements HttpClientAdapter {
  Server({int all = 60, int branch = 3}) {
    // newest first: highest id first
    rows = [
      for (var i = all; i >= 1; i--) entry(i, i <= branch ? 'branch' : 'accounts'),
    ];
  }

  late List<Map<String, dynamic>> rows;
  final queries = <Map<String, dynamic>>[];
  final holds = <String, Completer<void>>{}; // "module|page"
  final failOnce = <String>{}; // "module|page"

  /// Inserted at the top just before page [page] is served (a new audit
  /// event arriving between Load More taps shifts every page by one).
  ({int page, Map<String, dynamic> row})? insertBefore;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path != ApiConstants.settingsAudit) return _json({'status': 'success', 'data': {}});
    final q = Map<String, dynamic>.from(o.queryParameters);
    queries.add(q);
    final module = (q['module'] ?? '') as String;
    final page = int.parse(q['page'] as String);
    final key = '$module|$page';
    final hold = holds[key];
    if (hold != null) await hold.future;
    if (failOnce.remove(key)) {
      return _json({'status': 'error', 'message': 'Audit service unavailable.', 'data': {}}, 500);
    }
    final ins = insertBefore;
    if (ins != null && ins.page == page) {
      rows = [ins.row, ...rows];
      insertBefore = null;
    }
    var list = rows;
    if (module.isNotEmpty) list = list.where((r) => r['module'] == module).toList();
    final search = (q['search'] ?? '').toString().toLowerCase();
    if (search.isNotEmpty) {
      list = list
          .where((r) =>
              '${r['actor_name']}'.toLowerCase().contains(search) ||
              '${r['actor_email']}'.toLowerCase().contains(search))
          .toList();
    }
    final from = q['date_from'] as String?;
    final to = q['date_to'] as String?;
    if (from != null) list = list.where((r) => (r['created_at'] as String).substring(0, 10).compareTo(from) >= 0).toList();
    if (to != null) list = list.where((r) => (r['created_at'] as String).substring(0, 10).compareTo(to) <= 0).toList();
    final pageSize = int.tryParse('${q['page_size'] ?? 25}') ?? 25;
    final totalPages = list.isEmpty ? 1 : (list.length / pageSize).ceil();
    final served = page > totalPages ? totalPages : page; // Django get_page clamps
    return _json({
      'status': 'success',
      'message': 'Audit logs retrieved.',
      'data': {
        'count': list.length,
        'page': page, // echoes the requested page, as production does
        'page_size': pageSize,
        'total_pages': totalPages,
        'results': list.skip((served - 1) * pageSize).take(pageSize).toList(),
      }
    });
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

late Server server;

List<Override> overrides() => [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

/// A container that keeps auditLogProvider alive, as the screen does.
Future<ProviderContainer> container() async {
  final c = ProviderContainer(overrides: overrides());
  addTearDown(c.dispose);
  c.listen(auditLogProvider, (_, __) {}, fireImmediately: true);
  await c.read(auditLogProvider.future);
  return c;
}

AuditLogState stateOf(ProviderContainer c) => c.read(auditLogProvider).requireValue;
List<int> ids(ProviderContainer c) => stateOf(c).entries.map((e) => e.id).toList();

void setFilters(ProviderContainer c, AuditLogFilters Function(AuditLogFilters) f) =>
    c.read(auditFiltersProvider.notifier).state = f(c.read(auditFiltersProvider));

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('paging (provider)', () {
    test('first page: GET /settings/audit/?page=1 and nothing else; 25 newest entries', () async {
      server = Server();
      final c = await container();
      expect(server.queries, [
        {'page': '1'}
      ]);
      final s = stateOf(c);
      expect(s.entries, hasLength(25));
      expect(s.entries.first.id, 60);
      expect([s.total, s.page, s.totalPages, s.hasMore], [60, 1, 3, true]);
    });

    test('Load More appends the next page after the existing entries, in order', () async {
      server = Server();
      final c = await container();
      await c.read(auditLogProvider.notifier).loadMore();
      expect(server.queries.last, {'page': '2'});
      expect(ids(c), [for (var i = 60; i >= 11; i--) i]);
      expect(stateOf(c).page, 2);
    });

    test('a new event shifting pages does not duplicate entries; earlier entries are kept', () async {
      server = Server()..insertBefore = (page: 2, row: entry(61, 'accounts'));
      final c = await container();
      await c.read(auditLogProvider.notifier).loadMore();
      final list = ids(c);
      expect(list.toSet().length, list.length, reason: 'no duplicate ids');
      expect(list.take(25), [for (var i = 60; i >= 36; i--) i], reason: 'page 1 untouched');
      expect(list, hasLength(49)); // page 2 repeated id 36, which is skipped
    });

    test('end of list: no Load More beyond the last page and no further requests', () async {
      server = Server();
      final c = await container();
      final n = c.read(auditLogProvider.notifier);
      await n.loadMore();
      await n.loadMore();
      expect(ids(c), [for (var i = 60; i >= 1; i--) i]);
      expect(stateOf(c).hasMore, isFalse);
      final before = server.queries.length;
      await n.loadMore();
      expect(server.queries.length, before);
    });

    test('a second Load More while one is in flight sends no extra request', () async {
      server = Server()..holds['|2'] = Completer();
      final c = await container();
      final n = c.read(auditLogProvider.notifier);
      final first = n.loadMore();
      await settle();
      expect(stateOf(c).loadingMore, isTrue);
      await n.loadMore();
      await n.loadMore();
      server.holds['|2']!.complete();
      await first;
      expect(server.queries.where((q) => q['page'] == '2'), hasLength(1));
      expect(ids(c), hasLength(50));
      expect(stateOf(c).loadingMore, isFalse);
    });

    test('a failed Load More keeps the loaded entries, reports the error, and can be retried', () async {
      server = Server()..failOnce.add('|2');
      final c = await container();
      final n = c.read(auditLogProvider.notifier);
      await n.loadMore();
      expect(ids(c), hasLength(25));
      expect(stateOf(c).loadMoreError, 'Audit service unavailable.');
      expect(stateOf(c).page, 1);
      await n.loadMore();
      expect(ids(c), hasLength(50));
      expect(stateOf(c).loadMoreError, isNull);
    });

    test('a failed first page is an error state; invalidating retries it', () async {
      server = Server()..failOnce.add('|1');
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      c.listen(auditLogProvider, (_, __) {}, fireImmediately: true);
      await expectLater(c.read(auditLogProvider.future), throwsA(isA<DioException>()));
      expect(friendlyAuditError(c.read(auditLogProvider).error!), 'Audit service unavailable.');
      c.invalidate(auditLogProvider);
      await c.read(auditLogProvider.future);
      expect(ids(c), hasLength(25));
    });
  });

  group('module filter (provider)', () {
    test('sends module=<exact backend value> and returns only that module', () async {
      server = Server();
      final c = await container();
      setFilters(c, (f) => f.copyWith(module: 'branch', page: 1));
      await c.read(auditLogProvider.future);
      expect(server.queries.last, {'module': 'branch', 'page': '1'});
      expect(stateOf(c).entries.map((e) => e.module).toSet(), {'branch'});
      expect(ids(c), [3, 2, 1]);
    });

    test('changing the module after Load More resets to page 1 with only the new records', () async {
      server = Server();
      final c = await container();
      await c.read(auditLogProvider.notifier).loadMore();
      expect(stateOf(c).page, 2);
      setFilters(c, (f) => f.copyWith(module: 'branch', page: 1));
      await c.read(auditLogProvider.future);
      final s = stateOf(c);
      expect(s.page, 1);
      expect(s.filters.module, 'branch');
      expect(ids(c), [3, 2, 1]);
      expect(server.queries.last['page'], '1');
    });

    test('a Load More response for the previous module cannot overwrite the new module\'s results', () async {
      server = Server()..holds['|2'] = Completer();
      final c = await container();
      final pending = c.read(auditLogProvider.notifier).loadMore();
      await settle();
      setFilters(c, (f) => f.copyWith(module: 'branch', page: 1));
      await c.read(auditLogProvider.future);
      server.holds['|2']!.complete();
      await pending;
      await settle();
      expect(ids(c), [3, 2, 1]);
      expect(stateOf(c).filters.module, 'branch');
      expect(stateOf(c).loadingMore, isFalse);
      // and Load More still works for the new filter
      expect(stateOf(c).hasMore, isFalse);
    });

    test('a slow first page for a superseded module cannot overwrite the newer module\'s results', () async {
      server = Server()..holds['accounts|1'] = Completer();
      final c = await container();
      setFilters(c, (f) => f.copyWith(module: 'accounts', page: 1)); // held
      await settle();
      setFilters(c, (f) => f.copyWith(module: 'branch', page: 1));
      await c.read(auditLogProvider.future);
      server.holds['accounts|1']!.complete();
      await settle();
      expect(stateOf(c).filters.module, 'branch');
      expect(ids(c), [3, 2, 1]);
    });

    test('the module list offers exactly the values the backend writes (incl. web\'s six)', () {
      final values = kAuditLogModules.map((m) => m.value).toSet();
      expect(values, {
        'accounts', 'announcements', 'assets', 'birthday', 'branch', 'company', 'company_financial_year',
        'documents', 'employees', 'leave', 'payroll', 'recruitment', 'settings', 'voice_commands', 'wfh',
      });
      expect(values.containsAll(['accounts', 'settings', 'company', 'branch', 'announcements', 'birthday']), isTrue);
      expect(values.intersection({'auth', 'attendance', 'announcement'}), isEmpty,
          reason: 'never written to AuditLog');
    });
  });

  group('search and dates stay compatible', () {
    test('search/date_from/date_to are sent on page 1 and carried unchanged into Load More', () async {
      server = Server(all: 60, branch: 0);
      final c = await container();
      setFilters(c, (f) => f.copyWith(search: 'actor', dateFrom: '2026-10-01', dateTo: '2026-11-30', page: 1));
      await c.read(auditLogProvider.future);
      expect(server.queries.last,
          {'search': 'actor', 'date_from': '2026-10-01', 'date_to': '2026-11-30', 'page': '1'});
      await c.read(auditLogProvider.notifier).loadMore();
      expect(server.queries.last,
          {'search': 'actor', 'date_from': '2026-10-01', 'date_to': '2026-11-30', 'page': '2'});
      expect(ids(c), hasLength(50));
    });

    test('combined module + search narrows on the server', () async {
      server = Server();
      final c = await container();
      setFilters(c, (f) => f.copyWith(module: 'branch', search: 'actor 2', page: 1));
      await c.read(auditLogProvider.future);
      expect(server.queries.last, {'search': 'actor 2', 'module': 'branch', 'page': '1'});
      expect(ids(c), [2]);
    });
  });

  group('screen', () {
    Finder byKey(String k) => find.byKey(Key(k));
    String count(WidgetTester tester) => tester.widget<Text>(byKey('audit-count')).data!;

    Future<void> pumpScreen(WidgetTester tester, Server s) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = s;
      final router = GoRouter(initialLocation: AppRoutes.settingsAuditLog, routes: [
        GoRoute(path: AppRoutes.settingsAuditLog, builder: (_, __) => const AuditScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: overrides(), child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
    }

    Future<void> tapFooter(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(byKey(key), 400, scrollable: find.byType(Scrollable).last);
      await tester.tap(byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('Load more appends: the count grows and the first entry stays; then End of audit log',
        (tester) async {
      await pumpScreen(tester, Server());
      expect(count(tester), 'Showing 25 of 60 records');
      expect(find.text('Actor 60'), findsOneWidget);
      await tapFooter(tester, 'audit-load-more');
      expect(count(tester), 'Showing 50 of 60 records');
      await tapFooter(tester, 'audit-load-more');
      expect(count(tester), 'Showing 60 of 60 records');
      expect(byKey('audit-load-more'), findsNothing);
      await tester.scrollUntilVisible(byKey('audit-end-of-list'), 400, scrollable: find.byType(Scrollable).last);
      expect(byKey('audit-end-of-list'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Actor 60'), -400, scrollable: find.byType(Scrollable).last);
      expect(find.text('Actor 60'), findsOneWidget, reason: 'earlier records were not replaced');
    });

    testWidgets('the module dropdown offers the backend modules and sends the exact value', (tester) async {
      await pumpScreen(tester, Server());
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(byKey('audit-module-filter'));
      await tester.pumpAndSettle();
      for (final m in kAuditLogModules) {
        expect(find.text(m.label), findsWidgets, reason: m.label);
      }
      expect(find.text('auth'), findsNothing);
      await tester.tap(find.text('Branch').last);
      await tester.pumpAndSettle();
      expect(server.queries.last, {'module': 'branch', 'page': '1'});
      expect(count(tester), 'Showing 3 of 3 records');
      expect(byKey('audit-load-more'), findsNothing);
    });

    testWidgets('a failed first load shows the server message and Retry reloads', (tester) async {
      await pumpScreen(tester, Server()..failOnce.add('|1'));
      expect(find.text('Could not load audit log'), findsOneWidget);
      expect(find.text('Audit service unavailable.'), findsOneWidget);
      await tester.tap(byKey('audit-retry'));
      await tester.pumpAndSettle();
      expect(count(tester), 'Showing 25 of 60 records');
    });

    testWidgets('a failed Load More keeps the list, shows the error and Retry appends', (tester) async {
      await pumpScreen(tester, Server()..failOnce.add('|2'));
      await tapFooter(tester, 'audit-load-more');
      expect(count(tester), 'Showing 25 of 60 records');
      expect(tester.widget<Text>(byKey('audit-load-more-error')).data, 'Audit service unavailable.');
      await tapFooter(tester, 'audit-load-more-retry');
      expect(count(tester), 'Showing 50 of 60 records');
      expect(byKey('audit-load-more-error'), findsNothing);
    });

    testWidgets('an empty result shows the empty state', (tester) async {
      await pumpScreen(tester, Server(all: 0, branch: 0));
      expect(find.text('No audit records'), findsOneWidget);
    });
  });
}

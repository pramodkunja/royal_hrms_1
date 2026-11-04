import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile_app/features/announcements/presentation/providers/announcement_providers.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Phase 11.1: announcements pagination against a stand-in for the
// production list view (apps/announcements/views.py): ?page & ?page_size
// (max 50), optional ?category, response {count, page, page_size,
// total_pages, pinned_count, total_reactions, total_views, results}. Like
// Django's Paginator.get_page, a page number past the end returns the LAST
// page again, and an empty list still has total_pages = 1.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> ann(int id, {String category = 'general'}) => {
      'id': id,
      'title': 'Announcement $id',
      'body': 'Body $id',
      'category': category,
      'posted_by_name': 'HR',
      'can_edit': false,
      'created_at': '2026-11-01T10:00:00Z',
      'updated_at': '2026-11-01T10:00:00Z',
    };

class FakeAnnouncementsServer implements HttpClientAdapter {
  FakeAnnouncementsServer(this.items);
  List<Map<String, dynamic>> items; // newest first
  final listCalls = <Map<String, dynamic>>[];
  bool failNext = false;
  Completer<void>? hold;

  /// Pretend the server reports more pages than it delivers.
  int? forceTotalPages;
  bool emptyAfterFirst = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == '/announcements/' && o.method == 'GET') {
      listCalls.add(Map.of(o.queryParameters));
      if (hold != null) {
        final h = hold!;
        hold = null;
        await h.future;
      }
      if (failNext) {
        failNext = false;
        return _json(500, {'status': 'error', 'message': 'Server error.', 'data': {}});
      }
      final category = o.queryParameters['category'] as String?;
      final filtered = category == null ? items : items.where((a) => a['category'] == category).toList();
      final size = (o.queryParameters['page_size'] as int).clamp(1, 50);
      final pages = filtered.isEmpty ? 1 : (filtered.length / size).ceil();
      final page = (o.queryParameters['page'] as int).clamp(1, pages); // get_page clamps
      var results = filtered.skip((page - 1) * size).take(size).toList();
      if (emptyAfterFirst && page > 1) results = [];
      return _json(200, {
        'status': 'success',
        'message': 'Announcements fetched.',
        'data': {
          'count': items.length, // un-filtered, as in production
          'page': page,
          'page_size': size,
          'total_pages': forceTotalPages ?? pages,
          'pinned_count': 0,
          'total_reactions': 0,
          'total_views': 0,
          'results': results,
        },
      });
    }
    if (o.path.endsWith('/react/')) {
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {'has_reacted': true, 'reactions_count': 1}
      });
    }
    return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'e@example.com',
          fullName: 'Pat',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: [],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

List<Map<String, dynamic>> many(int n, {int from = 1, String category = 'general'}) =>
    [for (var i = from; i < from + n; i++) ann(i, category: category)];

late FakeAnnouncementsServer server;

ProviderContainer containerFor(FakeAnnouncementsServer s) {
  server = s;
  final c = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
  ]);
  addTearDown(c.dispose);
  c.listen(announcementsProvider, (_, __) {}); // keep it alive like the screen does
  return c;
}

List<String> ids(ProviderContainer c) =>
    c.read(announcementsProvider).requireValue.announcements.map((a) => a.id).toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('paging (provider)', () {
    test('first page: page 1, page_size 20; more pages known from total_pages', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      final page = await c.read(announcementsProvider.future);
      expect(server.listCalls.single, {'page': 1, 'page_size': 20});
      expect(page.announcements, hasLength(20));
      expect((page.currentPage, page.totalPages, page.hasMore), (1, 3, true));
    });

    test('next page is appended after the earlier ones, in order', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      await c.read(announcementsProvider.notifier).loadMore();
      expect(server.listCalls.last, {'page': 2, 'page_size': 20});
      expect(ids(c), [for (var i = 1; i <= 40; i++) '$i']);
      expect(c.read(announcementsProvider).requireValue.currentPage, 2);
    });

    test('no repeats when the list shifts between requests', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      server.items = [ann(100), ...server.items]; // a new post moves everything down one
      await c.read(announcementsProvider.notifier).loadMore();
      final shown = ids(c);
      expect(shown.toSet().length, shown.length);
      expect(shown, hasLength(39)); // 20 + 19 new (announcement 20 came again)
    });

    test('one request at a time', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      final gate = server.hold = Completer<void>();
      final first = c.read(announcementsProvider.notifier).loadMore();
      expect(c.read(announcementsProvider).requireValue.loadingMore, isTrue);
      await c.read(announcementsProvider.notifier).loadMore();
      await c.read(announcementsProvider.notifier).loadMore();
      await Future<void>.delayed(const Duration(milliseconds: 20)); // let the request reach the server
      expect(server.listCalls, hasLength(2)); // page 1 + one page 2
      gate.complete();
      await first;
      expect(ids(c), hasLength(40));
    });

    test('nothing more is asked for after the last page', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      final n = c.read(announcementsProvider.notifier);
      await n.loadMore();
      await n.loadMore();
      expect(ids(c), hasLength(45));
      expect(c.read(announcementsProvider).requireValue.hasMore, isFalse);
      await n.loadMore();
      expect(server.listCalls.map((q) => q['page']), [1, 2, 3]);
    });

    test('refresh reloads page 1 and drops the loaded pages', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      await c.read(announcementsProvider.notifier).loadMore();
      await c.read(announcementsProvider.notifier).refresh();
      expect(server.listCalls.last, {'page': 1, 'page_size': 20});
      final page = c.read(announcementsProvider).requireValue;
      expect((page.currentPage, page.announcements.length, page.hasMore), (1, 20, true));
    });

    test('a category change starts again at page 1 of that category', () async {
      final c = containerFor(FakeAnnouncementsServer([...many(30), ...many(25, from: 200, category: 'hr')]));
      await c.read(announcementsProvider.future);
      await c.read(announcementsProvider.notifier).loadMore();
      c.read(announcementCategoryProvider.notifier).state = 'hr';
      final page = await c.read(announcementsProvider.future);
      expect(server.listCalls.last, {'page': 1, 'page_size': 20, 'category': 'hr'});
      expect(page.announcements.every((a) => a.category == 'hr'), isTrue);
      expect((page.currentPage, page.totalPages), (1, 2));
      await c.read(announcementsProvider.notifier).loadMore();
      expect(server.listCalls.last, {'page': 2, 'page_size': 20, 'category': 'hr'});
      expect(ids(c), hasLength(25));
    });

    test('a page that arrives after the list was reset is dropped', () async {
      final c = containerFor(FakeAnnouncementsServer([...many(30), ...many(5, from: 200, category: 'hr')]));
      await c.read(announcementsProvider.future);
      final gate = server.hold = Completer<void>();
      final pending = c.read(announcementsProvider.notifier).loadMore();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.read(announcementCategoryProvider.notifier).state = 'hr';
      gate.complete();
      await pending;
      final page = await c.read(announcementsProvider.future);
      expect(page.announcements.every((a) => a.category == 'hr'), isTrue);
      expect(page.announcements, hasLength(5));
    });

    test('a failed next page keeps what is shown and can be retried', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      server.failNext = true;
      await c.read(announcementsProvider.notifier).loadMore();
      var page = c.read(announcementsProvider).requireValue;
      expect(page.loadMoreError, 'Server error.');
      expect((page.announcements.length, page.currentPage, page.loadingMore), (20, 1, false));
      await c.read(announcementsProvider.notifier).loadMore();
      page = c.read(announcementsProvider).requireValue;
      expect((page.loadMoreError, page.announcements.length, page.currentPage), (null, 40, 2));
    });

    test('empty first page: nothing more to load', () async {
      final c = containerFor(FakeAnnouncementsServer([]));
      final page = await c.read(announcementsProvider.future);
      expect((page.announcements.length, page.totalPages, page.hasMore), (0, 1, false));
      await c.read(announcementsProvider.notifier).loadMore();
      expect(server.listCalls, hasLength(1));
    });

    test('an empty later page ends the list even if total_pages said more', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45))..emptyAfterFirst = true);
      await c.read(announcementsProvider.future);
      await c.read(announcementsProvider.notifier).loadMore();
      final page = c.read(announcementsProvider).requireValue;
      expect((page.announcements.length, page.hasMore), (20, false));
      await c.read(announcementsProvider.notifier).loadMore();
      expect(server.listCalls, hasLength(2));
    });

    test('the server repeating its last page (page past the end) does not duplicate', () async {
      final c = containerFor(FakeAnnouncementsServer(many(15))..forceTotalPages = 3);
      await c.read(announcementsProvider.future);
      await c.read(announcementsProvider.notifier).loadMore(); // server clamps to page 1
      final page = c.read(announcementsProvider).requireValue;
      expect((ids(c).length, page.hasMore), (15, false));
    });

    test('a reaction made while a page loads is kept', () async {
      final c = containerFor(FakeAnnouncementsServer(many(45)));
      await c.read(announcementsProvider.future);
      final gate = server.hold = Completer<void>();
      final pending = c.read(announcementsProvider.notifier).loadMore();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await c.read(announcementsProvider.notifier).toggleReaction('1');
      expect(c.read(announcementsProvider).requireValue.loadingMore, isTrue); // still loading
      gate.complete();
      await pending;
      final first = c.read(announcementsProvider).requireValue.announcements.first;
      expect((first.id, first.hasReacted), ('1', true));
      expect(ids(c), hasLength(40));
    });
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester, FakeAnnouncementsServer s) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = s;
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
          authStateProvider.overrideWith(_Auth.new),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('scrolling to the end loads the next pages until the end', (tester) async {
      await pump(tester, FakeAnnouncementsServer(many(45)));
      expect(find.text('Announcement 1'), findsOneWidget);
      for (var i = 0; i < 12 && find.byKey(const Key('announcements-end')).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
        await tester.pumpAndSettle();
      }
      expect(server.listCalls.map((q) => q['page']), [1, 2, 3]);
      expect(find.text('Announcement 45'), findsOneWidget);
      expect(find.byKey(const Key('announcements-end')), findsOneWidget);
    });

    testWidgets('a failed page shows Retry, which loads it', (tester) async {
      await pump(tester, FakeAnnouncementsServer(many(25)));
      server.failNext = true;
      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
          find.byKey(const Key('announcements-load-more-error')), find.byType(ListView).last, const Offset(0, -300));
      expect(find.text('Server error.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(server.listCalls.map((q) => q['page']), [1, 2, 2]); // failed, then retried
      expect(find.byKey(const Key('announcements-load-more-error')), findsNothing);
      final page = ProviderScope.containerOf(tester.element(find.byType(AnnouncementsScreen)))
          .read(announcementsProvider)
          .requireValue;
      expect(page.announcements.map((a) => a.id), [for (var i = 1; i <= 25; i++) '$i']);
    });

    testWidgets('pull to refresh asks for page 1 again', (tester) async {
      await pump(tester, FakeAnnouncementsServer(many(5)));
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      expect(server.listCalls.map((q) => q['page']), [1, 1]);
      expect(find.byKey(const Key('announcements-end')), findsNothing); // a single page: no end marker
    });

    testWidgets('empty list: the empty state, refreshable, no further requests', (tester) async {
      await pump(tester, FakeAnnouncementsServer([]));
      expect(find.text('No announcements yet'), findsOneWidget);
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      expect(server.listCalls.map((q) => q['page']), [1, 1]);
    });
  });
}

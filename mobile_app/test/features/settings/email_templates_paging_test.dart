import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
import 'package:mobile_app/features/settings/presentation/email_templates/email_templates_screen.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

// Task 15 (audit F-ET01): GET /settings/email-templates/ is paginated
// (EmailTemplateListCreateView → core.pagination.paginate: ?page, ?page_size
// default 20 / max 100; envelope {count, page, page_size, total_pages,
// results} with results grouped by template_type; ordered template_type,
// display_name). Web reads only the first page; mobile loads every page.
// Synthetic templates on a stand-in server; nothing is sent or changed.

const _types = ['document', 'notification', 'reminder', 'wish'];

Map<String, dynamic> tpl(int id) => {
      'id': id,
      'name': 'tpl_$id',
      'display_name': 'Template ${id.toString().padLeft(3, '0')}',
      'description': 'Synthetic template $id',
      'subject': 'Subject $id',
      'body': 'Body',
      'template_type': _types[id % _types.length],
      'template_type_display': _types[id % _types.length],
      'is_active': true,
      'is_builtin': false,
      'available_variables': <String>[],
      'attachments': <Object>[],
    };

class Server implements HttpClientAdapter {
  Server(this.total);
  int total;
  final failPages = <int>{}; // these pages answer 500 (each once)
  final holdPages = <int, Completer<void>>{};
  bool overlap = false; // each later page repeats the previous page's last item
  bool omitTotalPages = false;
  int? fakeTotalPages; // a server claiming more pages than it has
  final requests = <Map<String, dynamic>>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.settingsEmailTemplates && o.method == 'GET') {
      requests.add(Map<String, dynamic>.from(o.queryParameters));
      final page = (o.queryParameters['page'] as int?) ?? 1;
      final size = min((o.queryParameters['page_size'] as int?) ?? 20, 100);
      final gate = holdPages[page];
      if (gate != null) await gate.future;
      if (failPages.remove(page)) {
        return _json({'status': 'error', 'message': 'An unexpected error occurred. Please try again later.', 'data': {}}, 500);
      }
      final pages = max(1, (total / size).ceil());
      var start = (page - 1) * size;
      if (overlap && page > 1) start -= 1;
      final ids = [for (var i = start; i < min(start + size, total); i++) i + 1];
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final id in ids) {
        grouped.putIfAbsent(_types[id % _types.length], () => []).add(tpl(id));
      }
      return _json({
        'status': 'success',
        'message': 'Email templates retrieved successfully.',
        'data': {
          'count': total,
          'page': page,
          'page_size': size,
          if (!omitTotalPages) 'total_pages': fakeTotalPages ?? pages,
          'results': grouped,
        },
      });
    }
    return _json({'status': 'success', 'data': <String, dynamic>{}});
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

const admin = UserEntity(
  id: 'a1',
  email: 'admin@example.test',
  fullName: 'Test Admin',
  role: 'system_admin',
  roleDisplay: 'Admin',
  mustChangePassword: false,
  permissions: ['settings.view', 'settings.edit'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

late Server server;

List<Override> overrides() => [
      authStateProvider.overrideWith(() => _Auth(admin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

ProviderContainer containerFor(Server s) {
  server = s;
  final c = ProviderContainer(overrides: overrides());
  addTearDown(c.dispose);
  c.listen(emailTemplatesProvider, (_, __) {});
  return c;
}

List<int> pagesAsked() => [for (final r in server.requests) r['page'] as int];

Future<void> pumpScreen(WidgetTester tester, Server s) async {
  tester.view.physicalSize = const Size(1080, 20000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s;
  await tester.pumpWidget(screenApp());
  await tester.pumpAndSettle();
}

Widget screenApp() => ProviderScope(
      overrides: overrides(),
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => const EmailTemplatesScreen())]),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('loading every page (notifier)', () {
    test('asks page 1 with page_size 100, then each further page; all templates, in order, once', () async {
      final c = containerFor(Server(250));
      final list = await c.read(emailTemplatesProvider.future);
      final ids = list.map((t) => t.id).toList();
      expect(ids, hasLength(250));
      expect(ids.toSet(), {for (var i = 1; i <= 250; i++) i});
      expect(server.requests, [
        {'page': 1, 'page_size': 100},
        {'page': 2, 'page_size': 100},
        {'page': 3, 'page_size': 100},
      ]);
      final p = c.read(emailTemplatesPagingProvider);
      expect([p.complete, p.loading, p.error, p.total], [true, false, null, 250]);
    });

    test('a single page makes one request; more than 20 is no longer cut off', () async {
      final c = containerFor(Server(42));
      expect(await c.read(emailTemplatesProvider.future), hasLength(42));
      expect(pagesAsked(), [1]);
    });

    test('no templates → empty list, one request, complete', () async {
      final c = containerFor(Server(0));
      expect(await c.read(emailTemplatesProvider.future), isEmpty);
      expect(pagesAsked(), [1]);
      expect(c.read(emailTemplatesPagingProvider).complete, isTrue);
    });

    test('overlapping pages never duplicate a template', () async {
      final c = containerFor(Server(230)..overlap = true);
      final list = await c.read(emailTemplatesProvider.future);
      final ids = list.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.toSet(), {for (var i = 1; i <= 230; i++) i});
    });

    test('a response without total_pages is treated as the last page', () async {
      final c = containerFor(Server(150)..omitTotalPages = true);
      expect(await c.read(emailTemplatesProvider.future), hasLength(100));
      expect(pagesAsked(), [1]);
    });

    test('an empty page ends paging even if total_pages claims more', () async {
      final c = containerFor(Server(120)..fakeTotalPages = 9);
      expect(await c.read(emailTemplatesProvider.future), hasLength(120));
      expect(pagesAsked(), [1, 2, 3], reason: 'page 3 came back empty');
    });

    test('a first-page failure is the provider error (the screen shows its error view)', () async {
      final c = containerFor(Server(50)..failPages.add(1));
      await expectLater(c.read(emailTemplatesProvider.future), throwsA(anything));
    });

    test('a later page failing keeps what loaded; retry resumes from that page only', () async {
      final c = containerFor(Server(250)..failPages.add(2));
      final list = await c.read(emailTemplatesProvider.future);
      expect(list, hasLength(100), reason: 'page 1 is kept');
      var p = c.read(emailTemplatesPagingProvider);
      expect([p.complete, p.error != null, p.total], [false, true, 250]);
      expect(pagesAsked(), [1, 2]);

      await c.read(emailTemplatesProvider.notifier).loadRemaining();
      expect(c.read(emailTemplatesProvider).value, hasLength(250));
      expect(pagesAsked(), [1, 2, 2, 3], reason: 'page 1 is not fetched again');
      p = c.read(emailTemplatesPagingProvider);
      expect([p.complete, p.error], [true, null]);
    });

    test('retry while a retry is running, or after the last page, sends nothing more', () async {
      final s = Server(250)..failPages.add(2);
      final c = containerFor(s);
      await c.read(emailTemplatesProvider.future);
      s.holdPages[2] = Completer();
      final n = c.read(emailTemplatesProvider.notifier);
      final first = n.loadRemaining();
      final second = n.loadRemaining(); // duplicate tap
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(pagesAsked(), [1, 2, 2]);
      s.holdPages[2]!.complete();
      await Future.wait([first, second]);
      expect(pagesAsked(), [1, 2, 2, 3]);
      await n.loadRemaining(); // everything loaded
      expect(pagesAsked(), [1, 2, 2, 3]);
    });

    test('a refresh starts again from page 1', () async {
      final c = containerFor(Server(150));
      await c.read(emailTemplatesProvider.future);
      c.invalidate(emailTemplatesProvider);
      await c.read(emailTemplatesProvider.future);
      expect(pagesAsked(), [1, 2, 1, 2]);
    });

    test('a misbehaving total_pages is capped', () async {
      final s = Server(100000)..fakeTotalPages = 100000;
      final c = containerFor(s);
      final list = await c.read(emailTemplatesProvider.future);
      expect(pagesAsked().last, EmailTemplatesNotifier.maxPages);
      expect(list, hasLength(EmailTemplatesNotifier.maxPages * 100));
    });
  });

  group('screen', () {
    testWidgets('templates beyond the first 20 are listed and searchable', (tester) async {
      await pumpScreen(tester, Server(130));
      expect(find.text('Template 001'), findsOneWidget);
      expect(find.text('Template 130'), findsOneWidget);
      expect(find.byKey(const Key('email-templates-loading-more')), findsNothing);
      expect(find.byKey(const Key('email-templates-load-more-error')), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'template 125');
      await tester.pumpAndSettle();
      expect(find.text('Template 125'), findsOneWidget);
      expect(find.text('Template 001'), findsNothing);
      expect(find.text('1 of 130 templates'), findsOneWidget);
      // search is local — no further requests
      expect(pagesAsked(), [1, 2]);
    });

    testWidgets('the screen keeps its loader until every page has arrived, then lists all', (tester) async {
      final s = Server(130)..holdPages[2] = Completer();
      tester.view.physicalSize = const Size(1080, 20000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = s;
      await tester.pumpWidget(screenApp());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // build() is still awaiting page 2, so the provider is loading: the
      // screen keeps its existing full-screen loader until all pages arrive.
      s.holdPages[2]!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Template 130'), findsOneWidget);
    });

    testWidgets('a later page failing keeps the list and offers Retry, which completes it', (tester) async {
      await pumpScreen(tester, Server(130)..failPages.add(2));
      expect(find.text('Template 100'), findsOneWidget);
      expect(find.text('Template 101'), findsNothing);
      expect(find.byKey(const Key('email-templates-load-more-error')), findsOneWidget);
      expect(find.textContaining('(100 of 130)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('email-templates-load-more-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Template 130'), findsOneWidget);
      expect(find.byKey(const Key('email-templates-load-more-error')), findsNothing);
      expect(pagesAsked(), [1, 2, 2]);
    });

    testWidgets('during a Retry the list stays and a progress line shows; a second tap sends nothing', (tester) async {
      final s = Server(130)..failPages.add(2);
      await pumpScreen(tester, s);
      s.holdPages[2] = Completer();
      await tester.tap(find.byKey(const Key('email-templates-load-more-retry')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('email-templates-loading-more')), findsOneWidget);
      expect(find.textContaining('(100 of 130)'), findsOneWidget);
      expect(find.text('Template 100'), findsOneWidget);
      expect(find.byKey(const Key('email-templates-load-more-retry')), findsNothing);
      s.holdPages[2]!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Template 130'), findsOneWidget);
      expect(pagesAsked(), [1, 2, 2]);
    });

    testWidgets('no templates → the existing empty state', (tester) async {
      await pumpScreen(tester, Server(0));
      expect(find.text('Template 001'), findsNothing);
      expect(find.byKey(const Key('email-templates-load-more-error')), findsNothing);
    });
  });
}

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
import 'package:mobile_app/features/announcements/data/models/announcement_model.dart';
import 'package:mobile_app/features/announcements/presentation/announcement_permissions.dart';
import 'package:mobile_app/features/announcements/presentation/providers/announcement_providers.dart';
import 'package:mobile_app/features/announcements/presentation/widgets/post_announcement_sheet.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// P1-6: branch-scoped announcements, as web dashboard/announcements/page.tsx
// (local branch read; production cross-checked by the earlier audit):
// org-wide posters (settings.edit or superuser) choose "All Branches"
// (visibility=all) or any active branch (visibility=branch); everyone else is
// locked to their own branch — "All Employees" means their branch — and an
// unresolved branch refuses the save; "By Department" sends visibility=
// department with target_branch null; departments are fetched with
// ?branch=<own> for branch-scoped posters. Payload {title, body, category,
// visibility, is_pinned, send_email, target_department, target_branch} to
// POST /announcements/ or PUT /announcements/<id>/. The backend
// (AnnouncementWriteSerializer) does NOT enforce the branch scope.
// Mocked Dio, synthetic data — nothing is posted.

class Server implements HttpClientAdapter {
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];
  final writeTimeouts = <({Duration? send, Duration? receive})>[];
  int? failStatus;
  String failMessage = 'Announcement service is unavailable.';
  DioExceptionType? timeoutType; // throws this for the next write(s)
  Completer<void>? holdWrite;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  List<Map<String, dynamic>> writes(String method) => calls
      .where((c) => c.method == method)
      .map((c) => Map<String, dynamic>.from(c.body as Map))
      .toList();
  Map<String, dynamic> lastQuery(String path) => calls.lastWhere((c) => c.method == 'GET' && c.path == path).query;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    if (o.method == 'POST' || o.method == 'PUT') {
      writeTimeouts.add((send: o.sendTimeout, receive: o.receiveTimeout));
      final gate = holdWrite;
      if (gate != null) await gate.future;
      final t = timeoutType;
      if (t != null) throw DioException(requestOptions: o, type: t);
      if (failStatus != null) {
        return _json({'status': 'error', 'message': failMessage, 'data': {}}, failStatus!);
      }
      final b = Map<String, dynamic>.from(o.data as Map);
      return _json({
        'status': 'success',
        'message': 'Announcement posted.',
        'data': {
          'id': 50,
          ...b,
          'can_edit': true,
          'posted_by_name': 'Test Poster',
          'created_at': '2026-11-09T10:00:00Z',
          'updated_at': '2026-11-09T10:00:00Z',
        }
      }, o.method == 'POST' ? 201 : 200);
    }
    if (o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {
          'count': 2,
          'results': [
            {'id': 1, 'branch_name': 'North', 'branch_code': 'BR-001'},
            {'id': 2, 'branch_name': 'South', 'branch_code': 'BR-002'},
          ]
        }
      });
    }
    if (o.path == ApiConstants.departments) {
      final scoped = o.queryParameters['branch'] == 'North';
      return _json({
        'status': 'success',
        'data': {
          'results': [
            {'id': 11, 'name': 'Ops North'},
            if (!scoped) {'id': 12, 'name': 'Finance HQ'},
          ]
        }
      });
    }
    if (o.path == ApiConstants.announcements) {
      return _json({
        'status': 'success',
        'data': {
          'count': 0,
          'page': 1,
          'page_size': 10,
          'total_pages': 1,
          'pinned_count': 0,
          'total_reactions': 0,
          'total_views': 0,
          'results': []
        }
      });
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

UserEntity user(List<String> perms, {String? branch, bool superuser = false}) => UserEntity(
      id: 'u1',
      email: 'poster@example.test',
      fullName: 'Test Poster',
      role: 'hr',
      roleDisplay: 'HR',
      branch: branch,
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

const posterPerms = ['announcements.view', 'announcements.create', 'announcements.edit', 'announcements.delete'];
final branchHr = user(posterPerms, branch: 'North');
final unresolvedHr = user(posterPerms, branch: 'Nowhere');
final orgAdmin = user([...posterPerms, 'settings.edit'], branch: 'North');
final superuser = user(const [], superuser: true);

Map<String, dynamic> ann(
        {String visibility = 'all', int? branch, int? dept, String title = 'Existing post', bool sendEmail = false}) =>
    {
      'id': 40,
      'title': title,
      'body': 'Existing body',
      'category': 'policy',
      'visibility': visibility,
      'target_branch': branch,
      'target_department': dept,
      'is_pinned': true,
      'send_email': sendEmail,
      'can_edit': true,
      'posted_by_name': 'Test Poster',
      'created_at': '2026-11-01T10:00:00Z',
      'updated_at': '2026-11-01T10:00:00Z',
    };

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> openSheet(WidgetTester tester, UserEntity u, {Map<String, dynamic>? editing, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(u),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          ref.watch(announcementsProvider);
          return Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: PostAnnouncementSheet(
                      editing: editing == null ? null : AnnouncementModel.fromJson(editing), ref: ref),
                ),
              ),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Title *'), 'Branch townhall');
  await tester.enterText(find.widgetWithText(TextFormField, 'Body *'), 'Friday 4pm in the main hall.');
}

Future<void> chooseDropdown(WidgetTester tester, String key, String option) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester, String label) async {
  final btn = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Map<String, dynamic> audience(Map<String, dynamic> b) =>
    {'visibility': b['visibility'], 'target_branch': b['target_branch'], 'target_department': b['target_department']};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('single-branch (branch-scoped) poster', () {
    testWidgets('branch is locked to their own; "All Employees" posts to their branch, never company-wide',
        (tester) async {
      await openSheet(tester, branchHr);
      expect(server.lastQuery(ApiConstants.branches), {'status': 'active', 'page_size': 100});
      expect(byKey('announcement-branch'), findsNothing, reason: 'no branch picker');
      expect(find.descendant(of: byKey('announcement-branch-locked'), matching: find.text('North')), findsOneWidget);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      final b = server.writes('POST').single;
      expect(audience(b), {'visibility': 'branch', 'target_branch': 1, 'target_department': null});
      expect(b.keys, containsAll(['target_department', 'target_branch']), reason: 'web sends both, null when unused');
      expect([b['title'], b['body'], b['category'], b['is_pinned'], b['send_email']],
          ['Branch townhall', 'Friday 4pm in the main hall.', 'general', false, true],
          reason: 'web: a new post starts with Send email on');
    });

    testWidgets('"By Department" lists their branch\'s departments and posts department-wide (no branch)',
        (tester) async {
      await openSheet(tester, branchHr);
      await fill(tester);
      await chooseDropdown(tester, 'announcement-visibility', 'By Department');
      expect(server.lastQuery(ApiConstants.departments), {'page_size': 200, 'branch': 'North'});
      await chooseDropdown(tester, 'announcement-department', 'Ops North');
      expect(find.text('Finance HQ'), findsNothing);
      await submit(tester, 'Post Announcement');
      expect(audience(server.writes('POST').single),
          {'visibility': 'department', 'target_branch': null, 'target_department': 11});
    });

    testWidgets('an unresolved branch refuses the save (no company-wide fallback, no request)', (tester) async {
      await openSheet(tester, unresolvedHr);
      expect(find.descendant(of: byKey('announcement-branch-locked'), matching: find.text('Not assigned')),
          findsOneWidget);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(server.writes('POST'), isEmpty);
      expect(find.text(kAnnouncementBranchUnresolved), findsOneWidget);
      expect(find.text('Post Announcement'), findsWidgets, reason: 'still open');
    });

    testWidgets('editing their own-branch post keeps it on their branch (no scope note)', (tester) async {
      await openSheet(tester, branchHr, editing: ann(visibility: 'branch', branch: 1));
      expect(byKey('announcement-scope-note'), findsNothing);
      await tester.enterText(find.widgetWithText(TextFormField, 'Existing post'), 'Updated post');
      await submit(tester, 'Save Changes');
      final put = server.calls.where((c) => c.method == 'PUT').single;
      expect(put.path, ApiConstants.announcementDetail('40'));
      final b = server.writes('PUT').single;
      expect(audience(b), {'visibility': 'branch', 'target_branch': 1, 'target_department': null});
      expect([b['title'], b['category'], b['is_pinned']], ['Updated post', 'policy', true]);
    });

    testWidgets('editing a company-wide or other-branch post warns and saves it limited to their branch',
        (tester) async {
      await openSheet(tester, branchHr, editing: ann(visibility: 'branch', branch: 2));
      expect(byKey('announcement-scope-note'), findsOneWidget);
      await submit(tester, 'Save Changes');
      expect(audience(server.writes('PUT').single), {'visibility': 'branch', 'target_branch': 1, 'target_department': null});

      await tester.pumpWidget(const SizedBox());
      await openSheet(tester, branchHr, editing: ann());
      expect(byKey('announcement-scope-note'), findsOneWidget);
      await submit(tester, 'Save Changes');
      expect(server.writes('PUT').single['visibility'], 'branch', reason: 'not left company-wide');
    });

    testWidgets('editing a department post keeps the department', (tester) async {
      await openSheet(tester, branchHr, editing: ann(visibility: 'department', dept: 11));
      expect(find.text('Ops North'), findsOneWidget);
      expect(byKey('announcement-scope-note'), findsNothing);
      await submit(tester, 'Save Changes');
      expect(audience(server.writes('PUT').single),
          {'visibility': 'department', 'target_branch': null, 'target_department': 11});
    });
  });

  group('org-wide poster (settings.edit / superuser — the only multi-branch scope)', () {
    testWidgets('defaults to All Branches → company-wide; departments are unfiltered', (tester) async {
      await openSheet(tester, orgAdmin);
      expect(byKey('announcement-branch-locked'), findsNothing);
      expect(find.text('All Branches'), findsOneWidget);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(audience(server.writes('POST').single), {'visibility': 'all', 'target_branch': null, 'target_department': null});
    });

    testWidgets('may target any active branch, including one that is not their own', (tester) async {
      await openSheet(tester, orgAdmin);
      await fill(tester);
      await chooseDropdown(tester, 'announcement-branch', 'South');
      await submit(tester, 'Post Announcement');
      expect(audience(server.writes('POST').single), {'visibility': 'branch', 'target_branch': 2, 'target_department': null});
    });

    testWidgets('department list is company-wide for org-wide posters', (tester) async {
      await openSheet(tester, orgAdmin);
      await chooseDropdown(tester, 'announcement-visibility', 'By Department');
      expect(server.lastQuery(ApiConstants.departments), {'page_size': 200});
      await tester.tap(byKey('announcement-department'));
      await tester.pumpAndSettle();
      expect(find.text('Finance HQ'), findsWidgets);
    });

    testWidgets('editing a branch post preselects that branch and keeps it', (tester) async {
      await openSheet(tester, orgAdmin, editing: ann(visibility: 'branch', branch: 2));
      expect(find.text('South'), findsOneWidget);
      expect(byKey('announcement-scope-note'), findsNothing);
      await submit(tester, 'Save Changes');
      expect(audience(server.writes('PUT').single), {'visibility': 'branch', 'target_branch': 2, 'target_department': null});
    });

    testWidgets('editing a company-wide post keeps it company-wide', (tester) async {
      await openSheet(tester, orgAdmin, editing: ann());
      await submit(tester, 'Save Changes');
      expect(audience(server.writes('PUT').single), {'visibility': 'all', 'target_branch': null, 'target_department': null});
    });

    testWidgets('a superuser is org-wide too', (tester) async {
      await openSheet(tester, superuser);
      expect(byKey('announcement-branch'), findsOneWidget);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(server.writes('POST').single['visibility'], 'all');
    });
  });

  group('provider guard (the backend does not enforce branch scope)', () {
    Future<ProviderContainer> signedIn(UserEntity u) async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(u));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(announcementsProvider, (_, __) {});
      c.listen(announcementBranchesProvider, (_, __) {});
      await c.read(announcementsProvider.future);
      return c;
    }

    AnnouncementFormData form(String visibility, {int? branch, int? dept}) => AnnouncementFormData(
        title: 'T', body: 'B', visibility: visibility, targetBranch: branch, targetDepartment: dept);

    test('a branch-scoped poster cannot post company-wide or to another branch; own branch is allowed', () async {
      final c = await signedIn(branchHr);
      final n = c.read(announcementsProvider.notifier);
      expect(await n.create(form('all')), kAnnouncementOutOfScope);
      expect(await n.create(form('branch', branch: 2)), kAnnouncementOutOfScope);
      expect(await n.edit('40', form('all')), kAnnouncementOutOfScope);
      expect(server.writes('POST'), isEmpty);
      expect(server.writes('PUT'), isEmpty);
      expect(await n.create(form('branch', branch: 1)), isNull);
      expect(await n.create(form('department', dept: 11)), isNull);
      expect(server.writes('POST'), hasLength(2));
    });

    test('an unresolved branch is refused, not turned company-wide', () async {
      final c = await signedIn(unresolvedHr);
      expect(await c.read(announcementsProvider.notifier).create(form('branch', branch: 1)),
          kAnnouncementBranchUnresolved);
      expect(server.writes('POST'), isEmpty);
    });

    test('an org-wide poster may post company-wide or to any branch', () async {
      final c = await signedIn(orgAdmin);
      final n = c.read(announcementsProvider.notifier);
      expect(await n.create(form('all')), isNull);
      expect(await n.create(form('branch', branch: 2)), isNull);
      expect(server.writes('POST').map(audience).toList(), [
        {'visibility': 'all', 'target_branch': null, 'target_department': null},
        {'visibility': 'branch', 'target_branch': 2, 'target_department': null},
      ]);
    });

    test('without announcements.create / .edit the write is refused before any request', () async {
      final c = await signedIn(user(['announcements.view'], branch: 'North'));
      final n = c.read(announcementsProvider.notifier);
      expect(await n.create(form('branch', branch: 1)), kAnnouncementCreateDenied);
      expect(await n.edit('40', form('branch', branch: 1)), kAnnouncementEditDenied);
      expect(server.writes('POST'), isEmpty);
      expect(server.writes('PUT'), isEmpty);
    });

    test('scope helpers: org-wide and own-branch resolution', () {
      const branches = [BranchSimple(id: 1, name: 'North'), BranchSimple(id: 2, name: 'South')];
      expect(isOrgWideAnnouncer(orgAdmin), isTrue);
      expect(isOrgWideAnnouncer(superuser), isTrue);
      expect(isOrgWideAnnouncer(branchHr), isFalse);
      expect(announcementOwnBranchId(branchHr, branches), 1);
      expect(announcementOwnBranchId(unresolvedHr, branches), isNull);
      expect(announcementOwnBranchId(user(posterPerms), branches), isNull);
    });
  });

  group('failure and retry', () {
    testWidgets('a failed save shows the error in the form, keeps every value, and the retry posts them',
        (tester) async {
      await openSheet(tester, branchHr, with_: Server()..failStatus = 500);
      await fill(tester);
      await chooseDropdown(tester, 'announcement-visibility', 'By Department');
      await chooseDropdown(tester, 'announcement-department', 'Ops North');
      await submit(tester, 'Post Announcement');

      expect(tester.widget<Text>(find.descendant(of: byKey('announcement-save-error'), matching: find.byType(Text))).data,
          'Announcement service is unavailable.');
      expect(find.widgetWithText(TextFormField, 'Branch townhall'), findsOneWidget);
      expect(find.text('Ops North'), findsOneWidget);

      server.failStatus = null;
      await submit(tester, 'Post Announcement');
      final posts = server.writes('POST');
      expect(posts, hasLength(2));
      expect(posts.last['title'], 'Branch townhall');
      expect(audience(posts.last), {'visibility': 'department', 'target_branch': null, 'target_department': 11});
      expect(byKey('announcement-save-error'), findsNothing, reason: 'closed on success');
    });
  });

  group('Send email default (web openCreate: send_email = canPost; openEdit keeps the saved value)', () {
    bool emailOn(WidgetTester tester) => tester
        .widget<Switch>(find.descendant(of: byKey('announcement-send-email'), matching: find.byType(Switch)))
        .value;

    Future<void> toggleEmail(WidgetTester tester) async {
      final sw = find.descendant(of: byKey('announcement-send-email'), matching: find.byType(Switch));
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }

    testWidgets('a new announcement starts with Send email on and posts send_email: true', (tester) async {
      await openSheet(tester, orgAdmin);
      expect(emailOn(tester), isTrue);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(server.writes('POST').single['send_email'], isTrue);
    });

    testWidgets('turning it off posts send_email: false', (tester) async {
      await openSheet(tester, orgAdmin);
      await fill(tester);
      await toggleEmail(tester);
      expect(emailOn(tester), isFalse);
      await submit(tester, 'Post Announcement');
      expect(server.writes('POST').single['send_email'], isFalse);
    });

    testWidgets('turning it off and back on explicitly posts send_email: true', (tester) async {
      await openSheet(tester, orgAdmin);
      await fill(tester);
      await toggleEmail(tester);
      await toggleEmail(tester);
      expect(emailOn(tester), isTrue);
      await submit(tester, 'Post Announcement');
      expect(server.writes('POST').single['send_email'], isTrue);
    });

    testWidgets('editing keeps the saved value (off stays off, on stays on)', (tester) async {
      await openSheet(tester, orgAdmin, editing: ann(sendEmail: false));
      expect(emailOn(tester), isFalse, reason: 'not reset to the new-post default');
      await submit(tester, 'Save Changes');
      expect(server.writes('PUT').single['send_email'], isFalse);

      await tester.pumpWidget(const SizedBox());
      await openSheet(tester, orgAdmin, editing: ann(sendEmail: true));
      expect(emailOn(tester), isTrue);
      await submit(tester, 'Save Changes');
      expect(server.writes('PUT').single['send_email'], isTrue);
    });

    testWidgets('editing can switch it on explicitly', (tester) async {
      await openSheet(tester, orgAdmin, editing: ann(sendEmail: false));
      await toggleEmail(tester);
      await submit(tester, 'Save Changes');
      expect(server.writes('PUT').single['send_email'], isTrue);
    });

    testWidgets('branch scope is unchanged with email off: a scoped poster still posts only to their branch',
        (tester) async {
      await openSheet(tester, branchHr);
      await fill(tester);
      await toggleEmail(tester);
      await submit(tester, 'Post Announcement');
      final b = server.writes('POST').single;
      expect(b['send_email'], isFalse);
      expect(audience(b), {'visibility': 'branch', 'target_branch': 1, 'target_department': null});
    });

    testWidgets('branch scope is unchanged with email on: an unresolved branch is still refused', (tester) async {
      await openSheet(tester, unresolvedHr);
      expect(emailOn(tester), isTrue);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(server.writes('POST'), isEmpty);
      expect(find.text(kAnnouncementBranchUnresolved), findsOneWidget);
    });

    testWidgets('a failed save keeps the chosen email setting and the retry sends it', (tester) async {
      await openSheet(tester, orgAdmin, with_: Server()..failStatus = 500);
      await fill(tester);
      await toggleEmail(tester); // off
      await submit(tester, 'Post Announcement');
      expect(byKey('announcement-save-error'), findsOneWidget);
      expect(emailOn(tester), isFalse, reason: 'kept for retry');
      server.failStatus = null;
      await submit(tester, 'Post Announcement');
      final posts = server.writes('POST');
      expect(posts, hasLength(2));
      expect(posts.every((b) => b['send_email'] == false), isTrue);
    });

    test('without announcements.create the form would start with email off (web: send_email = canPost)', () {
      expect(canPostAnnouncements(user(const ['announcements.view'])), isFalse);
      expect(canPostAnnouncements(orgAdmin), isTrue);
    });
  });

  group('save timeout (web: 30 s; "may still have been saved"; no automatic retry)', () {
    Future<void> toggleEmailOff(WidgetTester tester) async {
      final sw = find.descendant(of: byKey('announcement-send-email'), matching: find.byType(Switch));
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }

    String? saveError(WidgetTester tester) {
      final f = find.descendant(of: byKey('announcement-save-error'), matching: find.byType(Text));
      return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
    }

    testWidgets('create and edit requests carry the 30 s send/receive timeout', (tester) async {
      await openSheet(tester, orgAdmin);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      await tester.pumpWidget(const SizedBox());
      final created = server.writeTimeouts.single;
      await openSheet(tester, orgAdmin, editing: ann());
      await submit(tester, 'Save Changes');
      for (final t in [created, server.writeTimeouts.single]) {
        expect(t.send, const Duration(seconds: 30));
        expect(t.receive, const Duration(seconds: 30));
      }
    });

    testWidgets('create timeout: the "may still have been saved" warning, values kept, no automatic retry',
        (tester) async {
      await openSheet(tester, branchHr, with_: Server()..timeoutType = DioExceptionType.receiveTimeout);
      await fill(tester);
      await toggleEmailOff(tester);
      await chooseDropdown(tester, 'announcement-visibility', 'By Department');
      await chooseDropdown(tester, 'announcement-department', 'Ops North');
      await submit(tester, 'Post Announcement');

      expect(saveError(tester), kAnnouncementSaveTimedOut);
      expect(find.textContaining('may still have been saved'), findsOneWidget);
      expect(server.writes('POST'), hasLength(1), reason: 'never resent automatically');
      await tester.pump(const Duration(seconds: 40));
      await tester.pumpAndSettle();
      expect(server.writes('POST'), hasLength(1));
      // everything the user chose is still there
      expect(find.widgetWithText(TextFormField, 'Branch townhall'), findsOneWidget);
      expect(find.text('Ops North'), findsOneWidget);
      expect(
          tester.widget<Switch>(find.descendant(of: byKey('announcement-send-email'), matching: find.byType(Switch))).value,
          isFalse);
      expect(find.widgetWithText(FilledButton, 'Post Announcement'), findsOneWidget, reason: 'form still open');
    });

    testWidgets('edit timeout (send) shows the same warning and keeps the edit', (tester) async {
      await openSheet(tester, orgAdmin,
          editing: ann(visibility: 'branch', branch: 2), with_: Server()..timeoutType = DioExceptionType.sendTimeout);
      await tester.enterText(find.widgetWithText(TextFormField, 'Existing post'), 'Edited during outage');
      await submit(tester, 'Save Changes');
      expect(saveError(tester), kAnnouncementSaveTimedOut);
      expect(server.writes('PUT'), hasLength(1));
      expect(find.widgetWithText(TextFormField, 'Edited during outage'), findsOneWidget);
      expect(find.text('South'), findsOneWidget);
    });

    testWidgets('a connection that never opened is not reported as possibly saved', (tester) async {
      await openSheet(tester, orgAdmin, with_: Server()..timeoutType = DioExceptionType.connectionTimeout);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(saveError(tester), 'The request is taking too long. Please try again.');
      expect(find.textContaining('may still have been saved'), findsNothing);
    });

    testWidgets('while saving: the form is locked (no second request, no close); the user may retry after',
        (tester) async {
      final s = Server()..holdWrite = Completer();
      await openSheet(tester, orgAdmin, with_: s);
      await fill(tester);
      final btn = find.widgetWithText(FilledButton, 'Post Announcement');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump();
      expect(tester.widget<IconButton>(byKey('announcement-close')).onPressed, isNull);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      s.timeoutType = DioExceptionType.receiveTimeout;
      s.holdWrite!.complete();
      s.holdWrite = null;
      await tester.pumpAndSettle();
      expect(s.writes('POST'), hasLength(1));
      expect(saveError(tester), kAnnouncementSaveTimedOut);
      expect(tester.widget<IconButton>(byKey('announcement-close')).onPressed, isNotNull);

      // an explicit second tap by the user is their decision (web allows it)
      s.timeoutType = null;
      await submit(tester, 'Post Announcement');
      expect(s.writes('POST'), hasLength(2));
      expect(byKey('announcement-save-error'), findsNothing, reason: 'saved and closed');
    });

    testWidgets('a normal success still closes the form with no warning', (tester) async {
      await openSheet(tester, orgAdmin);
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(byKey('announcement-save-error'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Post Announcement'), findsNothing);
    });

    testWidgets('a server validation error still shows the server\'s message (not the timeout text)',
        (tester) async {
      await openSheet(tester, orgAdmin,
          with_: Server()
            ..failStatus = 400
            ..failMessage = 'A branch must be selected when visibility is By Branch.');
      await fill(tester);
      await submit(tester, 'Post Announcement');
      expect(saveError(tester), 'A branch must be selected when visibility is By Branch.');
    });

    test('branch scope is checked before sending, so a timing-out server is never reached', () async {
      server = Server()..timeoutType = DioExceptionType.receiveTimeout;
      final c = ProviderContainer(overrides: overrides(branchHr));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(announcementsProvider, (_, __) {});
      c.listen(announcementBranchesProvider, (_, __) {});
      await c.read(announcementsProvider.future);
      final n = c.read(announcementsProvider.notifier);
      expect(await n.create(AnnouncementFormData(title: 'T', body: 'B', visibility: 'all')), kAnnouncementOutOfScope);
      expect(server.writes('POST'), isEmpty);
      expect(await n.create(AnnouncementFormData(title: 'T', body: 'B', visibility: 'branch', targetBranch: 1)),
          kAnnouncementSaveTimedOut);
      expect(server.writes('POST'), hasLength(1));
    });
  });
}

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/referrals/presentation/providers/referral_providers.dart';
import 'package:mobile_app/features/referrals/presentation/widgets/refer_candidate_dialog.dart';

// Task 76: Refer-a-Candidate branch picker.
// Web referrals/page.tsx: picker (required) for usePermission
// ("recruitment.view"), filled from GET /branch/branches/?status=active
// &page_size=100; others see their own branch read-only. Submit:
// POST /recruitment/referrals/ {name, email, phone?, position_applied,
// branch?: <id>, notes?}. Backend: the branch list needs has_perm
// branches.view (and shows only the user's own branch without
// settings.edit); ReferralSubmitSerializer doesn't take `branch` at all, so
// the server never stores or validates it. Mobile: picker for
// recruitment.view + branches.view (superuser / settings.edit pass both);
// no branch-list request for anyone else. Synthetic users and branches; a
// stand-in server applies those rules.

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> branch(int id, String name) => {
      'id': id,
      'branch_code': 'B$id',
      'branch_name': name,
      'address': '',
      'state': 1,
      'state_name': 'State',
      'city': 1,
      'city_name': 'City',
      'status': 'active',
      'is_headquarter': false,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

class Server implements HttpClientAdapter {
  Server(this.u);
  final UserEntity u;
  final branchQueries = <Map<String, dynamic>>[];
  final posts = <Object?>[];
  List<Map<String, dynamic>> branches = [branch(1, 'North Office'), branch(2, 'South Office')];
  String? refuseSubmit;
  bool refuseBranches = false; // the server refusing even a permitted-looking user

  bool _has(String p) => u.isSuperuser || u.permissions.contains('settings.edit') || u.permissions.contains(p);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == '/branch/branches/' && o.method == 'GET') {
      branchQueries.add(Map.of(o.queryParameters));
      if (refuseBranches || !_has('branches.view')) {
        return _json({'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}}, 403);
      }
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {'count': branches.length, 'page': 1, 'total_pages': 1, 'results': branches},
      });
    }
    if (o.path == '/recruitment/referrals/' && o.method == 'POST') {
      posts.add(o.data);
      if (refuseSubmit != null) return _json({'status': 'error', 'message': refuseSubmit, 'data': {}}, 400);
      final d = o.data as Map;
      return _json({
        'status': 'success',
        'message': 'Referral submitted successfully.',
        'data': {
          'id': 101,
          'name': d['name'],
          'email': d['email'],
          'position_applied': d['position_applied'],
          'status': 'pending',
          'created_at': '2026-11-16T09:00:00Z',
        },
      }, 201);
    }
    return _json({'status': 'success', 'message': 'ok', 'data': {'count': 0, 'results': <Object>[]}});
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

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms, {bool superuser = false, String? branch = 'South Office', List<String>? modules}) =>
    UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      branch: branch,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final recruitmentOnly = user(['recruitment.view']);
final branchesOnly = user(['branches.view']);
final both = user(['recruitment.view', 'branches.view']);
final neither = user(['leave.view']);
final superuserOnly = user(const [], superuser: true);
final settingsAdmin = user(['settings.view', 'settings.edit'], superuser: true);
final olderAdmin = user(['settings.view', 'settings.edit']);

late Server server;
final picker = find.byKey(const Key('referral-branch-picker'));

Future<void> pump(WidgetTester tester, UserEntity u,
    {Size size = const Size(1080, 2400), double textScale = 1, void Function(Server)? setup}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(u);
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Consumer(builder: (context, ref, _) {
        ref.watch(authStateProvider);
        return Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(onPressed: () => showReferCandidateDialog(ctx), child: const Text('OPEN')),
            ),
          ),
        );
      }),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  Future<void> enter(String label, String v) async {
    final f = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(f);
    await tester.enterText(f, v);
  }

  await enter('e.g. Rahul Sharma', 'Asha Candidate');
  await enter('candidate@email.com', 'asha.candidate@example.test');
  await enter('e.g. Senior Developer', 'QA Engineer');
  final rel = find.text('Select relationship…').evaluate().isNotEmpty
      ? find.text('Select relationship…')
      : find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(rel.first);
  await tester.tap(rel.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Former Colleague').last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  final btn = find.text('Submit Referral');
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String name) async {
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('who gets the picker (web recruitment.view; backend list: branches.view)', () {
    for (final (label, u, picks) in [
      ('recruitment.view only', recruitmentOnly, false),
      ('branches.view only', branchesOnly, false),
      ('both', both, true),
      ('neither', neither, false),
      ('explicit superuser', superuserOnly, true),
      ('settings.edit admin', settingsAdmin, true),
      ('older admin session (no flag)', olderAdmin, true),
    ]) {
      testWidgets('$label → ${picks ? 'picker' : 'read-only branch, no branch request'}', (tester) async {
        expect(canPickReferralBranch(u), picks);
        await pump(tester, u);
        expect(picker, picks ? findsOneWidget : findsNothing);
        if (picks) {
          expect(server.branchQueries, [
            {'page': 1, 'page_size': 100, 'status': 'active'}
          ]);
        } else {
          expect(find.text('South Office'), findsOneWidget); // own branch, read-only
          expect(server.branchQueries, isEmpty); // never a doomed 403
        }
      });
    }
  });

  group('picker behaviour', () {
    testWidgets('starts on the user\'s own branch; another can be picked; that id is sent', (tester) async {
      await pump(tester, both);
      expect(find.text('South Office'), findsOneWidget); // pre-selected
      await fill(tester);
      await choose(tester, 'North Office');
      await submit(tester);
      expect(server.posts.single, {
        'name': 'Asha Candidate',
        'email': 'asha.candidate@example.test',
        'position_applied': 'QA Engineer',
        'branch': 1,
        'notes': 'Relationship: Former Colleague',
      });
    });

    testWidgets('required: own branch not in the list → must pick; nothing sent until then', (tester) async {
      await pump(tester, user(['recruitment.view', 'branches.view'], branch: 'Elsewhere'));
      await fill(tester);
      await submit(tester);
      expect(find.text('Please select a branch.'), findsOneWidget);
      expect(server.posts, isEmpty);
      await choose(tester, 'South Office');
      await submit(tester);
      expect((server.posts.single as Map)['branch'], 2);
    });

    testWidgets('empty branch list: says so; submission blocked as on web', (tester) async {
      await pump(tester, both, setup: (s) => s.branches = []);
      expect(find.text('No active branches'), findsOneWidget);
      await fill(tester);
      await submit(tester);
      expect(find.text('Please select a branch.'), findsOneWidget);
      expect(server.posts, isEmpty);
    });

    testWidgets('branch list refused by the server: shown, and nothing can be submitted', (tester) async {
      await pump(tester, both, setup: (s) => s.refuseBranches = true);
      expect(server.branchQueries, hasLength(1)); // asked once, refused
      expect(find.text('You do not have permission to do this.'), findsOneWidget); // existing 403 wording
      await fill(tester);
      await submit(tester);
      expect(find.text('Please select a branch.'), findsOneWidget);
      expect(server.posts, isEmpty);
    });

    testWidgets('backend submission refusal is shown in the dialog', (tester) async {
      await pump(tester, both, setup: (s) => s.refuseSubmit = 'This candidate was already referred.');
      await fill(tester);
      await submit(tester);
      expect(find.text('This candidate was already referred.'), findsOneWidget);
      expect(find.byType(ReferCandidateDialog), findsOneWidget); // stays open
    });
  });

  group('existing referral flow without the picker', () {
    for (final (label, u) in [('employee', neither), ('recruitment.view only', recruitmentOnly), ('branches.view only', branchesOnly)]) {
      testWidgets('$label: same payload, no branch sent, no branch request', (tester) async {
        await pump(tester, u);
        await fill(tester);
        await submit(tester);
        expect(server.posts.single, {
          'name': 'Asha Candidate',
          'email': 'asha.candidate@example.test',
          'position_applied': 'QA Engineer',
          'notes': 'Relationship: Former Colleague',
        });
        expect(server.branchQueries, isEmpty);
        expect(find.byType(ReferCandidateDialog), findsNothing); // closed on success
      });
    }
  });

  group('module and layout', () {
    test('recruitment module off: Referrals (and so the dialog) not reachable', () {
      final off = user(const [], superuser: true, modules: const ['leave']);
      expect(canAccessPath(off, AppRoutes.referrals), isFalse);
      expect(canAccessPath(user(const [], superuser: true, modules: const ['recruitment']), AppRoutes.referrals), isTrue);
    });

    for (final (label, scale) in [('×1.0', 1.0), ('×1.5', 1.5), ('×2.0', 2.0)]) {
      testWidgets('360 dp, text $label: picker and a long branch name fit', (tester) async {
        await pump(tester, both, size: const Size(360, 780), textScale: scale, setup: (s) {
          s.branches = [branch(1, 'North Office'), branch(2, 'South Office'), branch(3, 'Regional Headquarters and Training Centre, Bengaluru')];
        });
        expect(tester.takeException(), isNull);
        await choose(tester, 'Regional Headquarters and Training Centre, Bengaluru');
        expect(tester.takeException(), isNull);
      });
    }
  });
}

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
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/screens/interview_list_screen.dart';

// Task 18 (audit A-I1): web interview-list/page.tsx branch filter.
//  - Unrestricted users (isUnrestrictedUser: is_superuser || settings.edit):
//    <select> "All Branches" (default, no param) + active branches
//    "Name (CODE)", loaded once via GET /branch/branches/?status=active&
//    page_size=100; picking one sends ?branch=<id> and restarts at page 1,
//    keeping search and status.
//  - Everyone else: their own branch shown locked; CandidateListCreateView
//    ignores `branch` for them and scopes by their branch name.
// Synthetic data on a stand-in server; nothing is written.

Map<String, dynamic> cand(int id, String name, int branch, {String status = 'pending'}) => {
      'id': id,
      'name': name,
      'email': 'c$id@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': branch,
      'branch_name': branch == 1 ? 'North' : 'South',
      'interview_date': '2026-11-20',
      'interview_mode': 'in_person',
      'status': status,
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': <Object>[],
    };

Map<String, dynamic> branchJson(int id, String name, String code) => {
      'id': id,
      'branch_code': code,
      'branch_name': name,
      'address': '',
      'state': 1,
      'state_name': 'S',
      'city': 1,
      'city_name': 'C',
      'status': 'active',
      'is_headquarter': false,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> all = [
    cand(1, 'Asha North', 1),
    cand(2, 'Bala North', 1, status: 'selected'),
    cand(3, 'Chen South', 2),
    cand(4, 'Dev South', 2, status: 'rejected'),
  ];
  List<Map<String, dynamic>> branches = [branchJson(1, 'North', 'BR-N'), branchJson(2, 'South', 'BR-S')];
  bool failBranches = false;
  Completer<void>? holdBranches;
  final holdByBranch = <String, Completer<void>>{}; // key: branch param or ''
  final listCalls = <Map<String, dynamic>>[];
  final branchCalls = <Map<String, dynamic>>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.branches && o.method == 'GET') {
      branchCalls.add(Map<String, dynamic>.from(o.queryParameters));
      final gate = holdBranches;
      if (gate != null) await gate.future;
      if (failBranches) return _json({'status': 'error', 'message': 'Server error.', 'data': {}}, 500);
      return _json({
        'status': 'success',
        'data': {'count': branches.length, 'results': branches}
      });
    }
    if (o.path == ApiConstants.candidateStats) {
      return _json({'status': 'success', 'data': {'total': all.length}});
    }
    if (o.path == ApiConstants.candidates && o.method == 'GET') {
      final q = Map<String, dynamic>.from(o.queryParameters);
      listCalls.add(q);
      final gate = holdByBranch['${q['branch'] ?? ''}'];
      if (gate != null) await gate.future;
      var rows = all;
      if (q['branch'] != null) rows = rows.where((c) => c['branch'] == q['branch']).toList();
      if (q['status'] != null) rows = rows.where((c) => c['status'] == q['status']).toList();
      final search = '${q['search'] ?? ''}'.toLowerCase();
      if (search.isNotEmpty) rows = rows.where((c) => '${c['name']}'.toLowerCase().contains(search)).toList();
      const size = 10; // backend default page_size
      final page = (q['page'] as int?) ?? 1;
      final pages = rows.isEmpty ? 1 : (rows.length / size).ceil();
      return _json({
        'status': 'success',
        'data': {
          'count': rows.length,
          'page': page,
          'page_size': size,
          'total_pages': pages,
          'status_choices': <Object>[],
          'results': rows.skip((page - 1) * size).take(size).toList(),
        }
      });
    }
    return _json({'status': 'success', 'data': <Object>[]});
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

UserEntity user(List<String> perms, {bool superuser = false, String? branch}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      branch: branch,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final admin = user(const ['recruitment.view', 'recruitment.edit', 'settings.edit']);
final superuser = user(const [], superuser: true);
final branchHr = user(const ['recruitment.view', 'recruitment.edit'], branch: 'North');

late Server server;
late ProviderContainer container;

Future<void> pumpScreen(WidgetTester tester, {UserEntity? as, Server? with_, bool settle = true}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? admin)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: InterviewListScreen()),
  ));
  container = ProviderScope.containerOf(tester.element(find.byType(InterviewListScreen)));
  if (settle) await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> pickBranch(WidgetTester tester, String label) async {
  await tester.tap(byKey('candidate-branch-filter'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

List<String> shownNames() => ['Asha North', 'Bala North', 'Chen South', 'Dev South']
    .where((n) => find.text(n).evaluate().isNotEmpty)
    .toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('who gets the picker (web isUnrestrictedUser)', () {
    test('superuser or settings.edit only', () {
      expect(isUnrestrictedCandidateViewer(admin), isTrue);
      expect(isUnrestrictedCandidateViewer(superuser), isTrue);
      expect(isUnrestrictedCandidateViewer(branchHr), isFalse);
      expect(isUnrestrictedCandidateViewer(null), isFalse);
    });

    testWidgets('a branch-restricted user sees their branch locked; no branch param is sent', (tester) async {
      await pumpScreen(tester, as: branchHr);
      expect(byKey('candidate-branch-locked'), findsOneWidget);
      expect(find.descendant(of: byKey('candidate-branch-locked'), matching: find.text('North')), findsOneWidget);
      expect(byKey('candidate-branch-filter'), findsNothing);
      expect(server.listCalls.every((q) => !q.containsKey('branch')), isTrue);
    });

    testWidgets('a restricted user with no branch shows "—"', (tester) async {
      await pumpScreen(tester, as: user(const ['recruitment.view']));
      expect(find.descendant(of: byKey('candidate-branch-locked'), matching: find.text('—')), findsOneWidget);
    });
  });

  group('options and default', () {
    testWidgets('loads active branches (status=active, page_size=100); default All Branches, no param',
        (tester) async {
      await pumpScreen(tester);
      expect(server.branchCalls.single, {'status': 'active', 'page_size': 100});
      expect(server.listCalls.single.containsKey('branch'), isFalse);
      expect(find.text('All Branches'), findsOneWidget);
      expect(shownNames(), ['Asha North', 'Bala North', 'Chen South', 'Dev South']);
      await tester.tap(byKey('candidate-branch-filter'));
      await tester.pumpAndSettle();
      expect(find.text('North (BR-N)'), findsWidgets);
      expect(find.text('South (BR-S)'), findsWidgets);
    });

    testWidgets('superuser gets the picker too', (tester) async {
      await pumpScreen(tester, as: superuser);
      expect(byKey('candidate-branch-filter'), findsOneWidget);
    });

    testWidgets('while branches load the picker is disabled with a spinner', (tester) async {
      final s = Server()..holdBranches = Completer();
      await pumpScreen(tester, with_: s, settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(byKey('candidate-branch-loading'), findsOneWidget);
      final field = tester.widget<DropdownButton<int?>>(find.descendant(
          of: byKey('candidate-branch-filter'), matching: find.byType(DropdownButton<int?>)));
      expect(field.onChanged, isNull);
      s.holdBranches!.complete();
      await tester.pumpAndSettle();
      expect(byKey('candidate-branch-loading'), findsNothing);
    });

    testWidgets('no active branches → only All Branches', (tester) async {
      await pumpScreen(tester, with_: Server()..branches = []);
      await tester.tap(byKey('candidate-branch-filter'));
      await tester.pumpAndSettle();
      expect(find.text('North (BR-N)'), findsNothing);
      expect(find.text('All Branches'), findsWidgets);
    });

    testWidgets('a branch-list error keeps All Branches usable and offers a retry', (tester) async {
      final s = Server()..failBranches = true;
      await pumpScreen(tester, with_: s);
      expect(byKey('candidate-branch-retry'), findsOneWidget);
      expect(shownNames(), hasLength(4), reason: 'the candidate list is unaffected');
      s.failBranches = false;
      await tester.tap(byKey('candidate-branch-retry'));
      await tester.pumpAndSettle();
      expect(byKey('candidate-branch-retry'), findsNothing);
      expect(s.branchCalls, hasLength(2));
      await pickBranch(tester, 'South (BR-S)');
      expect(shownNames(), ['Chen South', 'Dev South']);
    });
  });

  group('filtering', () {
    testWidgets('picking a branch sends ?branch=<id> (page 1) and shows only it', (tester) async {
      await pumpScreen(tester);
      await pickBranch(tester, 'North (BR-N)');
      expect(server.listCalls.last, {'branch': 1, 'page': 1});
      expect(shownNames(), ['Asha North', 'Bala North']);
    });

    testWidgets('changing and clearing the branch: South, then All Branches drops the param', (tester) async {
      await pumpScreen(tester);
      await pickBranch(tester, 'North (BR-N)');
      await pickBranch(tester, 'South (BR-S)');
      expect(server.listCalls.last['branch'], 2);
      expect(shownNames(), ['Chen South', 'Dev South']);
      await pickBranch(tester, 'All Branches');
      expect(server.listCalls.last.containsKey('branch'), isFalse);
      expect(shownNames(), hasLength(4));
    });

    testWidgets('branch combines with the status tab and the search', (tester) async {
      await pumpScreen(tester);
      await pickBranch(tester, 'South (BR-S)');
      await tester.tap(find.text('Rejected').first);
      await tester.pumpAndSettle();
      expect(server.listCalls.last, {'branch': 2, 'status': 'rejected', 'page': 1});
      expect(shownNames(), ['Dev South']);
      await tester.enterText(byKey('candidate-search'), 'chen');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(server.listCalls.last, {'search': 'chen', 'status': 'rejected', 'branch': 2, 'page': 1});
      // switching branch keeps search and status
      await pickBranch(tester, 'North (BR-N)');
      expect(server.listCalls.last, {'search': 'chen', 'status': 'rejected', 'branch': 1, 'page': 1});
    });

    testWidgets('empty branch → "No candidates in <branch>"', (tester) async {
      final s = Server()..all = [cand(1, 'Asha North', 1)];
      await pumpScreen(tester, with_: s);
      await pickBranch(tester, 'South (BR-S)');
      expect(find.text('No candidates in South'), findsOneWidget);
    });

    testWidgets('rapid changes: a slower earlier branch\'s answer never replaces the newer one', (tester) async {
      final s = Server();
      await pumpScreen(tester, with_: s);
      s.holdByBranch['1'] = Completer();
      // While North is held its spinner never settles, so pick with plain pumps.
      Future<void> pickNoSettle(String label) async {
        await tester.tap(byKey('candidate-branch-filter'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text(label).last);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await pickNoSettle('North (BR-N)'); // held
      expect(server.listCalls.last['branch'], 1);
      await pickNoSettle('South (BR-S)'); // answers at once
      expect(server.listCalls.last['branch'], 2);
      expect(shownNames(), ['Chen South', 'Dev South']);
      s.holdByBranch['1']!.complete(); // North arrives late
      await tester.pumpAndSettle();
      expect(shownNames(), ['Chen South', 'Dev South']);
    });

    testWidgets('the next page keeps the picked branch', (tester) async {
      final s = Server()..all = [for (var i = 1; i <= 14; i++) cand(i, 'South $i', 2), cand(99, 'Asha North', 1)];
      await pumpScreen(tester, with_: s);
      await pickBranch(tester, 'South (BR-S)');
      await tester.runAsync(() => container.read(candidateListProvider.notifier).loadMore());
      await tester.pumpAndSettle();
      expect(s.listCalls.last, {'branch': 2, 'page': 2});
      expect(container.read(candidateListProvider).value!.items, hasLength(14));
    });

    testWidgets('a restricted user never sends a branch, even if one were set', (tester) async {
      await pumpScreen(tester, as: branchHr);
      container.read(candidateBranchFilterProvider.notifier).state = 2;
      await tester.pumpAndSettle();
      expect(server.listCalls, hasLength(greaterThanOrEqualTo(2)), reason: 'the list reloaded');
      expect(server.listCalls.every((q) => !q.containsKey('branch')), isTrue);
    });

    testWidgets('pull-to-refresh keeps the picked branch', (tester) async {
      await pumpScreen(tester);
      await pickBranch(tester, 'North (BR-N)');
      await tester.runAsync(() => container.read(candidateListProvider.notifier).refresh());
      await tester.pumpAndSettle();
      expect(server.listCalls.last['branch'], 1);
      expect(shownNames(), ['Asha North', 'Bala North']);
    });
  });
}

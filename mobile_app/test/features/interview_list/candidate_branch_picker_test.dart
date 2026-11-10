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
import 'package:mobile_app/features/interview_list/data/models/candidate_model.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/add_candidate_sheet.dart';

// Task 29: web AddCandidateModal.tsx / EditCandidateModal.tsx —
// unrestricted = isUnrestrictedUser(user) (lib/auth.ts: is_superuser ||
// settings.edit). Unrestricted → "Branch *" <select> of active branches
// (required); everyone else → their own branch name, disabled/read-only.
// CandidateListCreateView.post → _scoped_candidate_branch overrides the branch
// of any non-settings.edit caller with their own. Creating at all still needs
// canCreate (superuser or own recruitment.create). Stand-in server only.

const candidateId = 7;

Map<String, dynamic> cand({int? branch}) => {
      'id': candidateId,
      'name': 'Existing Person',
      'email': 'existing@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': branch,
      'branch_name': branch == null ? '' : (branch == 1 ? 'North' : 'South'),
      'interview_date': null,
      'interview_mode': 'in_person',
      'status': 'pending',
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': <Object>[],
    };

class Server implements HttpClientAdapter {
  final calls = <String>[];
  final branchQueries = <Map<String, dynamic>>[];
  final writes = <({String method, Map<String, dynamic> body})>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    if (o.method == 'POST' || o.method == 'PUT') {
      final body = Map<String, dynamic>.from(o.data as Map);
      writes.add((method: o.method, body: body));
      return _json({'status': 'success', 'data': {...cand(branch: body['branch'] as int?), ...body, 'id': 99}}, 201);
    }
    if (o.path == ApiConstants.branches) {
      branchQueries.add(Map<String, dynamic>.from(o.queryParameters));
      return _json({
        'status': 'success',
        'data': {
          'results': [
            {'id': 1, 'branch_name': 'North', 'branch_code': 'BR-N'},
            {'id': 2, 'branch_name': 'South', 'branch_code': 'BR-S'},
          ]
        }
      });
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {'count': 0, 'page': 1, 'page_size': 10, 'total_pages': 1, 'status_choices': <Object>[], 'results': <Object>[]}
      });
    }
    return _json({'status': 'success', 'data': {'results': <Object>[]}});
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

UserEntity user(List<String> perms, {bool superuser = false, String? branch = 'North'}) => UserEntity(
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

final superuser = user(const [], superuser: true, branch: null);
final createAndSettings = user(const ['recruitment.view', 'recruitment.create', 'settings.edit']);
final createOnly = user(const ['recruitment.view', 'recruitment.create']);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);
final noCreate = user(const ['recruitment.view']);
final editOnly = user(const ['recruitment.view', 'recruitment.edit']);
final editAndSettings = user(const ['recruitment.view', 'recruitment.edit', 'settings.edit']);

late Server server;

Future<void> openForm(WidgetTester tester, UserEntity u, {Map<String, dynamic>? existing}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Consumer(builder: (_, ref, __) {
        ref.watch(authStateProvider);
        ref.watch(candidateListProvider);
        return Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      AddCandidateDialog(existing: existing == null ? null : CandidateModel.fromJson(existing)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
      }),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Finder get lockedField => find.byKey(const Key('candidate-branch-locked-field'));
String lockedText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: lockedField, matching: find.byType(Text))).data!;
bool get branchListRequested => server.calls.contains('GET ${ApiConstants.branches}');

Future<void> fillBasics(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Anjali Sharma'), 'New Person');
  await tester.enterText(find.widgetWithText(TextFormField, 'anjali@gmail.com'), 'new@example.test');
  await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Backend Engineer'), 'Analyst');
}

Future<void> pickBranch(WidgetTester tester, String name) async {
  final hint = find.text('— Select branch —');
  await tester.ensureVisible(hint);
  await tester.tap(hint);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, String label) async {
  final b = find.text(label).last;
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Add Candidate', () {
    for (final (name, u) in [('superuser', superuser), ('recruitment.create + settings.edit', createAndSettings)]) {
      testWidgets('$name: picker open (active branches), a branch is required, and the picked one is sent',
          (tester) async {
        await openForm(tester, u);
        expect(lockedField, findsNothing);
        expect(server.branchQueries.single, {'status': 'active', 'page_size': 100});
        await fillBasics(tester);
        await save(tester, 'Add to List');
        expect(find.text('Please select a branch'), findsOneWidget);
        expect(server.writes, isEmpty);
        await pickBranch(tester, 'South');
        await save(tester, 'Add to List');
        expect(server.writes.single.method, 'POST');
        expect(server.writes.single.body['branch'], 2);
      });
    }

    testWidgets('recruitment.create without settings.edit: own branch shown locked; no branch list; '
        'no branch sent (the server sets it)', (tester) async {
      await openForm(tester, createOnly);
      expect(lockedField, findsOneWidget);
      expect(lockedText(tester), 'North');
      expect(find.text('— Select branch —'), findsNothing);
      expect(branchListRequested, isFalse);
      await fillBasics(tester);
      await save(tester, 'Add to List');
      expect(find.text('Please select a branch'), findsNothing);
      expect(server.writes.single.method, 'POST');
      expect(server.writes.single.body.containsKey('branch'), isFalse);
      expect(branchListRequested, isFalse);
    });

    testWidgets('a restricted creator with no branch on their account sees "—"', (tester) async {
      await openForm(tester, user(const ['recruitment.create'], branch: null));
      expect(lockedText(tester), '—');
    });

    for (final (name, u) in [('no create permission', noCreate), ('settings.edit only (no recruitment.create)', settingsOnly)]) {
      testWidgets('$name: cannot open the form; no requests at all', (tester) async {
        await openForm(tester, u);
        expect(find.byKey(const Key('add-candidate-denied')), findsOneWidget);
        expect(server.calls.where((c) => c.contains('/branch/') || c.startsWith('POST')), isEmpty);
      });
    }
  });

  group('Edit (existing behaviour, now on the web lock rule)', () {
    testWidgets('restricted editor, candidate with no branch: own branch filled and sent (as before)', (tester) async {
      await openForm(tester, editOnly, existing: cand());
      expect(lockedField, findsOneWidget);
      await save(tester, 'Save Changes');
      expect(server.writes.single.method, 'PUT');
      expect(server.writes.single.body['branch'], 1);
    });

    testWidgets('restricted editor, candidate already in a branch: branch kept and sent', (tester) async {
      await openForm(tester, editOnly, existing: cand(branch: 2));
      await save(tester, 'Save Changes');
      expect(server.writes.single.body['branch'], 2);
    });

    testWidgets('settings.edit editor: picker open on the candidate\'s branch and changeable', (tester) async {
      await openForm(tester, editAndSettings, existing: cand(branch: 1));
      expect(lockedField, findsNothing);
      final current = find.text('North');
      await tester.ensureVisible(current.first);
      await tester.tap(current.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('South').last);
      await tester.pumpAndSettle();
      await save(tester, 'Save Changes');
      expect(server.writes.single.body['branch'], 2);
    });
  });

  group('rule', () {
    test('unrestricted = superuser or settings.edit (web isUnrestrictedUser)', () {
      expect(isUnrestrictedCandidateViewer(superuser), isTrue);
      expect(isUnrestrictedCandidateViewer(createAndSettings), isTrue);
      expect(isUnrestrictedCandidateViewer(settingsOnly), isTrue);
      expect(isUnrestrictedCandidateViewer(createOnly), isFalse);
      expect(isUnrestrictedCandidateViewer(user(const ['recruitment.create'])), isFalse);
      // a system_admin *role name* alone no longer unlocks it
      expect(
          isUnrestrictedCandidateViewer(const UserEntity(
              id: 'x',
              email: 'a@example.test',
              fullName: 'A',
              role: 'system_admin',
              roleDisplay: 'Admin',
              mustChangePassword: false,
              permissions: ['recruitment.create'],
              onboardingStatus: 'complete',
              assessmentStatus: 'complete')),
          isFalse);
    });
  });
}

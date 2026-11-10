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
import 'package:mobile_app/features/interview_list/presentation/screens/interview_list_screen.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/add_candidate_sheet.dart';

// Task 21: web interview-list page renders "Add Candidate" (AddCandidateModal,
// a modal — no route) only when canCreate = usePermission("recruitment.create")
// → is_superuser || own permission; settings.edit alone does NOT count on web.
// The backend POST /recruitment/candidates/ also requires recruitment.create.
// Stand-in server; no real candidate is created.

Map<String, dynamic> cand(int id, String name) => {
      'id': id,
      'name': name,
      'email': 'c$id@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': 1,
      'branch_name': 'North',
      'interview_date': '2026-12-01',
      'interview_mode': 'in_person',
      'status': 'pending',
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': <Object>[],
    };

class Server implements HttpClientAdapter {
  final calls = <String>[];
  final posts = <Map<String, dynamic>>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    if (o.path == ApiConstants.candidates && o.method == 'POST') {
      final body = Map<String, dynamic>.from(o.data as Map);
      posts.add(body);
      return _json({'status': 'success', 'message': 'Candidate added.', 'data': cand(50, body['name'] as String)}, 201);
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {'count': 1, 'page': 1, 'page_size': 10, 'total_pages': 1, 'status_choices': <Object>[], 'results': [cand(1, 'Existing One')]}
      });
    }
    if (o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {
          'results': [
            {'id': 1, 'branch_name': 'North', 'branch_code': 'BR-N'}
          ]
        }
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      branch: 'North',
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final creator = user(const ['recruitment.view', 'recruitment.create']);
final viewer = user(const ['recruitment.view']);
final editorOnly = user(const ['recruitment.view', 'recruitment.edit']);
final superuser = user(const [], superuser: true);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, Widget home, UserEntity u) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(u),
    child: MaterialApp(
      home: Consumer(builder: (_, ref, child) {
        ref.watch(authStateProvider);
        ref.watch(candidateListProvider);
        return child!;
      }, child: home),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Opens the dialog the way the menu does (showDialog from a button).
Widget opener(Widget dialog) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () => showDialog(context: context, builder: (_) => dialog),
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rule (web canCreate)', () {
    test('recruitment.create or superuser; view, edit-only and settings.edit-only are not enough', () {
      expect(canCreateCandidates(creator), isTrue);
      expect(canCreateCandidates(superuser), isTrue);
      expect(canCreateCandidates(viewer), isFalse);
      expect(canCreateCandidates(editorOnly), isFalse);
      expect(canCreateCandidates(settingsOnly), isFalse);
      expect(canCreateCandidates(null), isFalse);
      expect(canOpenCandidateBulkImport(creator), canCreateCandidates(creator), reason: 'same web rule');
    });
  });

  group('menu entry (Interview List quick actions)', () {
    for (final (name, u) in [('creator', creator), ('superuser', superuser)]) {
      testWidgets('$name sees Add Candidate', (tester) async {
        await pump(tester, const InterviewListScreen(), u);
        await tester.tap(find.byType(FloatingActionButton).first);
        await tester.pumpAndSettle();
        expect(find.text('Add Candidate'), findsOneWidget);
        // close again (the shared menu must not be torn down while open)
        await tester.tap(find.byType(FloatingActionButton).first, warnIfMissed: false);
        await tester.pumpAndSettle();
      });
    }

    for (final (name, u) in [('view-only', viewer), ('edit-only', editorOnly), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: no quick-action button, no Add Candidate', (tester) async {
        await pump(tester, const InterviewListScreen(), u);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Add Candidate'), findsNothing);
      });
    }
  });

  group('form opened directly (create mode)', () {
    for (final (name, u) in [('view-only', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: a "no permission" dialog — no form, no requests', (tester) async {
        await pump(tester, opener(const AddCandidateDialog()), u);
        server.calls.clear();
        await openDialog(tester);
        expect(find.byKey(const Key('add-candidate-denied')), findsOneWidget);
        expect(find.text(kCandidateCreateDenied), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(server.calls, isEmpty, reason: 'not even the branch list');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('add-candidate-denied')), findsNothing);
      });
    }

    testWidgets('creator: the normal form (branch locked to their own — no branch list needed)', (tester) async {
      await pump(tester, opener(const AddCandidateDialog()), creator);
      server.calls.clear();
      await openDialog(tester);
      expect(find.byKey(const Key('add-candidate-denied')), findsNothing);
      expect(find.byType(TextFormField), findsWidgets);
      expect(server.calls, isNot(contains('GET ${ApiConstants.branches}')));
    });

    testWidgets('edit mode is unaffected (recruitment.edit without create still edits)', (tester) async {
      await pump(tester, opener(AddCandidateDialog(existing: CandidateModel.fromJson(cand(1, 'Existing One')))), editorOnly);
      await openDialog(tester);
      expect(find.byKey(const Key('add-candidate-denied')), findsNothing);
      expect(find.byType(TextFormField), findsWidgets);
    });
  });

  group('the create action itself', () {
    Future<(Object?, Server, WidgetRef)> attempt(WidgetTester tester, UserEntity u) async {
      server = Server();
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(u),
        child: Consumer(builder: (_, ref, __) {
          captured = ref;
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      Object? error;
      await tester.runAsync(() async {
        try {
          await captured.read(candidateListProvider.notifier).addCandidate({
            'name': 'New Person',
            'email': 'new.person@example.test',
            'position_applied': 'Analyst',
            'branch': 1,
          });
        } catch (e) {
          error = e;
        }
      });
      return (error, server, captured);
    }

    for (final (name, u) in [('view-only', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: refused before any POST', (tester) async {
        final (err, s, _) = await attempt(tester, u);
        expect(err, isA<CandidateCreateDenied>());
        expect('$err', kCandidateCreateDenied);
        expect(s.posts, isEmpty);
      });
    }

    for (final (name, u) in [('creator', creator), ('superuser', superuser)]) {
      testWidgets('$name: one POST with the payload as given; the list gains it', (tester) async {
        final (err, s, ref) = await attempt(tester, u);
        expect(err, isNull);
        expect(s.posts.single, {
          'name': 'New Person',
          'email': 'new.person@example.test',
          'position_applied': 'Analyst',
          'branch': 1,
        });
        expect(ref.read(candidateListProvider).value!.items.first.name, 'New Person');
      });
    }
  });
}

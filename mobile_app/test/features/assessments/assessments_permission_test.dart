import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/assessments/data/models/assessment_model.dart';
import 'package:mobile_app/features/assessments/presentation/providers/assessments_providers.dart';
import 'package:mobile_app/features/assessments/presentation/screens/assessments_screen.dart';
import 'package:mobile_app/features/assessments/presentation/screens/my_assessments_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 23 (audit A-AS1): web assessments/page.tsx (usePermission /
// useAnyPermission: superuser or own codename, no settings.edit bypass):
//   isAdminView = any of assessments.view/create/edit/delete, else the
//     employee's "My Assessments";
//   New / Create Assessment → assessments.create;
//   Sections, Assign, Edit → assessments.edit; Delete → assessments.delete;
//   Results → everyone on the management view.
// Backend apps/assessments/views/admin.py checks the same codenames.
// Stand-in server; nothing is created, assigned or deleted for real.

Map<String, dynamic> assessment(String id, String title) => {
      'id': id,
      'title': title,
      'description': 'Synthetic assessment',
      'is_active': true,
      'is_default': false,
      'pass_percentage': 70,
      'max_attempts': null,
      'effective_max_attempts': 3,
      'time_limit_mins': null,
      'effective_time_limit_mins': null,
      'item_count': 0,
      'candidates': <Object>[],
    };

class Server implements HttpClientAdapter {
  Server({this.list = const []});
  final List<Map<String, dynamic>> list;
  final calls = <String>[];

  int count(String method, String path) => calls.where((c) => c == '$method $path').length;
  List<String> get writes => calls.where((c) => !c.startsWith('GET ')).toList();

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add('${o.method} ${o.path}');
    if (o.method == 'GET' && o.path == ApiConstants.assessments) {
      return _json({'status': 'success', 'data': {'count': list.length, 'results': list}});
    }
    if (o.method == 'GET' && o.path == ApiConstants.assessmentsMy) {
      return _json({'status': 'success', 'data': <Object>[]});
    }
    if (o.method == 'POST' && o.path == ApiConstants.assessments) {
      return _json({'status': 'success', 'data': assessment('new', 'Created')}, 201);
    }
    if (o.method == 'PUT' && o.path.startsWith('/assessments/')) {
      return _json({'status': 'success', 'data': assessment('a1', 'Edited')});
    }
    if (o.method == 'DELETE' || (o.method == 'POST' && o.path == ApiConstants.assessmentAssign)) {
      return _json({'status': 'success', 'data': <String, dynamic>{}});
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
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final viewOnly = user(const ['assessments.view']);
final viewEdit = user(const ['assessments.view', 'assessments.edit']);
final viewCreate = user(const ['assessments.view', 'assessments.create']);
final viewDelete = user(const ['assessments.view', 'assessments.delete']);
final full = user(const ['assessments.view', 'assessments.create', 'assessments.edit', 'assessments.delete']);
final superuser = user(const [], superuser: true);
final settingsOnly = user(const ['settings.edit', 'settings.view']);
final employee = user(const []);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pumpScreen(WidgetTester tester, UserEntity u, {List<Map<String, dynamic>>? list}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(list: list ?? [assessment('a1', 'Aptitude Test')]);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(u),
    child: MaterialApp(
      home: Consumer(builder: (_, ref, child) {
        ref.watch(authStateProvider);
        return child!;
      }, child: const AssessmentsScreen()),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
bool shows(String text) => find.text(text).evaluate().isNotEmpty;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web usePermission / useAnyPermission)', () {
    test('management view: any assessments.* codename or superuser; settings.edit alone is not enough', () {
      for (final u in [viewOnly, viewEdit, viewCreate, viewDelete, full, superuser,
        user(const ['assessments.create']), user(const ['assessments.edit']), user(const ['assessments.delete'])]) {
        expect(canManageAssessmentsView(u), isTrue, reason: '${u.permissions}');
      }
      expect(canManageAssessmentsView(settingsOnly), isFalse);
      expect(canManageAssessmentsView(employee), isFalse);
      expect(canManageAssessmentsView(null), isFalse);
    });

    test('each action has its own codename', () {
      expect([canCreateAssessments(viewCreate), canEditAssessments(viewCreate), canDeleteAssessments(viewCreate)],
          [true, false, false]);
      expect([canCreateAssessments(viewEdit), canEditAssessments(viewEdit), canDeleteAssessments(viewEdit)],
          [false, true, false]);
      expect([canCreateAssessments(viewDelete), canEditAssessments(viewDelete), canDeleteAssessments(viewDelete)],
          [false, false, true]);
      expect([canCreateAssessments(superuser), canEditAssessments(superuser), canDeleteAssessments(superuser)],
          [true, true, true]);
      expect([canCreateAssessments(settingsOnly), canEditAssessments(settingsOnly), canDeleteAssessments(settingsOnly)],
          [false, false, false]);
    });

    test('route: any assessments.* codename', () {
      expect(requiredPermissionsFor(AppRoutes.assessments),
          ['assessments.view', 'assessments.create', 'assessments.edit', 'assessments.delete']);
      expect(canAccessPath(user(const ['assessments.edit']), AppRoutes.assessments), isTrue);
      expect(canAccessPath(employee, AppRoutes.assessments), isFalse);
    });
  });

  group('screen and per-action visibility', () {
    testWidgets('view-only: list and Results; no New, Items, Assign, Edit or Delete', (tester) async {
      await pumpScreen(tester, viewOnly);
      expect(shows('Aptitude Test'), isTrue);
      expect(shows('Results'), isTrue);
      for (final t in ['New Assessment', 'Items', 'Assign']) {
        expect(shows(t), isFalse, reason: t);
      }
      expect(byKey('assessment-edit'), findsNothing);
      expect(byKey('assessment-delete'), findsNothing);
    });

    testWidgets('view + edit: Items, Assign, Edit; no New or Delete', (tester) async {
      await pumpScreen(tester, viewEdit);
      expect([shows('Items'), shows('Assign')], [true, true]);
      expect(byKey('assessment-edit'), findsOneWidget);
      expect(byKey('assessment-delete'), findsNothing);
      expect(shows('New Assessment'), isFalse);
    });

    testWidgets('view + create: New Assessment only', (tester) async {
      await pumpScreen(tester, viewCreate);
      expect(shows('New Assessment'), isTrue);
      expect([shows('Items'), shows('Assign')], [false, false]);
      expect(byKey('assessment-edit'), findsNothing);
      expect(byKey('assessment-delete'), findsNothing);
    });

    testWidgets('view + delete: Delete only', (tester) async {
      await pumpScreen(tester, viewDelete);
      expect(byKey('assessment-delete'), findsOneWidget);
      expect(byKey('assessment-edit'), findsNothing);
      expect(shows('New Assessment'), isFalse);
    });

    for (final (name, u) in [('all four codenames', full), ('superuser', superuser)]) {
      testWidgets('$name: every action', (tester) async {
        await pumpScreen(tester, u);
        expect([shows('New Assessment'), shows('Items'), shows('Assign'), shows('Results')], [true, true, true, true]);
        expect(byKey('assessment-edit'), findsOneWidget);
        expect(byKey('assessment-delete'), findsOneWidget);
      });
    }

    for (final (name, u) in [('settings.edit only', settingsOnly), ('employee', employee)]) {
      testWidgets('$name: "My Assessments" instead — the management list is never requested', (tester) async {
        await pumpScreen(tester, u);
        expect(find.byType(MyAssessmentsScreen), findsOneWidget);
        expect(shows('Aptitude Test'), isFalse);
        expect(server.count('GET', ApiConstants.assessments), 0);
      });
    }

    testWidgets('empty list: Create Assessment only with assessments.create', (tester) async {
      await pumpScreen(tester, viewOnly, list: const []);
      expect(shows('No assessments yet'), isTrue);
      expect(shows('Create Assessment'), isFalse);
    });

    testWidgets('empty list with assessments.create: Create Assessment shown', (tester) async {
      await pumpScreen(tester, viewCreate, list: const []);
      expect(shows('Create Assessment'), isTrue);
    });
  });

  group('the actions themselves', () {
    Future<(WidgetRef, Server)> host(WidgetTester tester, UserEntity u) async {
      server = Server(list: [assessment('a1', 'Aptitude Test')]);
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: overrides(u),
        child: Consumer(builder: (_, ref, __) {
          captured = ref;
          ref.watch(authStateProvider);
          ref.watch(assessmentsProvider);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      return (captured, server);
    }

    Future<List<String?>> runAll(WidgetTester tester, WidgetRef ref) async {
      final n = ref.read(assessmentsProvider.notifier);
      final form = AssessmentFormData(title: 'T');
      final out = <String?>[];
      await tester.runAsync(() async {
        out.add(await n.createAssessment(form));
        out.add(await n.editAssessment('a1', form));
        out.add(await assignCandidateToAssessment(ref,
            candidateId: 'e1', assessmentId: 'a1', templateName: 'assessment_assigned'));
        out.add(await n.removeAssessment('a1'));
      });
      return out;
    }

    testWidgets('view-only: create, edit, assign and delete are refused before any request', (tester) async {
      final (ref, s) = await host(tester, viewOnly);
      expect(await runAll(tester, ref), List.filled(4, kAssessmentEditDenied));
      expect(s.writes, isEmpty);
    });

    testWidgets('settings.edit only: refused too (no bypass on web)', (tester) async {
      final (ref, s) = await host(tester, settingsOnly);
      expect(await runAll(tester, ref), List.filled(4, kAssessmentEditDenied));
      expect(s.writes, isEmpty);
    });

    testWidgets('each codename unlocks only its own action', (tester) async {
      final (ref, s) = await host(tester, viewEdit);
      expect(await runAll(tester, ref), [kAssessmentEditDenied, null, null, kAssessmentEditDenied]);
      expect(s.writes, ['PUT ${ApiConstants.assessmentDetail('a1')}', 'POST ${ApiConstants.assessmentAssign}']);
    });

    for (final (name, u) in [('all four codenames', full), ('superuser', superuser)]) {
      testWidgets('$name: every action goes through', (tester) async {
        final (ref, s) = await host(tester, u);
        expect(await runAll(tester, ref), [null, null, null, null]);
        expect(s.writes, [
          'POST ${ApiConstants.assessments}',
          'PUT ${ApiConstants.assessmentDetail('a1')}',
          'POST ${ApiConstants.assessmentAssign}',
          'DELETE ${ApiConstants.assessmentDetail('a1')}',
        ]);
      });
    }
  });
}

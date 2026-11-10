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
import 'package:mobile_app/features/candidate_review/data/models/approval_model.dart';
import 'package:mobile_app/features/candidate_review/presentation/screens/candidate_review_screen.dart';

// Task 26: web candidate-review/page.tsx — the Branch column (header + cell,
// `row.branch || "—"`) renders only when `currentUser?.is_superuser === true`;
// no permission grants it. The API returns `branch` for everyone, and the
// review drawer (OnboardingDrawer.tsx, Basic Info) shows Branch to anyone who
// can open it. Stand-in server; nothing is approved or rejected.

Map<String, dynamic> applicant(String id, String name, String branch) => {
      'id': id,
      'full_name': name,
      'email': '$id@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': branch,
      'role_name': '',
      'role_display': '',
      'employee_id': '',
      'date_of_joining': null,
      'onboarding_status': 'submitted',
      'date_joined': '2026-11-01T10:00:00Z',
      'candidate_id': 9,
      'position_applied': 'Engineer',
      'profile': <String, dynamic>{},
      'documents': <Object>[],
    };

final rows = [applicant('u1', 'Asha Test', 'North Branch'), applicant('u2', 'Bala Test', '')];

class Server implements HttpClientAdapter {
  final writes = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') writes.add('${o.method} ${o.path}');
    final Object data = o.path == ApiConstants.onboardingApprovals
        ? {'count': rows.length, 'results': rows}
        : {'results': <Object>[]};
    return ResponseBody.fromString(jsonEncode({'status': 'success', 'data': data}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
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

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'hr1',
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

final superuser = user(const [], superuser: true);
final onboardingApprover = user(const ['recruitment.view', 'onboarding.approve']);
final employeesApprover = user(const ['recruitment.view', 'employees.approve']);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);

late Server server;

Future<void> pumpScreen(WidgetTester tester, UserEntity u) async {
  tester.view.physicalSize = const Size(1080, 3200);
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
      home: Consumer(builder: (_, ref, child) {
        ref.watch(authStateProvider);
        return child!;
      }, child: const Scaffold(body: CandidateReviewScreen())),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
String branchShown(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: byKey('review-branch-$id'), matching: find.byType(Text))).data!;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('superuser sees each row\'s branch, "—" when it has none', (tester) async {
    await pumpScreen(tester, superuser);
    expect(branchShown(tester, 'u1'), 'North Branch');
    expect(branchShown(tester, 'u2'), '—');
  });

  for (final (name, u) in [
    ('onboarding.approve', onboardingApprover),
    ('employees.approve', employeesApprover),
    ('settings.edit only', settingsOnly),
  ]) {
    testWidgets('$name: no branch on the rows', (tester) async {
      await pumpScreen(tester, u);
      expect(byKey('review-branch-u1'), findsNothing);
      expect(byKey('review-branch-u2'), findsNothing);
      expect(find.text('North Branch'), findsNothing);
      // the rest of the row is unchanged
      expect(find.text('Asha Test'), findsOneWidget);
      expect(find.text('Engineer'), findsWidgets);
    });
  }

  testWidgets('an approver\'s Review still works, and the review sheet still shows Branch (as web)', (tester) async {
    await pumpScreen(tester, onboardingApprover);
    expect(byKey('review-button-u1'), findsOneWidget);
    await tester.tap(byKey('review-button-u1'));
    await tester.pumpAndSettle();
    expect(find.text('Review — Asha Test'), findsOneWidget);
    expect(find.text('North Branch'), findsOneWidget, reason: 'web OnboardingDrawer shows Branch to every reviewer');
    expect(server.writes, isEmpty);
  });

  test('branch stays in the model for everyone', () {
    expect(ApprovalUser.fromJson(rows.first).branch, 'North Branch');
  });
}

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
import 'package:mobile_app/features/candidate_review/presentation/providers/approval_providers.dart';
import 'package:mobile_app/features/candidate_review/presentation/screens/candidate_review_screen.dart';

// Task 22 (audit A-C1): web candidate-review/page.tsx — per row:
//   onboarding_status === "rejected" → "Awaiting resubmission" badge (anyone)
//   else canApprove (usePermission("employees.approve") ||
//        usePermission("onboarding.approve"); superuser passes; no
//        settings.edit bypass) → "Review"
//   else nothing.
// OnboardingApprovalView (GET/POST /onboarding/approvals/…) requires
// onboarding.approve server-side. Stand-in server; no decision is real.

Map<String, dynamic> applicant(String id, String name, String status) => {
      'id': id,
      'full_name': name,
      'email': '$id@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Test Branch',
      'role_name': '',
      'role_display': '',
      'employee_id': '',
      'date_of_joining': null,
      'onboarding_status': status,
      'date_joined': '2026-11-01T10:00:00Z',
      'candidate_id': 9,
      'position_applied': 'Engineer',
      'profile': <String, dynamic>{},
      'documents': <Object>[],
    };

class Server implements HttpClientAdapter {
  Server(this.rows);
  final List<Map<String, dynamic>> rows;
  final posts = <({String path, Map<String, dynamic> body})>[];
  int postStatus = 200;
  final paths = <String>[];

  ResponseBody _json(int status, Object b) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add('${o.method} ${o.path}');
    if (o.method == 'POST' && o.path.startsWith(ApiConstants.onboardingApprovals)) {
      posts.add((path: o.path, body: Map<String, dynamic>.from(o.data as Map)));
      if (postStatus != 200) {
        return _json(postStatus, {'status': 'error', 'message': 'This user has not submitted their onboarding form.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'message': 'Onboarding rejected.', 'data': {}});
    }
    if (o.path == ApiConstants.onboardingApprovals) {
      return _json(200, {
        'status': 'success',
        'data': {'count': rows.length, 'results': rows}
      });
    }
    return _json(200, {'status': 'success', 'data': {'results': <Object>[]}});
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

final onboardingApprover = user(const ['recruitment.view', 'onboarding.approve']);
final employeesApprover = user(const ['recruitment.view', 'employees.approve']);
final superuser = user(const [], superuser: true);
final viewer = user(const ['recruitment.view']);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);

final rows = [
  applicant('u1', 'Asha Submitted', 'submitted'),
  applicant('u2', 'Bala Revision', 'rejected'),
  applicant('u3', 'Chen Approved', 'approved'),
];

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pumpScreen(WidgetTester tester, UserEntity u) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(rows);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(u),
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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rule (web canApprove)', () {
    test('employees.approve, onboarding.approve or superuser; settings.edit alone is not enough', () {
      expect(canReviewOnboarding(onboardingApprover), isTrue);
      expect(canReviewOnboarding(employeesApprover), isTrue);
      expect(canReviewOnboarding(superuser), isTrue);
      expect(canReviewOnboarding(viewer), isFalse);
      expect(canReviewOnboarding(settingsOnly), isFalse);
      expect(canReviewOnboarding(null), isFalse);
    });

    test('only a sent-back (rejected) row awaits resubmission', () {
      expect(isAwaitingResubmission(ApprovalUser.fromJson(applicant('a', 'A', 'rejected'))), isTrue);
      expect(isAwaitingResubmission(ApprovalUser.fromJson(applicant('a', 'A', 'submitted'))), isFalse);
      expect(isAwaitingResubmission(ApprovalUser.fromJson(applicant('a', 'A', 'approved'))), isFalse);
    });
  });

  group('row actions', () {
    for (final (name, u) in [
      ('onboarding.approve', onboardingApprover),
      ('employees.approve', employeesApprover),
      ('superuser', superuser),
    ]) {
      testWidgets('$name: Review on submitted and approved rows; badge on the sent-back row', (tester) async {
        await pumpScreen(tester, u);
        expect(byKey('review-button-u1'), findsOneWidget);
        expect(byKey('review-button-u3'), findsOneWidget, reason: 'web offers Review for approved rows too');
        expect(byKey('review-button-u2'), findsNothing);
        expect(byKey('review-awaiting-u2'), findsOneWidget);
        expect(find.text('Awaiting resubmission'), findsOneWidget);
      });
    }

    for (final (name, u) in [('view-only', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: no Review anywhere; the sent-back badge still shows', (tester) async {
        await pumpScreen(tester, u);
        expect(find.text('Review'), findsNothing);
        for (final id in ['u1', 'u2', 'u3']) {
          expect(byKey('review-button-$id'), findsNothing, reason: id);
        }
        expect(byKey('review-awaiting-u2'), findsOneWidget);
        // tapping the row itself opens nothing and sends nothing
        await tester.tap(find.text('Asha Submitted'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Review —'), findsNothing);
        expect(server.posts, isEmpty);
      });
    }

    testWidgets('an approver\'s Review opens the review sheet', (tester) async {
      await pumpScreen(tester, onboardingApprover);
      await tester.tap(byKey('review-button-u1'));
      await tester.pumpAndSettle();
      expect(find.text('Review — Asha Submitted'), findsOneWidget);
    });
  });

  group('the decision action itself', () {
    Future<(String?, Server)> attempt(WidgetTester tester, UserEntity u, String userId, {int postStatus = 200}) async {
      server = Server(rows)..postStatus = postStatus;
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: overrides(u),
        child: Consumer(builder: (_, ref, __) {
          captured = ref;
          ref.watch(authStateProvider);
          ref.watch(approvalsProvider);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      final err = await tester.runAsync(() => captured
          .read(approvalsProvider.notifier)
          .act(userId, decision: 'reject', remarks: 'Please re-upload the PAN card.'));
      return (err, server);
    }

    for (final (name, u) in [('view-only', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: refused before any request', (tester) async {
        final (err, s) = await attempt(tester, u, 'u1');
        expect(err, kOnboardingReviewDenied);
        expect(s.posts, isEmpty);
      });
    }

    testWidgets('approver, sent-back row: refused before any request', (tester) async {
      final (err, s) = await attempt(tester, onboardingApprover, 'u2');
      expect(err, kOnboardingReviewDenied);
      expect(s.posts, isEmpty);
    });

    testWidgets('approver, submitted row: one POST with the decision payload; the row leaves the list', (tester) async {
      final (err, s) = await attempt(tester, onboardingApprover, 'u1');
      expect(err, isNull);
      expect(s.posts.single.path, ApiConstants.onboardingApprove('u1'));
      expect(s.posts.single.body, {'decision': 'reject', 'remarks': 'Please re-upload the PAN card.'});
    });

    testWidgets('a server refusal is returned as its message (existing handling)', (tester) async {
      final (err, s) = await attempt(tester, superuser, 'u3', postStatus: 400);
      expect(s.posts, hasLength(1));
      expect(err, 'This user has not submitted their onboarding form.');
    });
  });
}

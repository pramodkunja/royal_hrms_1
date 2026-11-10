import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';
import 'package:mobile_app/features/employees/presentation/screens/employee_profile_screen.dart';

// Task 13 (audit C-E11): web employees/[id]/page.tsx pending-onboarding gate.
// GET /employees/<code>/ (EmployeeDetailView: employees.view + branch scope)
// returns onboarding_status (pending | draft | submitted | complete |
// rejected). When pending or draft, web keeps the header (Reset Password for
// employees.edit) but replaces the tabs and the edit form with "Onboarding
// form not submitted" and a badge: "Form saved as draft" (draft) or
// "Awaiting employee submission". Synthetic data; read-only stand-in server.

const code = 'EMP-9';
const detailPath = '/employees/$code/';

Map<String, dynamic> employee({Object? onboarding = 'pending', bool omit = false}) => {
      'id': 'u9',
      'employee_id': code,
      'first_name': 'Nia',
      'last_name': 'Test',
      'full_name': 'Nia Test',
      'email': 'nia.test@example.test',
      'phone': '9000000009',
      'department': 'QA',
      'designation': 'Analyst',
      'branch': 'North',
      'role': 'employee',
      'role_display': 'Employee',
      'is_active': true,
      'status': 'onboarding',
      if (!omit) 'onboarding_status': onboarding,
      'date_of_joining': '2026-11-01',
      'hr': <String, dynamic>{'id': null, 'name': null},
      'documents': <Object>[],
      'profile': <String, dynamic>{},
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class Server implements HttpClientAdapter {
  Server(this.detail);
  Map<String, dynamic> detail;
  final calls = <({String method, String path})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path));
    if (o.path == detailPath && o.method == 'GET') {
      return _json(200, {'status': 'success', 'message': 'Employee retrieved.', 'data': detail});
    }
    if (o.method == 'GET') return _json(200, {'status': 'success', 'data': []});
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
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

UserEntity hrUser(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = hrUser(['employees.view', 'employees.edit']);
final viewer = hrUser(['employees.view']);

late Server server;
late ProviderContainer container;

Future<void> pumpDetail(WidgetTester tester, {UserEntity? as, Map<String, dynamic>? detail}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(detail ?? employee());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
  ));
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
  await container.read(authStateProvider.future);
  await tester.pumpAndSettle();
}

final gate = find.byKey(const Key('employee-pending-onboarding'));
final badge = find.byKey(const Key('employee-onboarding-badge'));
final resetButton = find.byKey(const Key('employee-reset-password'));

String badgeText(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: badge, matching: find.byType(Text))).data!;

void expectGate(WidgetTester tester, String badgeLabel) {
  expect(gate, findsOneWidget);
  expect(find.text('Onboarding form not submitted'), findsOneWidget);
  expect(
      find.text('This employee has not yet submitted their onboarding form for approval. '
          'Profile details will appear here once they submit and HR approves their application.'),
      findsOneWidget);
  expect(badgeText(tester), badgeLabel);
  expect(find.byType(TabBar), findsNothing);
  expect(find.text('Approval Matrix'), findsNothing);
  expect(find.text('Cancel'), findsNothing, reason: 'no Save/Cancel bar');
  expect(find.text('Nia Test'), findsWidgets, reason: 'the header stays');
}

void expectProfile(WidgetTester tester) {
  expect(gate, findsNothing);
  expect(find.text('Onboarding form not submitted'), findsNothing);
  expect(find.byType(TabBar), findsOneWidget);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('parsing', () {
    test('onboarding_status is read; only pending and draft are "not submitted"', () {
      final expected = {
        'pending': true,
        'draft': true,
        'submitted': false,
        'complete': false,
        'rejected': false,
        '': false,
        ' draft ': true,
        'PENDING': false, // exact server values only
      };
      expected.forEach((status, pending) {
        final e = EmployeeModel.fromJson(employee(onboarding: status));
        expect(e.isPendingOnboarding, pending, reason: status);
      });
      final missing = EmployeeModel.fromJson(employee(omit: true));
      expect([missing.onboardingStatus, missing.isPendingOnboarding], ['', false]);
      expect(EmployeeModel.fromJson(employee(onboarding: 7)).onboardingStatus, '',
          reason: 'wrong-typed values are ignored, not thrown');
    });

    test('copyWith (used by the activate toggle) keeps the onboarding status', () {
      final e = EmployeeModel.fromJson(employee(onboarding: 'draft')).copyWith(isActive: false, status: 'inactive');
      expect([e.onboardingStatus, e.isPendingOnboarding, e.isActive], ['draft', true, false]);
    });
  });

  group('pending / draft gate (web isPendingOnboarding)', () {
    testWidgets('pending → card, "Awaiting employee submission", no tabs or edit form', (tester) async {
      await pumpDetail(tester);
      expectGate(tester, 'Awaiting employee submission');
    });

    testWidgets('draft → "Form saved as draft"', (tester) async {
      await pumpDetail(tester, detail: employee(onboarding: 'draft'));
      expectGate(tester, 'Form saved as draft');
    });

    testWidgets('an editor keeps Reset Password (web header) but not the active toggle', (tester) async {
      await pumpDetail(tester);
      expect(resetButton, findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-password-dialog')), findsOneWidget);
    });

    testWidgets('a viewer sees the same card and no Reset Password', (tester) async {
      await pumpDetail(tester, as: viewer);
      expectGate(tester, 'Awaiting employee submission');
      expect(resetButton, findsNothing);
    });

    testWidgets('the gate only reads: one GET of the detail, no writes', (tester) async {
      await pumpDetail(tester);
      expect(server.calls.where((c) => c.method != 'GET'), isEmpty);
      expect(server.calls.where((c) => c.path == detailPath), hasLength(1));
    });
  });

  group('submitted, rejected, complete or unknown → full profile', () {
    for (final status in ['submitted', 'rejected', 'complete']) {
      testWidgets(status, (tester) async {
        await pumpDetail(tester, detail: employee(onboarding: status));
        expectProfile(tester);
        expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull, reason: 'editor can toggle');
      });
    }

    testWidgets('no onboarding_status in the response → profile as before', (tester) async {
      await pumpDetail(tester, detail: employee(omit: true));
      expectProfile(tester);
    });
  });

  group('refresh', () {
    testWidgets('once the employee submits, fresh detail data shows the profile', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server(employee());
      // The detail source the screen watches (employeeDetailProvider), fed
      // from a value the test can change — as a reload after submit would.
      final source = StateProvider<Map<String, dynamic>>((_) => employee());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(editor)),
          dioProvider
              .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
          employeeDetailProvider.overrideWith((ref, id) async => EmployeeModel.fromJson(ref.watch(source))),
        ],
        child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
      ));
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(tester.element(find.byType(EmployeeProfileScreen)));
      await container.read(authStateProvider.future);
      await tester.pumpAndSettle();
      expect(gate, findsOneWidget);
      container.read(source.notifier).state = employee(onboarding: 'submitted');
      await tester.pumpAndSettle();
      expectProfile(tester);
    });

    testWidgets('loading shows the spinner, then the gate', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hold = Completer<void>();
      server = Server(employee());
      final slow = _Slow(server, hold);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => _Auth(editor)),
          dioProvider
              .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = slow),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullStorage()),
        ],
        child: const MaterialApp(home: EmployeeProfileScreen(employeeId: code)),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(gate, findsNothing);
      hold.complete();
      await tester.pumpAndSettle();
      expect(gate, findsOneWidget);
    });
  });
}

class _Slow implements HttpClientAdapter {
  _Slow(this.inner, this.hold);
  final Server inner;
  final Completer<void> hold;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? body, Future<void>? cancel) async {
    await hold.future;
    return inner.fetch(o, body, cancel);
  }

  @override
  void close({bool force = false}) {}
}

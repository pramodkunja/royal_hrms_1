import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/screens/force_change_password_screen.dart';
import 'package:mobile_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';

UserEntity _user({required bool mustChangePassword}) => UserEntity(
      id: 'u-1',
      email: 'temp@example.com',
      fullName: 'Temp User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: mustChangePassword,
      permissions: const [],
      onboardingStatus: 'complete',
      companyCode: 'ROYAL01',
    );

/// Auth repository fake: the cached user (session restoration) and what the
/// next login returns are scripted per test.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.cached});

  UserEntity? cached;
  UserEntity? nextLogin;
  int logoutCalls = 0;
  final List<String> loginEmails = [];

  @override
  Future<UserEntity?> getCachedUser() async => cached;

  @override
  Future<UserEntity> login(String companyCode, String email, String password) async {
    loginEmails.add(email);
    return nextLogin!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    cached = null;
  }

  @override
  Future<void> clearSession() async => cached = null;

  @override
  Future<void> forgotPassword(String companyCode, String email) => throw UnimplementedError();

  @override
  Future<String> verifyOtp(String companyCode, String email, String otp) => throw UnimplementedError();

  @override
  Future<void> resetPassword(String companyCode, String resetToken, String newPassword, String confirmPassword) =>
      throw UnimplementedError();
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

/// POST /change-password/ stand-in. [respond] decides each answer; requests
/// are recorded (bodies only — this test never prints them).
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<({String path, Object? body})> calls = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _, Future<void>? __) {
    calls.add((path: options.path, body: options.data));
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

// The backend's real success reply (apps/accounts/views.py ChangePasswordView).
Future<ResponseBody> _success(RequestOptions _) async => _json(200, {
      'status': 'success',
      'message': 'Password changed successfully. Please log in again with your new password.',
      'data': {},
    });

Widget _stub(String label) => Scaffold(body: Center(child: Text(label)));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _FakeAuthRepository repo;
  late _FakeBackend backend;
  late GoRouter router;

  Future<void> pumpApp(
    WidgetTester tester, {
    required UserEntity? cached,
    String initialLocation = AppRoutes.dashboard,
    Future<ResponseBody> Function(RequestOptions)? respond,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _FakeAuthRepository(cached: cached);
    backend = _FakeBackend(respond ?? _success);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend;

    // Same shape as appRouterProvider: refresh on every auth change and
    // delegate every redirect to the real resolveAuthRedirect.
    final testRouterProvider = Provider<GoRouter>((ref) {
      final refresh = ValueNotifier<int>(0);
      ref.listen(authStateProvider, (_, __) => refresh.value++);
      ref.onDispose(refresh.dispose);
      return GoRouter(
        initialLocation: initialLocation,
        refreshListenable: refresh,
        redirect: (context, state) => resolveAuthRedirect(
          authState: ref.read(authStateProvider).valueOrNull,
          path: state.uri.path,
        ),
        routes: [
          GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
          GoRoute(path: AppRoutes.changePassword, builder: (_, __) => const ForceChangePasswordScreen()),
          GoRoute(path: AppRoutes.dashboard, builder: (_, __) => _stub('DASHBOARD'), routes: [
            GoRoute(path: 'approvals', builder: (_, __) => _stub('APPROVALS')),
            GoRoute(path: 'profile', builder: (_, __) => _stub('PROFILE')),
          ]),
          GoRoute(path: '/settings/roles', builder: (_, __) => _stub('ROLES')),
          GoRoute(path: AppRoutes.onboarding, builder: (_, __) => _stub('ONBOARDING')),
        ],
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          dioProvider.overrideWithValue(dio),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
        ],
        child: Consumer(builder: (context, ref, _) {
          router = ref.watch(testRouterProvider);
          return MaterialApp.router(routerConfig: router);
        }),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
        of: find.widgetWithText(AppTextField, label),
        matching: find.byType(TextFormField),
      );

  Future<void> fillForm(WidgetTester tester, {String current = 'Temp#Pass1', String next = 'N3w!Secure#Pass', String? confirm}) async {
    await tester.enterText(field('Current Password'), current);
    await tester.enterText(field('New Password'), next);
    await tester.enterText(field('Confirm New Password'), confirm ?? next);
  }

  Finder button(String label) => find.widgetWithText(AppButton, label);

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  bool stillRequired(WidgetTester tester) =>
      containerOf(tester).read(authStateProvider).valueOrNull?.user?.mustChangePassword ?? false;

  Finder onChangePasswordScreen() => find.byType(ForceChangePasswordScreen);

  testWidgets('a user without the flag reaches the dashboard and cannot open the change screen', (tester) async {
    // The real app's splash waits for auth to load before going to the
    // dashboard; navigate the same way once it has.
    await pumpApp(tester, cached: _user(mustChangePassword: false));
    router.go(AppRoutes.dashboard);
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);

    router.go(AppRoutes.changePassword);
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(onChangePasswordScreen(), findsNothing);
  });

  testWidgets('a restored session with the flag lands on the change-password screen', (tester) async {
    await pumpApp(tester, cached: _user(mustChangePassword: true));
    expect(onChangePasswordScreen(), findsOneWidget);
    expect(find.text('DASHBOARD'), findsNothing);
  });

  testWidgets('direct navigation and deep links cannot leave the change-password screen', (tester) async {
    await pumpApp(tester, cached: _user(mustChangePassword: true));

    for (final location in [
      AppRoutes.dashboard,
      '/dashboard/approvals?id=42',
      '/dashboard/profile',
      '/settings/roles',
      AppRoutes.onboarding,
      AppRoutes.login,
    ]) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(onChangePasswordScreen(), findsOneWidget, reason: 'go($location)');
    }

    // An OS-delivered deep link (the platform's pushRouteInformation path).
    await tester.binding.handlePushRoute('/dashboard/approvals');
    await tester.pumpAndSettle();
    expect(onChangePasswordScreen(), findsOneWidget);
    expect(find.text('APPROVALS'), findsNothing);
  });

  testWidgets('back navigation cannot leave the change-password screen', (tester) async {
    await pumpApp(tester, cached: _user(mustChangePassword: true));

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(onChangePasswordScreen(), findsOneWidget);
  });

  testWidgets('logout stays available and returns to login', (tester) async {
    await pumpApp(tester, cached: _user(mustChangePassword: true));

    await tester.tap(button('Log Out'));
    await tester.pumpAndSettle();

    expect(repo.logoutCalls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets('a successful change ends the session, pre-fills login, and only a cleared flag opens the app',
      (tester) async {
    await pumpApp(tester, cached: _user(mustChangePassword: true));
    await fillForm(tester);
    await tester.tap(button('Change Password'));
    await tester.pumpAndSettle();

    final call = backend.calls.single;
    expect(call.path, ApiConstants.changePassword);
    expect((call.body as Map).keys, unorderedEquals(['old_password', 'new_password', 'confirm_password']));
    expect(repo.logoutCalls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Password changed. Sign in with your new password.'), findsOneWidget);
    expect(tester.widget<TextFormField>(field('Company Code')).controller!.text, 'ROYAL01');
    expect(tester.widget<TextFormField>(field('Email Address')).controller!.text, 'temp@example.com');
    expect(tester.widget<TextFormField>(field('Password')).controller!.text, isEmpty);

    // The next login's response is authoritative: cleared → normal access.
    repo.nextLogin = _user(mustChangePassword: false);
    await tester.enterText(field('Password'), 'N3w!Secure#Pass');
    await tester.tap(button('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('if the backend still reports the requirement after re-login, the user is sent back',
      (tester) async {
    await pumpApp(tester, cached: null, initialLocation: AppRoutes.login);
    repo.nextLogin = _user(mustChangePassword: true);
    await tester.enterText(field('Company Code'), 'ROYAL01');
    await tester.enterText(field('Email Address'), 'temp@example.com');
    await tester.enterText(field('Password'), 'Temp#Pass1');
    await tester.tap(button('Sign In'));
    await tester.pumpAndSettle();

    expect(onChangePasswordScreen(), findsOneWidget);
    expect(find.text('DASHBOARD'), findsNothing);
  });

  testWidgets('a rejected change keeps the user on the screen with the server message', (tester) async {
    await pumpApp(
      tester,
      cached: _user(mustChangePassword: true),
      respond: (_) async => _json(400, {'status': 'error', 'message': 'Current password is incorrect.', 'data': {}}),
    );
    await fillForm(tester);
    await tester.tap(button('Change Password'));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect.'), findsOneWidget);
    expect(onChangePasswordScreen(), findsOneWidget);
    expect(repo.logoutCalls, 0);
    expect(stillRequired(tester), isTrue);
  });

  testWidgets('a network failure does not clear the requirement', (tester) async {
    await pumpApp(
      tester,
      cached: _user(mustChangePassword: true),
      respond: (options) async => throw DioException.connectionError(requestOptions: options, reason: 'offline'),
    );
    await fillForm(tester);
    await tester.tap(button('Change Password'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach server. Check your connection.'), findsOneWidget);
    expect(onChangePasswordScreen(), findsOneWidget);
    expect(repo.logoutCalls, 0);
    expect(stillRequired(tester), isTrue);
  });

  testWidgets('a second submission while one is in flight is ignored', (tester) async {
    final gate = Completer<void>();
    await pumpApp(
      tester,
      cached: _user(mustChangePassword: true),
      respond: (options) async {
        await gate.future;
        return _success(options);
      },
    );
    await fillForm(tester);
    await tester.tap(button('Change Password'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(backend.calls, hasLength(1));
    // While the request is held open: tapping again and the keyboard "done"
    // action (which also submits) must not send a second request.
    // The submit button now shows a spinner instead of its label (it's the
    // first AppButton on the screen); a tap on it must do nothing.
    expect(button('Change Password'), findsNothing);
    await tester.tap(find.byType(AppButton).first, warnIfMissed: false);
    await tester.showKeyboard(field('Confirm New Password'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 50));
    expect(backend.calls, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();
    expect(backend.calls, hasLength(1));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('client-side checks block a bad submission without calling the server', (tester) async {
    await pumpApp(tester, cached: _user(mustChangePassword: true));

    await fillForm(tester, confirm: 'Different#Pass1');
    await tester.tap(button('Change Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);

    await fillForm(tester, current: 'Same#Pass123', next: 'Same#Pass123');
    await tester.tap(button('Change Password'));
    await tester.pumpAndSettle();
    expect(find.text('New password must be different from the current password.'), findsOneWidget);

    await fillForm(tester, next: 'short');
    await tester.tap(button('Change Password'));
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters.'), findsOneWidget);

    expect(backend.calls, isEmpty);
    expect(stillRequired(tester), isTrue);
  });
}

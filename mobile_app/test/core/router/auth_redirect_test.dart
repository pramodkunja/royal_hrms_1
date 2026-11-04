import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/auth_interceptor.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

UserEntity _user({
  bool mustChangePassword = false,
  String onboardingStatus = 'complete',
  bool isSuperuser = false,
  List<String> permissions = const ['employees.view'],
}) =>
    UserEntity(
      id: 'u-1',
      email: 'temp@example.com',
      fullName: 'Temp User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: mustChangePassword,
      permissions: permissions,
      onboardingStatus: onboardingStatus,
      isSuperuser: isSuperuser,
      companyCode: 'ROYAL01',
    );

String? _redirect(UserEntity? user, String path) =>
    resolveAuthRedirect(authState: user == null ? const AuthState.initial() : AuthState(user: user), path: path);

// Every place a user could try to go, including deep-link style paths with
// sub-routes and query strings (GoRouter hands redirect the path only).
const _protectedPaths = [
  '/dashboard',
  '/dashboard/approvals',
  '/dashboard/employees/emp-42',
  '/dashboard/profile',
  '/dashboard/settings',
  '/settings/roles',
  '/employees/bulk-import',
  '/onboarding',
  '/onboarding/awaiting-approval',
  '/login',
  '/forgot-password',
  '/no-such-route',
];

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.cached);

  final UserEntity? cached;

  @override
  Future<UserEntity?> getCachedUser() async => cached;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<UserEntity> login(String companyCode, String email, String password) => throw UnimplementedError();

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

ResponseBody _json(int status, Map<String, dynamic> body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RefreshThenOkAdapter implements HttpClientAdapter {
  int protectedCalls = 0;
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    if (options.path == ApiConstants.tokenRefresh) {
      refreshCalls++;
      return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    protectedCalls++;
    return protectedCalls == 1
        ? _json(401, {'status': 'error', 'message': 'Token expired.'})
        : _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('resolveAuthRedirect — mandatory password change', () {
    test('a flagged user is sent to the change-password screen from every protected path', () {
      final flagged = _user(mustChangePassword: true);
      for (final path in _protectedPaths) {
        expect(_redirect(flagged, path), AppRoutes.changePassword, reason: path);
      }
    });

    test('a flagged user may stay on the change-password screen (no redirect loop)', () {
      expect(_redirect(_user(mustChangePassword: true), AppRoutes.changePassword), isNull);
    });

    test('the splash is let through; it forwards to the dashboard, which is redirected', () {
      final flagged = _user(mustChangePassword: true);
      expect(_redirect(flagged, AppRoutes.splash), isNull);
      expect(_redirect(flagged, AppRoutes.dashboard), AppRoutes.changePassword);
    });

    test('the requirement comes before onboarding, and superusers are not exempt (as on web)', () {
      for (final status in ['pending', 'draft', 'rejected', 'submitted']) {
        final flagged = _user(mustChangePassword: true, onboardingStatus: status);
        expect(_redirect(flagged, AppRoutes.dashboard), AppRoutes.changePassword, reason: status);
        expect(_redirect(flagged, AppRoutes.onboarding), AppRoutes.changePassword, reason: status);
      }
      expect(_redirect(_user(mustChangePassword: true, isSuperuser: true), AppRoutes.dashboard),
          AppRoutes.changePassword);
    });

    test('a user without the flag reaches the dashboard and is sent away from change-password', () {
      // Holds the approval permission /dashboard/approvals requires
      // (route permissions: access_control.dart).
      final user = _user(permissions: const ['employees.view', 'leave.approve']);
      expect(_redirect(user, AppRoutes.dashboard), isNull);
      expect(_redirect(user, '/dashboard/approvals'), isNull);
      expect(_redirect(user, AppRoutes.changePassword), AppRoutes.dashboard);
    });

    test('signed out: change-password and protected areas go to login; login stays reachable', () {
      for (final path in [AppRoutes.changePassword, AppRoutes.dashboard, '/settings/roles', AppRoutes.onboarding]) {
        expect(_redirect(null, path), AppRoutes.login, reason: path);
      }
      expect(_redirect(null, AppRoutes.login), isNull);
      expect(_redirect(null, AppRoutes.forgotPassword), isNull);
      // Still loading (no auth state yet) behaves as signed out.
      expect(resolveAuthRedirect(authState: null, path: AppRoutes.changePassword), AppRoutes.login);
    });

    test('existing onboarding redirects are unchanged for users without the flag', () {
      expect(_redirect(_user(onboardingStatus: 'pending'), AppRoutes.dashboard), AppRoutes.onboarding);
      expect(_redirect(_user(onboardingStatus: 'submitted'), AppRoutes.dashboard), AppRoutes.onboardingAwaiting);
      expect(_redirect(_user(), AppRoutes.onboarding), AppRoutes.dashboard);
    });
  });

  group('wiring and state', () {
    test('the app router registers the change-password route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final paths = router.configuration.routes.whereType<GoRoute>().map((r) => r.path);
      expect(paths, contains(AppRoutes.changePassword));
    });

    test('the flag follows the backend contract: a boolean, absent or null treated as not required', () {
      Map<String, dynamic> json(Object? flag, {bool include = true}) => {
            'id': 'u-1', 'email': 'a@b.com', 'full_name': 'A', 'role': 'employee',
            if (include) 'must_change_password': flag,
          };
      expect(UserModel.fromJson(json(true)).mustChangePassword, isTrue);
      expect(UserModel.fromJson(json(false)).mustChangePassword, isFalse);
      expect(UserModel.fromJson(json(null)).mustChangePassword, isFalse);
      expect(UserModel.fromJson(json(null, include: false)).mustChangePassword, isFalse);
      // Survives the secure-storage round trip used for session restoration.
      final cached = UserModel.fromJson(jsonDecode(jsonEncode(UserModel.fromJson(json(true)).toJson())));
      expect(cached.mustChangePassword, isTrue);
    });

    test('session restoration keeps the requirement', () async {
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(_user(mustChangePassword: true))),
      ]);
      addTearDown(container.dispose);
      final state = await container.read(authStateProvider.future);
      expect(state.user!.mustChangePassword, isTrue);
      expect(resolveAuthRedirect(authState: state, path: AppRoutes.dashboard), AppRoutes.changePassword);
    });

    test('a profile/onboarding status refresh keeps the requirement', () async {
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(_user(mustChangePassword: true, onboardingStatus: 'submitted')),
        ),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      container.read(authStateProvider.notifier).updateOnboardingStatus('complete');
      final state = container.read(authStateProvider).requireValue;
      expect(state.user!.mustChangePassword, isTrue);
      expect(resolveAuthRedirect(authState: state, path: AppRoutes.dashboard), AppRoutes.changePassword);
    });

    test('a token refresh does not clear the requirement', () async {
      final adapter = _RefreshThenOkAdapter();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(_user(mustChangePassword: true))),
        secureStorageProvider.overrideWithValue(_NullSecureStorage()),
        cookieJarProvider.overrideWithValue(CookieJar()),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);

      final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = adapter;
      dio.interceptors.add(container.read(authInterceptorProvider(dio)));
      final response = await dio.get<dynamic>('/employees/me/');

      expect(response.statusCode, 200);
      expect(adapter.refreshCalls, 1);
      final state = container.read(authStateProvider).requireValue;
      expect(state.user!.mustChangePassword, isTrue);
      expect(resolveAuthRedirect(authState: state, path: AppRoutes.dashboard), AppRoutes.changePassword);
    });
  });
}

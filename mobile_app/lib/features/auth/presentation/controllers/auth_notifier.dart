import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../states/auth_state.dart';

class AuthNotifier extends AsyncNotifier<AuthState> {
  // Use ref.read inside methods — never store late final fields in an
  // AsyncNotifier because build() can be re-invoked, causing LateInitializationError.
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    // Keep this provider alive across screen transitions so the auth state
    // is never lost between splash → login → dashboard navigation.
    ref.keepAlive();

    // Auto-logout when the refresh token is rejected by the server.
    // AuthInterceptor sets sessionExpiredProvider=true; we react here so the
    // user is sent back to the login screen instead of seeing endless 401s.
    ref.listen<bool>(sessionExpiredProvider, (_, expired) {
      if (!expired) return;
      // Reset the flag before calling logout to prevent re-entrancy.
      ref.read(sessionExpiredProvider.notifier).state = false;
      logout();
    });

    try {
      final cachedUser = await _repository.getCachedUser();
      return AuthState(user: cachedUser);
    } catch (_) {
      // Any storage error on first launch is non-fatal; treat as not authenticated.
      return const AuthState.initial();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await LoginUseCase(_repository)(email, password);
      return AuthState(user: user);
    });
  }

  Future<void> logout() async {
    try {
      await LogoutUseCase(_repository)();
    } catch (_) {
      // Swallow logout errors — always clear local session.
    }
    state = const AsyncData(AuthState.initial());
  }
}

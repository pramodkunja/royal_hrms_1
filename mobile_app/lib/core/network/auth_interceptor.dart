import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../security/secure_storage.dart';
import 'api_client.dart';

/// Handles all authentication concerns for every Dio request:
///
/// onRequest — reads the stored access token and injects it as
///   `Authorization: Bearer <token>` so the backend can authenticate the
///   request even when cookies don't reach the server — on native the
///   cookie jar may be empty after reinstall/session expiry, and on web
///   the httpOnly cookie is dropped by the browser whenever the app isn't
///   served from the exact same origin as the API (SameSite=Lax).
///
/// onError  — intercepts 401 responses, attempts a silent token
///   refresh (sending the stored refresh token in the body, since the
///   same cross-origin cookie problem applies to the refresh cookie),
///   retries the original request with the new token, and signals
///   `sessionExpiredProvider` when the refresh also fails so that
///   [AuthNotifier] can auto-logout and redirect to login.
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final Ref _ref;
  bool _isRefreshing = false;

  // Each entry keeps the handler so we can resolve/reject it properly
  // once the in-flight refresh completes.
  final List<_Pending> _pending = [];

  AuthInterceptor(this._dio, this._ref);

  SecureStorageService get _storage => _ref.read(secureStorageProvider);

  // ── onRequest — inject Bearer token ───────────────────────────────────────

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Always send the access token as a Bearer header — the Django backend
    // checks the cookie first and falls back to this header, so it's a safe
    // no-op wherever the cookie already works, and the only thing that makes
    // auth work at all wherever it doesn't (native cookie jar empty, or web
    // served from a different origin than the API).
    try {
      final token = await _storage.read(AppConstants.keyAccessToken);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // If secure storage read fails, proceed without the header.
      // The server will return 401 and the error handler will refresh.
    }
    handler.next(options);
  }

  // ── onError — silent refresh then retry ───────────────────────────────────

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;

    if (response == null || response.statusCode != 401) {
      handler.next(err);
      return;
    }

    final path = err.requestOptions.path;

    // Never attempt a silent refresh for endpoints that run before a session
    // exists. A 401 here always means "these credentials/this token are
    // invalid" — never "your existing session expired" — so treating it as
    // one triggers a pointless second round-trip to /token/refresh/ (which
    // also 401s with no session to refresh), a spurious logout() side
    // effect via sessionExpiredProvider, and a race between that logout's
    // state write and the login call's own error state.
    const unauthenticatedPaths = [
      ApiConstants.login,
      ApiConstants.tokenRefresh,
      ApiConstants.logout,
      ApiConstants.forgotPassword,
      ApiConstants.verifyOtp,
      ApiConstants.resetPassword,
    ];
    if (unauthenticatedPaths.any(path.contains)) {
      handler.next(err);
      return;
    }

    // Queue requests that arrive while a refresh is already in progress.
    if (_isRefreshing) {
      _pending.add(_Pending(err.requestOptions, handler));
      return;
    }

    _isRefreshing = true;
    try {
      // Send the stored refresh token in the body as a fallback for whenever
      // the httpOnly refresh cookie doesn't reach the server (see onRequest).
      // The backend prefers the cookie and only falls back to this field.
      final storedRefreshToken = await _storage.read(AppConstants.keyRefreshToken);
      final refreshResp = await _dio.post(
        ApiConstants.tokenRefresh,
        data: (storedRefreshToken != null && storedRefreshToken.isNotEmpty)
            ? {'refresh': storedRefreshToken}
            : null,
      );

      // Persist the new tokens so subsequent requests pick them up via
      // onRequest above (and the cookie jar is also updated by CookieManager
      // on native, or Set-Cookie directly wherever the cookie does reach us).
      final newAccessToken = _extractToken(refreshResp.data, 'access');
      if (newAccessToken != null) {
        await _storage.write(AppConstants.keyAccessToken, newAccessToken);
      }
      final newRefreshToken = _extractToken(refreshResp.data, 'refresh');
      if (newRefreshToken != null) {
        await _storage.write(AppConstants.keyRefreshToken, newRefreshToken);
      }

      // Retry the original request — onRequest will add the new Bearer header.
      final retryResponse = await _dio.fetch(err.requestOptions);
      _resolvePending();
      handler.resolve(retryResponse);
    } on DioException catch (refreshErr) {
      // Only a definitive rejection *from the server* (it responded, saying
      // the refresh token itself is invalid/expired) means the session has
      // truly ended. A network-level failure — timeout, no connectivity,
      // the app being backgrounded mid-request — has no response at all and
      // proves nothing about the session; treating it the same forced a
      // full logout over a transient connectivity blip on whatever unlucky
      // request happened to hit the expired-access-token window first (e.g.
      // submitting a form after leaving it open for a while).
      if (refreshErr.response != null) {
        _signalSessionExpired();
        final authError = DioException(
          requestOptions: err.requestOptions,
          error: const UnauthorizedException(),
          type: DioExceptionType.badResponse,
        );
        // Every request queued behind this refresh gets the same verdict as
        // the one that triggered it — previously queued requests were always
        // force-rejected as "unauthorized" even on a mere network blip,
        // while the triggering request got the real (non-auth) error; that
        // mismatch is what this shared helper fixes.
        _rejectPending(authError);
        handler.next(authError);
      } else {
        _rejectPending(err);
        handler.next(err);
      }
    } catch (e) {
      // A non-DioException failure during refresh (e.g. a secure-storage
      // platform exception from a locked/corrupted Keychain/Keystore) used
      // to fall through uncaught: `_isRefreshing` still reset via `finally`,
      // but neither the triggering request nor anything in `_pending` ever
      // got resolved/rejected, so every queued request hung forever. Treat
      // it like a network-level failure — nothing proves the session is
      // invalid, but every queued request must still be settled, not left
      // hanging — while still surfacing it as a real (non-fake-success)
      // failure to the caller.
      final fallbackError = DioException(
        requestOptions: err.requestOptions,
        error: e,
        type: DioExceptionType.unknown,
      );
      _rejectPending(fallbackError);
      handler.next(fallbackError);
    } finally {
      _isRefreshing = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Backend envelope: { success, message, data: { access: "...", refresh: "..." } }
  String? _extractToken(dynamic responseData, String key) {
    try {
      return ((responseData as Map<String, dynamic>)['data']
          as Map<String, dynamic>)[key] as String?;
    } catch (_) {
      return null;
    }
  }

  void _resolvePending() {
    for (final p in _pending) {
      _dio.fetch(p.options).then(
        (response) => p.handler.resolve(response),
        onError: (Object err) {
          if (err is DioException) p.handler.next(err);
        },
      );
    }
    _pending.clear();
  }

  // Settles every queued request with the same verdict [error] carries —
  // the caller decides whether that's a genuine auth failure (session
  // truly expired) or a network-level failure (nothing proven), so queued
  // requests are never misreported differently than the request that
  // triggered the refresh in the first place.
  void _rejectPending(DioException error) {
    for (final p in _pending) {
      p.handler.next(
        DioException(
          requestOptions: p.options,
          error: error.error,
          type: error.type,
          response: error.response,
        ),
      );
    }
    _pending.clear();
  }

  void _signalSessionExpired() {
    try {
      _ref.read(sessionExpiredProvider.notifier).state = true;
    } catch (_) {
      // Provider may already be disposed during hot-restart — ignore.
    }
  }
}

class _Pending {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  const _Pending(this.options, this.handler);
}

final authInterceptorProvider = Provider.family<AuthInterceptor, Dio>(
  (ref, dio) => AuthInterceptor(dio, ref),
);

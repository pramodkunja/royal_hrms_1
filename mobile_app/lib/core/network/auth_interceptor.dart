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

  /// `RequestOptions.extra` flag set on a request that is being replayed
  /// after a successful refresh. A 401 on such a request is final — it is
  /// never refreshed or queued again (see [onError]).
  static const retriedAfterRefreshKey = 'authRetriedAfterRefresh';

  // The single in-flight refresh shared by every concurrent 401. It settles
  // as soon as /token/refresh/ itself finishes — *before* any request is
  // replayed — so a replayed request that 401s again can never end up
  // waiting on the very refresh that is waiting on it. (The previous
  // `_isRefreshing` flag + `_pending` queue stayed locked until the
  // triggering request's retry completed, so a second 401 on that retry
  // queued itself behind its own refresh and hung every later 401 in the
  // app forever.)
  Future<_RefreshResult>? _refreshInFlight;

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

    // A request already replayed once after a successful refresh that is
    // *still* rejected: the fresh session itself isn't accepted (user
    // deactivated, tenant/permission change, ...). Refreshing again would
    // loop, and waiting on another refresh is what used to deadlock — so
    // end the session instead.
    if (err.requestOptions.extra[retriedAfterRefreshKey] == true) {
      _signalSessionExpired();
      handler.next(_unauthorizedError(err.requestOptions));
      return;
    }

    // Every concurrent 401 shares one refresh; each request then settles
    // its own handler below, so none can be left hanging.
    final result = await (_refreshInFlight ??=
        _refreshSession().whenComplete(() => _refreshInFlight = null));

    switch (result) {
      case _RefreshSucceeded():
        await _retry(err.requestOptions, handler);
      case _RefreshRejected():
        // Only a definitive rejection *from the server* (it responded,
        // saying the refresh token itself is invalid/expired) means the
        // session has truly ended — signalled once inside _refreshSession.
        handler.next(_unauthorizedError(err.requestOptions));
      case _RefreshNetworkFailure():
        // A network-level failure — timeout, no connectivity, the app being
        // backgrounded mid-request — proves nothing about the session, so
        // it must never force a logout; surface the request's own error.
        handler.next(err);
      case _RefreshUnexpectedFailure(:final error):
        // A non-DioException failure during refresh (e.g. a secure-storage
        // platform exception from a locked/corrupted Keychain/Keystore).
        // Treated like a network-level failure — nothing proves the session
        // is invalid — but still surfaced as a real failure, never hung.
        handler.next(
          DioException(
            requestOptions: err.requestOptions,
            error: error,
            type: DioExceptionType.unknown,
          ),
        );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Calls /token/refresh/ and persists any returned tokens. Never throws —
  // every outcome is returned so each waiting request can settle itself.
  Future<_RefreshResult> _refreshSession() async {
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
      return const _RefreshSucceeded();
    } on DioException catch (refreshErr) {
      if (refreshErr.response != null) {
        _signalSessionExpired();
        return const _RefreshRejected();
      }
      return const _RefreshNetworkFailure();
    } catch (e) {
      return _RefreshUnexpectedFailure(e);
    }
  }

  // Replays [options] once with the refreshed session. Any failure of the
  // replay is that request's own outcome — a non-401 error (e.g. a 500) no
  // longer counts as a refresh rejection and so no longer forces a logout;
  // a 401 is handled by the retriedAfterRefreshKey branch in onError.
  //
  // The same RequestOptions instance is reused on purpose: onRequest then
  // overwrites the Authorization header, and CookieManager recognises its
  // own previous Cookie header on this instance and rebuilds it from the
  // updated jar instead of merging in the stale access-token cookie.
  Future<void> _retry(RequestOptions options, ErrorInterceptorHandler handler) async {
    options.extra[retriedAfterRefreshKey] = true;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } catch (e) {
      handler.next(
        DioException(requestOptions: options, error: e, type: DioExceptionType.unknown),
      );
    }
  }

  DioException _unauthorizedError(RequestOptions options) => DioException(
        requestOptions: options,
        error: const UnauthorizedException(),
        type: DioExceptionType.badResponse,
      );

  // Backend envelope: { success, message, data: { access: "...", refresh: "..." } }
  String? _extractToken(dynamic responseData, String key) {
    try {
      return ((responseData as Map<String, dynamic>)['data']
          as Map<String, dynamic>)[key] as String?;
    } catch (_) {
      return null;
    }
  }

  void _signalSessionExpired() {
    try {
      _ref.read(sessionExpiredProvider.notifier).state = true;
    } catch (_) {
      // Provider may already be disposed during hot-restart — ignore.
    }
  }
}

sealed class _RefreshResult {
  const _RefreshResult();
}

class _RefreshSucceeded extends _RefreshResult {
  const _RefreshSucceeded();
}

/// The server answered the refresh with an error — the session has ended.
class _RefreshRejected extends _RefreshResult {
  const _RefreshRejected();
}

/// No response at all (timeout, offline) — says nothing about the session.
class _RefreshNetworkFailure extends _RefreshResult {
  const _RefreshNetworkFailure();
}

class _RefreshUnexpectedFailure extends _RefreshResult {
  final Object error;
  const _RefreshUnexpectedFailure(this.error);
}

final authInterceptorProvider = Provider.family<AuthInterceptor, Dio>(
  (ref, dio) => AuthInterceptor(dio, ref),
);

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';
import '../security/secure_storage.dart';
import 'api_client.dart';

/// Handles all authentication concerns for every Dio request:
///
/// onRequest — reads the stored access token and injects it as
///   `Authorization: Bearer <token>` so the backend can authenticate
///   the request even when the cookie jar is empty (native only;
///   on web the browser sends httpOnly cookies automatically).
///
/// onError  — intercepts 401 responses, attempts a silent token
///   refresh, retries the original request with the new token, and
///   signals `sessionExpiredProvider` when the refresh also fails so
///   that [AuthNotifier] can auto-logout and redirect to login.
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
    // On native platforms we send the access token as a Bearer header because
    // the PersistCookieJar may be empty after reinstall or session expiry.
    // The Django backend accepts both Cookie and Authorization: Bearer.
    // On web, the browser attaches httpOnly cookies automatically via CORS
    // withCredentials, so no extra header is needed.
    if (!kIsWeb) {
      try {
        final token = await _storage.read(AppConstants.keyAccessToken);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // If secure storage read fails, proceed without the header.
        // The server will return 401 and the error handler will refresh.
      }
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

    // Never retry the refresh or logout endpoints — avoids infinite loops.
    if (path.contains(ApiConstants.tokenRefresh) ||
        path.contains(ApiConstants.logout)) {
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
      final refreshResp = await _dio.post(ApiConstants.tokenRefresh);

      // Persist the new access token so subsequent requests pick it up
      // via onRequest above (and the cookie jar is also updated by CookieManager).
      final newToken = _extractToken(refreshResp.data);
      if (newToken != null) {
        await _storage.write(AppConstants.keyAccessToken, newToken);
      }

      // Retry the original request — onRequest will add the new Bearer header.
      final retryResponse = await _dio.fetch(err.requestOptions);
      _resolvePending();
      handler.resolve(retryResponse);
    } on DioException {
      _rejectPending();
      _signalSessionExpired();
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: const UnauthorizedException(),
          type: DioExceptionType.badResponse,
        ),
      );
    } finally {
      _isRefreshing = false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Backend envelope: { success, message, data: { access: "..." } }
  String? _extractToken(dynamic responseData) {
    try {
      return ((responseData as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['access'] as String?;
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

  void _rejectPending() {
    for (final p in _pending) {
      p.handler.next(
        DioException(
          requestOptions: p.options,
          error: const UnauthorizedException(),
          type: DioExceptionType.badResponse,
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

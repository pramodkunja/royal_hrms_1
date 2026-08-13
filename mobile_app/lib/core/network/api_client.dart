import 'dart:developer' as developer;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../error/exceptions.dart';
import 'auth_interceptor.dart';

// CookieJar is the abstract base; PersistCookieJar and DefaultCookieJar both
// implement it. The web build receives a DefaultCookieJar (in-memory) while
// native builds receive a PersistCookieJar from main().
final cookieJarProvider = Provider<CookieJar>(
  (ref) => throw UnimplementedError('Override cookieJarProvider in ProviderScope'),
);

// Set to true by AuthInterceptor when both the access token and the refresh
// token have been rejected (i.e. the session has truly expired). AuthNotifier
// watches this and calls logout() so the user is redirected to the login screen
// automatically instead of getting stuck with endless 401 errors.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      // withCredentials tells the browser to include httpOnly cookies in
      // cross-origin requests (CORS). Ignored on native platforms.
      extra: <String, dynamic>{'withCredentials': true},
    ),
  );

  // On web the browser automatically attaches httpOnly cookies to requests
  // (provided withCredentials is set). Adding CookieManager would conflict.
  if (!kIsWeb) {
    dio.interceptors.add(CookieManager(ref.watch(cookieJarProvider)));
  }

  dio.interceptors.add(ref.watch(authInterceptorProvider(dio)));

  // Debug-only diagnostic logging — compiled out of release builds via
  // kDebugMode, and even in debug never logs headers (so the Authorization
  // bearer token and any Set-Cookie/Cookie session data are never printed)
  // or request/response bodies (which can carry passwords, OTPs, salary,
  // and other PII). Only method, path, status/error, and duration are logged.
  if (kDebugMode) {
    dio.interceptors.add(_DebugLoggingInterceptor());
  }

  return dio;
});

/// See the `if (kDebugMode)` guard above — this interceptor is never
/// constructed in a release build. It deliberately logs nothing beyond
/// method/path/status/duration; see that comment for why headers and bodies
/// are excluded even in debug.
class _DebugLoggingInterceptor extends Interceptor {
  static const _stopwatchExtraKey = '_debugLogStopwatch';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchExtraKey] = Stopwatch()..start();
    developer.log('→ ${options.method} ${options.path}', name: 'api');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final elapsed = _elapsedMs(response.requestOptions);
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.path} (${elapsed}ms)',
      name: 'api',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _elapsedMs(err.requestOptions);
    developer.log(
      '✗ ${err.response?.statusCode ?? err.type} ${err.requestOptions.path} (${elapsed}ms)',
      name: 'api',
    );
    handler.next(err);
  }

  int _elapsedMs(RequestOptions options) {
    final stopwatch = options.extra[_stopwatchExtraKey];
    return stopwatch is Stopwatch ? stopwatch.elapsedMilliseconds : -1;
  }
}

/// Parses a Dio error into a typed [AppException]. Always prefers the
/// backend's own `message` field when the response body includes one —
/// the hardcoded per-status defaults below are only a fallback for
/// responses that didn't carry a message (e.g. a connection failure with
/// no response at all). Never falls back to Dio's own `error.message` /
/// `error.toString()` — that's an internal diagnostic string (e.g. "DioException
/// [bad response]: ...") that must never reach the user-facing UI.
AppException parseDioException(DioException error) {
  // Connection-level failures never carry a `response` (there was no reply
  // to read a status code from), so classify those by DioExceptionType
  // before falling through to the status-code checks below.
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkException('The request is taking too long. Please try again.');
    case DioExceptionType.connectionError:
      return const NoInternetException();
    case DioExceptionType.cancel:
      return const NetworkException('Request was cancelled.');
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break; // Fall through — a real response may still be present below.
  }

  final statusCode = error.response?.statusCode;
  final body = error.response?.data;
  // DRF's own permission/exception handling (e.g. a bare `permission_classes`
  // rejection, not one of our views' explicit `error()` calls) returns
  // {"detail": "..."} instead of the app's usual {status, message, data}
  // envelope — fall back to it so those responses still surface a real
  // message instead of the generic per-status default below. Both fields are
  // type-checked (not blindly cast) since a malformed/unexpected error body
  // — e.g. a field-errors dict under `message` instead of a plain string —
  // must degrade to the per-status default, not throw while parsing the
  // error itself.
  final serverMessage = body is Map
      ? (body['message'] is String
          ? body['message'] as String
          : (body['detail'] is String ? body['detail'] as String : null))
      : null;

  if (statusCode == 401) {
    return serverMessage != null
        ? UnauthorizedException(serverMessage)
        : const UnauthorizedException();
  }
  if (statusCode == 403) {
    // The backend's account-lockout check (too many failed logins) only
    // ever runs inside the login view and only ever returns 403 from that
    // one endpoint — every other 403 in the app is a plain permission
    // denial from an already-authenticated request. Keying off the request
    // path (rather than guessing from the message text) is exact, not a
    // heuristic, because of that backend guarantee.
    final isLoginAttempt = error.requestOptions.path.contains(ApiConstants.login);
    if (isLoginAttempt) {
      return serverMessage != null
          ? AccountLockedException(serverMessage)
          : const AccountLockedException();
    }
    return serverMessage != null ? ForbiddenException(serverMessage) : const ForbiddenException();
  }
  if (statusCode == 404) {
    return serverMessage != null ? NotFoundException(serverMessage) : const NotFoundException();
  }
  if (statusCode == 408) {
    return const NetworkException('The request is taking too long. Please try again.');
  }
  if (statusCode == 422) {
    return serverMessage != null
        ? ValidationException(serverMessage, 422)
        : const ValidationException();
  }
  if (statusCode == 429) {
    return serverMessage != null
        ? RateLimitException(serverMessage)
        : const RateLimitException();
  }
  if (statusCode != null && statusCode >= 500) {
    return serverMessage != null ? ServerException(serverMessage) : const ServerException();
  }
  return NetworkException(
    serverMessage ?? 'Something went wrong. Please try again.',
    statusCode: statusCode,
  );
}

/// Single, centralized conversion from *any* caught error to a short,
/// user-facing message — never Django/Dio internals. Prefer this over
/// hand-rolled per-feature error-formatting so every screen shows
/// consistent copy for the same underlying failure.
String userFriendlyMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is DioException) return parseDioException(error).message;
  return 'Something went wrong. Please try again.';
}

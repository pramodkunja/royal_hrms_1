import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  return dio;
});

/// Parses a Dio error into a typed [AppException].
AppException parseDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  final body = error.response?.data;
  final serverMessage = body is Map ? body['message'] as String? : null;

  if (statusCode == 401) return const UnauthorizedException();
  if (statusCode == 403) return AccountLockedException(serverMessage ?? 'Access denied.');
  if (statusCode == 404) return const NotFoundException();
  if (statusCode == 429) return const RateLimitException();
  if (statusCode != null && statusCode >= 500) {
    return ServerException(serverMessage ?? 'Server error. Please try again.');
  }
  return NetworkException(
    serverMessage ?? error.message ?? 'Network error.',
    statusCode: statusCode,
  );
}

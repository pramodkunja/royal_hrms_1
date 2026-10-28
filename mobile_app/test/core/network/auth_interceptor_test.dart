import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/network/auth_interceptor.dart';
import 'package:mobile_app/core/security/secure_storage.dart';

// Every awaited request is bounded so a regression back to the old deadlock
// fails the test instead of hanging the suite.
const _hangTimeout = Duration(seconds: 5);

const _protectedPath = '/employees/me/';

/// In-memory stand-in for the platform keychain/keystore.
class _FakeSecureStorage extends SecureStorageService {
  final Map<String, String> values = {};
  Object? readError;

  @override
  Future<String?> read(String key) async {
    if (readError != null) throw readError!;
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);
}

/// Answers every request through [respond] and records what was sent.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  int callsTo(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    // Snapshot the headers as sent — the same RequestOptions instance is
    // reused (and mutated) when a request is replayed.
    requests.add(options.copyWith(headers: Map.of(options.headers)));
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

ResponseBody _ok([Map<String, dynamic> data = const {}]) =>
    _json(200, {'status': 'success', 'message': 'ok', 'data': data});

ResponseBody _unauthorized() =>
    _json(401, {'status': 'error', 'message': 'Authentication credentials were not provided.'});

void main() {
  late ProviderContainer container;
  late _FakeSecureStorage storage;
  late Dio dio;
  late _ScriptedAdapter adapter;

  void setUpClient(Future<ResponseBody> Function(RequestOptions options) respond) {
    storage = _FakeSecureStorage();
    container = ProviderContainer(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'));
    adapter = _ScriptedAdapter(respond);
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(container.read(authInterceptorProvider(dio)));
  }

  bool sessionExpired() => container.read(sessionExpiredProvider);

  Future<Response<dynamic>> getProtected([String path = _protectedPath]) =>
      dio.get<dynamic>(path).timeout(_hangTimeout);

  // Asserts [future] fails with a DioException (rather than hanging or
  // succeeding) and returns it for further checks.
  Future<DioException> expectDioError(Future<Object?> future) async {
    try {
      await future.timeout(_hangTimeout);
    } on DioException catch (e) {
      return e;
    }
    fail('Expected a DioException');
  }

  group('AuthInterceptor', () {
    test('refresh succeeds, the original request is retried once and succeeds', () async {
      var firstAttempt = true;
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) return _ok();
        if (firstAttempt) {
          firstAttempt = false;
          return _unauthorized();
        }
        return _ok({'id': 'emp-1'});
      });

      final response = await getProtected();

      expect(response.statusCode, 200);
      expect(response.data['data']['id'], 'emp-1');
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 1);
      expect(adapter.callsTo(_protectedPath), 2);
      expect(sessionExpired(), isFalse);
    });

    test('tokens returned by refresh are persisted and sent on the retry', () async {
      var firstAttempt = true;
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) {
          return _ok({'access': 'new-access', 'refresh': 'new-refresh'});
        }
        if (firstAttempt) {
          firstAttempt = false;
          return _unauthorized();
        }
        return _ok();
      });
      storage.values[AppConstants.keyRefreshToken] = 'old-refresh';

      await getProtected();

      final refreshCall =
          adapter.requests.singleWhere((r) => r.path == ApiConstants.tokenRefresh);
      expect(refreshCall.data, {'refresh': 'old-refresh'});
      expect(storage.values[AppConstants.keyAccessToken], 'new-access');
      expect(storage.values[AppConstants.keyRefreshToken], 'new-refresh');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer new-access');
    });

    test('a retry that 401s again ends the session instead of looping or hanging', () async {
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) return _ok();
        return _unauthorized(); // The refreshed session is still rejected.
      });

      final error = await expectDioError(getProtected());

      expect(error.error, isA<UnauthorizedException>());
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 1);
      expect(adapter.callsTo(_protectedPath), 2);
      expect(sessionExpired(), isTrue);
    });

    test('later 401s still refresh after a retry 401 (the refresh lock is released)', () async {
      var protectedCalls = 0;
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) return _ok();
        protectedCalls++;
        // Calls 1–2: the first request and its rejected retry.
        // Call 3: a new request 401s; call 4: its retry succeeds.
        return protectedCalls == 4 ? _ok() : _unauthorized();
      });

      await expectDioError(getProtected());
      final response = await getProtected();

      expect(response.statusCode, 200);
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 2);
    });

    test('concurrent 401s share a single refresh and all complete', () async {
      final refreshGate = Completer<void>();
      final rejectedOnce = <String>{};
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) {
          await refreshGate.future;
          return _ok();
        }
        if (rejectedOnce.add(options.path)) return _unauthorized();
        return _ok({'path': options.path});
      });

      final paths = List.generate(5, (i) => '/resource/$i/');
      final futures = paths.map(getProtected).toList();

      // Let every request reach the interceptor while the refresh is held.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 1);
      refreshGate.complete();

      final responses = await Future.wait(futures);
      expect(responses.map((r) => r.data['data']['path']), paths);
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 1);
      expect(sessionExpired(), isFalse);
    });

    test('refresh rejected by the server fails every waiting request and signals session expiry',
        () async {
      final refreshGate = Completer<void>();
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) {
          await refreshGate.future;
          return _json(401, {'status': 'error', 'message': 'Token is invalid or expired.'});
        }
        return _unauthorized();
      });

      final futures = List.generate(3, (i) => expectDioError(getProtected('/resource/$i/')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      refreshGate.complete();

      final errors = await Future.wait(futures);
      for (final error in errors) {
        expect(error.error, isA<UnauthorizedException>());
      }
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 1);
      expect(sessionExpired(), isTrue);
    });

    test('refresh network failure fails waiting requests without logging out', () async {
      final refreshGate = Completer<void>();
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) {
          await refreshGate.future;
          throw DioException.connectionError(requestOptions: options, reason: 'offline');
        }
        return _unauthorized();
      });

      final futures = List.generate(3, (i) => expectDioError(getProtected('/resource/$i/')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      refreshGate.complete();

      final errors = await Future.wait(futures);
      for (final error in errors) {
        // Each request surfaces its own original 401 — nothing proved the
        // session is over, so no forced logout.
        expect(error.response?.statusCode, 401);
      }
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 1);
      expect(sessionExpired(), isFalse);
    });

    test('a non-Dio exception during refresh settles every waiting request', () async {
      final storageFailure = StateError('keystore unavailable');
      setUpClient((options) async => _unauthorized());
      storage.readError = storageFailure;

      final errors = await Future.wait(
        List.generate(3, (i) => expectDioError(getProtected('/resource/$i/'))),
      );

      for (final error in errors) {
        expect(error.type, DioExceptionType.unknown);
        expect(error.error, same(storageFailure));
      }
      expect(sessionExpired(), isFalse);
    });

    test('requests waiting on a refresh each settle with their own retry outcome', () async {
      final refreshGate = Completer<void>();
      final rejectedOnce = <String>{};
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) {
          await refreshGate.future;
          return _ok();
        }
        if (rejectedOnce.add(options.path)) return _unauthorized();
        if (options.path == '/fails/') {
          return _json(500, {'status': 'error', 'message': 'Server error'});
        }
        return _ok();
      });

      final succeeds = getProtected('/succeeds/');
      final fails = expectDioError(getProtected('/fails/'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      refreshGate.complete();

      expect((await succeeds).statusCode, 200);
      expect((await fails).response?.statusCode, 500);
      // A failed retry is that request's own error, not a refresh rejection.
      expect(sessionExpired(), isFalse);
    });

    test('a server error on the retry is returned as-is and does not end the session', () async {
      var firstAttempt = true;
      setUpClient((options) async {
        if (options.path == ApiConstants.tokenRefresh) return _ok();
        if (firstAttempt) {
          firstAttempt = false;
          return _unauthorized();
        }
        return _json(500, {'status': 'error', 'message': 'Server error'});
      });

      final error = await expectDioError(getProtected());

      expect(error.response?.statusCode, 500);
      expect(sessionExpired(), isFalse);
    });

    test('a 401 from a pre-session endpoint is passed through without a refresh', () async {
      setUpClient((options) async => _unauthorized());

      final error = await expectDioError(
        dio.post<dynamic>(ApiConstants.login, data: {'email': 'x'}),
      );

      expect(error.response?.statusCode, 401);
      expect(adapter.callsTo(ApiConstants.tokenRefresh), 0);
      expect(sessionExpired(), isFalse);
    });
  });
}

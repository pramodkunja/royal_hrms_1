import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/data/models/forgot_password_models.dart';
import 'package:mobile_app/features/auth/presentation/controllers/forgot_password_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/forgot_password_state.dart';

class _FakeSecureStorage extends SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);
}

/// Stands in for the Django backend: answers each request through [respond]
/// and records the decoded JSON body that was sent.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.respond);

  final ResponseBody Function(String path, Map<String, dynamic> body) respond;
  final List<({String path, Map<String, dynamic> body})> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : <String, dynamic>{};
    calls.add((path: options.path, body: body));
    return respond(options.path, body);
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

// Mirrors core/responses.py: success() and error() envelopes.
ResponseBody _success(String message, [Map<String, dynamic> data = const {}]) =>
    _json(200, {'status': 'success', 'message': message, 'data': data});

ResponseBody _error(String message, {int status = 400}) =>
    _json(status, {'status': 'error', 'message': message, 'data': {}});

const _resetToken = '6f1c2f0e-3c55-4d2a-9a51-0f7a4e7c2b10';

/// Happy-path backend that also enforces the real serializers' required
/// `company_code` field, like apps/accounts/serializers.py does.
ResponseBody _happyBackend(String path, Map<String, dynamic> body) {
  final code = body['company_code'];
  if (code is! String || code.isEmpty) {
    return _error('company_code: This field is required.');
  }
  if (path == ApiConstants.forgotPassword) {
    return _success('OTP sent to your email address. It is valid for 10 minutes.');
  }
  if (path == ApiConstants.verifyOtp) {
    return _success('OTP verified successfully.', {'reset_token': _resetToken});
  }
  if (path == ApiConstants.resetPassword) {
    return _success('Password reset successfully.');
  }
  return _error('Not found.', status: 404);
}

void main() {
  late ProviderContainer container;
  late _FakeBackend backend;

  void setUpBackend(ResponseBody Function(String path, Map<String, dynamic> body) respond) {
    backend = _FakeBackend(respond);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
      ..httpClientAdapter = backend;
    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      ],
    );
    addTearDown(container.dispose);
  }

  ForgotPasswordState state() => container.read(forgotPasswordProvider);
  ForgotPasswordNotifier notifier() => container.read(forgotPasswordProvider.notifier);

  group('request models', () {
    test('every recovery request serialises company_code', () {
      expect(
        const ForgotPasswordRequestModel(companyCode: 'ROYAL01', email: 'a@b.com').toJson(),
        {'company_code': 'ROYAL01', 'email': 'a@b.com'},
      );
      expect(
        const VerifyOtpRequestModel(companyCode: 'ROYAL01', email: 'a@b.com', otp: '123456')
            .toJson(),
        {'company_code': 'ROYAL01', 'email': 'a@b.com', 'otp': '123456'},
      );
      expect(
        const ResetPasswordRequestModel(
          companyCode: 'ROYAL01',
          resetToken: _resetToken,
          newPassword: 'NewPass@123',
          confirmPassword: 'NewPass@123',
        ).toJson(),
        {
          'company_code': 'ROYAL01',
          'reset_token': _resetToken,
          'new_password': 'NewPass@123',
          'confirm_password': 'NewPass@123',
        },
      );
    });
  });

  group('forgot password flow', () {
    test('sends company_code on all three requests and completes the reset', () async {
      setUpBackend(_happyBackend);

      await notifier().sendOtp('  ROYAL01 ', ' User@Example.com ');
      expect(state().step, ForgotPasswordStep.otp);
      expect(state().companyCode, 'ROYAL01');

      await notifier().verifyOtp('123456');
      expect(state().step, ForgotPasswordStep.reset);
      expect(state().resetToken, _resetToken);

      await notifier().resetPassword('NewPass@123', 'NewPass@123');
      expect(state().step, ForgotPasswordStep.success);
      expect(state().errorMessage, isNull);

      expect(backend.calls.map((c) => c.path), [
        ApiConstants.forgotPassword,
        ApiConstants.verifyOtp,
        ApiConstants.resetPassword,
      ]);
      expect(backend.calls[0].body, {'company_code': 'ROYAL01', 'email': 'user@example.com'});
      expect(backend.calls[1].body['company_code'], 'ROYAL01');
      expect(backend.calls[1].body['otp'], '123456');
      expect(backend.calls[2].body, {
        'company_code': 'ROYAL01',
        'reset_token': _resetToken,
        'new_password': 'NewPass@123',
        'confirm_password': 'NewPass@123',
      });
    });

    test('resending the OTP reuses the same company code and email', () async {
      setUpBackend(_happyBackend);

      await notifier().sendOtp('ROYAL01', 'user@example.com');
      final s = state();
      await notifier().sendOtp(s.companyCode!, s.email!);

      expect(backend.calls, hasLength(2));
      expect(backend.calls[1].body, backend.calls[0].body);
      expect(state().step, ForgotPasswordStep.otp);
    });

    test('an invalid company code stays on the email step with the server message', () async {
      setUpBackend((path, body) => _error('Invalid company code.', status: 404));

      await notifier().sendOtp('NOPE', 'user@example.com');

      expect(state().step, ForgotPasswordStep.email);
      expect(state().errorMessage, 'Invalid company code.');
      expect(state().companyCode, isNull);
      expect(state().isLoading, isFalse);
    });

    test('a missing company code is rejected by the backend contract', () async {
      setUpBackend(_happyBackend);

      await notifier().sendOtp('   ', 'user@example.com');

      expect(backend.calls.single.body['company_code'], '');
      expect(state().step, ForgotPasswordStep.email);
      expect(state().errorMessage, 'company_code: This field is required.');
    });

    test('an invalid OTP keeps the user on the OTP step and allows a retry', () async {
      var otpAttempts = 0;
      setUpBackend((path, body) {
        if (path == ApiConstants.verifyOtp && ++otpAttempts == 1) {
          return _error('Invalid OTP. Please try again.');
        }
        return _happyBackend(path, body);
      });

      await notifier().sendOtp('ROYAL01', 'user@example.com');
      await notifier().verifyOtp('000000');
      expect(state().step, ForgotPasswordStep.otp);
      expect(state().errorMessage, 'Invalid OTP. Please try again.');

      await notifier().verifyOtp('123456');
      expect(state().step, ForgotPasswordStep.reset);
      expect(state().errorMessage, isNull);
      expect(backend.calls.where((c) => c.path == ApiConstants.verifyOtp).map(
            (c) => c.body['company_code'],
          ), ['ROYAL01', 'ROYAL01']);
    });

    test('an expired OTP shows the backend message', () async {
      const expired = 'OTP has expired or maximum attempts exceeded. Please request a new OTP.';
      setUpBackend((path, body) =>
          path == ApiConstants.verifyOtp ? _error(expired) : _happyBackend(path, body));

      await notifier().sendOtp('ROYAL01', 'user@example.com');
      await notifier().verifyOtp('123456');

      expect(state().step, ForgotPasswordStep.otp);
      expect(state().errorMessage, expired);
    });

    test('a backend validation error on reset keeps the reset step', () async {
      const invalidToken = 'This reset token has already been used or has expired.';
      setUpBackend((path, body) => path == ApiConstants.resetPassword
          ? _error(invalidToken)
          : _happyBackend(path, body));

      await notifier().sendOtp('ROYAL01', 'user@example.com');
      await notifier().verifyOtp('123456');
      await notifier().resetPassword('NewPass@123', 'NewPass@123');

      expect(state().step, ForgotPasswordStep.reset);
      expect(state().errorMessage, invalidToken);
    });

    test('a network failure shows a connection message and does not advance', () async {
      setUpBackend((path, body) => throw DioException.connectionError(
            requestOptions: RequestOptions(path: path),
            reason: 'offline',
          ));

      await notifier().sendOtp('ROYAL01', 'user@example.com');

      expect(state().step, ForgotPasswordStep.email);
      expect(state().errorMessage, contains('internet'));
      expect(state().isLoading, isFalse);
    });

    test('rate limiting surfaces the server message', () async {
      setUpBackend((path, body) =>
          _error('Request was throttled. Expected available in 3600 seconds.', status: 429));

      await notifier().sendOtp('ROYAL01', 'user@example.com');

      expect(state().errorMessage, contains('throttled'));
    });

    test('OTP and reset steps do nothing before a company code was captured', () async {
      setUpBackend(_happyBackend);

      await notifier().verifyOtp('123456');
      await notifier().resetPassword('NewPass@123', 'NewPass@123');

      expect(backend.calls, isEmpty);
      expect(state().step, ForgotPasswordStep.email);
    });

    test('reset() clears the captured company code', () async {
      setUpBackend(_happyBackend);

      await notifier().sendOtp('ROYAL01', 'user@example.com');
      notifier().reset();

      expect(state().companyCode, isNull);
      expect(state().step, ForgotPasswordStep.email);
    });
  });
}

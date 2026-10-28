import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/presentation/widgets/forgot_password_form.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';

class _FakeSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

class _RecordingBackend implements HttpClientAdapter {
  final List<({String path, Object? body})> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add((path: options.path, body: options.data));
    return ResponseBody.fromString(
      jsonEncode({'status': 'success', 'message': 'OTP sent.', 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // The app's text styles use google_fonts; never fetch fonts in tests.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _RecordingBackend backend;

  Future<void> pumpForm(WidgetTester tester, {String? initialCompanyCode}) async {
    backend = _RecordingBackend();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
      ..httpClientAdapter = backend;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ForgotPasswordForm(
                onBackToLogin: () {},
                initialCompanyCode: initialCompanyCode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // AppTextField renders its label as a sibling Text above the input.
  Finder field(String label) => find.descendant(
        of: find.widgetWithText(AppTextField, label),
        matching: find.byType(TextFormField),
      );

  testWidgets('pre-fills the company code carried over from login', (tester) async {
    await pumpForm(tester, initialCompanyCode: 'ROYAL01');

    final companyField = tester.widget<TextFormField>(field('Company Code'));
    expect(companyField.controller!.text, 'ROYAL01');
  });

  testWidgets('blocks sending an OTP until a company code is entered', (tester) async {
    await pumpForm(tester);

    await tester.enterText(field('Email Address'), 'user@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Company code is required.'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets('sends the entered company code and moves to the OTP step', (tester) async {
    await pumpForm(tester);

    await tester.enterText(field('Company Code'), 'ROYAL01');
    await tester.enterText(field('Email Address'), 'user@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(backend.calls.single.path, ApiConstants.forgotPassword);
    expect(backend.calls.single.body, {'company_code': 'ROYAL01', 'email': 'user@example.com'});
    expect(find.textContaining('6-digit OTP sent to user@example.com'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/features/auth/data/models/login_request_model.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart' show authRepositoryProvider;
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/widgets/login_form.dart';
import 'package:mobile_app/shared/formatters/company_code_formatter.dart';

// Task 55: Login Company Code in upper case — typed or pasted, kept with the
// cursor where it was, and sent upper case. Backend: companies are created
// upper case (tenants/services.py) and login matches company_code__iexact, so
// this never changes which company matches. Email/password untouched (the
// existing login use case already trims and lower-cases the email).
// Synthetic credentials only; the repository is a stand-in.

class FakeAuthRepo implements AuthRepository {
  final logins = <(String, String, String)>[];
  Object? failNext;

  @override
  Future<UserEntity?> getCachedUser() async => null;

  @override
  Future<UserEntity> login(String companyCode, String email, String password) async {
    logins.add((companyCode, email, password));
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    return UserEntity(
      id: 'u1',
      email: email,
      fullName: 'Test User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: const [],
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
      companyCode: companyCode,
    );
  }

  @override
  Future<void> logout() async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<void> forgotPassword(String companyCode, String email) => throw UnimplementedError();
  @override
  Future<String> verifyOtp(String companyCode, String email, String otp) => throw UnimplementedError();
  @override
  Future<void> resetPassword(String companyCode, String resetToken, String newPassword, String confirmPassword) =>
      throw UnimplementedError();
}

late FakeAuthRepo repo;

Finder field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );
TextEditingController ctrl(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).controller!;

Future<void> pumpLogin(WidgetTester tester, {LoginPrefill? prefill}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  repo = FakeAuthRepo();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SingleChildScrollView(child: LoginForm()))),
    GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const Scaffold(body: Text('DASHBOARD'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      if (prefill != null) loginPrefillProvider.overrideWith((ref) => prefill),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester) async {
  await tester.tap(find.text('Sign In').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('normalization', () {
    test('ASCII a–z become A–Z; everything else is kept; length never changes', () {
      expect(upperCaseAscii('royal01'), 'ROYAL01');
      expect(upperCaseAscii('RoYaL-hr_2'), 'ROYAL-HR_2');
      expect(upperCaseAscii(''), '');
      expect(upperCaseAscii('ROYAL01'), 'ROYAL01');
      // Non-ASCII letters are left alone (no ß→SS / ı→I surprises).
      expect(upperCaseAscii('straße ı é'), 'STRAßE ı é');
      expect(upperCaseAscii('straße').length, 'straße'.length);
      expect(normalizeCompanyCode('  royal01 \n'), 'ROYAL01');
      expect(normalizeCompanyCode('   '), '');
    });

    test('4. the formatter keeps selection and composing range exactly', () {
      const f = UpperCaseAsciiFormatter();
      final out = f.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'roXyal',
          selection: TextSelection(baseOffset: 1, extentOffset: 4),
          composing: TextRange(start: 2, end: 4),
        ),
      );
      expect(out.text, 'ROXYAL');
      expect(out.selection, const TextSelection(baseOffset: 1, extentOffset: 4));
      expect(out.composing, const TextRange(start: 2, end: 4));
      const same = TextEditingValue(text: 'ROYAL', selection: TextSelection.collapsed(offset: 5));
      expect(identical(f.formatEditUpdate(TextEditingValue.empty, same), same), isTrue);
    });

    test('7. the request body carries the normalized code; email/password as given', () {
      final body =
          LoginRequestModel(companyCode: normalizeCompanyCode(' royal01 '), email: 'a@b.test', password: 'Pw x')
              .toJson();
      expect(body, {'company_code': 'ROYAL01', 'email': 'a@b.test', 'password': 'Pw x'});
    });
  });

  group('login form', () {
    testWidgets('1/2. lowercase and mixed case typed become upper case', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(field('Company Code'), 'royal01');
      await tester.pump();
      expect(ctrl(tester, 'Company Code').text, 'ROYAL01');
      await tester.enterText(field('Company Code'), 'RoYaL-Hr2');
      await tester.pump();
      expect(ctrl(tester, 'Company Code').text, 'ROYAL-HR2');
      final tf = tester.widget<TextField>(field('Company Code'));
      expect(tf.textCapitalization, TextCapitalization.characters);
      expect(tf.autocorrect, isFalse);
    });

    testWidgets('3. pasted text is upper-cased', (tester) async {
      await pumpLogin(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'royal-pasted01'};
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(field('Company Code'));
      await tester.pump();
      final editable = tester
          .state<EditableTextState>(find.descendant(of: field('Company Code'), matching: find.byType(EditableText)));
      await editable.pasteText(SelectionChangedCause.toolbar);
      await tester.pump();
      expect(ctrl(tester, 'Company Code').text, 'ROYAL-PASTED01');
    });

    testWidgets('4. editing in the middle keeps the cursor where the user typed', (tester) async {
      await pumpLogin(tester);
      await tester.tap(field('Company Code'));
      await tester.pump();
      tester.testTextInput
          .updateEditingValue(const TextEditingValue(text: 'ROYAL', selection: TextSelection.collapsed(offset: 2)));
      await tester.pump();
      // The keyboard inserts "x" at offset 2.
      tester.testTextInput
          .updateEditingValue(const TextEditingValue(text: 'ROxYAL', selection: TextSelection.collapsed(offset: 3)));
      await tester.pump();
      final c = ctrl(tester, 'Company Code');
      expect(c.text, 'ROXYAL');
      expect(c.selection, const TextSelection.collapsed(offset: 3));
      // A selection survives too.
      tester.testTextInput.updateEditingValue(
          const TextEditingValue(text: 'ROXyal', selection: TextSelection(baseOffset: 1, extentOffset: 5)));
      await tester.pump();
      expect((c.text, c.selection), ('ROXYAL', const TextSelection(baseOffset: 1, extentOffset: 5)));
    });

    testWidgets('5/6. empty or blank: the existing "required" message, nothing sent', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(field('Email Address'), 'user@example.test');
      await tester.enterText(field('Password'), 'pw');
      await signIn(tester);
      expect(find.text('Company code is required.'), findsOneWidget);
      await tester.enterText(field('Company Code'), '   ');
      await signIn(tester);
      expect(repo.logins, isEmpty);
    });

    testWidgets('7/10. sign-in sends the upper-case trimmed code; email handling and password unchanged',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(field('Company Code'), ' royal01 ');
      await tester.enterText(field('Email Address'), 'Mixed.Case@Example.Test');
      await tester.enterText(field('Password'), 'MiXeD pass!');
      expect(ctrl(tester, 'Email Address').text, 'Mixed.Case@Example.Test',
          reason: 'the email field itself is not changed');
      await signIn(tester);
      // Email: trimmed and lower-cased by the existing login use case (as
      // before this task); password exactly as typed.
      expect(repo.logins.single, ('ROYAL01', 'mixed.case@example.test', 'MiXeD pass!'));
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('8. a prefilled company code (after a forced password change) is shown and sent upper case',
        (tester) async {
      await pumpLogin(tester,
          prefill: const LoginPrefill(companyCode: 'royal01', email: 'user@example.test', notice: 'Password changed.'));
      expect(ctrl(tester, 'Company Code').text, 'ROYAL01');
      expect(ctrl(tester, 'Email Address').text, 'user@example.test');
      await tester.enterText(field('Password'), 'new-pass');
      await signIn(tester);
      expect(repo.logins.single.$1, 'ROYAL01');
    });

    testWidgets('9. a failed sign-in shows the server message; the retry sends the same normalized code',
        (tester) async {
      await pumpLogin(tester);
      repo.failNext = const UnauthorizedException('Invalid credentials.');
      await tester.enterText(field('Company Code'), 'royal01');
      await tester.enterText(field('Email Address'), 'user@example.test');
      await tester.enterText(field('Password'), 'wrong');
      await signIn(tester);
      expect(find.textContaining('Invalid credentials'), findsOneWidget);
      expect(ctrl(tester, 'Company Code').text, 'ROYAL01', reason: 'kept for the retry');
      await tester.enterText(field('Password'), 'right');
      await signIn(tester);
      expect(repo.logins.map((l) => l.$1), ['ROYAL01', 'ROYAL01']);
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('10. Email and Password fields have no upper-case formatter', (tester) async {
      await pumpLogin(tester);
      await tester.enterText(field('Email Address'), 'lower@example.test');
      await tester.enterText(field('Password'), 'lowerpass');
      await tester.pump();
      expect(ctrl(tester, 'Email Address').text, 'lower@example.test');
      expect(ctrl(tester, 'Password').text, 'lowerpass');
      expect(tester.widget<TextField>(field('Email Address')).inputFormatters ?? const [], isEmpty);
      expect(tester.widget<TextField>(field('Password')).inputFormatters ?? const [], isEmpty);
    });

    testWidgets('use case: any caller is normalized (no path sends lower case)', (tester) async {
      await pumpLogin(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(LoginForm)));
      await container.read(authStateProvider.notifier).login('  mixedCase9 ', 'a@b.test', 'p');
      expect(repo.logins.single.$1, 'MIXEDCASE9');
    });
  });
}

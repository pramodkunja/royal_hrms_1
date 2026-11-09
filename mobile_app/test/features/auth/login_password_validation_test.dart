import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/app_constants.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/auth/presentation/widgets/login_form.dart';
import 'package:mobile_app/shared/validators/form_validators.dart';

// P0: sign-in must accept any non-empty password. Production LoginSerializer
// has password min_length=1 and web login has no length check; the 8-char
// rule belongs only to creating/changing a password (ChangePassword /
// ResetPassword serializers min_length=8). Synthetic credentials only.

class _FakeAuth extends AuthNotifier {
  final logins = <List<String>>[];
  @override
  Future<AuthState> build() async => const AuthState();
  @override
  Future<void> login(String companyCode, String email, String password) async {
    logins.add([companyCode, email, password]);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('FormValidators.loginPassword (sign-in)', () {
    test('accepts a non-empty password shorter than eight characters', () {
      expect(AppConstants.minPasswordLength, 8);
      expect(FormValidators.loginPassword('abc'), isNull);
      expect(FormValidators.loginPassword('1'), isNull);
      expect(FormValidators.loginPassword('abcdefgh'), isNull);
    });

    test('rejects an empty password', () {
      expect(FormValidators.loginPassword(''), 'Password is required.');
      expect(FormValidators.loginPassword(null), 'Password is required.');
    });
  });

  group('FormValidators.password (create / change / reset) is unchanged', () {
    test('still requires at least eight characters', () {
      expect(FormValidators.password('abc'), 'Password must be at least 8 characters.');
      expect(FormValidators.password('abcdefg'), 'Password must be at least 8 characters.');
      expect(FormValidators.password('abcdefgh'), isNull);
    });

    test('still rejects an empty password', () {
      expect(FormValidators.password(''), 'Password is required.');
      expect(FormValidators.password(null), 'Password is required.');
    });
  });

  group('LoginForm', () {
    late _FakeAuth auth;

    Future<void> pumpForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      auth = _FakeAuth();
      await tester.pumpWidget(ProviderScope(
        overrides: [authStateProvider.overrideWith(() => auth)],
        child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LoginForm()))),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, {required String password}) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'TEST01');
      await tester.enterText(fields.at(1), 'user@example.test');
      await tester.enterText(fields.at(2), password);
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
    }

    testWidgets('a short non-empty password passes validation and is submitted as typed', (tester) async {
      await pumpForm(tester);
      await fill(tester, password: 'abc');
      expect(find.textContaining('at least 8 characters'), findsNothing);
      expect(auth.logins, [
        ['TEST01', 'user@example.test', 'abc']
      ]);
    });

    testWidgets('an empty password is rejected and nothing is submitted', (tester) async {
      await pumpForm(tester);
      await fill(tester, password: '');
      expect(find.text('Password is required.'), findsOneWidget);
      expect(auth.logins, isEmpty);
    });
  });
}

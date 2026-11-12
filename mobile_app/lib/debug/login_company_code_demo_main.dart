// DEBUG-ONLY demo of Login → Company Code upper-casing (Task 55) on the real
// login form, without calling a server:
//
//   flutter run -d <emulator> -t lib/debug/login_company_code_demo_main.dart
//
// The auth repository is a stand-in: every sign-in is refused (so the form
// stays for a retry) and what would have been sent is shown on screen, with
// the password masked. A button puts a lower-case code on the clipboard for
// the paste test. Not imported by lib/main.dart, so not part of the release
// app; refuses to run outside debug builds.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/exceptions.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart' show authRepositoryProvider;
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/widgets/login_form.dart';

final _sent = ValueNotifier<String>('Nothing sent yet');

class _DemoRepo implements AuthRepository {
  int attempts = 0;

  @override
  Future<UserEntity?> getCachedUser() async => null;

  @override
  Future<UserEntity> login(String companyCode, String email, String password) async {
    attempts++;
    final line = 'Attempt $attempts → company_code="$companyCode" email="$email" password=${'•' * password.length}';
    debugPrint('FAKE_AUTH company_code="$companyCode" attempt=$attempts');
    _sent.value = line;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    throw const UnauthorizedException('Invalid credentials. (demo: every sign-in is refused)');
  }

  @override
  Future<void> logout() async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<void> forgotPassword(String companyCode, String email) async {}
  @override
  Future<String> verifyOtp(String companyCode, String email, String otp) async => '';
  @override
  Future<void> resetPassword(String companyCode, String resetToken, String newPassword, String confirmPassword) async {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  runApp(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(_DemoRepo())],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton(
                key: const Key('copy-code'),
                onPressed: () => Clipboard.setData(const ClipboardData(text: 'royal-paste01')),
                child: const Text('Copy "royal-paste01" to clipboard'),
              ),
              const SizedBox(height: 16),
              const LoginForm(),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _sent,
                builder: (_, v, __) => Text(v, key: const Key('sent'), style: const TextStyle(fontFamily: 'monospace')),
              ),
            ]),
          ),
        ),
      ),
    ),
  ));
}

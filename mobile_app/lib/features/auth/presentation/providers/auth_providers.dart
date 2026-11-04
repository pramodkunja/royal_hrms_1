import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_notifier.dart';
import '../controllers/forgot_password_notifier.dart';
import '../states/auth_state.dart';
import '../states/forgot_password_state.dart';

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final forgotPasswordProvider =
    NotifierProvider<ForgotPasswordNotifier, ForgotPasswordState>(
  ForgotPasswordNotifier.new,
);

/// Non-secret values handed from a completed forced password change
/// (ForceChangePasswordScreen) to the login form, so the user doesn't retype
/// the company code and email they signed in with seconds ago — mirrors
/// web's app/change-password/page.tsx redirect to /login?company_code=&email=.
/// Never carries a password. LoginForm reads it once and clears it.
class LoginPrefill {
  final String? companyCode;
  final String? email;
  final String? notice;

  const LoginPrefill({this.companyCode, this.email, this.notice});
}

final loginPrefillProvider = StateProvider<LoginPrefill?>((ref) => null);

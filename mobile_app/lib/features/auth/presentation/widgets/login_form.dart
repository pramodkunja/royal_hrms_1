import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/shared/validators/form_validators.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(authStateProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);

    // Imperative navigation: runs after the async login call completes,
    // so we are never inside a build phase here. ref.listen in build() can
    // fire during a rebuild and trigger "modify provider during build" errors.
    if (!mounted) return;
    if (ref.read(authStateProvider).valueOrNull?.isAuthenticated ?? false) {
      context.go(AppRoutes.dashboard);
    }
  }

  String _formatError(Object? error) {
    if (error == null) return 'An unknown error occurred.';
    if (error is UnauthorizedException) {
      return 'Invalid email or password. Please check your credentials.';
    }
    if (error is AccountLockedException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Your account has been locked. Please contact HR support.';
    }
    if (error is RateLimitException) {
      return 'Too many sign-in attempts. Please wait a few minutes and try again.';
    }
    if (error is NetworkException) {
      final msg = error.message;
      if (msg.contains('XMLHttpRequest') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Connection refused') ||
          msg.contains('SocketException')) {
        return 'Cannot reach the server. Check your network connection.';
      }
      return msg;
    }
    if (error is AppException) return error.message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final isLoading = authAsync.isLoading;
    final errorMessage = authAsync.hasError ? _formatError(authAsync.error) : null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errorMessage != null) _ErrorBanner(message: errorMessage),
          if (errorMessage != null) const SizedBox(height: 16),
          AppTextField(
            label: 'Email Address',
            hint: 'you@company.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: FormValidators.email,
            enabled: !isLoading,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _passwordCtrl,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            validator: FormValidators.password,
            enabled: !isLoading,
            onFieldSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textHint,
                size: 20,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : () => context.push(AppRoutes.forgotPassword),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              child: Text(
                'Forgot password?',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Sign In',
            onPressed: _submit,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

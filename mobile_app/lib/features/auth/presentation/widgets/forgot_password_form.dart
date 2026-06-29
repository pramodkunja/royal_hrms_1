import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/shared/validators/form_validators.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';
import '../providers/auth_providers.dart';
import '../states/forgot_password_state.dart';
import 'otp_input_widget.dart';

class ForgotPasswordForm extends ConsumerStatefulWidget {
  final VoidCallback onBackToLogin;

  const ForgotPasswordForm({super.key, required this.onBackToLogin});

  @override
  ConsumerState<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<ForgotPasswordForm> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _currentOtp = '';
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);
    final notifier = ref.read(forgotPasswordProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.errorMessage != null) ...[
          _ErrorBanner(message: state.errorMessage!),
          const SizedBox(height: 16),
        ],
        switch (state.step) {
          ForgotPasswordStep.email => _EmailStep(
              formKey: _emailFormKey,
              controller: _emailCtrl,
              isLoading: state.isLoading,
              onSubmit: () {
                if (_emailFormKey.currentState?.validate() ?? false) {
                  notifier.sendOtp(_emailCtrl.text);
                }
              },
              onBackToLogin: widget.onBackToLogin,
            ),
          ForgotPasswordStep.otp => _OtpStep(
              email: state.email ?? '',
              isLoading: state.isLoading,
              onOtpChanged: (otp) => _currentOtp = otp,
              onSubmit: () => notifier.verifyOtp(_currentOtp),
              onResend: () => notifier.sendOtp(state.email ?? ''),
            ),
          ForgotPasswordStep.reset => _ResetStep(
              formKey: _resetFormKey,
              passwordCtrl: _passwordCtrl,
              confirmCtrl: _confirmCtrl,
              showPassword: _showPassword,
              showConfirm: _showConfirm,
              isLoading: state.isLoading,
              onTogglePassword: () => setState(() => _showPassword = !_showPassword),
              onToggleConfirm: () => setState(() => _showConfirm = !_showConfirm),
              onSubmit: () {
                if (_resetFormKey.currentState?.validate() ?? false) {
                  notifier.resetPassword(_passwordCtrl.text);
                }
              },
            ),
          ForgotPasswordStep.success => _SuccessStep(onBackToLogin: widget.onBackToLogin),
        },
      ],
    );
  }
}

class _EmailStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;

  const _EmailStep({
    required this.formKey,
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter your registered email and we\'ll send you an OTP.',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Email Address',
            hint: 'you@company.com',
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: FormValidators.email,
            enabled: !isLoading,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Send OTP', onPressed: onSubmit, isLoading: isLoading),
          const SizedBox(height: 12),
          AppButton(
            label: 'Back to Login',
            onPressed: isLoading ? null : onBackToLogin,
            variant: AppButtonVariant.ghost,
          ),
        ],
      ),
    );
  }
}

class _OtpStep extends StatelessWidget {
  final String email;
  final bool isLoading;
  final void Function(String) onOtpChanged;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _OtpStep({
    required this.email,
    required this.isLoading,
    required this.onOtpChanged,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the 6-digit OTP sent to $email.',
            style: AppTextStyles.bodySecondary),
        const SizedBox(height: 24),
        OtpInputWidget(onCompleted: onOtpChanged, onChanged: onOtpChanged),
        const SizedBox(height: 24),
        AppButton(label: 'Verify OTP', onPressed: isLoading ? null : onSubmit, isLoading: isLoading),
        const SizedBox(height: 12),
        AppButton(
          label: 'Resend OTP',
          onPressed: isLoading ? null : onResend,
          variant: AppButtonVariant.ghost,
        ),
      ],
    );
  }
}

class _ResetStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool showPassword;
  final bool showConfirm;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  const _ResetStep({
    required this.formKey,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.showPassword,
    required this.showConfirm,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create a new password for your account.', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 20),
          AppTextField(
            label: 'New Password',
            hint: 'Minimum 8 characters',
            controller: passwordCtrl,
            obscureText: !showPassword,
            textInputAction: TextInputAction.next,
            validator: FormValidators.password,
            enabled: !isLoading,
            suffixIcon: IconButton(
              icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textHint, size: 20),
              onPressed: onTogglePassword,
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirm New Password',
            hint: 'Re-enter your password',
            controller: confirmCtrl,
            obscureText: !showConfirm,
            textInputAction: TextInputAction.done,
            validator: (v) => FormValidators.confirmPassword(v, passwordCtrl.text),
            enabled: !isLoading,
            onFieldSubmitted: (_) => onSubmit(),
            suffixIcon: IconButton(
              icon: Icon(showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textHint, size: 20),
              onPressed: onToggleConfirm,
            ),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Reset Password', onPressed: isLoading ? null : onSubmit, isLoading: isLoading),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final VoidCallback onBackToLogin;

  const _SuccessStep({required this.onBackToLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
        const SizedBox(height: 16),
        Text('Password Reset Successful!',
            style: AppTextStyles.h4, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Your password has been updated. You can now sign in.',
            style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        AppButton(label: 'Back to Login', onPressed: onBackToLogin),
      ],
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
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

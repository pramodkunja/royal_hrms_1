import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/shared/validators/form_validators.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';
import 'package:mobile_app/shared/widgets/auth_background.dart';
import '../providers/auth_providers.dart';

/// Mandatory password change for a user whose login response carried
/// `must_change_password: true` (a provisioning-time or admin-reset
/// password). resolveAuthRedirect keeps such a user on this screen until the
/// flag clears — mirrors web's app/change-password/page.tsx.
///
/// Uses the same POST /change-password/ {old_password, new_password,
/// confirm_password} as the profile screen (apps/accounts/views.py
/// ChangePasswordView). On success the backend clears the flag, blacklists
/// the refresh token and deletes the auth cookies — the session is over, so
/// this logs out locally and the router moves to login, with the company
/// code and email pre-filled. The next login's response is the authoritative
/// check that the flag is cleared: if it is still set, the router sends the
/// user straight back here.
class ForceChangePasswordScreen extends ConsumerStatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  ConsumerState<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends ConsumerState<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPasswords = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Duplicate-submission guard: a second tap while a request is in flight
    // is ignored (the button is also disabled, but onFieldSubmitted isn't).
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await changeMyPassword(
      ref,
      oldPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    if (!mounted) return;
    if (err != null) {
      // Rejected or unreachable: the requirement stays exactly as it was.
      setState(() {
        _submitting = false;
        _error = err;
      });
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull?.user;
    ref.read(loginPrefillProvider.notifier).state = LoginPrefill(
      companyCode: user?.companyCode,
      email: user?.email,
      notice: 'Password changed. Sign in with your new password.',
    );
    _currentCtrl.clear();
    _newCtrl.clear();
    _confirmCtrl.clear();
    // The server already ended the session; clear it locally. The router
    // reacts to the auth change and moves to login on its own.
    await ref.read(authStateProvider.notifier).logout();
  }

  Future<void> _logout() async {
    if (_submitting) return;
    await ref.read(authStateProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).valueOrNull?.user?.email;

    // Back navigation can't leave this screen: there is nowhere else this
    // user is allowed to go (resolveAuthRedirect would bounce them back).
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuthBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Set a new password',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'You’re signed in with a temporary password. Choose a new one to continue.',
                                style: AppTextStyles.bodySecondary,
                              ),
                              if (email != null) ...[
                                const SizedBox(height: 4),
                                Text(email, style: AppTextStyles.bodySmall),
                              ],
                              const SizedBox(height: 20),
                              if (_error != null) ...[
                                _ErrorBanner(message: _error!),
                                const SizedBox(height: 16),
                              ],
                              AppTextField(
                                label: 'Current Password',
                                hint: 'Your temporary password',
                                controller: _currentCtrl,
                                obscureText: !_showPasswords,
                                textInputAction: TextInputAction.next,
                                validator: (v) => FormValidators.required(v, fieldName: 'Current password'),
                                enabled: !_submitting,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'New Password',
                                hint: 'Minimum 8 characters',
                                controller: _newCtrl,
                                obscureText: !_showPasswords,
                                textInputAction: TextInputAction.next,
                                // Mirrors ChangePasswordSerializer: min length 8
                                // and different from the current password. The
                                // server's own validators (common/numeric/
                                // similar-to-user) come back as its message.
                                validator: (v) {
                                  final base = FormValidators.password(v);
                                  if (base != null) return base;
                                  if (v == _currentCtrl.text) {
                                    return 'New password must be different from the current password.';
                                  }
                                  return null;
                                },
                                enabled: !_submitting,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Confirm New Password',
                                hint: 'Re-enter your new password',
                                controller: _confirmCtrl,
                                obscureText: !_showPasswords,
                                textInputAction: TextInputAction.done,
                                validator: (v) => FormValidators.confirmPassword(v, _newCtrl.text),
                                enabled: !_submitting,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _showPasswords = !_showPasswords),
                                  icon: Icon(
                                    _showPasswords ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: Text(_showPasswords ? 'Hide passwords' : 'Show passwords'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'Change Password',
                                onPressed: _submitting ? null : _submit,
                                isLoading: _submitting,
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: 'Log Out',
                                onPressed: _submitting ? null : _logout,
                                variant: AppButtonVariant.ghost,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

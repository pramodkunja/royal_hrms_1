import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';
import '../states/forgot_password_state.dart';
import '../widgets/forgot_password_form.dart';

class ForgotPasswordScreen extends ConsumerWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(forgotPasswordProvider.select((s) => s.step));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // onPopInvokedWithResult fires inside Navigator.didUpdateWidget — a
        // widget rebuild. Riverpod forbids direct provider writes during any
        // build phase. Future.microtask defers reset() to the next microtask,
        // which runs after the current build finishes.
        Future.microtask(() => ref.read(forgotPasswordProvider.notifier).reset());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            // reset() is already handled by PopScope.onPopInvokedWithResult —
            // calling it here too would double-reset AND risk a second build-
            // phase write. Just pop; the PopScope callback takes care of cleanup.
            onPressed: () => context.pop(),
          ),
          title: Text(_stepTitle(step), style: AppTextStyles.h4),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepIndicator(currentStep: step),
                      const SizedBox(height: 28),
                      ForgotPasswordForm(
                        onBackToLogin: () {
                          // This uses context.go(), which does NOT trigger
                          // PopScope, so it is safe to reset() here directly.
                          ref.read(forgotPasswordProvider.notifier).reset();
                          context.go(AppRoutes.login);
                        },
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

  String _stepTitle(ForgotPasswordStep step) => switch (step) {
        ForgotPasswordStep.email => 'Forgot Password',
        ForgotPasswordStep.otp => 'Verify OTP',
        ForgotPasswordStep.reset => 'New Password',
        ForgotPasswordStep.success => 'Done',
      };
}

class _StepIndicator extends StatelessWidget {
  final ForgotPasswordStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ForgotPasswordStep.values;
    final current = steps.indexOf(currentStep);

    return Row(
      children: List.generate(steps.length - 1, (i) {
        final isActive = i <= current;
        final isCompleted = i < current;
        return Expanded(
          child: Row(
            children: [
              _StepDot(isActive: isActive, isCompleted: isCompleted, number: i + 1),
              if (i < steps.length - 2)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? AppColors.primary : AppColors.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool isActive;
  final bool isCompleted;
  final int number;

  const _StepDot({required this.isActive, required this.isCompleted, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.primary : AppColors.border,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text(
                '$number',
                style: AppTextStyles.labelSmall.copyWith(
                  color: isActive ? Colors.white : AppColors.textHint,
                ),
              ),
      ),
    );
  }
}

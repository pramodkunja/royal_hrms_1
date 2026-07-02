import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/shared/widgets/auth_background.dart';
import '../widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LoginHeader(),
                    SizedBox(height: 32),
                    _LoginCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.elevatedShadow,
          ),
          child: Image.asset(
            'assets/images/Royal_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Text('👑', style: TextStyle(fontSize: 36))),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Royal HRMS',
          style: AppTextStyles.h2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Enterprise HR Management',
          style: AppTextStyles.bodySecondary.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign In', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text('Enter your credentials to continue', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 24),
          const LoginForm(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';

/// Full-screen "404 / not found" state, shown by GoRouter's [errorBuilder]
/// for unmatched routes and reusable inside individual screens for a
/// resource-not-found (API 404) result.
class NotFoundView extends StatelessWidget {
  final String? message;
  final VoidCallback? onGoHome;

  const NotFoundView({super.key, this.message, this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Lottie.asset(
                    'assets/animations/404 error page with cat.json',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Page Not Found', style: AppTextStyles.h3, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  message ?? "The page you're looking for doesn't exist or has been moved.",
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Go to Dashboard',
                  leadingIcon: Icons.home_outlined,
                  onPressed: onGoHome ?? () => context.go(AppRoutes.dashboard),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

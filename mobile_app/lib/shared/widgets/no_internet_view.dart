import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';

/// Full-screen "no internet connection" state. Used app-wide by the global
/// connectivity overlay (see [ConnectivityOverlay]) and can also be dropped
/// into any individual screen's error branch.
class NoInternetView extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const NoInternetView({super.key, this.onRetry, this.message});

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
                  width: 220,
                  height: 220,
                  child: Lottie.asset(
                    'assets/animations/No internet connection.json',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Internet Connection',
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? 'Please check your network settings and try again.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Retry',
                    onPressed: onRetry,
                    width: 160,
                    leadingIcon: Icons.refresh,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';

/// Placeholder dashboard — replace with full implementation in the next module.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Royal HRMS', style: AppTextStyles.h4),
        backgroundColor: AppColors.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user?.fullName.isNotEmpty == true
                    ? user!.fullName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.surface),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: AppTextStyles.bodySecondary,
              ),
              Text(
                user?.fullName ?? 'User',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user?.roleDisplay ?? '',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Sign Out',
                variant: AppButtonVariant.outline,
                leadingIcon: Icons.logout_rounded,
                onPressed: () => ref.read(authStateProvider.notifier).logout(),
              ),
              const SizedBox(height: 8),
              Text(
                'Dashboard module coming soon.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

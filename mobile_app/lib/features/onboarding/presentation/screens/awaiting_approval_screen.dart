import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class AwaitingApprovalScreen extends ConsumerWidget {
  const AwaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _IllustrationCard(),
              const SizedBox(height: 40),
              Text(
                'Profile Submitted!',
                style: AppTextStyles.h1
                    .copyWith(fontSize: 26, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your profile has been submitted successfully and is awaiting HR approval.\n\nYou will receive an email once your profile is approved and your employee account is activated.',
                style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const _StatusTimeline(),
              const Spacer(flex: 3),
              _LogoutButton(ref: ref),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_top_rounded,
            size: 56,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: const Column(
        children: [
          _TimelineStep(
            icon: Icons.check_circle_rounded,
            iconColor: Color(0xFF22C55E),
            label: 'Profile Submitted',
            sublabel: 'Waiting for HR review',
            isDone: true,
          ),
          _TimelineDivider(isDone: false),
          _TimelineStep(
            icon: Icons.manage_accounts_outlined,
            iconColor: AppColors.textSecondary,
            label: 'HR Review',
            sublabel: 'Your documents are being verified',
            isDone: false,
          ),
          _TimelineDivider(isDone: false),
          _TimelineStep(
            icon: Icons.badge_outlined,
            iconColor: AppColors.textSecondary,
            label: 'Account Activation',
            sublabel: 'Access your employee dashboard',
            isDone: false,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.isDone,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                : AppColors.border.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDone
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineDivider extends StatelessWidget {
  const _TimelineDivider({required this.isDone});
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
      child: Container(
        width: 2,
        height: 24,
        color: isDone
            ? const Color(0xFF22C55E)
            : AppColors.border.withValues(alpha: 0.4),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref.read(authStateProvider.notifier).logout();
        },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Logout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

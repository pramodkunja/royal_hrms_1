import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class AwaitingApprovalScreen extends ConsumerStatefulWidget {
  const AwaitingApprovalScreen({super.key});

  @override
  ConsumerState<AwaitingApprovalScreen> createState() =>
      _AwaitingApprovalScreenState();
}

class _AwaitingApprovalScreenState
    extends ConsumerState<AwaitingApprovalScreen> {
  Timer? _timer;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _pollStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    try {
      final dio = ref.read(dioProvider);
      final response =
          await dio.get(ApiConstants.onboardingProfile);
      final raw = response.data;
      final data = raw is Map && raw.containsKey('data')
          ? raw['data'] as Map<String, dynamic>
          : raw as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status == 'complete' && mounted) {
        setState(() => _approved = true);
      }
    } catch (_) {
      // Silently ignore poll errors — will retry in 30s.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _approved
            ? _ApprovedView(
                onContinue: () {
                  ref
                      .read(authStateProvider.notifier)
                      .updateOnboardingStatus('complete');
                },
              )
            : _WaitingView(
                onRefresh: _pollStatus,
                onLogout: () =>
                    ref.read(authStateProvider.notifier).logout(),
              ),
      ),
    );
  }
}

// ─── Waiting view ───────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.onRefresh, required this.onLogout});
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _CircleIcon(
            icon: Icons.hourglass_top_rounded,
            color: AppColors.primary,
            bgColor: AppColors.primary.withValues(alpha: 0.08),
          ),
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
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const _StatusTimeline(approved: false),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Approved view ───────────────────────────────────────────────────────────

class _ApprovedView extends StatelessWidget {
  const _ApprovedView({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _CircleIcon(
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF22C55E),
            bgColor: const Color(0xFF22C55E).withValues(alpha: 0.08),
          ),
          const SizedBox(height: 40),
          Text(
            'Application Approved!',
            style: AppTextStyles.h1.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF22C55E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Congratulations! Your profile has been reviewed and approved by HR. Your employee account is now active.',
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const _StatusTimeline(approved: true),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text('Go to Dashboard'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Shared components ────────────────────────────────────────────────────────

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 56, color: color),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.approved});
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const _TimelineStep(
            icon: Icons.check_circle_rounded,
            iconColor: Color(0xFF22C55E),
            label: 'Profile Submitted',
            sublabel: 'Waiting for HR review',
            isDone: true,
          ),
          _TimelineDivider(isDone: approved),
          _TimelineStep(
            icon: approved
                ? Icons.check_circle_rounded
                : Icons.manage_accounts_outlined,
            iconColor: approved
                ? const Color(0xFF22C55E)
                : AppColors.textSecondary,
            label: 'HR Review',
            sublabel: approved
                ? 'Your documents have been verified'
                : 'Your documents are being verified',
            isDone: approved,
          ),
          _TimelineDivider(isDone: approved),
          _TimelineStep(
            icon: approved ? Icons.badge_rounded : Icons.badge_outlined,
            iconColor: approved
                ? const Color(0xFF22C55E)
                : AppColors.textSecondary,
            label: 'Account Activation',
            sublabel: approved
                ? 'Your employee account is now active'
                : 'Access your employee dashboard',
            isDone: approved,
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
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDone
                        ? AppColors.textPrimary
                        : AppColors.textSecondary),
              ),
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

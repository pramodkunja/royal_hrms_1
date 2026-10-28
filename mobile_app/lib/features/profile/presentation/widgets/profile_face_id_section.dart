import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../facial_recognition/presentation/controllers/face_registration_controller.dart';
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import '../../../facial_recognition/presentation/state/face_registration_state.dart';
import '../../../facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
import '../../../facial_recognition/presentation/widgets/face_consent_text.dart';
import '../../../facial_recognition/presentation/widgets/face_status_badge.dart';
import 'profile_widgets.dart';

/// Ports web's "Face Registration" card on ProfileClient.tsx exactly (see
/// hooks/useFaceRegistrationCard.ts for the state precedence this mirrors):
/// the toggle-off ("disabled") state shows a contact-admin message with no
/// action, and every other state offers a capture button — "Register My
/// Face" the first time (faceCardState "not_registered"), "Update My Face"
/// once a registration already exists (approved/rejected), matching web's
/// `mode={faceCardState === "not_registered" ? "register" : "update"}`.
class ProfileFaceIdSection extends ConsumerStatefulWidget {
  const ProfileFaceIdSection({super.key});

  @override
  ConsumerState<ProfileFaceIdSection> createState() => _ProfileFaceIdSectionState();
}

class _ProfileFaceIdSectionState extends ConsumerState<ProfileFaceIdSection> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(faceRegistrationControllerProvider.notifier).loadStatus());
  }

  /// Backs both the first-time "Register My Face" button and the
  /// post-registration "Update My Face" one — both go through the exact same
  /// self-submit capture flow (POST /attendance/face-registration/ via
  /// FaceRegistrationController.submit), only the sheet's copy differs. A
  /// first-time submission and a replacement submission are the same backend
  /// call; the endpoint doesn't distinguish them.
  Future<void> _openCaptureFlow({required String title, required String subtitle}) async {
    final controller = ref.read(faceRegistrationControllerProvider.notifier);
    controller.startCapture();
    final result = await showFaceCaptureSheet(
      context,
      title: title,
      subtitle: subtitle,
      consentNoticeText: kFaceConsentNoticeEmployee,
    );

    if (!mounted) return;
    if (result?.captured.embedding != null) {
      await controller.submit(result!.captured, consentAcknowledged: result.consentAcknowledged);
      if (mounted && ref.read(faceRegistrationControllerProvider).phase == FaceRegistrationPhase.error) {
        final message = ref.read(faceRegistrationControllerProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Could not save your face ID.'), backgroundColor: AppColors.error),
        );
      }
    } else {
      controller.cancelCapture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final verificationAsync = ref.watch(faceVerificationStatusProvider);
    final regState = ref.watch(faceRegistrationControllerProvider);

    return verificationAsync.when(
      data: (verification) => _card(isMandatory: verification.isMandatory, regState: regState),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _card({required bool isMandatory, required FaceRegistrationUiState regState}) {
    if (!isMandatory) {
      return ProfileSectionCard(
        icon: Icons.face_outlined,
        title: 'Face Registration',
        child: _InfoRow(
          icon: Icons.face_retouching_off_outlined,
          iconColor: AppColors.textHint,
          title: 'Face ID verification is currently disabled',
          subtitle: 'Contact admin to use this feature.',
        ),
      );
    }

    final busy = regState.phase == FaceRegistrationPhase.capturing || regState.phase == FaceRegistrationPhase.submitting;
    // isRegisterMode picks the sheet copy and button label ("Register My
    // Face" vs "Update My Face") — otherwise both buttons do the exact same
    // thing (see _openCaptureFlow's own doc comment).
    final (title, subtitle, iconColor, showActionButton, isRegisterMode) = switch (regState.phase) {
      FaceRegistrationPhase.approved => (
          'Face ID registered', 'Required for clock-in/out.', AppColors.success, true, false,
        ),
      FaceRegistrationPhase.pending || FaceRegistrationPhase.capturing || FaceRegistrationPhase.submitting => (
          'Face ID pending HR approval', 'You\'ll be able to clock in with it once it\'s approved.', AppColors.warning, false, false,
        ),
      FaceRegistrationPhase.rejected => (
          'Face ID registration was rejected',
          regState.registration?.notes.isNotEmpty == true ? regState.registration!.notes : 'Please update and resubmit.',
          AppColors.error,
          true,
          false,
        ),
      FaceRegistrationPhase.idle || FaceRegistrationPhase.error => (
          'Face ID not yet registered',
          'Register your face to clock in and out with Face ID.',
          AppColors.textHint,
          true,
          true,
        ),
    };

    return ProfileSectionCard(
      icon: Icons.face_outlined,
      title: 'Face Registration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoRow(icon: Icons.face_outlined, iconColor: iconColor, title: title, subtitle: subtitle),
              ),
              const SizedBox(width: 8),
              FaceStatusBadge(status: regState.registration?.status),
            ],
          ),
          if (showActionButton) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _openCaptureFlow(
                          title: isRegisterMode ? 'Register My Face' : 'Update My Face',
                          subtitle: isRegisterMode
                              ? 'This registers your Face ID for clock-in verification.'
                              : 'This replaces your current Face ID and needs re-approval.',
                        ),
                icon: busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt_outlined, size: 16),
                label: Text(busy
                    ? (isRegisterMode ? 'Registering…' : 'Updating…')
                    : (isRegisterMode ? 'Register My Face' : 'Update My Face')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoRow({required this.icon, required this.iconColor, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

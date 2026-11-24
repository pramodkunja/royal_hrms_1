import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../diagnostics/face_diagnostics.dart';
import '../capture/face_capture_controller.dart';
import '../capture/face_capture_state.dart';
import '../../face_api/face_api_pipeline.dart' show kRegistrationFramesToCapture, kVerificationFramesToCapture;
import '../capture/liveness_tracker.dart';
import 'face_capture_camera_view.dart';
import 'face_consent_panel.dart';

/// Result of [showFaceCaptureSheet] — the captured embedding plus whether a
/// consent notice had to be (and was) acknowledged first. `consentAcknowledged`
/// is always true when [showFaceCaptureSheet] was called with a
/// `consentNoticeText` (the sheet can't return at all otherwise), and always
/// false when it wasn't (clock-in verification never asks for consent).
class FaceCaptureSheetResult {
  final FaceCaptureUiState captured;
  final bool consentAcknowledged;
  const FaceCaptureSheetResult({required this.captured, required this.consentAcknowledged});
}

/// Single entry point for every face-capture flow in the app (self
/// registration, HR-assisted registration, clock-in verification). Opens a
/// dedicated full-screen "Face ID Check" route (the old half-height bottom
/// sheet left the preview cramped and the guide unrelated to the camera).
/// The function name and result type are unchanged so no caller has to change.
///
/// Pass [consentNoticeText] for registration flows (self-service or
/// HR-witnessed) — a consent screen is shown first and the camera never
/// opens until it's acknowledged. Omit it for clock-in verification, which
/// never collects new biometric data and so never needs fresh consent.
/// Back / close returns null (cancelled); the camera is released on exit.
Future<FaceCaptureSheetResult?> showFaceCaptureSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  String instructionText = 'Look directly at the camera',
  String? consentNoticeText,
}) {
  return Navigator.of(context).push<FaceCaptureSheetResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FaceCaptureScreen(
        subtitle: subtitle,
        instructionText: instructionText,
        consentNoticeText: consentNoticeText,
      ),
    ),
  );
}

class FaceCaptureScreen extends ConsumerStatefulWidget {
  final String subtitle;
  final String instructionText;
  final String? consentNoticeText;

  const FaceCaptureScreen({
    super.key,
    required this.subtitle,
    required this.instructionText,
    required this.consentNoticeText,
  });

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> with WidgetsBindingObserver {
  late bool _consentAcknowledged = widget.consentNoticeText == null;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (!_consentAcknowledged) return;
    if (lifecycle == AppLifecycleState.paused) {
      _wasBackgrounded = true;
    } else if (lifecycle == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      // The OS may have taken the camera while backgrounded (or the user may
      // have changed the permission): restart cleanly instead of showing a
      // frozen preview. A finished capture is left alone.
      final phase = ref.read(faceCaptureControllerProvider).phase;
      if (phase != FaceCapturePhase.ready && phase != FaceCapturePhase.extractingEmbedding) {
        ref.read(faceCaptureControllerProvider.notifier).retry();
      }
    }
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final registering = widget.consentNoticeText != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BlueAppBar(
        title: 'Face ID Check',
        onBack: _cancel,
        actions: [
          // Present only when the debug-build diagnostics switch is on.
          if (ref.watch(faceDiagnosticsEnabledProvider))
            IconButton(
              tooltip: 'Diagnostics',
              icon: const Icon(Icons.speed_outlined),
              onPressed: () {
                final s = ref.read(faceCaptureControllerProvider);
                showFaceDiagnosticsSheet(
                  context,
                  FaceDiagnosticsReport(
                    timingsMs: s.timingsMs,
                    descriptorLength: s.embedding?.length,
                    stage: 'live: ${s.phase.name}',
                    modelLoadMs: lastFaceModelLoadMs,
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: !_consentAcknowledged
              ? SingleChildScrollView(
                  child: FaceConsentPanel(
                    noticeText: widget.consentNoticeText!,
                    onAcknowledge: () => setState(() => _consentAcknowledged = true),
                    onCancel: _cancel,
                  ),
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.subtitle,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: AppColors.info),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No photo is stored — only a numeric face signature.',
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: FaceCaptureCameraView(
                        instructionText: widget.instructionText,
                        // Registration averages 4 frames, clock-in 3 — web
                        // REGISTRATION_/VERIFICATION_FRAMES_TO_CAPTURE.
                        framesToCapture: registering ? kRegistrationFramesToCapture : kVerificationFramesToCapture,
                        // Registration: blink AND turn; clock-in: turn only.
                        livenessMode: registering ? LivenessMode.blinkAndTurn : LivenessMode.turnOnly,
                        onReady: (captured) => Navigator.of(context).pop(
                          FaceCaptureSheetResult(captured: captured, consentAcknowledged: registering),
                        ),
                        onCancel: _cancel,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

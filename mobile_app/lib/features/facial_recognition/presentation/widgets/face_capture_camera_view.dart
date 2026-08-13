import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../capture/face_capture_controller.dart';
import '../capture/face_capture_state.dart';

/// Live camera preview + phase-driven status card for face capture — shared
/// by self-registration, HR-assisted registration, and clock-in
/// verification (mirrors web's FaceCaptureStage.tsx/FaceStatusPanel.tsx).
/// Starts the capture controller itself and calls [onReady] once a
/// liveness-checked embedding is available; the parent is responsible for
/// what happens with that embedding (submit registration, attach to a punch,
/// etc.) — this widget only ever hands over a finished result. Always used
/// inside a scrollable container (see face_capture_bottom_sheet.dart) so its
/// natural (non-flex) height never causes a layout overflow.
class FaceCaptureCameraView extends ConsumerStatefulWidget {
  final String instructionText;
  final void Function(FaceCaptureUiState state) onReady;
  final VoidCallback? onCancel;

  const FaceCaptureCameraView({
    super.key,
    required this.instructionText,
    required this.onReady,
    this.onCancel,
  });

  @override
  ConsumerState<FaceCaptureCameraView> createState() => _FaceCaptureCameraViewState();
}

class _FaceCaptureCameraViewState extends ConsumerState<FaceCaptureCameraView> {
  bool _delivered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(faceCaptureControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(faceCaptureControllerProvider, (previous, next) {
      if (next.phase == FaceCapturePhase.ready && !_delivered) {
        _delivered = true;
        widget.onReady(next);
      }
    });
    final state = ref.watch(faceCaptureControllerProvider);
    final controller = ref.read(faceCaptureControllerProvider.notifier);
    final camera = controller.cameraController;
    final isLive = state.phase == FaceCapturePhase.detecting || state.phase == FaceCapturePhase.livenessChecking;

    if (state.phase == FaceCapturePhase.unsupportedPlatform) {
      // No camera box at all here — there is nothing useful to show while a
      // platform we already know can't run face detection sits idle.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusCard(state: state, onRetry: controller.retry),
          if (widget.onCancel != null) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: widget.onCancel, child: const Text('Close')),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFF14181F),
                  child: camera != null && camera.value.isInitialized
                      ? CameraPreview(camera)
                      : Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ),
                ),
                if (isLive)
                  Center(
                    child: Container(
                      width: 170,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: state.phase == FaceCapturePhase.livenessChecking
                              ? AppColors.success
                              : Colors.white.withValues(alpha: 0.85),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                      ),
                    ),
                    child: Text(
                      _liveHint(state.phase, widget.instructionText),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StatusCard(state: state, onRetry: controller.retry),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 6),
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        ],
      ],
    );
  }

  String _liveHint(FaceCapturePhase phase, String instructionText) {
    return switch (phase) {
      FaceCapturePhase.detecting => instructionText,
      FaceCapturePhase.livenessChecking => 'Blink, or slowly turn your head',
      _ => '',
    };
  }
}

class _StatusCard extends StatelessWidget {
  final FaceCaptureUiState state;
  final VoidCallback onRetry;

  const _StatusCard({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, showRetry) = switch (state.phase) {
      FaceCapturePhase.idle || FaceCapturePhase.initializingCamera => (
          Icons.hourglass_top_outlined, 'Starting camera…', AppColors.textSecondary, false,
        ),
      FaceCapturePhase.unsupportedPlatform => (
          Icons.phonelink_lock_outlined,
          state.message ?? 'Face ID capture isn\'t available in a web browser.',
          AppColors.info,
          false,
        ),
      FaceCapturePhase.cameraDenied => (
          Icons.videocam_off_outlined,
          state.message ?? 'Camera permission is required to continue.',
          AppColors.error,
          true,
        ),
      FaceCapturePhase.detecting => (Icons.face_outlined, 'Looking for a face…', AppColors.primary, false),
      FaceCapturePhase.livenessChecking => (
          Icons.remove_red_eye_outlined, 'Confirming it\'s really you…', AppColors.primary, false,
        ),
      FaceCapturePhase.livenessFailed => (
          Icons.replay_outlined, state.message ?? 'Could not confirm liveness in time.', AppColors.error, true,
        ),
      FaceCapturePhase.extractingEmbedding => (Icons.hourglass_top_outlined, 'Processing…', AppColors.primary, false),
      FaceCapturePhase.ready => (Icons.check_circle_outline, 'Captured', AppColors.success, false),
      FaceCapturePhase.error => (
          Icons.error_outline, state.message ?? 'Something went wrong.', AppColors.error, true,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(color: color, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (showRetry) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
                child: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

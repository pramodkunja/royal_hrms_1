import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../capture/face_capture_controller.dart';
import '../capture/face_capture_geometry.dart';
import '../capture/face_capture_state.dart';
import '../capture/liveness_tracker.dart';

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

  /// Frames averaged into the descriptor (null: the controller's default,
  /// clock-in's 3). Registration passes 4, as web.
  final int? framesToCapture;

  /// Blink AND turn (registration) or turn only (clock-in), as web.
  final LivenessMode? livenessMode;
  final void Function(FaceCaptureUiState state) onReady;
  final VoidCallback? onCancel;

  const FaceCaptureCameraView({
    super.key,
    required this.instructionText,
    required this.onReady,
    this.onCancel,
    this.framesToCapture,
    this.livenessMode,
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
      ref
          .read(faceCaptureControllerProvider.notifier)
          .start(framesToCapture: widget.framesToCapture, livenessMode: widget.livenessMode);
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

    final live = state.phase == FaceCapturePhase.livenessChecking;
    final bottom = <Widget>[
      const SizedBox(height: 12),
      if (live) _LivenessProgress(state: state),
      if (live) const SizedBox(height: 10),
      _StatusCard(state: state, onRetry: controller.retry),
      if (widget.onCancel != null) ...[
        const SizedBox(height: 6),
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final boundedHeight = c.hasBoundedHeight;
        final stage = _Stage(
          state: state,
          camera: camera,
          instructionText: widget.instructionText,
          isLive: isLive,
          liveHint: _liveHint(state, widget.instructionText),
        );
        if (boundedHeight) {
          // Full-screen scan: the preview takes whatever the controls leave.
          // The controls scroll inside a capped band so large text / short
          // screens can never push the preview out or overflow the screen.
          return Column(
            children: [
              Expanded(child: stage),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight * 0.45),
                child: SingleChildScrollView(child: Column(children: bottom)),
              ),
            ],
          );
        }
        // Unbounded (scrollable host): size from width at the camera's
        // natural portrait aspect — never a hard-coded height.
        final aspect = state.previewAspect ?? (camera != null ? portraitPreviewAspect(camera.value.previewSize) : 3 / 4);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: aspect, child: stage),
            ...bottom,
          ],
        );
      },
    );
  }

  String _liveHint(FaceCaptureUiState state, String instructionText) {
    return switch (state.phase) {
      // liveHint (set by the pre-liveness distance/frontality/multi-face
      // checks — see face_capture_controller.dart's _handleFaces) takes
      // priority over the caller's static instruction whenever there's
      // something specific to correct; falls back to it otherwise.
      FaceCapturePhase.detecting => state.liveHint ?? instructionText,
      FaceCapturePhase.livenessChecking => state.liveHint ?? 'Please blink naturally AND turn your head slightly',
      _ => '',
    };
  }
}

/// The liveness stage the user is actually in, from the tracker's progress.
String _livenessStage(FaceCaptureUiState s) {
  if (s.blinkRequired && !s.blinkSeen && !s.turnSeen) return 'Blink naturally, then turn your head slightly';
  if (s.blinkRequired && !s.blinkSeen) return 'Blink naturally';
  if (!s.turnSeen) return 'Turn your head slightly';
  return 'Hold on…';
}

class _StatusCard extends StatelessWidget {
  final FaceCaptureUiState state;
  final VoidCallback onRetry;

  const _StatusCard({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, showRetry) = switch (state.phase) {
      FaceCapturePhase.idle || FaceCapturePhase.initializingCamera => (
          Icons.hourglass_top_outlined,
          'Opening camera…',
          AppColors.textSecondary,
          false,
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
      FaceCapturePhase.detecting => (
          Icons.face_outlined,
          // A face is tracked and nothing needs correcting → say so; otherwise
          // the hint under the preview says what to fix.
          state.faceBox != null && state.liveHint == null ? 'Face detected' : 'Position your face in the oval',
          AppColors.primary,
          false,
        ),
      FaceCapturePhase.livenessChecking => (
          Icons.remove_red_eye_outlined,
          _livenessStage(state),
          AppColors.primary,
          false,
        ),
      FaceCapturePhase.livenessFailed => (
          Icons.replay_outlined,
          state.message ?? 'Could not confirm liveness in time.',
          AppColors.error,
          true,
        ),
      FaceCapturePhase.extractingEmbedding => (
          Icons.hourglass_top_outlined,
          'Capturing and checking your face…',
          AppColors.primary,
          false,
        ),
      // Recoverable, expected — a lighting/eye-occlusion check on the
      // captured photo didn't pass, not something actually broken (see this
      // phase's own doc comment in face_capture_state.dart). Same "Try
      // again" shape as livenessFailed, just its own icon/message.
      FaceCapturePhase.qualityFailed => (
          Icons.wb_sunny_outlined,
          state.message ?? 'Capture quality check failed.',
          AppColors.warning,
          true,
        ),
      FaceCapturePhase.ready => (Icons.check_circle_outline, 'Face captured — verifying…', AppColors.success, false),
      FaceCapturePhase.error => (
          Icons.error_outline,
          state.message ?? 'Something went wrong.',
          AppColors.error,
          true,
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

/// The camera stage: the preview at its natural aspect (contain — never
/// stretched), the framing oval measured from the preview rectangle, and the
/// live instruction. The oval and the preview share one rectangle, so the guide
/// can never drift from what the camera sees.
class _Stage extends StatelessWidget {
  final FaceCaptureUiState state;
  final CameraController? camera;
  final String instructionText;
  final bool isLive;
  final String liveHint;

  const _Stage({
    required this.state,
    required this.camera,
    required this.instructionText,
    required this.isLive,
    required this.liveHint,
  });

  @override
  Widget build(BuildContext context) {
    final ready = camera != null && camera!.value.isInitialized;
    final aspect = state.previewAspect ?? (ready ? portraitPreviewAspect(camera!.value.previewSize) : 3 / 4);
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF14181F), borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = fitAspect(Size(c.maxWidth, c.maxHeight), aspect);
          if (!ready) {
            return Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withValues(alpha: 0.8)),
              ),
            );
          }
          final oval = guideOval(size);
          final inGuide = state.faceBox != null &&
              state.uprightFrame != null &&
              faceCentreInsideGuide(
                mapToPreview(state.faceBox!, state.uprightFrame!, size, mirrored: state.mirrored),
                oval,
              );
          final color = state.phase == FaceCapturePhase.livenessChecking || inGuide
              ? AppColors.success
              : Colors.white.withValues(alpha: 0.85);
          return Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Tight constraints of exactly the preview's own aspect, so
                  // CameraPreview's internal AspectRatio has nothing to stretch.
                  CameraPreview(camera!),
                  if (isLive)
                    CustomPaint(
                      key: const Key('face-guide-oval'),
                      painter: _OvalPainter(oval, color),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        liveHint,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OvalPainter extends CustomPainter {
  final Rect oval;
  final Color color;
  const _OvalPainter(this.oval, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.oval != oval || old.color != color;
}

/// Live liveness progress: which step is done and the time left.
class _LivenessProgress extends StatelessWidget {
  final FaceCaptureUiState state;
  const _LivenessProgress({required this.state});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool done) {
      final color = done ? AppColors.success : AppColors.textSecondary;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Wrap(
      key: const Key('liveness-progress'),
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        if (state.blinkRequired) chip('Blink', state.blinkSeen),
        chip('Turn head', state.turnSeen),
        if (state.livenessSecondsLeft != null)
          Text('${state.livenessSecondsLeft}s left',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../branches/presentation/widgets/branch_dlg_header.dart';
import '../capture/face_capture_state.dart';
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

/// Single entry point for every face-capture bottom sheet in the app (self
/// registration, HR-assisted registration, clock-in verification) — a
/// DraggableScrollableSheet with a scrollable body so the camera preview +
/// status card can never overflow the sheet's bounds, regardless of screen
/// size or keyboard insets (a plain fixed-size Column here is what caused
/// the original "RenderFlex overflowed" crash).
///
/// Pass [consentNoticeText] for registration flows (self-service or
/// HR-witnessed) — a consent screen is shown first and the camera never
/// opens until it's acknowledged. Omit it for clock-in verification, which
/// never collects new biometric data and so never needs fresh consent.
Future<FaceCaptureSheetResult?> showFaceCaptureSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  String instructionText = 'Look directly at the camera',
  String? consentNoticeText,
}) {
  return showModalBottomSheet<FaceCaptureSheetResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: AppColors.background,
          child: Column(
            children: [
              BranchDlgHeader(
                icon: Icons.face_outlined,
                title: title,
                subtitle: subtitle,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
              Expanded(
                child: _SheetBody(
                  scrollController: scrollController,
                  instructionText: instructionText,
                  consentNoticeText: consentNoticeText,
                  onDone: (result) => Navigator.of(sheetContext).pop(result),
                  onCancel: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SheetBody extends StatefulWidget {
  final ScrollController scrollController;
  final String instructionText;
  final String? consentNoticeText;
  final void Function(FaceCaptureSheetResult) onDone;
  final VoidCallback onCancel;

  const _SheetBody({
    required this.scrollController,
    required this.instructionText,
    required this.consentNoticeText,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  late bool _consentAcknowledged = widget.consentNoticeText == null;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (!_consentAcknowledged)
          FaceConsentPanel(
            noticeText: widget.consentNoticeText!,
            onAcknowledge: () => setState(() => _consentAcknowledged = true),
            onCancel: widget.onCancel,
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No photo is stored — only a numeric face signature.',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FaceCaptureCameraView(
            instructionText: widget.instructionText,
            onReady: (captured) => widget.onDone(FaceCaptureSheetResult(
              captured: captured,
              consentAcknowledged: widget.consentNoticeText != null,
            )),
            onCancel: widget.onCancel,
          ),
        ],
      ],
    );
  }
}

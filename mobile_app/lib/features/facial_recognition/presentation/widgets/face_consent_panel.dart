import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shown before the camera opens in any face-*registration* flow (self
/// registration and HR-witnessed registration — never for clock-in
/// verification, which doesn't collect new biometric data) — mirrors web's
/// FaceConsentPanel.tsx. Consent must be obtained before capture starts, not
/// just before submission; there is no "just close this and continue"
/// shortcut, only an explicit checkbox tick.
class FaceConsentPanel extends StatefulWidget {
  final String noticeText;
  final VoidCallback onAcknowledge;
  final VoidCallback onCancel;

  const FaceConsentPanel({
    super.key,
    required this.noticeText,
    required this.onAcknowledge,
    required this.onCancel,
  });

  @override
  State<FaceConsentPanel> createState() => _FaceConsentPanelState();
}

class _FaceConsentPanelState extends State<FaceConsentPanel> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biometric data consent', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text(widget.noticeText, style: AppTextStyles.body.copyWith(height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _checked = !_checked),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _checked,
                  onChanged: (v) => setState(() => _checked = v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('I have read and agree to the above.', style: AppTextStyles.body),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _checked ? widget.onAcknowledge : null,
              child: const Text('I Agree & Continue'),
            ),
          ],
        ),
      ],
    );
  }
}

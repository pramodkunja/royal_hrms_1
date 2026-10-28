import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../controllers/voice_command_controller.dart';
import '../providers/voice_mute_provider.dart';
import '../state/voice_conversation_state.dart';
import 'payslip_summary_card.dart';
import 'quick_action_chips.dart';

/// Sampled straight from assets/images/Bot.png so this panel's chrome
/// (borders, icons, spinner, buttons) reads as the same character talking,
/// rather than the app's unrelated navy theme color. Success/error stay on
/// AppColors.success/error below — those are meaningful status colors, not
/// branding, so they're left alone.
class _BotColors {
  static const Color blue = Color(0xFF1CA0C8);
  static const Color blueDark = Color(0xFF0F5D78);
  static const Color blueTint = Color(0xFFEAF7FB);
}

/// Mirrors frontend/components/VoiceConversationPanel.tsx's phase-driven
/// layout: listening -> transcript (in flight) -> result. A conversational
/// result that's still `awaitingInput` offers a mic button and a typed
/// fallback, same as web's inline text input.
class VoiceConversationPanel extends ConsumerStatefulWidget {
  final VoiceConversationState conversation;
  const VoiceConversationPanel({super.key, required this.conversation});

  @override
  ConsumerState<VoiceConversationPanel> createState() => _VoiceConversationPanelState();
}

class _VoiceConversationPanelState extends ConsumerState<VoiceConversationPanel> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitTyped(VoiceCommandController controller) {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    controller.submitTypedAnswer(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final muted = ref.watch(voiceMutedProvider);
    final controller = ref.read(voiceCommandControllerProvider.notifier);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 290,
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_BotColors.blueTint, AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _BotColors.blue.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(color: _BotColors.blue.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VOICE ASSISTANT',
                  style: AppTextStyles.labelSmall.copyWith(color: _BotColors.blueDark, letterSpacing: 0.6),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(muted ? Icons.volume_off : Icons.volume_up,
                          size: 18, color: _BotColors.blueDark.withValues(alpha: 0.7)),
                      onPressed: () => ref.read(voiceMutedProvider.notifier).toggle(),
                      tooltip: muted ? 'Unmute spoken responses' : 'Mute spoken responses',
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: _BotColors.blueDark.withValues(alpha: 0.7)),
                      onPressed: controller.close,
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBody(c, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(VoiceConversationState c, VoiceCommandController controller) {
    switch (c.phase) {
      case VoicePanelPhase.listening:
        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: _BotColors.blue, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.interimTranscript.isEmpty ? 'Listening…' : c.interimTranscript,
                style: AppTextStyles.body,
              ),
            ),
          ],
        );

      case VoicePanelPhase.typing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // A fresh command's shortcuts (VC-2) — not shown once mid-
            // conversation (see the `result` phase's own typed-answer field
            // below, which has no chips), same as web only rendering these
            // in its "greeting"/fresh-command phase.
            QuickActionChips(onPick: controller.submitTypedAnswer),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Type a command…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _submitTyped(controller),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, size: 18),
                  onPressed: () => _submitTyped(controller),
                  color: _BotColors.blue,
                ),
              ],
            ),
          ],
        );

      case VoicePanelPhase.transcript:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${c.transcript}"',
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _BotColors.blue),
                ),
                const SizedBox(width: 8),
                Text('Processing…', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
              ],
            ),
          ],
        );

      // An automatic, backend-driven second capture — the mic reopened on
      // its own after that first attempt came back unrecognized, so this
      // explicitly tells the user why (distinct from the tap-to-start
      // "listening" state above) and invites them to just try again, in
      // either language, rather than assuming it was a Hindi-specific miss.
      case VoicePanelPhase.retrying:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: const BoxDecoration(color: _BotColors.blue, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Didn't quite catch that", style: AppTextStyles.body),
                  const SizedBox(height: 2),
                  Text(
                    'Listening again — English or Hindi…',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        );

      // Backend asked for (or is re-asking for, after a mismatch) a facial-
      // proof capture — VoiceMicOverlay reacts to this exact phase and opens
      // the existing facial_recognition capture sheet on top of this panel,
      // then feeds the result back via controller.submitFaceProofCapture.
      // This state just keeps showing the last spoken message (already set
      // when this phase was entered — see VoiceConversationState.message)
      // with a small "opening camera" indicator underneath it, rather than
      // the normal "Answer by voice / type an answer" controls, which make
      // no sense for a camera step.
      case VoicePanelPhase.faceProof:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.message, style: AppTextStyles.body),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _BotColors.blue),
                ),
                const SizedBox(width: 8),
                Text('Opening camera…', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
              ],
            ),
          ],
        );

      case VoicePanelPhase.result:
        final payslipCard = PayslipCardData.tryExtract(c.result);
        if (c.conversational) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.language == 'hi') const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: _HindiBadge(),
              ),
              Text(c.message, style: AppTextStyles.body),
              if (payslipCard != null) PayslipSummaryCard(data: payslipCard),
              if (c.awaitingInput) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: controller.startListening,
                    icon: const Icon(Icons.mic, size: 18),
                    label: const Text('Answer by voice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _BotColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: AppTextStyles.bodySmall,
                        decoration: InputDecoration(
                          hintText: 'Or type your answer…',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onSubmitted: (_) => _submitTyped(controller),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: () => _submitTyped(controller),
                      color: _BotColors.blue,
                    ),
                  ],
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.language == 'hi') const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: _HindiBadge(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  c.resultStatus == VoiceResultStatus.error ? Icons.error_outline : Icons.check_circle_outline,
                  color: c.resultStatus == VoiceResultStatus.error ? AppColors.error : AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(c.message, style: AppTextStyles.body)),
              ],
            ),
            if (payslipCard != null) PayslipSummaryCard(data: payslipCard),
          ],
        );
    }
  }
}

/// Small "this reply was in Hindi" indicator — shown only for a Hindi
/// response (see VoiceConversationState.language, backend-reported, never
/// inferred client-side). Omitted for English since that's the
/// overwhelmingly common case; a badge on every single result would just be
/// visual noise for the normal path.
class _HindiBadge extends StatelessWidget {
  const _HindiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _BotColors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate, size: 11, color: _BotColors.blueDark),
          const SizedBox(width: 4),
          Text(
            'हिंदी',
            style: AppTextStyles.labelSmall.copyWith(
              color: _BotColors.blueDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

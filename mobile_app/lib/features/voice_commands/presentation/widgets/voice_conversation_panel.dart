import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../controllers/voice_command_controller.dart';
import '../providers/voice_mute_provider.dart';
import '../state/voice_conversation_state.dart';

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.elevatedShadow,
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
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint, letterSpacing: 0.6),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(muted ? Icons.volume_off : Icons.volume_up, size: 18, color: AppColors.textHint),
                      onPressed: () => ref.read(voiceMutedProvider.notifier).toggle(),
                      tooltip: muted ? 'Unmute spoken responses' : 'Mute spoken responses',
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: AppColors.textHint),
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
            const Icon(Icons.mic, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.interimTranscript.isEmpty ? 'Listening…' : c.interimTranscript,
                style: AppTextStyles.body,
              ),
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
                const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Processing…', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
              ],
            ),
          ],
        );

      case VoicePanelPhase.result:
        if (c.conversational) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.message, style: AppTextStyles.body),
              if (c.awaitingInput) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: controller.startListening,
                    icon: const Icon(Icons.mic, size: 18),
                    label: const Text('Answer by voice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ],
          );
        }
        return Row(
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
        );
    }
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Purely presentational animated "assistant character" that replaces the
/// old static mic icon. Owns no voice/business logic whatsoever — it just
/// renders idle/listening/thinking/speaking visuals and forwards taps to
/// [onTap], which the caller wires to its existing voice-command callback
/// unchanged (see VoiceMicOverlay, which passes
/// `controller.startListening`).
///
/// State is entirely driven by the three booleans below, set by whoever
/// already tracks the real voice-assistant state — this widget never reads
/// any provider itself.
class AnimatedVoiceAssistant extends StatefulWidget {
  final VoidCallback onTap;
  final bool isListening;
  final bool isSpeaking;
  final bool isThinking;
  /// The existing AI response text, shown in a floating speech bubble while
  /// [isSpeaking] is true. Purely for display — the text itself still comes
  /// entirely from the existing voice pipeline.
  final String? message;
  final double size;

  const AnimatedVoiceAssistant({
    super.key,
    required this.onTap,
    this.isListening = false,
    this.isSpeaking = false,
    this.isThinking = false,
    this.message,
    this.size = 96,
  });

  @override
  State<AnimatedVoiceAssistant> createState() => _AnimatedVoiceAssistantState();
}

class _AnimatedVoiceAssistantState extends State<AnimatedVoiceAssistant>
    with TickerProviderStateMixin {
  // Slow vertical bob — purely idle "alive" motion, on forever regardless of
  // state so the character never looks frozen.
  late final AnimationController _floatCtrl;
  // Gentle scale breathing, layered on top of the float.
  late final AnimationController _breatheCtrl;
  // One-shot bounce played on tap; independent of the loops above.
  late final AnimationController _tapCtrl;
  // Fast pulse used while speaking (mouth/body) and for the thinking dots.
  late final AnimationController _activeCtrl;

  late final Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _activeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _tapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_tapCtrl);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _breatheCtrl.dispose();
    _activeCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details) {
    _tapCtrl.forward(from: 0);
    widget.onTap();
  }

  Color get _accentColor {
    if (widget.isListening) return AppColors.info;
    if (widget.isThinking) return AppColors.secondary;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final coreSize = widget.size * 0.85;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tapCtrl.stop(),
      onTapUp: _handleTapUp,
      child: SizedBox(
        // Kept at exactly `size x size` — the same footprint the old mic
        // button had — so the caller's positioning/clamping/drag math (which
        // treats this widget as a fixed-size box) still lines up. Everything
        // that needs more room (rings, speech bubble, thinking dots) is a
        // Positioned child with a negative/overflowing offset, painted via
        // Clip.none rather than by growing this box.
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.isSpeaking && (widget.message ?? '').isNotEmpty)
              Positioned(
                bottom: widget.size + 14,
                left: widget.size / 2 - 100,
                width: 200,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _SpeechBubble(message: widget.message!),
                ),
              ),
            if (widget.isThinking)
              Positioned(
                bottom: widget.size + 10,
                left: widget.size / 2 - 40,
                width: 80,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _activeCtrl,
                    builder: (context, _) => _ThinkingDots(progress: _activeCtrl.value),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: Listenable.merge([_floatCtrl, _breatheCtrl, _activeCtrl, _tapCtrl]),
              builder: (context, _) {
                final floatT = Curves.easeInOut.transform(_floatCtrl.value);
                final dy = -4.0 * floatT; // 4px idle bob, within the 3-5px spec range.
                final breathe = 1.0 + 0.04 * Curves.easeInOut.transform(_breatheCtrl.value);
                final tapScale = _tapCtrl.isAnimating ? _tapScale.value : 1.0;
                final activePulse = widget.isListening || widget.isSpeaking
                    ? 1.0 + 0.05 * _activeCtrl.value
                    : 1.0;

                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: breathe * tapScale * activePulse,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (widget.isListening)
                            _SoundWaveRing(progress: _activeCtrl.value, size: widget.size),
                          // Soft aura behind the character — a shadow with no
                          // fill, so it reads as a glow rather than a colored
                          // disc showing through the GIF's own transparency.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _accentColor.withValues(alpha: widget.isListening ? 0.55 : 0.35),
                                  blurRadius: widget.isListening ? 20 : 14,
                                  spreadRadius: widget.isListening ? 2 : 0,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: coreSize,
                              height: coreSize,
                              // The provided idle character asset — this
                              // widget adds the container-level
                              // float/breathe/glow/bounce on top of it, no
                              // hand-drawn face on top.
                              child: Image.asset(
                                'assets/images/Bot.png',
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Small bars around the assistant that bounce while actively listening —
/// a lightweight stand-in for a real waveform, purely decorative.
class _SoundWaveRing extends StatelessWidget {
  final double progress;
  final double size;
  const _SoundWaveRing({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    final scale = size / 56;
    final boxSize = 74 * scale;
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(8, (i) {
          final angle = (i / 8) * 2 * math.pi;
          final phase = (progress + i / 8) % 1.0;
          final barLength = (4 + 5 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi))) * scale;
          return Transform.rotate(
            angle: angle,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 2.5 * scale,
                height: barLength,
                margin: EdgeInsets.only(top: 2 * scale),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  final double progress;
  const _ThinkingDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    final visibleDots = 1 + (progress * 3).floor().clamp(0, 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
      ),
      child: Text(
        'Thinking${'.' * visibleDots}',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String message;
  const _SpeechBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(fontSize: 12.5, height: 1.3),
        ),
      ),
    );
  }
}

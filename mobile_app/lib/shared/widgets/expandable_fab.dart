import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Whether ANY screen's [ExpandableFab] is currently expanded — the mini
/// action stack grows upward from the bottom-right corner past a single
/// collapsed FAB's height, into the same space the global voice-mic overlay
/// occupies (see voice_mic_overlay.dart). That overlay is mounted above
/// every route and has no way to know a given screen even has an
/// [ExpandableFab], let alone whether it's expanded — so it watches this
/// provider instead and steps aside while it's true.
final expandableFabOpenProvider = StateProvider<bool>((ref) => false);

/// One action revealed when an [ExpandableFab] is expanded.
class ExpandableFabAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ExpandableFabAction({required this.icon, required this.label, required this.onTap});
}

/// A single icon FAB that expands in place into a stack of labeled mini
/// actions above it (tap the main FAB to toggle, tap a mini action to run it
/// and auto-close). Pair with [ExpandableFabBarrier] in the screen's body
/// Stack for tap-outside-to-dismiss.
class ExpandableFab extends ConsumerStatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final List<ExpandableFabAction> actions;
  final Object heroTag;

  const ExpandableFab({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.actions,
    this.heroTag = 'expandable_fab',
  });

  @override
  ConsumerState<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends ConsumerState<ExpandableFab> {
  void _publish(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(expandableFabOpenProvider.notifier);
      if (notifier.state != value) notifier.state = value;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.expanded) _publish(true);
  }

  @override
  void didUpdateWidget(covariant ExpandableFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _publish(widget.expanded);
  }

  @override
  void dispose() {
    // Safety net: if this screen is popped/replaced while still expanded
    // (e.g. system back button, not one of its own actions), don't leave
    // the mic permanently hidden on every other screen.
    if (widget.expanded) {
      final notifier = ref.read(expandableFabOpenProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.state = false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final action in widget.actions) ...[
          _MiniFabAction(
            icon: action.icon,
            label: action.label,
            visible: widget.expanded,
            onTap: action.onTap,
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          heroTag: widget.heroTag,
          onPressed: widget.onToggle,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: AnimatedRotation(
            turns: widget.expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, size: 26),
          ),
        ),
      ],
    );
  }
}

/// Full-screen transparent tap-to-dismiss layer — place as the last child of
/// a body [Stack], gated on the same `expanded` flag passed to [ExpandableFab].
class ExpandableFabBarrier extends StatelessWidget {
  final bool visible;
  final VoidCallback onDismiss;
  const ExpandableFabBarrier({super.key, required this.visible, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onDismiss,
      ),
    );
  }
}

class _MiniFabAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool visible;
  final VoidCallback onTap;

  const _MiniFabAction({
    required this.icon,
    required this.label,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(0, 0.3),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(label,
                        style: AppTextStyles.label
                            .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

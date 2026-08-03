import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/expandable_fab.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../controllers/voice_command_controller.dart';
import 'voice_conversation_panel.dart';

/// Global, persistent voice-command entry point. Mounted once above the
/// entire app (see lib/app/app.dart's MaterialApp.router `builder`) so it's
/// available on every authenticated screen — not scoped to the dashboard
/// shell — mirroring how the web app's floating voice button persists
/// across its whole authenticated layout.
///
/// The idle bubble always starts on the right side of the screen — bottom
/// corner on screens with no FAB of their own, or bumped up to sit above one
/// on screens that do (see AppRoutes.screensWithFab) so it never starts out
/// overlapping a screen's own "Add" button — and is user-draggable to any
/// point on screen from there (see `_DraggableMicBubble`). Because this whole
/// widget lives above the Navigator and is never rebuilt on route change, a
/// dragged position sticks across every screen in the app until dragged
/// again — not just the current one.
///
/// Hides itself for any caller the backend wouldn't accept a voice command
/// from anyway: logged out, still mid-onboarding, or awaiting HR approval
/// (same three states go_router's own redirect in core/router/app_router.dart
/// gates on).
class VoiceMicOverlay extends ConsumerStatefulWidget {
  const VoiceMicOverlay({super.key});

  @override
  ConsumerState<VoiceMicOverlay> createState() => _VoiceMicOverlayState();
}

class _VoiceMicOverlayState extends ConsumerState<VoiceMicOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  static const double _bubbleSize = 56;

  @override
  void initState() {
    super.initState();
    // A slow, continuous loop — just enough motion to catch the eye without
    // being distracting on screens the user is trying to read.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider).valueOrNull;
    final user = authState?.user;
    final isEligible = (authState?.isAuthenticated ?? false) &&
        user != null &&
        !user.needsOnboarding &&
        !user.awaitingApproval;

    if (!isEligible) return const SizedBox.shrink();

    final conversation = ref.watch(voiceCommandControllerProvider);
    final controller = ref.read(voiceCommandControllerProvider.notifier);

    // Screens with an expandable multi-action FAB (Employees, Interview
    // List, Attendance's speed dial) grow their mini actions upward past a
    // single collapsed FAB's height when expanded — this overlay watches
    // expandableFabOpenProvider and steps out of the way entirely while
    // idle (an in-progress conversation stays put) whenever that happens,
    // then reappears the instant it collapses.
    final anyFabExpanded = ref.watch(expandableFabOpenProvider);
    if (conversation == null && anyFabExpanded) return const SizedBox.shrink();

    // Reactively read the current route so the bubble's DEFAULT position
    // (before any drag) can sit above a screen's own FAB instead of starting
    // out overlapping it. router.routerDelegate is a ChangeNotifier that
    // fires on every navigation (see go_router's GoRouterDelegate), so this
    // rebuilds on every route change without any per-screen opt-in.
    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        final hasFab = AppRoutes.screensWithFab.contains(path);

        // This Stack sits above MaterialApp.router's Navigator (see
        // app.dart), outside any Scaffold — so unlike a screen's own FAB
        // (which Scaffold auto-shifts above the bottom safe-area inset),
        // positions here are measured from the literal screen edge and must
        // add the inset explicitly.
        final screenSize = MediaQuery.sizeOf(context);
        final safeArea = MediaQuery.paddingOf(context);
        final bottomOffset = (hasFab ? 100.0 : 16.0) + safeArea.bottom;
        final defaultPosition = Offset(
          screenSize.width - _bubbleSize - 16,
          screenSize.height - bottomOffset - _bubbleSize,
        );

        if (conversation != null) {
          // The expanded conversation panel has a dynamic size (unlike the
          // fixed 56x56 bubble), so it isn't part of the free-drag system —
          // it just anchors bottom-right, the same safe way as the bubble's
          // own default (above the FAB when there is one).
          return Positioned(
            right: 16,
            bottom: bottomOffset,
            child: VoiceConversationPanel(conversation: conversation),
          );
        }

        return _DraggableMicBubble(
          key: const ValueKey('voice-mic-bubble'),
          defaultPosition: defaultPosition,
          screenSize: screenSize,
          safeArea: safeArea,
          pulse: _pulseController,
          onTap: controller.startListening,
          onTypeTap: controller.openTypedCommand,
        );
      },
    );
  }
}

/// Owns the drag gesture and the dragged-position state itself, entirely
/// separate from VoiceMicOverlay's State. Confining every per-frame
/// setState from onPanUpdate to this small widget means a drag only ever
/// rebuilds this cheap subtree (a clamp + a Positioned) — not
/// VoiceMicOverlay's provider watches above it — which is what keeps the
/// drag smooth rather than janky.
class _DraggableMicBubble extends StatefulWidget {
  final Offset defaultPosition;
  final Size screenSize;
  final EdgeInsets safeArea;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final VoidCallback onTypeTap;

  const _DraggableMicBubble({
    super.key,
    required this.defaultPosition,
    required this.screenSize,
    required this.safeArea,
    required this.pulse,
    required this.onTap,
    required this.onTypeTap,
  });

  @override
  State<_DraggableMicBubble> createState() => _DraggableMicBubbleState();
}

class _DraggableMicBubbleState extends State<_DraggableMicBubble> {
  static const double _bubbleSize = 56;
  static const double _edgeMargin = 8;

  // Null until the user drags the bubble at least once. Once set, this is
  // the exact top-left the bubble is pinned to (in the overlay's own
  // coordinate space, i.e. full-screen), overriding the default position —
  // "anywhere on screen" means the user's placement always wins once
  // they've expressed one.
  Offset? _draggedPosition;
  bool _dragging = false;

  // Keeps the bubble fully on-screen (clear of the status bar / home
  // indicator too) regardless of how it got here — a manual drag, or a
  // device rotation changing the available size out from under a
  // previously-valid position.
  Offset _clampToScreen(Offset pos) {
    const minX = _edgeMargin;
    final maxX = (widget.screenSize.width - _bubbleSize - _edgeMargin)
        .clamp(minX, double.infinity);
    final minY = widget.safeArea.top + _edgeMargin;
    final maxY = (widget.screenSize.height -
            widget.safeArea.bottom -
            _bubbleSize -
            _edgeMargin)
        .clamp(minY, double.infinity);
    return Offset(pos.dx.clamp(minX, maxX), pos.dy.clamp(minY, maxY));
  }

  @override
  Widget build(BuildContext context) {
    final target = _clampToScreen(_draggedPosition ?? widget.defaultPosition);

    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onPanStart: (_) => setState(() => _dragging = true),
      onPanUpdate: (details) => setState(() {
        final current = _draggedPosition ?? widget.defaultPosition;
        _draggedPosition = _clampToScreen(current + details.delta);
      }),
      onPanEnd: (_) => setState(() => _dragging = false),
      child: AnimatedScale(
        scale: _dragging ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Tooltip(
              message: 'Voice command — drag to move',
              child: _PulsingMicButton(pulse: widget.pulse),
            ),
            // Typed-command entry point — an alternative to speaking, same
            // idea as the web app's keyboard-icon toggle (left as this app's
            // own UI/UX call, not a copy of web's exact chat-input pattern).
            // A separate nested GestureDetector over its own small hit area
            // — Flutter's hit-testing gives the front-most/innermost
            // recognizer the tap, so this doesn't also trigger the parent
            // bubble's onTap/drag for the same touch, same as an IconButton
            // nested inside a larger tappable row elsewhere in Flutter apps.
            Positioned(
              left: -4,
              top: -4,
              child: Tooltip(
                message: 'Type a command instead',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTypeTap,
                  child: Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Icon(Icons.keyboard_alt_outlined, size: 13, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Zero-lag tracking while actively dragging (a plain Positioned, no
    // animation, follows the finger exactly); a smooth eased transition for
    // every other move — the settle after a drag ends, or a clamp kicking in
    // after a rotation.
    return _dragging
        ? Positioned(left: target.dx, top: target.dy, child: bubble)
        : AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: target.dx,
            top: target.dy,
            child: bubble,
          );
  }
}

/// The idle mic FAB with a soft, looping pulse ring behind it — a subtle
/// "tap me" cue rather than a static icon easy to overlook among everything
/// else on screen. Purely visual — all tap/drag handling lives in the
/// GestureDetector that wraps this in _DraggableMicBubble, so this stays a
/// simple StatelessWidget.
class _PulsingMicButton extends StatelessWidget {
  final Animation<double> pulse;
  const _PulsingMicButton({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              // One ring, continuously growing and fading — restarts the
              // instant it fully fades (AnimationController.repeat()).
              final t = pulse.value;
              return Opacity(
                opacity: (1 - t) * 0.45,
                child: Transform.scale(
                  scale: 1.0 + t * 0.9,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            ),
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 4,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.mic, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

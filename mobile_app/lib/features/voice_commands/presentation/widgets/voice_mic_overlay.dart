import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/expandable_fab.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../controllers/voice_command_controller.dart';
import '../state/voice_conversation_state.dart';
import 'animated_voice_assistant.dart';
import 'voice_conversation_panel.dart';

/// Vertical clearance reserved above a screen's own FAB, shared by
/// VoiceMicOverlay's default-position calc and _DraggableMicBubble's clamp.
/// The character asset's arm/wave graphic overflows slightly past its
/// nominal bounding box (see AnimatedVoiceAssistant's `Clip.none` comment),
/// so this is bigger than a bare FAB-height-plus-margin figure would need —
/// tuned against a real FloatingActionButton.extended on-device rather than
/// derived analytically.
const double _fabExclusion = 130;

/// Global, persistent voice-command entry point. Mounted once above the
/// entire app (see lib/app/app.dart's MaterialApp.router `builder`) so it's
/// available on every authenticated screen — not scoped to the dashboard
/// shell — mirroring how the web app's floating voice button persists
/// across its whole authenticated layout.
///
/// The idle bubble always stays on the right edge of the screen — resting
/// above a screen's own FAB (see AppRoutes.screensWithFab) so it never starts
/// out overlapping it, and only ever draggable vertically along that edge
/// (see `_DraggableMicBubble`). A dragged vertical position persists across
/// every screen in the app until dragged again, but is re-clamped above the
/// FAB zone fresh on every navigation — via `currentVisiblePathProvider` (see
/// app_router.dart) — so a position that was fine on one screen can never
/// stay stuck overlapping a different screen's FAB.
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

class _VoiceMicOverlayState extends ConsumerState<VoiceMicOverlay> {
  // Kept in lockstep with AnimatedVoiceAssistant's own default `size` —
  // this value drives the default-position/clamp math below, so if the
  // character's rendered size changes, this must move with it or drags and
  // the default resting spot will disagree with what's actually on screen.
  static const double _bubbleSize = 96;

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

    // The controller has no BuildContext of its own to open a modal bottom
    // sheet with — this is the one place in the voice-command flow that
    // needs one, so the orchestration (open the sheet, feed its result back)
    // lives here instead. Fires exactly once per transition INTO faceProof
    // (first ask or any retry — see VoiceCommandController's own comment on
    // why there's no client-side attempt counter), never on a rebuild that
    // merely happens to also have phase == faceProof.
    ref.listen<VoiceConversationState?>(voiceCommandControllerProvider, (previous, next) {
      final enteredFaceProof = next?.phase == VoicePanelPhase.faceProof &&
          previous?.phase != VoicePanelPhase.faceProof;
      if (enteredFaceProof) _openFaceProofCapture(controller);
    });

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
    // out overlapping it. currentVisiblePathProvider is updated by
    // _PathTrackingObserver on every push/pop/replace — including routes
    // reached via context.push(), which go_router's own
    // `currentConfiguration.uri` deliberately does not track (see that
    // provider's doc comment in app_router.dart) — so this stays correct
    // for every screen in the app, not just ones reached via context.go().
    final path = ref.watch(currentVisiblePathProvider);
    final hasFab = AppRoutes.screensWithFab.contains(path);

    // This Stack sits above MaterialApp.router's Navigator (see
    // app.dart), outside any Scaffold — so unlike a screen's own FAB
    // (which Scaffold auto-shifts above the bottom safe-area inset),
    // positions here are measured from the literal screen edge and must
    // add the inset explicitly.
    final screenSize = MediaQuery.sizeOf(context);
    final safeArea = MediaQuery.paddingOf(context);
    final bottomOffset = (hasFab ? _fabExclusion : 16.0) + safeArea.bottom;
    final defaultPosition = Offset(
      screenSize.width - _bubbleSize - 16,
      screenSize.height - bottomOffset - _bubbleSize,
    );
    if (conversation != null) {
      // The expanded conversation panel has a dynamic size (unlike the
      // fixed-size bubble), so it isn't part of the free-drag system —
      // it just anchors bottom-right, the same safe way as the bubble's
      // own default (above the FAB when there is one). The character
      // stays visible right below it — no longer swapped out — now
      // reacting to the real listening/thinking/speaking phase instead
      // of always sitting idle; it isn't draggable here (dragging only
      // matters for the idle bubble) and its tap is a no-op since the
      // panel's own mic/close controls already own every action while a
      // conversation is open.
      final isListening = conversation.phase == VoicePanelPhase.listening;
      final isThinking = conversation.phase == VoicePanelPhase.transcript;
      final isSpeaking = conversation.phase == VoicePanelPhase.result;
      return Positioned(
        right: 16,
        bottom: bottomOffset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            VoiceConversationPanel(conversation: conversation),
            const SizedBox(height: 10),
            AnimatedVoiceAssistant(
              onTap: () {},
              isListening: isListening,
              isThinking: isThinking,
              isSpeaking: isSpeaking,
              size: _bubbleSize,
            ),
          ],
        ),
      );
    }

    return _DraggableMicBubble(
      key: const ValueKey('voice-mic-bubble'),
      defaultPosition: defaultPosition,
      screenSize: screenSize,
      safeArea: safeArea,
      hasFab: hasFab,
      onTap: controller.startListening,
      onTypeTap: controller.openTypedCommand,
    );
  }

  /// Opens the same facial_recognition capture sheet manual clock-in already
  /// uses (see attendance_ring_card.dart's own showFaceCaptureSheet call) —
  /// no consentNoticeText, since verification never collects new biometric
  /// data and so never needs fresh consent (only self/HR registration does;
  /// see that sheet's own doc comment). Feeds whatever comes back (a capture
  /// result, or null if the user cancelled) straight back to the controller,
  /// which resubmits it to /voice/parse/ and decides what happens next —
  /// this widget makes no pass/fail judgment of its own.
  Future<void> _openFaceProofCapture(VoiceCommandController controller) async {
    final result = await showFaceCaptureSheet(
      context,
      title: 'Face ID Verification',
      subtitle: 'Confirm it\'s you to clock in.',
    );
    if (!mounted) return;
    await controller.submitFaceProofCapture(result);
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
  // Whether the CURRENT route has its own FAB — read fresh on every build
  // (via VoiceMicOverlay's route listener) so the exclusion zone below
  // always matches whatever screen is on screen right now, not whatever
  // screen was active the last time the bubble was dragged.
  final bool hasFab;
  final VoidCallback onTap;
  final VoidCallback onTypeTap;

  const _DraggableMicBubble({
    super.key,
    required this.defaultPosition,
    required this.screenSize,
    required this.safeArea,
    required this.hasFab,
    required this.onTap,
    required this.onTypeTap,
  });

  @override
  State<_DraggableMicBubble> createState() => _DraggableMicBubbleState();
}

class _DraggableMicBubbleState extends State<_DraggableMicBubble> {
  // Kept in lockstep with AnimatedVoiceAssistant's own default `size` (see
  // the matching constant/comment in _VoiceMicOverlayState above).
  static const double _bubbleSize = 96;
  static const double _edgeMargin = 8;
  // How much of the bubble hangs off the screen edge while "peeking" (idle,
  // undragged) — enough to read as a character poking in rather than a
  // button, without covering more of the screen than a normal FAB would.
  static const double _peekFraction = 0.4;

  // Null until the user drags the bubble at least once. Once set, this is
  // the exact top-left the bubble is pinned to (in the overlay's own
  // coordinate space, i.e. full-screen) — but only its Y is actually
  // honored; X always snaps back to the right edge (see onPanEnd) so the
  // bubble stays where the user asked for it — "on the right side" — and
  // never drifts onto the left half of the screen where it could sit over
  // unrelated left-aligned controls.
  Offset? _draggedPosition;
  bool _dragging = false;
  // True once idle long enough to recede toward the edge; false right after
  // any drag, so the character reads as fully present again immediately
  // after being touched.
  bool _peeking = true;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _armIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _peeking = true);
    });
  }

  // Keeps the bubble fully on-screen (clear of the status bar / home
  // indicator, AND clear of the current screen's own FAB) regardless of how
  // it got here — a manual drag, a device rotation, or simply navigating to
  // a different screen. widget.hasFab is read fresh on every rebuild (it
  // comes from the current route), so a position that was fine on a
  // no-FAB screen gets pushed back above the FAB the moment the user lands
  // on a screen that has one — a stale drag can never leave it stuck
  // overlapping a button.
  Offset _clampToScreen(Offset pos) {
    const minX = _edgeMargin;
    final maxX = (widget.screenSize.width - _bubbleSize - _edgeMargin)
        .clamp(minX, double.infinity);
    final minY = widget.safeArea.top + _edgeMargin;
    final fabExclusion = widget.hasFab ? _fabExclusion : _edgeMargin;
    final maxY = (widget.screenSize.height -
            widget.safeArea.bottom -
            _bubbleSize -
            fabExclusion)
        .clamp(minY, double.infinity);
    return Offset(pos.dx.clamp(minX, maxX), pos.dy.clamp(minY, maxY));
  }

  @override
  Widget build(BuildContext context) {
    final target = _clampToScreen(_draggedPosition ?? widget.defaultPosition);
    // Always peeks toward the right — the bubble only ever docks on the
    // right edge (see onPanEnd), so "peeking" always means hanging off that
    // same edge.
    final peekOffset = _peeking && !_dragging ? _bubbleSize * _peekFraction : 0.0;

    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _armIdleTimer();
        setState(() {
          _dragging = true;
          _peeking = false;
        });
      },
      onPanUpdate: (details) => setState(() {
        final current = _draggedPosition ?? widget.defaultPosition;
        _draggedPosition = _clampToScreen(current + details.delta);
      }),
      onPanEnd: (_) {
        // X always snaps back to the right edge — only the vertical drop
        // position is kept, so the bubble can never end up resting over
        // left-aligned content and stays exactly where the product ask is:
        // always on the right.
        final snappedX = widget.screenSize.width - _bubbleSize - _edgeMargin;
        setState(() {
          _dragging = false;
          _draggedPosition = _clampToScreen(Offset(snappedX, target.dy));
        });
        _armIdleTimer();
      },
      child: AnimatedScale(
        scale: _dragging ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Tooltip(
              message: 'Voice command — drag to move',
              child: AnimatedVoiceAssistant(onTap: widget.onTap, size: _bubbleSize),
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
    // every other move — the settle after a drag ends, a clamp kicking in
    // after a rotation, or the slow recede into the edge once idle.
    return _dragging
        ? Positioned(left: target.dx, top: target.dy, child: bubble)
        : AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            left: target.dx + peekOffset,
            top: target.dy,
            child: bubble,
          );
  }
}

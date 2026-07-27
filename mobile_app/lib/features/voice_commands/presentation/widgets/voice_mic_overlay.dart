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

    // Reactively read the current route so the mic can sit in the standard
    // bottom-right corner on the many screens with no FAB at all, and only
    // bump up above one on the screens that actually have it — rather than
    // sit needlessly high everywhere. router.routerDelegate is a
    // ChangeNotifier that fires on every navigation (see go_router's
    // GoRouterDelegate), so this rebuilds on every route change without
    // any per-screen opt-in.
    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        final hasFab = AppRoutes.screensWithFab.contains(path);
        final bottomOffset = hasFab ? 88.0 : 16.0;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          right: 16,
          bottom: bottomOffset,
          child: conversation == null
              ? _PulsingMicButton(
                  pulse: _pulseController,
                  onTap: controller.startListening,
                )
              : VoiceConversationPanel(conversation: conversation),
        );
      },
    );
  }
}

/// The idle mic FAB with a soft, looping pulse ring behind it — a subtle
/// "tap me" cue rather than a static icon easy to overlook among everything
/// else on screen.
class _PulsingMicButton extends StatelessWidget {
  final Animation<double> pulse;
  final VoidCallback onTap;
  const _PulsingMicButton({required this.pulse, required this.onTap});

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
          FloatingActionButton(
            heroTag: 'voice_mic_fab',
            mini: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Voice command',
            onPressed: onTap,
            child: const Icon(Icons.mic),
          ),
        ],
      ),
    );
  }
}

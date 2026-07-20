import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Plays once: logo pops in with a soft overshoot, loader waves in after.
  late final AnimationController _entrance;
  // Loops for as long as the splash is up: a slow ambient glow "breathing"
  // behind the logo, echoing the neon glow already baked into the artwork.
  late final AnimationController _pulse;
  // Loops: drives the three bouncing loader dots.
  late final AnimationController _dots;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _loaderOpacity;
  late final Animation<Offset> _loaderSlide;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
    _loaderOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );
    _loaderSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
    ));

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _entrance.forward();
    _resolveSession();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _dots.dispose();
    super.dispose();
  }

  Future<void> _resolveSession() async {
    // Session restore can resolve in a handful of milliseconds (no stored
    // session at all), which was dismissing this screen before the entrance
    // animation — or even a single frame of it — ever had a chance to show.
    // Enforcing a minimum display time guarantees the splash is always
    // actually seen; it never adds extra wait beyond however long the real
    // auth check takes, since this timer runs concurrently with it.
    final minDisplayTime =
        Future<void>.delayed(const Duration(milliseconds: 1800));
    try {
      // authStateProvider.future resolves the moment AuthNotifier.build() completes.
      // This is the canonical Riverpod way to await an AsyncNotifier's first value.
      final authState = await ref.read(authStateProvider.future);
      await minDisplayTime;
      if (!mounted) return;
      context.go(
          authState.isAuthenticated ? AppRoutes.dashboard : AppRoutes.login);
    } catch (_) {
      // Any error (e.g., storage failure on web) → treat as not authenticated.
      await minDisplayTime;
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    // White background + the real logo, matching the native launch screen
    // (see flutter_native_splash config in pubspec.yaml) so there's no color
    // flash handing off from the native splash to this Flutter-side one.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_entrance, _pulse]),
              builder: (context, child) {
                final glowScale = 1.0 + (_pulse.value * 0.10);
                final glowOpacity =
                    (0.18 + (_pulse.value * 0.22)) * _logoOpacity.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient glow halo — breathes gently behind the logo.
                    Transform.scale(
                      scale: glowScale,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF5B6FEE)
                                  .withValues(alpha: glowOpacity),
                              const Color(0xFF5B6FEE).withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                          scale: _logoScale.value, child: child),
                    ),
                  ],
                );
              },
              child: Image.asset(
                'assets/images/Royal_logo.png',
                width: 220,
              ),
            ),
            const SizedBox(height: 44),
            FadeTransition(
              opacity: _loaderOpacity,
              child: SlideTransition(
                position: _loaderSlide,
                child: _BouncingDots(controller: _dots),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots bouncing in a sine-wave stagger — a small, deliberate loader
/// instead of a generic spinner, echoing the logo's own playful glow.
class _BouncingDots extends StatelessWidget {
  final Animation<double> controller;
  const _BouncingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.22) % 1.0;
            final bounce = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.translate(
                offset: Offset(0, -bounce * 9),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: 0.45 + bounce * 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

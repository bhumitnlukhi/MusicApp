import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/library_controller.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'home_shell.dart';

/// First-launch welcome screen (light).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  /// Drop your hero photo here (transparent or light background works best).
  static const heroAsset = 'assets/images/onboarding_hero.png';

  Future<void> _start(BuildContext context) async {
    await context.read<LibraryController>().completeOnboarding();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const HomeShell(),
        // Home zooms up out of the depth as it fades in.
        transitionsBuilder: (_, a, _, child) {
          final t = Motion.decelerate.transform(a.value);
          return FadeTransition(
            opacity: a,
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemedScreen(
      dark: false,
      child: Builder(
        builder: (context) {
          final p = context.palette;
          final size = MediaQuery.sizeOf(context);
          return Scaffold(
            body: Stack(
              children: [
                // Hero image, anchored bottom-right like the design.
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: size.width * 0.78,
                  height: size.height * 0.62,
                  child: Entrance(
                    index: 6,
                    offset: 60,
                    duration: const Duration(milliseconds: 1100),
                    child: Image.asset(
                      heroAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) =>
                          _HeroPlaceholder(color: p.border),
                    ),
                  ),
                ),
                SafeArea(
                  // Fills the screen, but scrolls on very short ones.
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(child: ScreenLabel('01')),
                                    EqualizerBars(
                                      playing: true,
                                      color: p.fg,
                                      size: 22,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Each line flips up into place, one after another.
                                // Sized to fit both width and height (landscape).
                                for (final (i, line) in const [
                                  'Music',
                                  'for a',
                                  'brighter',
                                  'you.',
                                ].indexed)
                                  Entrance(
                                    index: i + 1,
                                    offset: 40,
                                    duration: const Duration(milliseconds: 800),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: DisplayTitle(
                                        line,
                                        size: math.min(
                                          size.width * 0.19,
                                          size.height * 0.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Entrance(
                                  index: 5,
                                  child: Text(
                                    'Discover. Listen. Feel.\nAnywhere.',
                                    style: AppText.ui(
                                      12.5,
                                      color: p.muted,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Entrance(
                                  index: 7,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: () => _start(context),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.ink,
                                        foregroundColor: AppColors.paper,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get Started',
                                            style: AppText.ui(
                                              14,
                                              weight: FontWeight.w500,
                                              color: AppColors.paper,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown until `assets/images/onboarding_hero.png` is added.
class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0.3, 0.1),
    child: Icon(Icons.headphones_rounded, size: 220, color: color),
  );
}

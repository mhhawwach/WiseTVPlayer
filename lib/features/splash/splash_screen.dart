import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/perf/perf_profile.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/device_utils.dart';
import '../../core/widgets/clapper_logo.dart';
import '../../core/widgets/update_dialog.dart';
import '../../services/update_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;     // one-shot intro
  late final AnimationController _glowCtrl; // continuous glow pulse

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _textFade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.45, 0.85, curve: Curves.easeOut));
    _textSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.45, 0.9, curve: Curves.easeOutCubic)),
    );

    // On low-tier TVs (webOS/Tizen), skip ALL splash animation — continuous
    // repaints (intro tween, pulsing glow, spinner) starve the weak renderer.
    if (Perf.reduceMotion) {
      _ctrl.value = 1.0; // jump to final state; build() renders a static splash
    } else {
      _glowCtrl.repeat(reverse: true);
      _ctrl.forward();
    }
    _navigate();
  }

  Future<void> _navigate() async {
    // Navigate as soon as warmup is done. The update check runs AFTER navigation
    // so it can NEVER block startup (dio's web timeouts are unreliable and
    // PackageInfo fetches version.json — both can hang on the TV's file:// Chrome
    // 79). On low-tier TVs the brand hold is minimal: the renderer warmup
    // already elapsed on the HTML boot screen — don't pile on more wait.
    await DeviceUtils.warmup()
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    await Future.delayed(Perf.reduceMotion
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 3000));
    if (!mounted) return;

    final hasPlaylists = StorageService.playlists.isNotEmpty;
    // After splash, pick a profile ("Who's watching?") before the menu.
    final destination = hasPlaylists ? '/profiles/select' : '/playlists';
    context.go(destination);

    // Update check — non-blocking; shows over whatever screen is current.
    // Skipped on web: the in-app updater points at the Android APK, which is
    // irrelevant on webOS (that build is sideloaded as an IPK, not auto-updated).
    if (!kIsWeb) {
      UpdateService.instance
          .checkForUpdate()
          .timeout(const Duration(seconds: 8), onTimeout: () => null)
          .then((info) {
        if (info != null && mounted) showUpdateDialog(context, info);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  // Static, zero-animation splash for low-tier TVs (no glow pulse, no intro
  // tween, no spinner) — those continuous repaints starve CanvasKit on the weak
  // webOS/Tizen renderer. Shows the same brand, just still.
  Widget _buildStatic() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClapperLogo(size: 116, animate: false),
            SizedBox(height: 28),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('WiseVod',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text('Player',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ],
            ),
            SizedBox(height: 10),
            Text('STREAM EVERYTHING',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0)),
            SizedBox(height: 30),
            Text('Loading…',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Perf.reduceMotion) return _buildStatic();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Pulsing brand glow backdrop ──────────────────────────────────
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) {
              final t = 0.5 + 0.5 * _glowCtrl.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.55,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12 * t),
                      AppColors.background,
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo: scale + fade + pulsing glow ────────────────────────
                AnimatedBuilder(
                  animation: Listenable.merge([_ctrl, _glowCtrl]),
                  builder: (_, child) {
                    final glow = 0.16 + 0.16 * _glowCtrl.value;
                    return Opacity(
                      opacity: _logoFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withValues(alpha: glow),
                                  blurRadius: 26,
                                  spreadRadius: 1),
                              BoxShadow(
                                  color: AppColors.accent
                                      .withValues(alpha: glow * 0.5),
                                  blurRadius: 38,
                                  spreadRadius: 0),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: const ClapperLogo(size: 116, animate: true),
                ),
                const SizedBox(height: 28),

                // ── Wordmark: assembles letter-by-letter from W and P ────────
                _AnimatedWordmark(controller: _ctrl),
                const SizedBox(height: 10),
                // ── Tagline: fade + slide up ─────────────────────────────────
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Opacity(
                    opacity: _textFade.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: const Text(
                        'STREAM EVERYTHING',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Loading indicator — fades in with the text ───────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Opacity(
                opacity: _textFade.value.clamp(0.0, 1.0),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated wordmark — both words grow letter-by-letter outward from their
// capitals (W and P), so the name "assembles" itself.
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedWordmark extends StatelessWidget {
  const _AnimatedWordmark({required this.controller});
  final AnimationController controller;

  static const _word1 = 'WiseVod';
  static const _word2 = 'Player';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var j = 0; j < _word1.length; j++)
          _Letter(
              controller: controller,
              char: _word1[j],
              delayIndex: j,
              color: AppColors.textPrimary),
        for (var j = 0; j < _word2.length; j++)
          _Letter(
              controller: controller,
              char: _word2[j],
              delayIndex: j,
              color: AppColors.primary),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.controller,
    required this.char,
    required this.delayIndex,
    required this.color,
  });

  final AnimationController controller;
  final String char;
  final int delayIndex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Each word's capital (delayIndex 0) appears first, then the rest cascade.
    final start = (0.45 + delayIndex * 0.05).clamp(0.0, 0.78);
    final end = (start + 0.22).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) {
        final v = anim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          ),
        );
      },
      child: Text(
        char,
        style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5),
      ),
    );
  }
}

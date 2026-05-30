import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WallpaperMode — presets shown behind all menus.
//
// Each entry is either:
//   • gradient-based  — solid color tint (assetImage == null)
//   • image-based     — a real photo/illustration (gradient == null)
//
// Image files live in assets/images/ and are referenced by [assetImage].
// ─────────────────────────────────────────────────────────────────────────────

enum WallpaperMode {
  none(
    label: 'None',
    labelAr: 'لا شيء',
    gradient: null,
    assetImage: null,
    // Overlay opacity: irrelevant for none, but keep consistent field
    overlayOpacity: 0.0,
  ),

  // ── Image wallpapers ───────────────────────────────────────────────────────
  iptv(
    label: 'IPTV',
    labelAr: 'IPTV',
    gradient: null,
    assetImage: 'assets/images/wallpaper_iptv.png',
    // Darker veil so text stays readable over the (blue) image.
    overlayOpacity: 0.72,
  ),
  wallpaper2(
    label: 'Wallpaper 2',
    labelAr: 'خلفية ٢',
    gradient: null,
    assetImage: 'assets/images/Wallpaper02.png',
    overlayOpacity: 0.68,
  ),

  // ── Gradient presets ───────────────────────────────────────────────────────
  cosmic(
    label: 'Cosmic',
    labelAr: 'كوني',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D0020), Color(0xFF0A0015), Color(0xFF05000D)],
      stops: [0.0, 0.5, 1.0],
    ),
    assetImage: null,
    overlayOpacity: 0.80,
  ),
  cinema(
    label: 'Cinema',
    labelAr: 'سينما',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A0800), Color(0xFF100600), Color(0xFF070200)],
      stops: [0.0, 0.5, 1.0],
    ),
    assetImage: null,
    overlayOpacity: 0.80,
  ),
  aurora(
    label: 'Aurora',
    labelAr: 'أورورا',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF001A14), Color(0xFF00100D), Color(0xFF000807)],
      stops: [0.0, 0.5, 1.0],
    ),
    assetImage: null,
    overlayOpacity: 0.80,
  ),
  neon(
    label: 'Neon',
    labelAr: 'نيون',
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0F0020), Color(0xFF050010), Color(0xFF02000A)],
      stops: [0.0, 0.5, 1.0],
    ),
    assetImage: null,
    overlayOpacity: 0.80,
  );

  const WallpaperMode({
    required this.label,
    required this.labelAr,
    required this.gradient,
    required this.assetImage,
    required this.overlayOpacity,
  });

  final String label;
  final String labelAr;

  /// Non-null for gradient-only presets.
  final Gradient? gradient;

  /// Non-null for image-based wallpapers.  Path relative to project root,
  /// e.g. 'assets/images/wallpaper_iptv.png'.
  final String? assetImage;

  /// Alpha of the dark veil rendered on top of the wallpaper for readability.
  /// Images need a lighter veil (~0.55); gradients need ~0.80.
  final double overlayOpacity;

  bool get hasWallpaper => gradient != null || assetImage != null;
  bool get isImageBased => assetImage != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

class WallpaperNotifier extends Notifier<WallpaperMode> {
  static const _key = 'app_wallpaper';

  @override
  WallpaperMode build() {
    final saved = StorageService.getSetting<String>(_key);
    if (saved == null) return WallpaperMode.iptv;
    return WallpaperMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => WallpaperMode.none,
    );
  }

  Future<void> setWallpaper(WallpaperMode mode) async {
    await StorageService.setSetting(_key, mode.name);
    state = mode;
  }
}

final wallpaperProvider =
    NotifierProvider<WallpaperNotifier, WallpaperMode>(WallpaperNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Widget — placed behind the widget tree in MaterialApp.builder
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the current wallpaper (image or gradient) with a dark veil overlay
/// for text readability.  Place as the first child of a [Stack].
class WallpaperBackground extends StatelessWidget {
  const WallpaperBackground({super.key, required this.mode});
  final WallpaperMode mode;

  @override
  Widget build(BuildContext context) {
    if (!mode.hasWallpaper) return const SizedBox.shrink();

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Base layer: real image or gradient ─────────────────────────────
          if (mode.isImageBased)
            Image.asset(
              mode.assetImage!,
              fit: BoxFit.cover,
              // Cap decode resolution — a 4K source PNG would otherwise decode
              // to a ~35 MB bitmap and thrash memory on a 2 GB TV. 1280 wide is
              // ample behind the dark readability veil.
              cacheWidth: 1280,
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: mode.gradient),
            ),

          // ── Dark veil for readability ───────────────────────────────────────
          // Opacity is tuned per preset — images need a lighter veil than
          // solid gradients so the detail is still visible.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(0, 0, 0, mode.overlayOpacity),
                  Color.fromRGBO(0, 0, 0, (mode.overlayOpacity + 0.1).clamp(0.0, 1.0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

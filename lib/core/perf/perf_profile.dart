import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable performance mode.
enum PerfMode { auto, low, high, ultra }

/// Resolved hardware class.
///   • low   — weak TVs (webOS α5-class, 2 GB Android boxes): minimal everything.
///   • high  — capable phones / Android TV: full effects, 250 MB image cache.
///   • ultra — desktop (Windows/macOS/Linux): cranks cache + buffers for max speed.
enum PerfTier { low, high, ultra }

/// App-wide performance profile.
///
/// Resolved once at startup from the saved user preference + native device
/// auto-detection, then read **synchronously** by performance-sensitive widgets
/// ([FocusableCard] motion, wallpaper layer, image-cache budget, home hero
/// auto-rotate, …).
///
/// The renderer choice (Impeller vs Skia) is fixed natively at engine start
/// — see `MainActivity.getFlutterShellArgs()` — so changes made in Settings are
/// persisted to [SharedPreferences] (which the native side reads on next launch)
/// and only take **full** effect after an app restart. The Settings UI says so.
///
/// Persisted in [SharedPreferences] (not Hive) specifically so the Kotlin side
/// can read [_kMode] to decide whether to disable Impeller before any Dart runs.
class Perf {
  Perf._();

  // ── Resolved snapshot (valid after [init]) ────────────────────────────────
  static PerfMode mode = PerfMode.auto;
  static bool autoDetectedLowEnd = false;
  static PerfTier tier = PerfTier.high;

  /// True → skip the expensive focus zoom/glow animations and home hero
  /// auto-rotate (keeps the focus *border* for visibility, just no motion).
  static bool reduceMotion = false;

  /// True → render the chosen wallpaper image/gradient behind the UI.
  static bool wallpaperAllowed = true;

  /// True → 250 MB image cache (high tier); false → small 64 MB cache.
  static bool largeImageCache = true;

  // ── SharedPreferences keys (native reads "flutter.<key>") ─────────────────
  static const _kMode = 'perf_mode'; // 'auto' | 'low' | 'high'
  static const _kMotion = 'perf_motion'; // bool override (animations ON)
  static const _kWallpaper = 'perf_wallpaper'; // bool override
  static const _kCache = 'perf_cache'; // bool override (large cache)

  static const _channel = MethodChannel('com.wiseapps.wisetv/device');

  /// Reads the saved mode + native low-end detection and computes the effective
  /// flags. Call once early in bootstrap (after the binding is ready).
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    mode = _parseMode(prefs.getString(_kMode));
    autoDetectedLowEnd = await _detectLowEnd();
    tier = _resolveTier(mode);

    // high AND ultra are "capable": full motion, wallpaper, large image cache.
    final bool capable = tier != PerfTier.low;
    // null override → follow the tier default.
    reduceMotion = !(prefs.getBool(_kMotion) ?? capable);
    wallpaperAllowed = prefs.getBool(_kWallpaper) ?? capable;
    largeImageCache = prefs.getBool(_kCache) ?? capable;
  }

  /// Apply the resolved image-cache budget to the engine's [imageCache].
  static void applyImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    if (tier == PerfTier.ultra) {
      // Ultra (desktop): huge cache so poster grids never re-decode. PCs have
      // the RAM; this is the bulk of the "lightning fast" feel.
      cache.maximumSize = 1200;
      cache.maximumSizeBytes = 1024 * 1024 * 1024; // 1 GB
    } else if (largeImageCache) {
      // High tier: generous cache for buttery poster scrolling on capable TVs.
      cache.maximumSize = 400;
      cache.maximumSizeBytes = 250 * 1024 * 1024;
    } else {
      // Low tier: the proven small budget that keeps weak 2 GB TVs off the
      // system low-memory killer.
      cache.maximumSize = 150;
      cache.maximumSizeBytes = 64 * 1024 * 1024;
    }
  }

  /// libmpv demuxer/back-buffer budget for the active tier — bigger = instant
  /// seeks and near-zero channel-switch time. Used by [PlayerFactory].
  static int get mediaBufferBytes => switch (tier) {
        PerfTier.ultra => 128 * 1024 * 1024, // desktop: huge buffer
        PerfTier.high => 32 * 1024 * 1024,
        PerfTier.low => 8 * 1024 * 1024,
      };

  // ── Setters (Settings UI) — persist + update the live snapshot ────────────

  /// Change the master mode. Resets the per-feature overrides so they follow
  /// the new tier's defaults (the user can then refine individual toggles).
  static Future<void> setMode(PerfMode m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, m.name);
    await prefs.remove(_kMotion);
    await prefs.remove(_kWallpaper);
    await prefs.remove(_kCache);

    mode = m;
    tier = _resolveTier(m);
    final bool capable = tier != PerfTier.low; // high or ultra
    reduceMotion = !capable;
    wallpaperAllowed = capable;
    largeImageCache = capable;
  }

  static Future<void> setAnimations(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMotion, on);
    reduceMotion = !on;
  }

  static Future<void> setWallpaperAllowed(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWallpaper, on);
    wallpaperAllowed = on;
  }

  static Future<void> setLargeImageCache(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCache, on);
    largeImageCache = on;
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  static PerfMode _parseMode(String? v) => switch (v) {
        'low' => PerfMode.low,
        'high' => PerfMode.high,
        'ultra' => PerfMode.ultra,
        _ => PerfMode.auto,
      };

  /// Native desktop (Windows/macOS/Linux) — strong hardware, gets Ultra by default.
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static PerfTier _resolveTier(PerfMode m) => switch (m) {
        PerfMode.low => PerfTier.low,
        PerfMode.high => PerfTier.high,
        PerfMode.ultra => PerfTier.ultra,
        PerfMode.auto => autoDetectedLowEnd
            ? PerfTier.low
            : (_isDesktop ? PerfTier.ultra : PerfTier.high),
      };

  static Future<bool> _detectLowEnd() async {
    // Smart-TV web builds (webOS / Tizen) run CanvasKit on weak TV GPUs/CPUs.
    // Always treat them as low tier: kills continuous animations, the heavy
    // wallpaper compositing, and the large image cache — all of which otherwise
    // starve the TV's renderer (verified: animations + wallpaper made the UI
    // unresponsive on webOS 6.5.3 / Chrome 79).
    // ignore: do_not_use_environment
    const target = String.fromEnvironment('FLUTTER_TARGET_PLATFORM');
    if (target.contains('webos') || target.contains('tizen')) return true;
    // Other native low-end detection is Android-only; web/iOS/desktop assume capable.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isLowEndDevice') ?? false;
    } catch (_) {
      // Channel not ready / unsupported — assume capable so we don't needlessly
      // degrade the experience.
      return false;
    }
  }
}

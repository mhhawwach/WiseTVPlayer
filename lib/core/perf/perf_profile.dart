import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selectable performance mode.
enum PerfMode { auto, low, high }

/// Resolved hardware class.
enum PerfTier { low, high }

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

    final bool tierHigh = tier == PerfTier.high;
    // null override → follow the tier default.
    reduceMotion = !(prefs.getBool(_kMotion) ?? tierHigh);
    wallpaperAllowed = prefs.getBool(_kWallpaper) ?? tierHigh;
    largeImageCache = prefs.getBool(_kCache) ?? tierHigh;
  }

  /// Apply the resolved image-cache budget to the engine's [imageCache].
  static void applyImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    if (largeImageCache) {
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
    final bool tierHigh = tier == PerfTier.high;
    reduceMotion = !tierHigh;
    wallpaperAllowed = tierHigh;
    largeImageCache = tierHigh;
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
        _ => PerfMode.auto,
      };

  static PerfTier _resolveTier(PerfMode m) => switch (m) {
        PerfMode.low => PerfTier.low,
        PerfMode.high => PerfTier.high,
        PerfMode.auto =>
          autoDetectedLowEnd ? PerfTier.low : PerfTier.high,
      };

  static Future<bool> _detectLowEnd() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isLowEndDevice') ?? false;
    } catch (_) {
      // Channel not ready / unsupported — assume capable so we don't needlessly
      // degrade the experience.
      return false;
    }
  }
}

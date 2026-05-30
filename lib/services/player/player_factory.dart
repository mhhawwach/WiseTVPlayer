import 'package:flutter/foundation.dart';

import 'app_player.dart';
import 'media_kit_player_impl.dart';

// Conditional imports resolve at compile time:
//   • dart.library.html  → only present on Flutter Web
//   • dart.library.io    → present on Android / iOS / desktop
// On the web build, WebPlayerImpl comes from web_player_impl.dart (dart:html).
// On native builds, it comes from web_player_stub.dart (no-op, never called).
import 'web_player_stub.dart'
  // ignore: uri_does_not_exist
  if (dart.library.html) 'web_player_impl.dart' as webplayer;

// Tizen: flutter-tizen compiles with dart.library.io but sets the
// FLUTTER_TARGET_PLATFORM env var. The real implementation is backed by
// the video_player package (binds to video_player_tizen on Tizen builds).
// On Android/iOS this is compiled but never instantiated — PlayerFactory
// only returns it when _isTizen is true.
import 'tizen_player_impl.dart' as tizenplayer;

export 'app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PlayerFactory — creates the right AppPlayer for the current platform.
//
//   Android / iOS  →  MediaKitPlayerImpl  (libmpv, full IPTV support)
//   Flutter Web    →  WebPlayerImpl       (HTML5 <video>, LG WebOS target)
//   Tizen          →  TizenPlayerImpl     (Samsung Smart TV — stub for now)
// ─────────────────────────────────────────────────────────────────────────────

class PlayerFactory {
  PlayerFactory._();

  /// Default buffer: 32 MB (VOD). Pass 8 MB for live TV for faster zapping.
  static AppPlayer create({int bufferSize = 32 * 1024 * 1024}) {
    if (kIsWeb) {
      // LG WebOS or any Flutter Web target.
      // Resolves to web_player_impl.dart (HTML5 <video>) at compile time.
      return webplayer.WebPlayerImpl();
    }

    // Check for Tizen at compile time — flutter-tizen sets this define.
    if (_isTizen) {
      return tizenplayer.TizenPlayerImpl();
    }

    // Android, iOS, macOS, Windows, Linux — all use media_kit / libmpv.
    return MediaKitPlayerImpl(bufferSize: bufferSize);
  }

  static bool get _isTizen {
    // flutter-tizen injects FLUTTER_TARGET_PLATFORM=tizen at build time.
    // ignore: do_not_use_environment
    const os = String.fromEnvironment('FLUTTER_TARGET_PLATFORM');
    return os.contains('tizen');
  }
}

import 'dart:io';
import 'package:flutter/services.dart';

/// Updates the iOS Control Center / Lock Screen "Now Playing" widget.
///
/// On Android the methods are no-ops; Android's media notification is
/// handled automatically by media_kit / ExoPlayer.
class NowPlayingService {
  NowPlayingService._();
  static final NowPlayingService instance = NowPlayingService._();

  static const _channel = MethodChannel('com.wiseapps.wisetv/nowplaying');

  /// Update the now-playing metadata.
  /// [title]    — channel / movie / episode name.
  /// [subtitle] — category, series name, etc.
  /// [artwork]  — HTTP URL of the channel logo / poster. May be null.
  Future<void> update({
    required String title,
    String subtitle = '',
    String? artwork,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'subtitle': subtitle,
        'artwork': artwork,
      });
    } catch (_) {
      // Non-fatal: Now Playing is a UX enhancement, never a blocker.
    }
  }

  /// Clear the now-playing info (e.g. when playback stops).
  Future<void> clear() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../features/player/widgets/aspect_mode.dart';

// ── Platform flags ────────────────────────────────────────────────────────────

// ignore: do_not_use_environment
const String _targetPlatform = String.fromEnvironment('FLUTTER_TARGET_PLATFORM');

/// True for the web build packaged as a Samsung Tizen .wgt. Playback there
/// uses the native AVPlay pipeline, which renders on the TV's video plane
/// BEHIND the browser graphics — so player backdrops must be TRANSPARENT
/// (the "hole punch") instead of black.
const bool kTizenWeb = kIsWeb && _targetPlatform == 'tizen';

/// Backdrop for the player screens: transparent on Tizen (hole punch for the
/// AVPlay video plane), black everywhere else.
const Color playerBackdrop =
    kTizenWeb ? Colors.transparent : Colors.black;

// ─────────────────────────────────────────────────────────────────────────────
// Platform-neutral player abstraction
//
// All three platform implementations (media_kit, Tizen, Web) expose this API.
// Player screens only import this file — never media_kit directly.
// ─────────────────────────────────────────────────────────────────────────────

// ── State model ───────────────────────────────────────────────────────────────

class AppPlayerState {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool playing;
  final bool buffering;
  final double bufferingPercentage;

  // Video metadata
  final int? videoWidth;
  final int? videoHeight;
  final String? videoCodec;
  final double? videoFps;
  final int? videoBitrateKbps;
  final String? pixelFormat;
  final String? hwPixelFormat;
  final String? colorMatrix;
  final String? colorLevels;

  // Audio metadata
  final String? audioCodec;
  final int? audioBitrateKbps;
  final String? audioSampleRate;
  final String? audioChannels;

  const AppPlayerState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.bufferingPercentage = 0,
    this.videoWidth,
    this.videoHeight,
    this.videoCodec,
    this.videoFps,
    this.videoBitrateKbps,
    this.pixelFormat,
    this.hwPixelFormat,
    this.colorMatrix,
    this.colorLevels,
    this.audioCodec,
    this.audioBitrateKbps,
    this.audioSampleRate,
    this.audioChannels,
  });
}

// ── Track model ───────────────────────────────────────────────────────────────

class AppTrack {
  final String id;
  final String? title;
  final String? language;
  final String? codec;
  const AppTrack({required this.id, this.title, this.language, this.codec});

  static const auto = AppTrack(id: 'auto');
  static const none = AppTrack(id: 'no');

  bool get isSentinel => id == 'auto' || id == 'no';

  @override
  String toString() =>
      title ?? language ?? (codec != null ? codec!.toUpperCase() : id);
}

class AppTracks {
  final List<AppTrack> video;
  final List<AppTrack> audio;
  final List<AppTrack> subtitle;

  const AppTracks({
    this.video = const [],
    this.audio = const [],
    this.subtitle = const [],
  });
}

// ── Abstract player interface ─────────────────────────────────────────────────

abstract class AppPlayer {
  // ── Synchronous state snapshot ────────────────────────────────────────────
  AppPlayerState get state;

  // ── Live streams ──────────────────────────────────────────────────────────
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<Duration> get bufferStream;

  /// Playback errors reported by the engine (stream won't open, decoder
  /// failure, …) as a short reason. Engines may also report recoverable
  /// hiccups here, so screens should treat an error as fatal only if playback
  /// isn't progressing (see PlaybackWatchdog). Engines that can't report
  /// errors leave this empty; the watchdog's open/stall timers still apply.
  Stream<String> get errorStream => const Stream.empty();

  // ── Track info ────────────────────────────────────────────────────────────
  AppTracks get tracks;
  AppTrack get selectedVideoTrack;
  AppTrack get selectedAudioTrack;
  AppTrack get selectedSubtitleTrack;

  // ── Playback control ──────────────────────────────────────────────────────
  Future<void> open(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);

  // ── Track selection ───────────────────────────────────────────────────────
  Future<void> setVideoTrack(AppTrack track);
  Future<void> setAudioTrack(AppTrack track);
  Future<void> setSubtitleTrack(AppTrack track);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  Future<void> dispose();

  // ── Video rendering ───────────────────────────────────────────────────────
  /// Returns the platform-specific widget that renders the video frame.
  Widget buildVideoWidget(BuildContext context, AspectMode mode);
}

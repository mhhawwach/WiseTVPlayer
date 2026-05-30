import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../features/player/widgets/aspect_mode.dart';
import 'app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tizen player — Samsung Smart TV (Tizen OS).
//
// Backed by the `video_player` package. On a Tizen build the platform
// implementation is `video_player_tizen`, which wraps Tizen's native
// capi-media-player (HLS / MPEG-DASH / progressive MP4 — covers IPTV VOD,
// catch-up, and most live formats).
//
// BUILDING FOR TIZEN
// ──────────────────
//   1. Install flutter-tizen:  https://github.com/flutter-tizen/flutter-tizen
//   2. Add the Tizen platform implementation (flutter-tizen's pub):
//        flutter-tizen pub add video_player_tizen
//   3. Build / run:
//        flutter-tizen build tpk   (or)   flutter-tizen run -d <tv-ip>
//
//   PlayerFactory already routes to this class when FLUTTER_TARGET_PLATFORM
//   contains "tizen", so no code change is needed.
//
// NOTE: the base video_player API has no audio/subtitle track switching;
// Tizen auto-selects the default tracks. Track selection is therefore a
// graceful no-op here (the track picker simply shows no alternatives).
// ─────────────────────────────────────────────────────────────────────────────

class TizenPlayerImpl extends AppPlayer {
  VideoPlayerController? _controller;

  // Bridge VideoPlayerController.value (a ValueListenable) → Dart streams,
  // matching the AppPlayer streaming contract the player screens expect.
  final _positionCtrl  = StreamController<Duration>.broadcast();
  final _durationOut   = StreamController<Duration>.broadcast();
  final _playingCtrl   = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _bufferCtrl    = StreamController<Duration>.broadcast();

  // Last-emitted values, so we only push on real change.
  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;
  bool _lastPlaying = false;
  bool _lastBuffering = false;
  Duration _lastBuffer = Duration.zero;

  void _onValue() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final v = c.value;

    if (v.position != _lastPos) {
      _lastPos = v.position;
      _positionCtrl.add(v.position);
    }
    if (v.duration != _lastDur) {
      _lastDur = v.duration;
      _durationOut.add(v.duration);
    }
    if (v.isPlaying != _lastPlaying) {
      _lastPlaying = v.isPlaying;
      _playingCtrl.add(v.isPlaying);
    }
    if (v.isBuffering != _lastBuffering) {
      _lastBuffering = v.isBuffering;
      _bufferingCtrl.add(v.isBuffering);
    }
    final buffered = v.buffered.isNotEmpty ? v.buffered.last.end : Duration.zero;
    if (buffered != _lastBuffer) {
      _lastBuffer = buffered;
      _bufferCtrl.add(buffered);
    }
  }

  // ── State snapshot ──────────────────────────────────────────────────────────

  @override
  AppPlayerState get state {
    final v = _controller?.value;
    if (v == null || !v.isInitialized) return const AppPlayerState();
    final buffered =
        v.buffered.isNotEmpty ? v.buffered.last.end : Duration.zero;
    return AppPlayerState(
      position: v.position,
      duration: v.duration,
      buffer: buffered,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      bufferingPercentage: 0,
      videoWidth: v.size.width.toInt(),
      videoHeight: v.size.height.toInt(),
    );
  }

  // ── Streams ─────────────────────────────────────────────────────────────────

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;
  @override
  Stream<Duration> get durationStream => _durationOut.stream;
  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<Duration> get bufferStream => _bufferCtrl.stream;

  // ── Tracks (not exposed by base video_player) ───────────────────────────────

  @override
  AppTracks get tracks => const AppTracks();
  @override
  AppTrack get selectedVideoTrack => AppTrack.auto;
  @override
  AppTrack get selectedAudioTrack => AppTrack.auto;
  @override
  AppTrack get selectedSubtitleTrack => AppTrack.none;

  // ── Playback control ────────────────────────────────────────────────────────

  @override
  Future<void> open(String url) async {
    // Tear down any previous controller before opening a new stream.
    final old = _controller;
    if (old != null) {
      old.removeListener(_onValue);
      await old.dispose();
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    c.addListener(_onValue);
    await c.initialize();
    await c.play();
    _onValue();
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> playOrPause() async {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? await c.pause() : await c.play();
  }

  @override
  Future<void> seek(Duration position) async =>
      _controller?.seekTo(position);

  @override
  Future<void> setVideoTrack(AppTrack track) async {}
  @override
  Future<void> setAudioTrack(AppTrack track) async {}
  @override
  Future<void> setSubtitleTrack(AppTrack track) async {}

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onValue);
      await c.dispose();
      _controller = null;
    }
    await _positionCtrl.close();
    await _durationOut.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _bufferCtrl.close();
  }

  // ── Video widget ────────────────────────────────────────────────────────────

  @override
  Widget buildVideoWidget(BuildContext context, AspectMode mode) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    final video = VideoPlayer(c);
    final size = c.value.size;

    Widget cropped(BoxFit fit) => ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: video,
            ),
          ),
        );

    Widget boxed(double ar) => ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(aspectRatio: ar, child: video),
          ),
        );

    switch (mode) {
      case AspectMode.contain:
        return boxed(c.value.aspectRatio);
      case AspectMode.cover:
        return cropped(BoxFit.cover);
      case AspectMode.fill:
        return cropped(BoxFit.fill);
      case AspectMode.ratio16x9:
        return boxed(16 / 9);
      case AspectMode.ratio4x3:
        return boxed(4 / 3);
    }
  }
}

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// dart:html is deprecated in favour of package:web but remains functional
// in Flutter Web. This file only compiles on the web target anyway.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../features/player/widgets/aspect_mode.dart';
import 'app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Web (HTML5 <video>) player — used on Flutter Web / LG WebOS.
//
// LG WebOS ships a Chromium-based browser. The Flutter Web build runs inside
// this browser via the CanvasKit or HTML renderer, and this class drives a
// native <video> element for hardware-accelerated HLS/MPEG-DASH playback.
//
// WebOS-specific notes:
//   • HLS (.m3u8) plays natively in WebOS Chromium — no MSE setup needed
//   • MPEG-DASH requires dash.js or hls.js injected in web/index.html
//   • The Magic Remote acts as a pointer + Enter/Back keys
//   • Key codes: Back = 461, Red = 403, Green = 404, Yellow = 405, Blue = 406
// ─────────────────────────────────────────────────────────────────────────────

class WebPlayerImpl extends AppPlayer {
  late final html.VideoElement _video;
  late final String _viewId;

  final _positionCtrl  = StreamController<Duration>.broadcast();
  final _durationCtrl  = StreamController<Duration>.broadcast();
  final _playingCtrl   = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _bufferCtrl    = StreamController<Duration>.broadcast();

  Timer? _pollTimer;

  WebPlayerImpl() {
    _viewId = 'wisetv-video-${DateTime.now().millisecondsSinceEpoch}';
    _video  = html.VideoElement()
      ..id           = _viewId
      ..style.width  = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..autoplay = false
      ..controls = false;

    // Register the platform view so Flutter can embed it.
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (_) => _video,
    );

    _attachListeners();
    _startPollTimer();
  }

  void _attachListeners() {
    _video.onPlay.listen((_)     => _playingCtrl.add(true));
    _video.onPause.listen((_)    => _playingCtrl.add(false));
    _video.onWaiting.listen((_)  => _bufferingCtrl.add(true));
    _video.onCanPlay.listen((_)  => _bufferingCtrl.add(false));
    _video.onDurationChange.listen((_) {
      final d = _video.duration;
      if (d.isFinite && !d.isNaN) {
        _durationCtrl.add(Duration(milliseconds: (d * 1000).round()));
      }
    });
    _video.onTimeUpdate.listen((_) {
      _positionCtrl.add(
          Duration(milliseconds: (_video.currentTime * 1000).round()));
    });
    _video.onError.listen((e) => debugPrint('WebPlayerImpl: video error $e'));
  }

  void _startPollTimer() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        final buffered = _video.buffered;
        if (buffered.length > 0) {
          final bufEnd = buffered.end(buffered.length - 1);
          final bufSec = bufEnd - _video.currentTime;
          if (bufSec >= 0) {
            _bufferCtrl.add(
                Duration(milliseconds: (bufSec * 1000).round()));
          }
        }
      } catch (_) {}
    });
  }

  // ── State ─────────────────────────────────────────────────────────────────

  @override
  AppPlayerState get state {
    final pos = _video.currentTime;
    final dur = _video.duration;
    double bufSec = 0;
    try {
      final buffered = _video.buffered;
      if (buffered.length > 0) {
        bufSec = buffered.end(buffered.length - 1) - pos;
      }
    } catch (_) {}
    return AppPlayerState(
      position: Duration(milliseconds: (pos * 1000).round()),
      duration: (dur.isFinite && !dur.isNaN)
          ? Duration(milliseconds: (dur * 1000).round())
          : Duration.zero,
      buffer:
          Duration(milliseconds: (bufSec * 1000).clamp(0, 3600000).round()),
      playing:   !_video.paused,
      buffering: _video.readyState < 3 && !_video.paused,
    );
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  @override Stream<Duration> get positionStream  => _positionCtrl.stream;
  @override Stream<Duration> get durationStream  => _durationCtrl.stream;
  @override Stream<bool>     get playingStream   => _playingCtrl.stream;
  @override Stream<bool>     get bufferingStream => _bufferingCtrl.stream;
  @override Stream<Duration> get bufferStream    => _bufferCtrl.stream;

  // ── Tracks (HTML5 TextTrack API) ──────────────────────────────────────────

  @override
  AppTracks get tracks {
    final subs = <AppTrack>[];
    final tt = _video.textTracks;
    final len = tt?.length ?? 0;
    for (var i = 0; i < len; i++) {
      final t = tt![i];
      subs.add(AppTrack(id: '$i', title: t.label, language: t.language));
    }
    return AppTracks(subtitle: subs);
  }

  @override AppTrack get selectedVideoTrack    => AppTrack.auto;
  @override AppTrack get selectedAudioTrack    => AppTrack.auto;
  @override AppTrack get selectedSubtitleTrack => AppTrack.none;

  // ── Playback control ──────────────────────────────────────────────────────

  @override
  Future<void> open(String url) async {
    // Prefer the JS bridge (index.html) which routes MPEG-TS (.ts) live
    // streams through mpegts.js. WebOS Chromium can't play raw .ts in a bare
    // <video>, so without this live channels never start. MP4/MKV/HLS fall
    // back to the native element inside the bridge.
    if (js_util.hasProperty(html.window, 'wisetvOpen')) {
      try {
        final handled =
            js_util.callMethod(html.window, 'wisetvOpen', [_video, url]);
        if (handled == true) return;
      } catch (_) {
        // Bridge threw — fall through to native playback below.
      }
    }
    _video.src = url;
    await _video.play();
  }

  @override Future<void> play()        async => _video.play();
  @override Future<void> pause()       async => _video.pause();
  @override Future<void> playOrPause() async =>
      _video.paused ? _video.play() : _video.pause();

  @override
  Future<void> seek(Duration position) async {
    _video.currentTime = position.inMilliseconds / 1000.0;
  }

  @override Future<void> setVideoTrack(AppTrack track) async {}
  @override Future<void> setAudioTrack(AppTrack track) async {}

  @override
  Future<void> setSubtitleTrack(AppTrack track) async {
    final tt  = _video.textTracks;
    final len = tt?.length ?? 0;
    for (var i = 0; i < len; i++) {
      tt![i].mode = (i.toString() == track.id) ? 'showing' : 'hidden';
    }
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    // Destroy any mpegts.js player bound to the element, then clear the source.
    if (js_util.hasProperty(html.window, 'wisetvDispose')) {
      try {
        js_util.callMethod(html.window, 'wisetvDispose', [_video]);
      } catch (_) {}
    } else {
      _video.pause();
      _video.src = '';
    }
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _bufferCtrl.close();
  }

  // ── Video widget ──────────────────────────────────────────────────────────

  @override
  Widget buildVideoWidget(BuildContext context, AspectMode mode) {
    return SizedBox.expand(
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

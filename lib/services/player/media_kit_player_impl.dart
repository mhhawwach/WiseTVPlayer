import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide Playlist;
import 'package:media_kit_video/media_kit_video.dart';

import '../../features/player/widgets/aspect_mode.dart';
import 'app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// media_kit implementation — used on Android, iOS, and desktop.
// ─────────────────────────────────────────────────────────────────────────────

class MediaKitPlayerImpl extends AppPlayer {
  late final Player _player;
  late final VideoController _controller;

  StreamSubscription<PlayerLog>? _logSub;
  bool _hwdecFellBack = false;

  MediaKitPlayerImpl({int bufferSize = 32 * 1024 * 1024}) {
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize,
        logLevel: MPVLogLevel.error,
      ),
    );

    // Zero-copy hardware decoding: Android MediaCodec renders decoded frames
    // straight into the output surface (the same path Netflix/Shahid use)
    // instead of copying every frame through CPU memory like `mediacodec-copy`
    // does. The copy path is what was dropping frames on this weak TV GPU; the
    // surface path keeps full frame-rate. The surface is attached only AFTER
    // the first frame's video parameters are known, which sidesteps the
    // Realtek decoder's "Output format changed unexpectedly" crash on attach.
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'mediacodec',
        androidAttachSurfaceAfterVideoParameters: true,
      ),
    );

    try {
      // Allow hardware decoding for every codec (some configs restrict it).
      (_player.platform as dynamic)?.setProperty('hwdec-codecs', 'all');
    } catch (_) {
      // Property API unavailable on this platform — ignore.
    }

    // Safety net: if a particular stream still trips the surface decoder on
    // this hardware ("BAD CODEC: Output format changed unexpectedly"),
    // transparently drop to the robust byte-buffer copy path. mpv re-inits the
    // decoder live, so playback recovers instead of dying — worst case we're
    // back to the previous (working but slower) behaviour, only for that codec.
    _logSub = _player.stream.log.listen((log) {
      if (_hwdecFellBack) return;
      final t = log.text.toLowerCase();
      if (t.contains('output format changed unexpectedly') ||
          t.contains('bad codec')) {
        _hwdecFellBack = true;
        try {
          (_player.platform as dynamic)
              ?.setProperty('hwdec', 'mediacodec-copy');
        } catch (_) {
          // Ignore — nothing more we can do from here.
        }
      }
    });
  }

  // ── State ─────────────────────────────────────────────────────────────────

  @override
  AppPlayerState get state {
    final s = _player.state;
    final vp = s.videoParams;
    final ap = s.audioParams;
    final vt = _bestVideoTrack(s);
    final at = _bestAudioTrack(s);

    final int? vidBitrateKbps = (vt != null && (vt.bitrate ?? 0) > 0)
        ? ((vt.bitrate ?? 0) / 1000).round()
        : null;
    final int? audBitrateKbps =
        (s.audioBitrate != null && s.audioBitrate! > 0)
            ? (s.audioBitrate! / 1000).round()
            : null;

    return AppPlayerState(
      position: s.position,
      duration: s.duration,
      buffer: s.buffer,
      playing: s.playing,
      buffering: s.buffering,
      bufferingPercentage: s.bufferingPercentage,
      videoWidth: vp.dw ?? vp.w ?? s.width,
      videoHeight: vp.dh ?? vp.h ?? s.height,
      videoCodec: vt?.codec,
      videoFps: (vt?.fps != null && (vt!.fps ?? 0) > 0) ? vt.fps : null,
      videoBitrateKbps: vidBitrateKbps,
      pixelFormat: vp.pixelformat,
      hwPixelFormat: vp.hwPixelformat,
      colorMatrix: vp.colormatrix,
      colorLevels: vp.colorlevels,
      audioCodec: at?.codec ?? ap.format,
      audioBitrateKbps: audBitrateKbps,
      audioSampleRate:
          (ap.sampleRate != null && (ap.sampleRate ?? 0) > 0)
              ? '${ap.sampleRate} Hz'
              : null,
      audioChannels: ap.hrChannels ??
          (ap.channelCount != null ? '${ap.channelCount} ch' : null),
    );
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  @override
  Stream<Duration> get positionStream => _player.stream.position;
  @override
  Stream<Duration> get durationStream => _player.stream.duration;
  @override
  Stream<bool> get playingStream => _player.stream.playing;
  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;
  @override
  Stream<Duration> get bufferStream => _player.stream.buffer;

  // ── Tracks ────────────────────────────────────────────────────────────────

  @override
  AppTracks get tracks {
    final s = _player.state;
    return AppTracks(
      video: s.tracks.video
          .where((t) => !_isSentinel(t.id))
          .map((t) => AppTrack(
                id: t.id,
                title: t.title,
                language: t.language,
                codec: t.codec,
              ))
          .toList(),
      audio: s.tracks.audio
          .where((t) => !_isSentinel(t.id))
          .map((t) => AppTrack(
                id: t.id,
                title: t.title,
                language: t.language,
                codec: t.codec,
              ))
          .toList(),
      subtitle: s.tracks.subtitle
          .where((t) => !_isSentinel(t.id))
          .map((t) => AppTrack(
                id: t.id,
                title: t.title,
                language: t.language,
                codec: t.codec,
              ))
          .toList(),
    );
  }

  @override
  AppTrack get selectedVideoTrack {
    final id = _player.state.track.video.id;
    return AppTrack(id: id);
  }

  @override
  AppTrack get selectedAudioTrack {
    final id = _player.state.track.audio.id;
    return AppTrack(id: id);
  }

  @override
  AppTrack get selectedSubtitleTrack {
    final id = _player.state.track.subtitle.id;
    return AppTrack(id: id);
  }

  // ── Playback control ──────────────────────────────────────────────────────

  @override
  Future<void> open(String url) => _player.open(Media(url));

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVideoTrack(AppTrack track) =>
      _player.setVideoTrack(VideoTrack(track.id, track.title, track.language));

  @override
  Future<void> setAudioTrack(AppTrack track) =>
      _player.setAudioTrack(AudioTrack(track.id, track.title, track.language));

  @override
  Future<void> setSubtitleTrack(AppTrack track) =>
      _player.setSubtitleTrack(
          SubtitleTrack(track.id, track.title, track.language));

  @override
  Future<void> dispose() {
    _logSub?.cancel();
    return _player.dispose();
  }

  // ── Video widget ──────────────────────────────────────────────────────────

  @override
  Widget buildVideoWidget(BuildContext context, AspectMode mode) {
    return AspectModeVideo(controller: _controller, mode: mode);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static bool _isSentinel(String id) => id == 'no' || id == 'auto';

  static VideoTrack? _bestVideoTrack(PlayerState s) {
    final selId = s.track.video.id;
    if (!_isSentinel(selId)) {
      final found =
          s.tracks.video.firstWhereOrNull((t) => t.id == selId);
      if (found != null) return found;
    }
    return s.tracks.video
        .firstWhereOrNull((t) => !_isSentinel(t.id));
  }

  static AudioTrack? _bestAudioTrack(PlayerState s) {
    final selId = s.track.audio.id;
    if (!_isSentinel(selId)) {
      final found =
          s.tracks.audio.firstWhereOrNull((t) => t.id == selId);
      if (found != null) return found;
    }
    return s.tracks.audio
        .firstWhereOrNull((t) => !_isSentinel(t.id));
  }
}

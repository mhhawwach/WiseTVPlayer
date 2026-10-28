// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// dart:html is deprecated in favour of package:web but remains functional in
// Flutter Web; this file only compiles on the web target (see player_factory's
// conditional import) and mirrors web_player_impl.dart's style.
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/material.dart';

import '../../features/player/widgets/aspect_mode.dart';
import 'app_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Samsung Tizen AVPlay player — used by the .wgt build on Samsung TVs.
//
// The TV's web engine does NOT decode video for inline HTML5 <video> (it
// "plays" — clock + audio — but frames never reach the compositor; verified
// with a drawImage pixel probe on a CU8000). Every commercial IPTV app on
// Samsung instead uses `webapis.avplay`: the TV's native player, which
// hardware-decodes H.264/HEVC/TS/HLS onto the VIDEO PLANE that sits BEHIND
// the browser graphics. The app then paints TRANSPARENT pixels where the
// video should show (the "hole punch"): see `kTizenWeb`-guarded backdrops in
// the player screens and the body-background handling in [open]/[dispose].
//
// AVPlay is a SINGLE global hardware pipeline: opening a new instance must
// tear down the previous one (see [_claimPipeline]).
// ─────────────────────────────────────────────────────────────────────────────

class AvplayPlayerImpl extends AppPlayer {
  /// Whether the Samsung webapis AVPlay object exists in this runtime.
  static bool get isAvailable {
    try {
      final w = js_util.getProperty(html.window, 'webapis');
      return w != null && js_util.hasProperty(w, 'avplay');
    } catch (_) {
      return false;
    }
  }

  static Object get _avplay =>
      js_util.getProperty(js_util.getProperty(html.window, 'webapis'), 'avplay');

  // The single hardware pipeline's current owner.
  static AvplayPlayerImpl? _owner;

  final _positionCtrl  = StreamController<Duration>.broadcast();
  final _durationCtrl  = StreamController<Duration>.broadcast();
  final _playingCtrl   = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _bufferCtrl    = StreamController<Duration>.broadcast();
  final _errorCtrl     = StreamController<String>.broadcast();

  Timer? _poll;
  bool _dead = false;        // pipeline stolen by a newer instance / disposed
  bool _prepared = false;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _prevBodyBg, _prevHtmlBg;

  // Last display rect pushed to the TV (physical px) — avoids redundant calls.
  int _rx = 0, _ry = 0, _rw = 0, _rh = 0;
  AspectMode _lastMode = AspectMode.contain;

  T? _call<T>(String method, [List<Object?> args = const []]) {
    if (_dead) return null;
    try {
      return js_util.callMethod(_avplay, method, args) as T?;
    } catch (e) {
      debugPrint('avplay.$method failed: $e');
      return null;
    }
  }

  String get _state => _call<String>('getState') ?? 'NONE';

  // ── Pipeline ownership ─────────────────────────────────────────────────────

  void _claimPipeline() {
    final prev = _owner;
    if (prev != null && !identical(prev, this)) {
      // Steal the hardware pipeline: silence the previous instance. Its screen
      // may still be mounted (e.g. the live-preview pane under a pushed player
      // route); it simply stops updating.
      prev._dead = true;
      prev._poll?.cancel();
      try { js_util.callMethod(_avplay, 'stop', const []); } catch (_) {}
      try { js_util.callMethod(_avplay, 'close', const []); } catch (_) {}
    }
    _owner = this;
  }

  // ── State snapshot ─────────────────────────────────────────────────────────

  @override
  AppPlayerState get state => AppPlayerState(
        position: _position,
        duration: _duration,
        playing: _playing,
        buffering: _buffering,
      );

  @override Stream<Duration> get positionStream  => _positionCtrl.stream;
  @override Stream<Duration> get durationStream  => _durationCtrl.stream;
  @override Stream<bool>     get playingStream   => _playingCtrl.stream;
  @override Stream<bool>     get bufferingStream => _bufferingCtrl.stream;
  @override Stream<Duration> get bufferStream    => _bufferCtrl.stream;
  @override Stream<String>   get errorStream     => _errorCtrl.stream;

  // ── Tracks ─────────────────────────────────────────────────────────────────

  @override
  AppTracks get tracks {
    final audio = <AppTrack>[];
    final subs = <AppTrack>[];
    try {
      final info = _call<Object>('getTotalTrackInfo');
      if (info != null) {
        final len = js_util.getProperty(info, 'length') as int? ?? 0;
        for (var i = 0; i < len; i++) {
          final t = js_util.getProperty(info, i);
          final type = js_util.getProperty(t, 'type') as String? ?? '';
          final index = js_util.getProperty(t, 'index');
          String? lang;
          try {
            final extraRaw = js_util.getProperty(t, 'extra_info');
            if (extraRaw is String && extraRaw.isNotEmpty) {
              final m = RegExp('"track_lang"\\s*:\\s*"([^"]*)"')
                  .firstMatch(extraRaw);
              lang = m?.group(1);
              if (lang != null && lang.isEmpty) lang = null;
            }
          } catch (_) {}
          final track = AppTrack(id: '$index', language: lang);
          if (type == 'AUDIO') audio.add(track);
          if (type == 'TEXT') subs.add(track);
        }
      }
    } catch (_) {}
    return AppTracks(audio: audio, subtitle: subs);
  }

  AppTrack _selAudio = AppTrack.auto;
  AppTrack _selSub = AppTrack.none;
  @override AppTrack get selectedVideoTrack    => AppTrack.auto;
  @override AppTrack get selectedAudioTrack    => _selAudio;
  @override AppTrack get selectedSubtitleTrack => _selSub;

  // ── Playback ───────────────────────────────────────────────────────────────

  @override
  Future<void> open(String url) async {
    _claimPipeline();
    _dead = false;
    _prepared = false;
    _buffering = true;
    _bufferingCtrl.add(true);

    // Hole punch: everything above the TV's video plane must be transparent.
    // The Flutter scene already is (transparent scaffolds on Tizen); the page
    // background is made transparent here and restored in dispose().
    _prevBodyBg = html.document.body?.style.background;
    _prevHtmlBg = html.document.documentElement?.style.background;
    html.document.body?.style.background = 'transparent';
    html.document.documentElement?.style.background = 'transparent';

    try { js_util.callMethod(_avplay, 'close', const []); } catch (_) {}
    _call('open', [url]);

    final listener = js_util.newObject();
    void set(String name, Function fn) =>
        js_util.setProperty(listener, name, js_util.allowInterop(fn));
    set('onbufferingstart', () {
      _buffering = true;
      _bufferingCtrl.add(true);
    });
    set('onbufferingprogress', (Object? percent) {});
    set('onbufferingcomplete', () {
      _buffering = false;
      _bufferingCtrl.add(false);
    });
    set('oncurrentplaytime', (Object? ms) {
      final v = (ms is num) ? ms.toInt() : 0;
      _position = Duration(milliseconds: v);
      _positionCtrl.add(_position);
    });
    set('onstreamcompleted', () {
      // Snap position to the end so the screens' near-end detection
      // (pos >= dur - 5s → mark watched / auto-advance) always fires.
      if (_duration > Duration.zero) {
        _position = _duration;
        _positionCtrl.add(_position);
      }
      _playing = false;
      _playingCtrl.add(false);
    });
    set('onerror', (Object? type) {
      debugPrint('avplay error: $type');
      _buffering = false;
      _bufferingCtrl.add(false);
      if (!_dead) _errorCtrl.add('Player error: $type');
    });
    set('onevent', (Object? type, Object? data) {});
    set('onsubtitlechange', (Object? a, Object? b, Object? c, Object? d) {});
    set('ondrmevent', (Object? a, Object? b) {});
    _call('setListener', [listener]);

    // Default the video plane to the full screen until the widget reports its
    // real rect (physical pixels; on TVs CSS px == physical at 1920×1080).
    final sw = html.window.screen?.width ?? 1920;
    final sh = html.window.screen?.height ?? 1080;
    _rw = 0; _rh = 0; // force the next _setRect through
    _setRect(0, 0, sw, sh);

    final done = Completer<void>();
    _call('prepareAsync', [
      js_util.allowInterop(() {
        _prepared = true;
        final ms = _call<num>('getDuration') ?? 0;
        _duration = Duration(milliseconds: ms.toInt());
        _durationCtrl.add(_duration);
        _applyDisplayMethod(_lastMode);
        _call('play');
        _playing = true;
        _playingCtrl.add(true);
        _buffering = false;
        _bufferingCtrl.add(false);
        if (!done.isCompleted) done.complete();
      }),
      js_util.allowInterop((Object? err) {
        debugPrint('avplay prepare failed: $err');
        _buffering = false;
        _bufferingCtrl.add(false);
        if (!_dead) _errorCtrl.add('The stream could not be opened ($err)');
        if (!done.isCompleted) done.complete();
      }),
    ]);

    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_dead) return;
      final ms = _call<num>('getCurrentTime');
      if (ms != null && ms > 0) {
        _position = Duration(milliseconds: ms.toInt());
        _positionCtrl.add(_position);
      }
      if (_duration == Duration.zero) {
        final d = _call<num>('getDuration');
        if (d != null && d > 0) {
          _duration = Duration(milliseconds: d.toInt());
          _durationCtrl.add(_duration);
        }
      }
      final playing = _state == 'PLAYING';
      if (playing != _playing) {
        _playing = playing;
        _playingCtrl.add(playing);
      }
    });

    await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
  }

  @override
  Future<void> play() async {
    if (!_prepared) return;
    _call('play');
    _playing = true;
    _playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    if (!_prepared) return;
    _call('pause');
    _playing = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> playOrPause() async => _playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async {
    if (!_prepared) return;
    _call('seekTo', [position.inMilliseconds]);
    _position = position;
    _positionCtrl.add(position);
  }

  @override
  Future<void> setVideoTrack(AppTrack track) async {}

  @override
  Future<void> setAudioTrack(AppTrack track) async {
    final idx = int.tryParse(track.id);
    if (idx == null) return;
    _call('setSelectTrack', ['AUDIO', idx]);
    _selAudio = track;
  }

  @override
  Future<void> setSubtitleTrack(AppTrack track) async {
    final idx = int.tryParse(track.id);
    if (idx == null) return;
    _call('setSelectTrack', ['TEXT', idx]);
    _selSub = track;
  }

  @override
  Future<void> dispose() async {
    _poll?.cancel();
    if (identical(_owner, this)) {
      try { js_util.callMethod(_avplay, 'stop', const []); } catch (_) {}
      try { js_util.callMethod(_avplay, 'close', const []); } catch (_) {}
      _owner = null;
      // Restore the page background hidden behind the app chrome.
      if (_prevBodyBg != null) {
        html.document.body?.style.background = _prevBodyBg!;
      }
      if (_prevHtmlBg != null) {
        html.document.documentElement?.style.background = _prevHtmlBg!;
      }
    }
    _dead = true;
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    await _bufferingCtrl.close();
    await _bufferCtrl.close();
    await _errorCtrl.close();
  }

  // ── Video plane geometry ───────────────────────────────────────────────────

  void _setRect(int x, int y, int w, int h) {
    if (_dead || w <= 0 || h <= 0) return;
    if (x == _rx && y == _ry && w == _rw && h == _rh) return;
    _rx = x; _ry = y; _rw = w; _rh = h;
    _call('setDisplayRect', [x, y, w, h]);
  }

  void _applyDisplayMethod(AspectMode mode) {
    _lastMode = mode;
    // AVPlay knows LETTER_BOX (fit, bars) and FULL_SCREEN (stretch to rect).
    // contain/cover map to letterbox/stretch of the full-screen rect; the two
    // fixed-ratio modes shape the RECT via the widget layout and stretch into
    // it, matching the native player's behaviour.
    final method = switch (mode) {
      AspectMode.contain => 'PLAYER_DISPLAY_MODE_LETTER_BOX',
      _ => 'PLAYER_DISPLAY_MODE_FULL_SCREEN',
    };
    _call('setDisplayMethod', [method]);
  }

  @override
  Widget buildVideoWidget(BuildContext context, AspectMode mode) {
    if (mode != _lastMode && _prepared) _applyDisplayMethod(mode);
    final inner = _AvplayViewport(player: this);
    return switch (mode) {
      AspectMode.ratio16x9 =>
        Center(child: AspectRatio(aspectRatio: 16 / 9, child: inner)),
      AspectMode.ratio4x3 =>
        Center(child: AspectRatio(aspectRatio: 4 / 3, child: inner)),
      _ => SizedBox.expand(child: inner),
    };
  }
}

/// Transparent placeholder that tells AVPlay where the video plane should be:
/// it measures its own on-screen rect after every layout and pushes it to
/// [AvplayPlayerImpl._setRect] in physical pixels.
class _AvplayViewport extends StatefulWidget {
  const _AvplayViewport({required this.player});
  final AvplayPlayerImpl player;

  @override
  State<_AvplayViewport> createState() => _AvplayViewportState();
}

class _AvplayViewportState extends State<_AvplayViewport> {
  void _report(BuildContext ctx) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final dpr = MediaQuery.of(ctx).devicePixelRatio;
      final origin = box.localToGlobal(Offset.zero);
      widget.player._setRect(
        (origin.dx * dpr).round(),
        (origin.dy * dpr).round(),
        (box.size.width * dpr).round(),
        (box.size.height * dpr).round(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, _) {
      _report(ctx);
      // Fully transparent: the TV's video plane shows through this hole.
      return const ColoredBox(color: Color(0x00000000));
    });
  }
}

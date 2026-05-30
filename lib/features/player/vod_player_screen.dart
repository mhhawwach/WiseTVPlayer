import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/vod_stream.dart';
import '../../services/now_playing_service.dart';
import '../../services/pip_service.dart';
import '../../services/player/player_factory.dart';
import 'widgets/aspect_mode.dart';
import 'widgets/player_control_button.dart';
import 'widgets/stats_overlay.dart';
import 'widgets/track_picker_sheet.dart';

class VodPlayerArgs {
  final VodStream vod;
  final Playlist playlist;
  final Duration startPosition;

  /// When set, used directly instead of building a URL from playlist + stream.
  /// Used by Catch-Up TV timeshift playback.
  final String? overrideUrl;

  /// History key prefix: 'vod' for movies, 'series' for episodes.
  final String historyType;

  /// Called once when the video naturally finishes (position ≥ duration − 5 s).
  /// Ignored for live / catchup. Series player uses this for auto-play countdown.
  final VoidCallback? onComplete;

  const VodPlayerArgs({
    required this.vod,
    required this.playlist,
    this.startPosition = Duration.zero,
    this.overrideUrl,
    this.historyType = 'vod',
    this.onComplete,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class VodPlayerScreen extends StatefulWidget {
  const VodPlayerScreen({super.key, required this.args});
  final VodPlayerArgs args;

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen>
    with WidgetsBindingObserver {
  late final AppPlayer _player;
  bool _controlsVisible = true;
  bool _statsVisible = false;
  String _streamUrl = '';
  Timer? _hideTimer;
  AspectMode _aspectMode = AspectMode.contain;

  // ── D-pad focus ─────────────────────────────────────────────────────────
  // The root node holds focus while the controls are hidden, so the first key
  // press wakes them. When shown, focus moves into [_controlsScope] so the
  // remote can navigate the on-screen buttons (including Stats-for-Nerds).
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'vod-player-root');
  final FocusScopeNode _controlsScope =
      FocusScopeNode(debugLabel: 'vod-player-controls');
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'vod-player-play');

  // ── PiP ──────────────────────────────────────────────────────────────────
  bool _pipSupported = false;
  bool _inPipMode = false;
  StreamSubscription<bool>? _pipSub;

  // ── Completion detection ──────────────────────────────────────────────────
  StreamSubscription<Duration>? _completionSub;
  bool _completionFired = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();

    // Every focus move within the controls keeps them awake.
    _controlsScope.addListener(() {
      if (_controlsScope.hasFocus) _scheduleHideControls();
    });

    _player = PlayerFactory.create();
    // Series episodes live under /series/, movies under /movie/. Using the
    // wrong path makes the server unable to serve the stream (buffers forever).
    final url = widget.args.overrideUrl ??
        (widget.args.historyType == 'series'
            ? widget.args.playlist.seriesStreamUrl(
                widget.args.vod.streamId.toString(),
                widget.args.vod.containerExtension,
              )
            : widget.args.playlist.vodStreamUrl(
                widget.args.vod.streamId.toString(),
                widget.args.vod.containerExtension,
              ));
    _streamUrl = url;
    _player.open(url);

    StorageService.saveHistory({
      'type': widget.args.historyType,
      'id': widget.args.vod.streamId,
      'name': widget.args.vod.name,
      'icon': widget.args.vod.streamIcon,
      'ext': widget.args.vod.containerExtension,
    });
    NowPlayingService.instance.update(
      title: widget.args.vod.name,
      subtitle: widget.args.playlist.name,
      artwork: widget.args.vod.streamIcon,
    );

    if (widget.args.startPosition > Duration.zero) {
      _player.durationStream.firstWhere((d) => d > Duration.zero).then((_) {
        _player.seek(widget.args.startPosition);
      });
    }
    _scheduleHideControls();
    // Controls start visible — land the D-pad on the play/pause button so the
    // remote can immediately navigate to Stats, tracks, aspect, etc.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controlsVisible && !_inPipMode) {
        _playFocusNode.requestFocus();
      }
    });

    // ── Near-end detection → fire onComplete ─────────────────────────────
    if (widget.args.onComplete != null) {
      _completionSub = _player.positionStream.listen((pos) {
        if (_completionFired) return;
        final dur = _player.state.duration;
        if (dur.inSeconds > 30 &&
            pos.inSeconds > 0 &&
            pos.inSeconds >= dur.inSeconds - 5) {
          _completionFired = true;
          _completionSub?.cancel();
          _completionSub = null;
          // Mark series episode as watched
          if (widget.args.historyType == 'series') {
            StorageService.markEpisodeWatched(widget.args.vod.streamId);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.args.onComplete!();
          });
        }
      });
    }

    PipService.instance.isSupported.then((v) {
      if (mounted) setState(() => _pipSupported = v);
    });
    _pipSub = PipService.instance.changes.listen((inPip) {
      if (!mounted) return;
      setState(() => _inPipMode = inPip);
      if (!inPip) _enterImmersive();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_inPipMode) {
      _enterImmersive();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pipSub?.cancel();
    _completionSub?.cancel();
    _rootFocusNode.dispose();
    _controlsScope.dispose();
    _playFocusNode.dispose();
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (pos > 5) {
      StorageService.updatePosition(
        widget.args.historyType,
        widget.args.vod.streamId,
        pos,
        durationSeconds: dur > 0 ? dur : null,
      );
    }
    _player.dispose();
    WakelockPlus.disable();
    NowPlayingService.instance.clear();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _enterImmersive() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
      // Hand focus back to the root so the next key press re-shows the controls
      // instead of silently operating a now-invisible (excluded) button.
      _rootFocusNode.requestFocus();
    });
  }

  void _showControls() {
    final wasHidden = !_controlsVisible;
    if (wasHidden) setState(() => _controlsVisible = true);
    _scheduleHideControls();
    // Only pull focus into the controls on the hidden→visible transition, so
    // ongoing navigation/taps don't yank the selection back to play/pause.
    if (wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controlsVisible && !_inPipMode) {
          _playFocusNode.requestFocus();
        }
      });
    }
  }

  void _showTrackPicker() {
    showTrackPicker(context, _player).then((_) => _enterImmersive());
  }

  void _enterPip() => PipService.instance.enter();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _rootFocusNode,
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          // Back / Escape: close the stats overlay first, otherwise exit.
          if (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (_statsVisible) {
              setState(() => _statsVisible = false);
              return KeyEventResult.handled;
            }
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }

          // Controls hidden: the first key press just wakes them (and moves
          // focus into them). Don't let it leak through to anything else.
          if (!_controlsVisible) {
            _showControls();
            return KeyEventResult.handled;
          }
          // Controls visible: keep them awake and let the focused button /
          // directional traversal handle the key.
          _scheduleHideControls();
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: _showControls,
          child: Stack(
            children: [
              // ── Video ─────────────────────────────────────────────────────
              Positioned.fill(
                child: _player.buildVideoWidget(context, _aspectMode),
              ),
              // ── Controls ──────────────────────────────────────────────────
              AnimatedOpacity(
                opacity: (_controlsVisible && !_inPipMode) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: FocusScope(
                  node: _controlsScope,
                  child: ExcludeFocus(
                    excluding: !_controlsVisible || _inPipMode,
                    child: _VodControls(
                      title: widget.args.vod.name,
                      player: _player,
                      aspectMode: _aspectMode,
                      showPip: _pipSupported,
                      statsActive: _statsVisible,
                      playFocusNode: _playFocusNode,
                      onCycleAspect: () =>
                          setState(() => _aspectMode = _aspectMode.next),
                      onTrackPicker: _showTrackPicker,
                      onPip: _pipSupported ? _enterPip : null,
                      onClose: () => Navigator.of(context).pop(),
                      onStats: () =>
                          setState(() => _statsVisible = !_statsVisible),
                    ),
                  ),
                ),
              ),
              // ── Stats overlay (independent of controls) ───────────────────
              if (_statsVisible && !_inPipMode)
                Positioned(
                  top: 60,
                  right: 8,
                  child: SafeArea(
                    child: StatsOverlay(
                      player: _player,
                      streamUrl: _streamUrl,
                      onClose: () =>
                          setState(() => _statsVisible = false),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VodControls extends StatelessWidget {
  const _VodControls({
    required this.title,
    required this.player,
    required this.aspectMode,
    required this.showPip,
    required this.statsActive,
    required this.playFocusNode,
    required this.onCycleAspect,
    required this.onTrackPicker,
    required this.onClose,
    required this.onStats,
    this.onPip,
  });

  final String title;
  final AppPlayer player;
  final AspectMode aspectMode;
  final bool showPip;
  final bool statsActive;
  final FocusNode playFocusNode;
  final VoidCallback onCycleAspect;
  final VoidCallback onTrackPicker;
  final VoidCallback onClose;
  final VoidCallback onStats;
  final VoidCallback? onPip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xEE000000),
          ],
          stops: [0, 0.25, 0.65, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  PlayerControlButton(
                    icon: Icons.arrow_back,
                    iconColor: Colors.white,
                    tooltip: 'Back',
                    onPressed: onClose,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AspectModeButton(mode: aspectMode, onCycle: onCycleAspect),
                  const SizedBox(width: 4),
                  PlayerControlButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Audio & Subtitles',
                    onPressed: onTrackPicker,
                  ),
                  PlayerControlButton(
                    icon: Icons.analytics_outlined,
                    active: statsActive,
                    tooltip: 'Stats for Nerds',
                    onPressed: onStats,
                  ),
                  if (showPip)
                    PlayerControlButton(
                      icon: Icons.picture_in_picture_alt_rounded,
                      tooltip: 'Picture in Picture',
                      onPressed: onPip,
                    ),
                ],
              ),
            ),
            const Spacer(),
            // ── Bottom seek + playback controls ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  _SeekBar(player: player),
                  const SizedBox(height: 8),
                  _PlaybackRow(player: player, playFocusNode: playFocusNode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.player});
  final AppPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (_, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.durationStream,
          builder: (_, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            final progress = dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0;
            return Column(
              children: [
                // The Slider binds ALL four arrow keys to value-adjustment, so
                // if D-pad focus ever lands on it the remote gets trapped and
                // can't reach the top-bar controls (Stats, tracks, …). Keep it
                // out of focus traversal — it still shows progress and remains
                // touch-draggable; on a remote, seeking uses the ±10s buttons.
                ExcludeFocus(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: dur.inMilliseconds > 0
                          ? (v) => player.seek(Duration(
                                milliseconds: (v * dur.inMilliseconds).round(),
                              ))
                          : null,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(pos),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Text(_fmt(dur),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PlaybackRow extends StatelessWidget {
  const _PlaybackRow({required this.player, required this.playFocusNode});
  final AppPlayer player;
  final FocusNode playFocusNode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PlayerControlButton(
          icon: Icons.replay_10,
          iconColor: Colors.white,
          iconSize: 28,
          tooltip: 'Rewind 10s',
          onPressed: () async {
            final pos    = player.state.position;
            final target = pos - const Duration(seconds: 10);
            await player.seek(target < Duration.zero ? Duration.zero : target);
          },
        ),
        const SizedBox(width: 16),
        StreamBuilder<bool>(
          stream: player.playingStream,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return PlayerControlButton(
              focusNode: playFocusNode,
              icon: playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              iconColor: Colors.white,
              iconSize: 48,
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: () => player.playOrPause(),
            );
          },
        ),
        const SizedBox(width: 16),
        PlayerControlButton(
          icon: Icons.forward_10,
          iconColor: Colors.white,
          iconSize: 28,
          tooltip: 'Forward 10s',
          onPressed: () async {
            final pos    = player.state.position;
            final dur    = player.state.duration;
            final target = pos + const Duration(seconds: 10);
            await player.seek(target > dur ? dur : target);
          },
        ),
      ],
    );
  }
}

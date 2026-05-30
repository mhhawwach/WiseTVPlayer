import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/live_stream.dart';
import '../../data/models/playlist.dart';
import '../../services/now_playing_service.dart';
import '../../services/pip_service.dart';
import '../../services/player/player_factory.dart';
import '../epg/epg_panel.dart';
import 'widgets/aspect_mode.dart';
import 'widgets/player_control_button.dart';
import 'widgets/resolution_badge.dart';
import 'widgets/stats_overlay.dart';
import 'widgets/track_picker_sheet.dart';

class LivePlayerArgs {
  final LiveStream stream;
  final Playlist playlist;
  final List<LiveStream> channelList;
  final int initialIndex;

  const LivePlayerArgs({
    required this.stream,
    required this.playlist,
    required this.channelList,
    required this.initialIndex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({super.key, required this.args});
  final LivePlayerArgs args;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen>
    with WidgetsBindingObserver {
  late final AppPlayer _player;
  late int _currentIndex;
  bool _controlsVisible = true;
  bool _statsVisible = false;
  String _currentStreamUrl = '';
  Timer? _hideTimer;
  AspectMode _aspectMode = AspectMode.contain;

  // ── D-pad focus ─────────────────────────────────────────────────────────
  // Up/Down always surf channels; the root node holds focus while controls are
  // hidden so any other key wakes them, then focus moves into [_controlsScope]
  // so Left/Right/OK drive the on-screen buttons (incl. Stats-for-Nerds).
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'live-player-root');
  final FocusScopeNode _controlsScope =
      FocusScopeNode(debugLabel: 'live-player-controls');
  final FocusNode _defaultControlFocus =
      FocusNode(debugLabel: 'live-player-default');

  // ── PiP ──────────────────────────────────────────────────────────────────
  bool _pipSupported = false;
  bool _inPipMode = false;
  StreamSubscription<bool>? _pipSub;

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

    _currentIndex = widget.args.initialIndex;
    // 8 MB buffer — optimised for fast channel switching on live TV
    _player = PlayerFactory.create(bufferSize: 8 * 1024 * 1024);
    _play(_currentIndex);
    _scheduleHideControls();
    // Controls start visible — land the D-pad on a neutral control so the
    // remote can immediately reach Stats / tracks / aspect.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controlsVisible && !_inPipMode) {
        _defaultControlFocus.requestFocus();
      }
    });

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
    _rootFocusNode.dispose();
    _controlsScope.dispose();
    _defaultControlFocus.dispose();
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

  void _play(int index) {
    final ch  = widget.args.channelList[index];
    final url = widget.args.playlist.liveStreamUrl(ch.streamId.toString(), 'ts');
    _currentStreamUrl = url;
    _player.open(url);
    StorageService.saveHistory({
      'type': 'live',
      'id': ch.streamId,
      'name': ch.name,
      'icon': ch.streamIcon,
    });
    NowPlayingService.instance.update(
      title: ch.name,
      subtitle: widget.args.playlist.name,
      artwork: ch.streamIcon,
    );
  }

  void _nextChannel() {
    if (_currentIndex < widget.args.channelList.length - 1) {
      setState(() => _currentIndex++);
      _play(_currentIndex);
    }
  }

  void _prevChannel() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _play(_currentIndex);
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
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
    // channel surfing (Up/Down) doesn't keep yanking the selection.
    if (wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controlsVisible && !_inPipMode) {
          _defaultControlFocus.requestFocus();
        }
      });
    }
  }

  void _showEpg() {
    final ch = widget.args.channelList[_currentIndex];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EpgPanel(stream: ch),
    ).then((_) => _enterImmersive());
  }

  void _showTrackPicker() {
    showTrackPicker(context, _player).then((_) => _enterImmersive());
  }

  void _enterPip() => PipService.instance.enter();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ch = widget.args.channelList[_currentIndex];

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

          // Up/Down always surf channels (and surface the controls briefly),
          // regardless of where focus currently sits.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _prevChannel();
            _showControls();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _nextChannel();
            _showControls();
            return KeyEventResult.handled;
          }

          // Controls hidden: the first Left/Right/OK just wakes them (and moves
          // focus into them).
          if (!_controlsVisible) {
            _showControls();
            return KeyEventResult.handled;
          }
          // Controls visible: keep them awake and let the focused button /
          // directional traversal handle Left/Right/OK.
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
              // ── Controls (hidden in PiP) ──────────────────────────────────
              AnimatedOpacity(
                opacity: (_controlsVisible && !_inPipMode) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: FocusScope(
                  node: _controlsScope,
                  child: ExcludeFocus(
                    excluding: !_controlsVisible || _inPipMode,
                    child: _LiveControls(
                      channel: ch,
                      aspectMode: _aspectMode,
                      showPip: _pipSupported,
                      statsActive: _statsVisible,
                      defaultFocusNode: _defaultControlFocus,
                      onCycleAspect: () =>
                          setState(() => _aspectMode = _aspectMode.next),
                      onTrackPicker: _showTrackPicker,
                      onEpg: AppConstants.epgEnabled ? _showEpg : null,
                      onPip: _pipSupported ? _enterPip : null,
                      onClose: () => Navigator.of(context).pop(),
                      onPrev: _currentIndex > 0 ? _prevChannel : null,
                      onNext: _currentIndex < widget.args.channelList.length - 1
                          ? _nextChannel
                          : null,
                      onStats: () =>
                          setState(() => _statsVisible = !_statsVisible),
                    ),
                  ),
                ),
              ),
              // ── Resolution badge — bottom-right corner, always visible ─────
              // Hidden in PiP and while the full stats overlay is open.
              if (!_inPipMode && !_statsVisible)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: SafeArea(
                    child: ResolutionBadge(player: _player),
                  ),
                ),
              // ── Stats overlay (independent of controls visibility) ─────────
              if (_statsVisible && !_inPipMode)
                Positioned(
                  top: 60,
                  right: 8,
                  child: SafeArea(
                    child: StatsOverlay(
                      player: _player,
                      streamUrl: _currentStreamUrl,
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

class _LiveControls extends StatelessWidget {
  const _LiveControls({
    required this.channel,
    required this.aspectMode,
    required this.showPip,
    required this.statsActive,
    required this.defaultFocusNode,
    required this.onCycleAspect,
    required this.onTrackPicker,
    required this.onEpg,
    required this.onClose,
    required this.onStats,
    this.onPip,
    this.onPrev,
    this.onNext,
  });

  final LiveStream channel;
  final AspectMode aspectMode;
  final bool showPip;
  final bool statsActive;
  final FocusNode defaultFocusNode;
  final VoidCallback onCycleAspect;
  final VoidCallback onTrackPicker;
  final VoidCallback? onEpg;
  final VoidCallback onClose;
  final VoidCallback onStats;
  final VoidCallback? onPip;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

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
            Color(0xCC000000),
          ],
          stops: [0, 0.3, 0.7, 1],
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
                      channel.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // LIVE badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.liveRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  AspectModeButton(mode: aspectMode, onCycle: onCycleAspect),
                  const SizedBox(width: 4),
                  PlayerControlButton(
                    focusNode: defaultFocusNode,
                    icon: Icons.tune_rounded,
                    tooltip: 'Audio & Subtitles',
                    onPressed: onTrackPicker,
                  ),
                  if (onEpg != null)
                    PlayerControlButton(
                      icon: Icons.info_outline,
                      tooltip: 'Programme Guide',
                      onPressed: onEpg,
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
            // ── Bottom channel controls ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CtrlBtn(
                    icon: Icons.skip_previous_rounded,
                    label: 'Prev',
                    onTap: onPrev,
                  ),
                  const SizedBox(width: 40),
                  _CtrlBtn(
                    icon: Icons.skip_next_rounded,
                    label: 'Next',
                    onTap: onNext,
                  ),
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

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(38),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

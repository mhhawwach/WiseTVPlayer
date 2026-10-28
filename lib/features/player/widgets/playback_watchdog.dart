import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/focusable_card.dart';
import '../../../services/player/app_player.dart';

/// Watches an [AppPlayer] for a stream that never starts, stops advancing, or
/// fails with an engine error — so the player screens can say so instead of
/// sitting on a black screen at 00:00 forever.
class PlaybackWatchdog {
  PlaybackWatchdog({
    required this.player,
    required this.onFailure,
    this.onStall,
    this.openTimeout = const Duration(seconds: 30),
    this.stallTimeout = const Duration(seconds: 15),
    this.errorGrace = const Duration(seconds: 4),
    @visibleForTesting DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _subs
      ..add(player.positionStream.listen(_onPosition))
      ..add(player.errorStream.listen(_onError))
      ..add(player.playingStream.listen((playing) {
        if (playing) _lastProgress = _now();
      }));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    restart();
  }

  final AppPlayer player;

  /// Playback can't continue. [reason] is short and safe to show on screen.
  final ValueChanged<String> onFailure;

  /// Playback started but froze. Return true when the caller is recovering
  /// (e.g. re-opening a live stream): the watchdog then waits for the stream
  /// to start again. Returning false (or no callback) reports a failure.
  final bool Function()? onStall;

  final Duration openTimeout;
  final Duration stallTimeout;

  /// Engines also report recoverable hiccups as errors; one only counts once
  /// playback has made no progress for this long after it.
  final Duration errorGrace;

  final DateTime Function() _now;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _timer;
  late DateTime _openedAt;
  late DateTime _lastProgress;
  Duration _lastPos = Duration.zero;
  bool _started = false;
  bool _failed = false;
  String? _lastError;
  DateTime? _errorAt;

  /// Call after (re)opening a stream.
  void restart() {
    _openedAt = _now();
    _lastProgress = _openedAt;
    _lastPos = Duration.zero;
    _started = false;
    _failed = false;
    _lastError = null;
    _errorAt = null;
  }

  void _onPosition(Duration pos) {
    if (pos == _lastPos) return;
    _lastPos = pos;
    if (pos <= Duration.zero) return;
    _started = true;
    _lastProgress = _now();
    _errorAt = null;
  }

  void _onError(String message) {
    _lastError = message;
    _errorAt ??= _now();
  }

  void _tick() {
    if (_failed) return;
    final now = _now();
    final error = _errorAt;
    if (error != null &&
        now.difference(error) >= errorGrace &&
        now.difference(_lastProgress) >= errorGrace) {
      _fail(_lastError);
      return;
    }
    if (!_started) {
      if (now.difference(_openedAt) >= openTimeout) {
        _fail(_lastError ??
            "The stream didn't start. It may be offline, or the server "
                "isn't reachable right now.");
      }
      return;
    }
    // Paused by the user is not a stall.
    if (!player.state.playing) {
      _lastProgress = now;
      return;
    }
    if (now.difference(_lastProgress) >= stallTimeout) {
      if (onStall?.call() ?? false) {
        restart();
        return;
      }
      _fail('Playback stopped and could not recover.');
    }
  }

  void _fail(String? reason) {
    _failed = true;
    onFailure(playbackErrorText(reason));
  }

  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
  }
}

/// A short, display-safe version of an engine error. Engine messages often
/// quote the stream URL, which embeds the account's username and password.
String playbackErrorText(String? raw) {
  var text = (raw ?? '').replaceAll(RegExp(r'\w+://\S+'), '').trim();
  if (text.isEmpty) text = 'Playback error.';
  return text.length > 160 ? '${text.substring(0, 157)}…' : text;
}

/// "Couldn't play" card over the player, with Retry (focused) and Back.
class PlaybackErrorOverlay extends StatefulWidget {
  const PlaybackErrorOverlay({
    super.key,
    required this.title,
    required this.reason,
    required this.onRetry,
    required this.onBack,
  });

  final String title;
  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  State<PlaybackErrorOverlay> createState() => _PlaybackErrorOverlayState();
}

class _PlaybackErrorOverlayState extends State<PlaybackErrorOverlay> {
  // The player screen already holds focus when this appears, so autofocus
  // would be ignored; claim it explicitly.
  final FocusNode _retryFocus = FocusNode(debugLabel: 'playback-retry');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _retryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.liveRed, size: 40),
              const SizedBox(height: 12),
              Text(
                "Couldn't play ${widget.title}",
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _OverlayButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    primary: true,
                    focusNode: _retryFocus,
                    onPressed: widget.onRetry,
                  ),
                  const SizedBox(width: 14),
                  _OverlayButton(
                    label: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: widget.onBack,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.focusNode,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      focusNode: focusNode,
      borderRadius: 12,
      focusScale: 1.05,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

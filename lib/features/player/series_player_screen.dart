import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';
import '../../data/models/series_stream.dart';
import '../../data/models/vod_stream.dart';
import 'vod_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Args
// ─────────────────────────────────────────────────────────────────────────────

class SeriesPlayerArgs {
  final SeriesEpisode episode;
  final Playlist playlist;
  final String seriesTitle;
  final Duration startPosition;

  /// All episodes in the current season (used for auto-play next episode).
  final List<SeriesEpisode> allEpisodes;

  /// Index of [episode] within [allEpisodes].
  final int currentIndex;

  const SeriesPlayerArgs({
    required this.episode,
    required this.playlist,
    required this.seriesTitle,
    this.startPosition = Duration.zero,
    this.allEpisodes = const [],
    this.currentIndex = 0,
  });

  bool get hasNext => currentIndex < allEpisodes.length - 1;
  SeriesEpisode? get nextEpisode =>
      hasNext ? allEpisodes[currentIndex + 1] : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SeriesPlayerScreen extends StatefulWidget {
  const SeriesPlayerScreen({super.key, required this.args});
  final SeriesPlayerArgs args;

  @override
  State<SeriesPlayerScreen> createState() => _SeriesPlayerScreenState();
}

class _SeriesPlayerScreenState extends State<SeriesPlayerScreen> {
  late SeriesPlayerArgs _current;

  // Force a new VodPlayerScreen instance when we advance to the next episode.
  Key _playerKey = UniqueKey();

  // Countdown state
  bool _showCountdown = false;
  int _countdown = 10;
  Timer? _countdownTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _current = widget.args;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Countdown logic ───────────────────────────────────────────────────────

  void _onEpisodeComplete() {
    if (!mounted || !_current.hasNext) return;
    setState(() {
      _showCountdown = true;
      _countdown = 10;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        _advanceToNext();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _advanceToNext() {
    _countdownTimer?.cancel();
    final next = _current.nextEpisode!;
    // Resume any partial progress on the next episode
    final epData = StorageService.getEpisodeData(next.id);
    final watched = (epData?['watched'] as bool?) ?? false;
    final savedPos = (epData?['position'] as int?) ?? 0;
    final startPosition = (!watched && savedPos > 30)
        ? Duration(seconds: savedPos)
        : Duration.zero;

    setState(() {
      _current = SeriesPlayerArgs(
        episode: next,
        playlist: _current.playlist,
        seriesTitle: _current.seriesTitle,
        allEpisodes: _current.allEpisodes,
        currentIndex: _current.currentIndex + 1,
        startPosition: startPosition,
      );
      _playerKey = UniqueKey();
      _showCountdown = false;
      _countdown = 10;
    });
  }

  void _dismissCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _showCountdown = false;
      _countdown = 10;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  VodPlayerArgs _buildArgs() {
    final ep = _current.episode;
    final vod = VodStream(
      num: ep.episodeNum,
      name: ep.title.isNotEmpty
          ? 'S${ep.season}E${ep.episodeNum} — ${ep.title}'
          : 'S${ep.season}E${ep.episodeNum}',
      streamId: ep.id,
      streamIcon: '',
      rating: '',
      ratingFiveItem: '',
      added: ep.added,
      categoryId: '',
      containerExtension: ep.containerExtension,
      customSid: ep.customSid,
      directSource: ep.directSource,
    );
    return VodPlayerArgs(
      vod: vod,
      playlist: _current.playlist,
      startPosition: _current.startPosition,
      historyType: 'series',
      onComplete: _current.hasNext ? _onEpisodeComplete : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        VodPlayerScreen(key: _playerKey, args: _buildArgs()),
        if (_showCountdown && _current.nextEpisode != null)
          _NextEpisodeOverlay(
            nextEpisode: _current.nextEpisode!,
            countdown: _countdown,
            onPlayNow: _advanceToNext,
            onDismiss: _dismissCountdown,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Up Next" overlay card — bottom-right corner
// ─────────────────────────────────────────────────────────────────────────────

class _NextEpisodeOverlay extends StatelessWidget {
  const _NextEpisodeOverlay({
    required this.nextEpisode,
    required this.countdown,
    required this.onPlayNow,
    required this.onDismiss,
  });

  final SeriesEpisode nextEpisode;
  final int countdown;
  final VoidCallback onPlayNow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final title = nextEpisode.title.isNotEmpty
        ? nextEpisode.title
        : 'Episode ${nextEpisode.episodeNum}';
    final epLabel =
        'S${nextEpisode.season}E${nextEpisode.episodeNum}';

    return Positioned(
      right: 24,
      bottom: 90,
      width: 300,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xEE0D0D1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.skip_next_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Next Episode',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Episode number
              Text(
                epLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),

              // Title
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Countdown bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: countdown / 10,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Playing in $countdown s…',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPlayNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Play Now'),
                    ),
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

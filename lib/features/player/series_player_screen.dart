import 'package:flutter/material.dart';

import '../../core/storage/storage_service.dart';
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

  /// All episodes the player can advance through, in order — the FULL series
  /// across every season, flattened (NOT just the current season). This lets the
  /// player roll straight into the next season's first episode.
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

  bool get hasNext =>
      currentIndex >= 0 && currentIndex < allEpisodes.length - 1;

  SeriesEpisode? get nextEpisode =>
      hasNext ? allEpisodes[currentIndex + 1] : null;

  /// True when the next episode begins a new season (drives the "Next Season"
  /// pill label instead of "Next Episode").
  bool get isNextNewSeason {
    final n = nextEpisode;
    return n != null && n.season != episode.season;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen — thin wrapper over the VOD player that feeds it the next-episode info
// (the "Up Next" pill + auto-advance both live in VodPlayerScreen now).
// ─────────────────────────────────────────────────────────────────────────────

class SeriesPlayerScreen extends StatefulWidget {
  const SeriesPlayerScreen({super.key, required this.args});
  final SeriesPlayerArgs args;

  @override
  State<SeriesPlayerScreen> createState() => _SeriesPlayerScreenState();
}

class _SeriesPlayerScreenState extends State<SeriesPlayerScreen> {
  late SeriesPlayerArgs _current;

  // Force a fresh VodPlayerScreen instance when we advance to the next episode.
  Key _playerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _current = widget.args;
  }

  void _advanceToNext() {
    if (!_current.hasNext) return;
    final next = _current.nextEpisode!;
    // Resume any partial progress on the next episode.
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
    });
  }

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
    final hasNext = _current.hasNext;
    return VodPlayerArgs(
      vod: vod,
      playlist: _current.playlist,
      startPosition: _current.startPosition,
      historyType: 'series',
      // Auto-advance at the end, and show the "Up Next" pill in the final 3
      // minutes (OK / tap to jump early). No next → neither fires.
      onComplete: hasNext ? _advanceToNext : null,
      nextLabel: hasNext
          ? (_current.isNextNewSeason ? 'Next Season' : 'Next Episode')
          : null,
      onNext: hasNext ? _advanceToNext : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VodPlayerScreen(key: _playerKey, args: _buildArgs());
  }
}

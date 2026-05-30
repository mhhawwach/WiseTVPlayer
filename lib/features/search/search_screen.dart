import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/live_stream.dart';
import '../../data/models/vod_stream.dart';
import '../../data/models/series_stream.dart';
import '../../features/player/live_player_screen.dart';
import '../../services/xtream_service.dart';

// ── Result model ─────────────────────────────────────────────────────────────

enum _ResultType { live, vod, series }

class _SearchResult {
  final _ResultType type;
  final int id;
  final String name;
  final String icon;
  final String ext;
  const _SearchResult(
      {required this.type,
      required this.id,
      required this.name,
      required this.icon,
      this.ext = 'mp4'});
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Lazy-loaded full content lists for searching — fetched once per session.
final _allLiveProvider = FutureProvider<List<LiveStream>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final p = StorageService.getPlaylist(id);
  if (p == null) return [];
  return ref.read(xtreamServiceProvider).getLiveStreams(p);
});

final _allVodProvider = FutureProvider<List<VodStream>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final p = StorageService.getPlaylist(id);
  if (p == null) return [];
  return ref.read(xtreamServiceProvider).getVodStreams(p);
});

final _allSeriesProvider = FutureProvider<List<SeriesStream>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final p = StorageService.getPlaylist(id);
  if (p == null) return [];
  return ref.read(xtreamServiceProvider).getSeries(p);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_SearchResult> _buildResults(
    AsyncValue<List<LiveStream>> live,
    AsyncValue<List<VodStream>> vod,
    AsyncValue<List<SeriesStream>> series,
  ) {
    if (_query.length < 2) return [];
    final q = _query.toLowerCase();
    final results = <_SearchResult>[];

    if (live.hasValue) {
      results.addAll(live.value!
          .where((c) => c.name.toLowerCase().contains(q))
          .take(20)
          .map((c) => _SearchResult(
              type: _ResultType.live,
              id: c.streamId,
              name: c.name,
              icon: c.streamIcon)));
    }
    if (vod.hasValue) {
      results.addAll(vod.value!
          .where((m) => m.name.toLowerCase().contains(q))
          .take(20)
          .map((m) => _SearchResult(
              type: _ResultType.vod,
              id: m.streamId,
              name: m.name,
              icon: m.streamIcon,
              ext: m.containerExtension)));
    }
    if (series.hasValue) {
      results.addAll(series.value!
          .where((s) => s.name.toLowerCase().contains(q))
          .take(20)
          .map((s) => _SearchResult(
              type: _ResultType.series, id: s.seriesId, name: s.name, icon: s.cover)));
    }
    return results;
  }

  void _openResult(_SearchResult r) {
    final pid = StorageService.activePlaylistId;
    if (pid == null) return;
    final playlist = StorageService.getPlaylist(pid)!;

    switch (r.type) {
      case _ResultType.live:
        final stream = ref.read(_allLiveProvider).value?.firstWhere((c) => c.streamId == r.id);
        if (stream == null) return;
        final all = ref.read(_allLiveProvider).value ?? [];
        context.push('/player/live',
            extra: LivePlayerArgs(
              stream: stream,
              playlist: playlist,
              channelList: all,
              initialIndex: all.indexOf(stream),
            ));
      case _ResultType.vod:
        final vod = VodStream(
          num: 0,
          name: r.name,
          streamId: r.id,
          streamIcon: r.icon,
          rating: '',
          ratingFiveItem: '',
          added: '',
          categoryId: '',
          containerExtension: r.ext,
          customSid: '',
          directSource: '',
        );
        context.go('/movies/detail', extra: vod);
      case _ResultType.series:
        final s = ref.read(_allSeriesProvider).value?.firstWhere((x) => x.seriesId == r.id);
        if (s == null) return;
        context.go('/series/detail', extra: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(_allLiveProvider);
    final vod = ref.watch(_allVodProvider);
    final series = ref.watch(_allSeriesProvider);

    final loading = live.isLoading || vod.isLoading || series.isLoading;
    final results = _buildResults(live, vod, series);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search live, movies, series...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            border: InputBorder.none,
            isDense: true,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.textMuted),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _query.length < 2
          ? _SearchHint(loading: loading)
          : results.isEmpty
              ? const Center(
                  child: Text('No results found',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  itemBuilder: (_, i) => _ResultTile(
                    result: results[i],
                    onTap: () => _openResult(results[i]),
                  ),
                ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('Indexing content for search...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 56, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Type at least 2 characters',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});
  final _SearchResult result;
  final VoidCallback onTap;

  static const _typeLabel = {
    _ResultType.live: 'LIVE',
    _ResultType.vod: 'MOVIE',
    _ResultType.series: 'SERIES',
  };

  // Cannot be const — AppColors.primary/accent are non-const getters (theme-dependent)
  static final _typeColor = {
    _ResultType.live: AppColors.liveRed,
    _ResultType.vod: AppColors.primary,
    _ResultType.series: AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onPressed: onTap,
      borderRadius: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChannelLogo(url: result.icon, width: 56, height: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(result.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _typeColor[result.type]!.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _typeLabel[result.type]!,
                style: TextStyle(
                    color: _typeColor[result.type],
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

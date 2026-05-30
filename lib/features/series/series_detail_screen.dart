import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rating.dart';
import '../../core/widgets/dpad_scrollable.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/series_stream.dart';
import '../../features/player/series_player_screen.dart';
import '../../services/xtream_service.dart';

Future<void> _launchTrailer(String trailer) async {
  if (trailer.isEmpty) return;
  final uri = trailer.startsWith('http')
      ? Uri.parse(trailer)
      : Uri.parse('https://www.youtube.com/watch?v=$trailer');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final seriesInfoProvider =
    FutureProvider.family<SeriesInfo, int>((ref, seriesId) async {
  final id = StorageService.activePlaylistId;
  if (id == null) throw Exception('No active playlist');
  final playlist = StorageService.getPlaylist(id)!;
  return ref.read(xtreamServiceProvider).getSeriesInfo(playlist, seriesId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});
  final SeriesStream series;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  String _selectedSeason = '';
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(seriesInfoProvider(widget.series.seriesId));
    final isWide = MediaQuery.of(context).size.width > 700;
    final heroHeight = isWide ? 380.0 : 300.0;

    return Scaffold(
      body: DpadScrollable(
        controller: _scrollCtrl,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
          // ── Hero ────────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: heroHeight,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _SeriesHero(series: widget.series),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: isWide
                ? _WideContent(
                    series: widget.series,
                    infoAsync: infoAsync,
                    selectedSeason: _selectedSeason,
                    onSeasonChanged: (s) =>
                        setState(() => _selectedSeason = s),
                  )
                : _NarrowContent(
                    series: widget.series,
                    infoAsync: infoAsync,
                    selectedSeason: _selectedSeason,
                    onSeasonChanged: (s) =>
                        setState(() => _selectedSeason = s),
                  ),
          ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _SeriesHero extends StatelessWidget {
  const _SeriesHero({required this.series});
  final SeriesStream series;

  @override
  Widget build(BuildContext context) {
    // Prefer wide backdropPath, fall back to cover
    final imageUrl = series.backdropPath.isNotEmpty
        ? series.backdropPath
        : series.cover;

    final ratingLabel = formatRatingLabel(series.rating);
    final hasRating = ratingLabel != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop image
        imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.surfaceVariant),
                placeholder: (_, __) =>
                    Container(color: AppColors.surfaceVariant),
              )
            : Container(color: AppColors.surfaceVariant),

        // Top vignette
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Color(0x00000000)],
              stops: [0.0, 0.35],
            ),
          ),
        ),

        // Bottom gradient — matches scaffold background (theme-aware)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppColors.background, const Color(0x00000000)],
              stops: const [0.0, 0.65],
            ),
          ),
        ),

        // Title + rating at bottom-left
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (series.genre.isNotEmpty)
                Text(
                  series.genre.split(',').first.trim().toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                series.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 12),
                  ],
                ),
              ),
              if (hasRating) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFB300), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      ratingLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Narrow layout ─────────────────────────────────────────────────────────────

class _NarrowContent extends StatelessWidget {
  const _NarrowContent({
    required this.series,
    required this.infoAsync,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final SeriesStream series;
  final AsyncValue<SeriesInfo> infoAsync;
  final String selectedSeason;
  final ValueChanged<String> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: infoAsync.when(
        loading: () => const _LoadingSection(),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (info) {
          final activeSeason = selectedSeason.isEmpty
              ? (info.seasonNumbers.isNotEmpty ? info.seasonNumbers.first : '')
              : selectedSeason;
          return _SeriesBody(
            series: series,
            info: info,
            selectedSeason: activeSeason,
            onSeasonChanged: onSeasonChanged,
          );
        },
      ),
    );
  }
}

// ── Wide layout ───────────────────────────────────────────────────────────────

class _WideContent extends StatelessWidget {
  const _WideContent({
    required this.series,
    required this.infoAsync,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final SeriesStream series;
  final AsyncValue<SeriesInfo> infoAsync;
  final String selectedSeason;
  final ValueChanged<String> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: poster thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: series.cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: series.cover,
                    width: 160,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const _CoverFallback(width: 160),
                    placeholder: (_, __) => const _CoverFallback(width: 160),
                  )
                : const _CoverFallback(width: 160),
          ),

          const SizedBox(width: 24),

          // Right: episodes + info
          Expanded(
            child: infoAsync.when(
              loading: () => const _LoadingSection(),
              error: (e, _) => Center(
                  child: Text(e.toString(),
                      style:
                          const TextStyle(color: AppColors.textSecondary))),
              data: (info) {
                final activeSeason = selectedSeason.isEmpty
                    ? (info.seasonNumbers.isNotEmpty
                        ? info.seasonNumbers.first
                        : '')
                    : selectedSeason;
                return _SeriesBody(
                  series: series,
                  info: info,
                  selectedSeason: activeSeason,
                  onSeasonChanged: onSeasonChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Series body (info + seasons + episodes) ───────────────────────────────────

class _SeriesBody extends StatelessWidget {
  const _SeriesBody({
    required this.series,
    required this.info,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final SeriesStream series;
  final SeriesInfo info;
  final String selectedSeason;
  final ValueChanged<String> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    final episodes = info.episodes[selectedSeason] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Meta chips ───────────────────────────────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (series.releaseDate.isNotEmpty)
              _Chip(label: series.releaseDate.length > 4
                  ? series.releaseDate.substring(0, 4)
                  : series.releaseDate),
            if (series.episodeRunTime > 0)
              _Chip(
                icon: Icons.schedule_rounded,
                label: '${series.episodeRunTime} min / ep',
              ),
            ...series.genre
                .split(',')
                .where((g) => g.trim().isNotEmpty)
                .take(3)
                .map((g) => _Chip(label: g.trim(), highlight: true)),
          ],
        ),

        // ── Plot ────────────────────────────────────────────────────────────
        if (series.plot.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            series.plot,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],

        // ── Watch Trailer button ─────────────────────────────────────────────
        if (series.youtubeTrailer.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 180,
            child: OutlinedButton.icon(
              onPressed: () => _launchTrailer(series.youtubeTrailer),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text('Watch Trailer'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],

        // ── Season selector ─────────────────────────────────────────────────
        if (info.seasonNumbers.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Seasons',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: info.seasonNumbers.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final selected = s == selectedSeason;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // Focusable so a TV remote can pick among multiple seasons
                  // (it also auto-scrolls into view on focus).
                  child: FocusableCard(
                    autofocus: i == 0,
                    borderRadius: 20,
                    focusScale: 1.05,
                    onPressed: () => onSeasonChanged(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? null
                            : Border.all(
                                color: AppColors.divider, width: 1),
                      ),
                      child: Text(
                        'S$s',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Episodes ────────────────────────────────────────────────────────
        if (episodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 4),
          ...episodes.asMap().entries.map((entry) => _EpisodeTile(
                key: ValueKey(entry.value.id),
                episode: entry.value,
                seriesTitle: series.name,
                allEpisodes: episodes,
                episodeIndex: entry.key,
              )),
        ],
      ],
    );
  }
}

// ── Episode tile ──────────────────────────────────────────────────────────────

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    super.key,
    required this.episode,
    required this.seriesTitle,
    required this.allEpisodes,
    required this.episodeIndex,
  });

  final SeriesEpisode episode;
  final String seriesTitle;
  final List<SeriesEpisode> allEpisodes;
  final int episodeIndex;

  @override
  Widget build(BuildContext context) {
    final title = episode.title.isNotEmpty
        ? episode.title
        : 'Episode ${episode.episodeNum}';

    // ── Progress / watched state ─────────────────────────────────────────
    final epData = StorageService.getEpisodeData(episode.id);
    final position = (epData?['position'] as int?) ?? 0;
    final duration = (epData?['duration'] as int?) ?? 0;
    final isWatched = (epData?['watched'] as bool?) ??
        (duration > 0 && position > 0 && position / duration > 0.9);
    final progressFraction = (duration > 0 && position > 0 && !isWatched)
        ? (position / duration).clamp(0.0, 1.0)
        : 0.0;
    final hasProgress = progressFraction > 0.02;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final id = StorageService.activePlaylistId!;
          final playlist = StorageService.getPlaylist(id)!;
          // Resume at saved position unless already watched
          final savedPos = (!isWatched && position > 30)
              ? Duration(seconds: position)
              : Duration.zero;
          context.push('/player/series',
              extra: SeriesPlayerArgs(
                episode: episode,
                playlist: playlist,
                seriesTitle: seriesTitle,
                startPosition: savedPos,
                allEpisodes: allEpisodes,
                currentIndex: episodeIndex,
              ));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // ── Episode number badge ─────────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isWatched
                            ? [
                                AppColors.primary.withValues(alpha: 0.35),
                                AppColors.primary.withValues(alpha: 0.2),
                              ]
                            : [
                                AppColors.primary.withValues(alpha: 0.2),
                                AppColors.primary.withValues(alpha: 0.08),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary
                            .withValues(alpha: isWatched ? 0.4 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: isWatched
                          ? Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 22)
                          : Text(
                              episode.episodeNum.toString(),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // ── Title + progress ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isWatched
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (episode.season > 0)
                      Text(
                        'Season ${episode.season}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    if (hasProgress) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progressFraction,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Play icon ─────────────────────────────────────────────────
              Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 32,
              ),

              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, this.highlight = false});
  final String label;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppColors.primary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: (width * 1.5).clamp(180.0, 260.0),
      color: AppColors.surfaceVariant,
      child: const Icon(Icons.video_library_outlined,
          color: AppColors.textMuted, size: 40),
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/perf/perf_profile.dart';
import '../../core/providers/wallpaper_provider.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/utils/rating.dart';
import '../../data/models/series_stream.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/series_player_screen.dart';
import '../../features/player/vod_player_screen.dart';
import '../movies/movies_list_screen.dart';
import '../series/series_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaper = ref.watch(wallpaperProvider);
    final vodAsync = ref.watch(allVodStreamsProvider);
    final seriesAsync = ref.watch(allSeriesProvider);
    final pid = StorageService.activePlaylistId;
    final playlistName =
        pid != null ? (StorageService.getPlaylist(pid)?.name ?? '') : '';

    // Continue Watching — sync, always available
    final continueWatching = StorageService.getHistory()
        .where((item) =>
            (item['type'] == 'vod' || item['type'] == 'series') &&
            ((item['position'] as int?) ?? 0) > 30 &&
            !((item['watched'] as bool?) ?? false))
        .take(10)
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          WallpaperBackground(mode: wallpaper),
          CustomScrollView(
            slivers: [
              // ── Transparent app bar ────────────────────────────────────────
              SliverAppBar(
                // Pinned so the bar never scrolls away — keeps D-pad focus
                // geometry stable so the remote can always move between the
                // top actions and the content/rail (was a focus trap on TV).
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 56,
                title: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WiseVodPlayer',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                        if (playlistName.isNotEmpty)
                          Text(
                            playlistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Top-bar actions removed: Search lives in the side rail, and
                // Refresh moved into the rail too. An empty app-bar action area
                // means Right from the rail lands on the hero/content (not the
                // top buttons), so the remote can actually reach the content.
              ),

              // ── Hero banner ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: vodAsync.when(
                  loading: () => const _HeroShimmer(),
                  error: (_, __) => const SizedBox(height: 12),
                  data: (movies) {
                    final featured = _getFeatured(movies);
                    if (featured.isEmpty) return const SizedBox(height: 12);
                    return _HeroBanner(featured: featured);
                  },
                ),
              ),

              // ── Continue Watching ──────────────────────────────────────────
              if (continueWatching.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Continue Watching',
                    icon: Icons.play_circle_rounded,
                    child: SizedBox(
                      height: 112,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: continueWatching.length,
                        itemBuilder: (ctx, i) =>
                            _ContinueCard(item: continueWatching[i]),
                      ),
                    ),
                  ),
                ),

              // ── Recently Added ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: vodAsync.when(
                  loading: () => const _RowShimmer(title: 'Recently Added'),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (movies) {
                    final items = _recentlyAdded(movies);
                    return items.isEmpty
                        ? const SizedBox.shrink()
                        : _Section(
                            title: 'Recently Added',
                            icon: Icons.new_releases_rounded,
                            child: _MovieRow(movies: items),
                          );
                  },
                ),
              ),

              // ── Top Rated Movies ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: vodAsync.when(
                  loading: () => const _RowShimmer(title: 'Top Rated'),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (movies) {
                    final items = _topRatedMovies(movies);
                    return items.isEmpty
                        ? const SizedBox.shrink()
                        : _Section(
                            title: 'Top Rated',
                            icon: Icons.star_rounded,
                            child: _MovieRow(movies: items),
                          );
                  },
                ),
              ),

              // ── Popular Series ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: seriesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (all) {
                    final items = _topRatedSeries(all);
                    return items.isEmpty
                        ? const SizedBox.shrink()
                        : _Section(
                            title: 'Popular Series',
                            icon: Icons.video_library_rounded,
                            child: _SeriesRow(series: items),
                          );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }


  // ── Data helpers ─────────────────────────────────────────────────────────

  static List<VodStream> _getFeatured(List<VodStream> all) {
    // Sort by rating ↓, then by added timestamp ↓ as tiebreaker so that
    // newly added high-rated content always surfaces first in the banner.
    final items = all.where((m) => m.streamIcon.isNotEmpty).toList()
      ..sort((a, b) {
        // Invalid/garbage ratings sink (treated as -1) so they never lead
        // the banner — only genuinely high-rated titles surface.
        final ratingCmp = (parseRating(b.rating) ?? -1)
            .compareTo(parseRating(a.rating) ?? -1);
        if (ratingCmp != 0) return ratingCmp;
        return (int.tryParse(b.added) ?? 0)
            .compareTo(int.tryParse(a.added) ?? 0);
      });
    return items.take(8).toList();
  }

  static List<VodStream> _recentlyAdded(List<VodStream> all) {
    final items = all.where((m) => m.streamIcon.isNotEmpty).toList()
      ..sort((a, b) => (int.tryParse(b.added) ?? 0)
          .compareTo(int.tryParse(a.added) ?? 0));
    return items.take(20).toList();
  }

  static List<VodStream> _topRatedMovies(List<VodStream> all) {
    final items = all
        .where(
            (m) => m.streamIcon.isNotEmpty && (parseRating(m.rating) ?? 0) >= 5)
        .toList()
      ..sort((a, b) => (parseRating(b.rating) ?? 0)
          .compareTo(parseRating(a.rating) ?? 0));
    return items.take(20).toList();
  }

  static List<SeriesStream> _topRatedSeries(List<SeriesStream> all) {
    final items = all
        .where((s) =>
            s.cover.isNotEmpty && (parseRating(s.rating) ?? 0) >= 5)
        .toList()
      ..sort((a, b) => (parseRating(b.rating) ?? 0)
          .compareTo(parseRating(a.rating) ?? 0));
    return items.take(20).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner — auto-scrolling PageView
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({required this.featured});
  final List<VodStream> featured;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  late final PageController _pageCtrl;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    // Honour the low-tier / reduce-motion setting — no ambient carousel motion.
    if (Perf.reduceMotion) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final next = (_page + 1) % widget.featured.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // Pause auto-advance while the banner is focused (so the page doesn't slide
  // out from under the D-pad selection); resume when focus leaves.
  void _onFocusChange(bool hasFocus) {
    if (hasFocus) {
      _timer?.cancel();
    } else {
      _startAutoScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _onFocusChange,
        child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (p) => setState(() => _page = p),
            itemCount: widget.featured.length,
            itemBuilder: (_, i) => _HeroCard(movie: widget.featured[i]),
          ),

          // Dots indicator
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.featured.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.movie});
  final VodStream movie;

  @override
  Widget build(BuildContext context) {
    final ratingLabel = formatRatingLabel(movie.rating);
    final hasRating = ratingLabel != null;

    return FocusableCard(
      onPressed: () => context.push('/movies/detail', extra: movie),
      borderRadius: 0,
      focusScale: 1.0, // full-width; scaling would overflow
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Backdrop image
          movie.streamIcon.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: movie.streamIcon,
                  fit: BoxFit.cover,
                  cacheManager: AppImageCacheManager(),
                  errorWidget: (_, __, ___) =>
                      _HeroFallback(name: movie.name),
                  placeholder: (_, __) =>
                      _HeroFallback(name: movie.name),
                )
              : _HeroFallback(name: movie.name),

          // Bottom gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x99000000),
                  Color(0xDD000000),
                ],
                stops: [0.35, 0.70, 1.0],
              ),
            ),
          ),

          // Text + play button
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movie.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.3,
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
                          color: Color(0xFFFFB300), size: 13),
                      const SizedBox(width: 4),
                      Text(
                        ratingLabel,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _HeroButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Play',
                      filled: true,
                      onTap: () {
                        final id = StorageService.activePlaylistId;
                        if (id == null) return;
                        final pl = StorageService.getPlaylist(id)!;
                        context.push('/player/vod',
                            extra: VodPlayerArgs(vod: movie, playlist: pl));
                      },
                    ),
                    const SizedBox(width: 10),
                    _HeroButton(
                      icon: Icons.info_outline_rounded,
                      label: 'More Info',
                      filled: false,
                      onTap: () => context.push('/movies/detail', extra: movie),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_creation_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section wrapper — header + scrollable child
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue Watching cards (landscape)
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (item['icon'] as String?) ?? '';
    final name = (item['name'] as String?) ?? '';
    final position = (item['position'] as int?) ?? 0;
    final duration = (item['duration'] as int?) ?? 0;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

    return FocusableCard(
      onPressed: () => _playHistory(item, context),
      borderRadius: 8,
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail with progress bar overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  SizedBox(
                    width: 155,
                    height: 88,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            cacheManager: AppImageCacheManager(),
                            errorWidget: (_, __, ___) =>
                                _ThumbFallback(type: item['type'] as String?),
                            placeholder: (_, __) =>
                                _ThumbFallback(type: item['type'] as String?),
                          )
                        : _ThumbFallback(type: item['type'] as String?),
                  ),
                  // Dark overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x66000000)],
                        ),
                      ),
                    ),
                  ),
                  // Play icon
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white70, size: 30),
                  ),
                  // Progress bar at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({this.type});
  final String? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(
          type == 'series'
              ? Icons.video_library_outlined
              : Icons.movie_outlined,
          color: AppColors.textMuted,
          size: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Movie / Series horizontal rows
// ─────────────────────────────────────────────────────────────────────────────

class _MovieRow extends StatelessWidget {
  const _MovieRow({required this.movies});
  final List<VodStream> movies;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: movies.length,
        itemBuilder: (_, i) => _PosterCard(
          imageUrl: movies[i].streamIcon,
          title: movies[i].name,
          rating: movies[i].rating,
          onTap: () => context.push('/movies/detail', extra: movies[i]),
        ),
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series});
  final List<SeriesStream> series;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: series.length,
        itemBuilder: (_, i) => _PosterCard(
          imageUrl: series[i].cover,
          title: series[i].name,
          rating: series[i].rating,
          onTap: () => context.push('/series/detail', extra: series[i]),
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.imageUrl,
    required this.title,
    required this.rating,
    required this.onTap,
  });
  final String imageUrl;
  final String title;
  final String rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratingLabel = formatRatingLabel(rating);
    final hasRating = ratingLabel != null;

    return FocusableCard(
      onPressed: onTap,
      borderRadius: 8,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  SizedBox(
                    width: 110,
                    height: 155,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            cacheManager: AppImageCacheManager(),
                            errorWidget: (_, __, ___) =>
                                _PosterFallback(title: title),
                            placeholder: (_, __) =>
                                _PosterFallback(title: title),
                          )
                        : _PosterFallback(title: title),
                  ),
                  // Rating badge
                  if (hasRating)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFB300), size: 9),
                            const SizedBox(width: 2),
                            Text(
                              ratingLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            // Title
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10, height: 1.3),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading shimmer states
// ─────────────────────────────────────────────────────────────────────────────

class _HeroShimmer extends StatelessWidget {
  const _HeroShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      color: AppColors.surfaceVariant,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _RowShimmer extends StatelessWidget {
  const _RowShimmer({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (_, __) => Container(
              width: 110,
              height: 155,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue Watching — play from history
// ─────────────────────────────────────────────────────────────────────────────

void _playHistory(Map<String, dynamic> item, BuildContext context) {
  final id = StorageService.activePlaylistId;
  if (id == null) return;
  final playlist = StorageService.getPlaylist(id)!;
  final type = (item['type'] as String?) ?? 'vod';
  final position = (item['position'] as int?) ?? 0;
  final startPos =
      position > 30 ? Duration(seconds: position) : Duration.zero;

  if (type == 'vod') {
    final vod = VodStream(
      num: 0,
      name: (item['name'] as String?) ?? '',
      streamId: (item['id'] as int?) ?? 0,
      streamIcon: (item['icon'] as String?) ?? '',
      rating: '',
      ratingFiveItem: '',
      added: '',
      categoryId: '',
      containerExtension: (item['ext'] as String?) ?? 'mp4',
      customSid: '',
      directSource: '',
    );
    context.push('/player/vod',
        extra: VodPlayerArgs(
          vod: vod,
          playlist: playlist,
          startPosition: startPos,
        ));
  } else if (type == 'series') {
    final ep = SeriesEpisode(
      id: (item['id'] as int?) ?? 0,
      title: (item['name'] as String?) ?? '',
      containerExtension: (item['ext'] as String?) ?? 'mp4',
      info: '',
      customSid: '',
      added: '',
      season: 0,
      episodeNum: 0,
      directSource: '',
    );
    context.push('/player/series',
        extra: SeriesPlayerArgs(
          episode: ep,
          playlist: playlist,
          seriesTitle: (item['name'] as String?) ?? '',
          startPosition: startPos,
        ));
  }
}

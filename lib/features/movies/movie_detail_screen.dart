import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rating.dart';
import '../../core/widgets/dpad_scrollable.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/vod_player_screen.dart';
import '../../services/xtream_service.dart';

// ── Trailer URL helper ────────────────────────────────────────────────────────

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

final vodInfoProvider = FutureProvider.family<VodInfo, int>((ref, vodId) async {
  final id = StorageService.activePlaylistId;
  if (id == null) throw Exception('No active playlist');
  final playlist = StorageService.getPlaylist(id)!;
  return ref.read(xtreamServiceProvider).getVodInfo(playlist, vodId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MovieDetailScreen extends ConsumerStatefulWidget {
  const MovieDetailScreen({super.key, required this.vod});
  final VodStream vod;

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vod = widget.vod;
    final infoAsync = ref.watch(vodInfoProvider(vod.streamId));
    final isWide = MediaQuery.of(context).size.width > 700;
    final heroHeight = isWide ? 380.0 : 300.0;

    return Scaffold(
      body: DpadScrollable(
        controller: _scrollCtrl,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── Hero ──────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: heroHeight,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.background,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _HeroBackdrop(
                  vod: vod,
                  // Use backdrop from info if available
                  infoAsync: infoAsync,
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: isWide
                  ? _WideContent(vod: vod, infoAsync: infoAsync)
                  : _NarrowContent(vod: vod, infoAsync: infoAsync),
            ),

            // Scroll clearance at bottom
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Hero backdrop ─────────────────────────────────────────────────────────────

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.vod, required this.infoAsync});
  final VodStream vod;
  final AsyncValue<VodInfo> infoAsync;

  @override
  Widget build(BuildContext context) {
    // Use backdrop from info if loaded, else fall back to stream icon (poster)
    final backdropUrl = infoAsync.valueOrNull?.backdropPath;
    final imageUrl = (backdropUrl != null && backdropUrl.isNotEmpty)
        ? backdropUrl
        : vod.streamIcon;

    final ratingLabel = formatRatingLabel(vod.rating);
    final hasRating = ratingLabel != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop / poster image
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

        // Top vignette — subtle darkening for back-button readability
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

        // Bottom gradient — fades to scaffold background (theme-aware)
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

        // Title + rating at bottom
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vod.name,
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

// ── Narrow layout (phone) ─────────────────────────────────────────────────────

class _NarrowContent extends StatelessWidget {
  const _NarrowContent({required this.vod, required this.infoAsync});
  final VodStream vod;
  final AsyncValue<VodInfo> infoAsync;

  @override
  Widget build(BuildContext context) {
    final id = StorageService.activePlaylistId;
    final playlist = id != null ? StorageService.getPlaylist(id) : null;
    final trailerUrl = infoAsync.valueOrNull?.youtubeTrailer ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Play button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: playlist == null
                  ? null
                  : () => context.push('/player/vod',
                      extra: VodPlayerArgs(vod: vod, playlist: playlist)),
              autofocus: true,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Play Now'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // Watch Trailer button — shown once info is loaded and trailer exists
          if (trailerUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchTrailer(trailerUrl),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: const Text('Watch Trailer'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Info from API
          infoAsync.when(
            loading: () => const _InfoShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) => _InfoBody(info: info),
          ),
        ],
      ),
    );
  }
}

// ── Wide layout (tablet / TV) ─────────────────────────────────────────────────

class _WideContent extends StatelessWidget {
  const _WideContent({required this.vod, required this.infoAsync});
  final VodStream vod;
  final AsyncValue<VodInfo> infoAsync;

  @override
  Widget build(BuildContext context) {
    final id = StorageService.activePlaylistId;
    final playlist = id != null ? StorageService.getPlaylist(id) : null;
    final trailerUrl = infoAsync.valueOrNull?.youtubeTrailer ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: poster thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: vod.streamIcon.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: vod.streamIcon,
                    width: 160,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const _PosterFallback(width: 160),
                    placeholder: (_, __) =>
                        const _PosterFallback(width: 160),
                  )
                : const _PosterFallback(width: 160),
          ),

          const SizedBox(width: 24),

          // Right: info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Button row: Play + optional Trailer
                Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: ElevatedButton.icon(
                        onPressed: playlist == null
                            ? null
                            : () => context.push('/player/vod',
                                extra:
                                    VodPlayerArgs(vod: vod, playlist: playlist)),
                        autofocus: true,
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text('Play Now'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (trailerUrl.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 160,
                        child: OutlinedButton.icon(
                          onPressed: () => _launchTrailer(trailerUrl),
                          icon: const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 20),
                          label: const Text('Trailer'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                infoAsync.when(
                  loading: () => const _InfoShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (info) => _InfoBody(info: info),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info body (shared by both layouts) ───────────────────────────────────────

class _InfoBody extends StatelessWidget {
  const _InfoBody({required this.info});
  final VodInfo info;

  @override
  Widget build(BuildContext context) {
    // Parse rating from info (may differ from stream rating)
    final ratingStr = info.rating;
    final hasRating = ratingStr.isNotEmpty &&
        double.tryParse(ratingStr) != null &&
        double.parse(ratingStr) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Chips row: rating + genre + duration ───────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (hasRating)
              _Chip(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFFB300),
                label: double.parse(ratingStr).toStringAsFixed(1),
              ),
            if (info.releaseDate.isNotEmpty)
              _Chip(label: info.releaseDate.length > 4
                  ? info.releaseDate.substring(0, 4)
                  : info.releaseDate),
            if (info.duration.isNotEmpty)
              _Chip(
                icon: Icons.schedule_rounded,
                label: info.duration,
              ),
            ...info.genre
                .split(',')
                .where((g) => g.trim().isNotEmpty)
                .take(3)
                .map((g) => _Chip(
                      label: g.trim(),
                      highlight: true,
                    )),
          ],
        ),

        if (info.plot.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Overview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.plot,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],

        if (info.director.isNotEmpty ||
            info.cast.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          if (info.director.isNotEmpty)
            _MetaRow('Director', info.director),
          if (info.cast.isNotEmpty)
            _MetaRow('Cast', info.cast),
          if (info.releaseDate.isNotEmpty)
            _MetaRow('Release', info.releaseDate),
          if (info.duration.isNotEmpty)
            _MetaRow('Runtime', info.duration),
        ],
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.iconColor,
    this.highlight = false,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
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
            Icon(icon, size: 12,
                color: iconColor ?? AppColors.textSecondary),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoShimmer extends StatelessWidget {
  const _InfoShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips placeholder
        Row(
          children: [
            _ShimmerBox(width: 60, height: 28),
            SizedBox(width: 8),
            _ShimmerBox(width: 80, height: 28),
            SizedBox(width: 8),
            _ShimmerBox(width: 70, height: 28),
          ],
        ),
        SizedBox(height: 20),
        _ShimmerBox(width: 90, height: 15),
        SizedBox(height: 8),
        _ShimmerBox(width: double.infinity, height: 13),
        SizedBox(height: 6),
        _ShimmerBox(width: double.infinity, height: 13),
        SizedBox(height: 6),
        _ShimmerBox(width: 200, height: 13),
      ],
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: (width * 1.5).clamp(180.0, 260.0),
      color: AppColors.surfaceVariant,
      child: const Icon(Icons.movie_creation_outlined,
          color: AppColors.textMuted, size: 40),
    );
  }
}

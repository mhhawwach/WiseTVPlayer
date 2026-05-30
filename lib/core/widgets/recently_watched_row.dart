import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../data/models/live_stream.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/live_player_screen.dart';
import '../../features/player/vod_player_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal scroll row of recently watched items.
///
/// [type] must be `'live'` or `'vod'`.
///
/// - Live items navigate directly to the Live player.
/// - VOD items navigate directly to the VOD player, restoring the saved position.
///
/// The widget returns `SizedBox.shrink()` when there are no items so it adds
/// zero height to the parent column.
class RecentlyWatchedRow extends StatelessWidget {
  const RecentlyWatchedRow({
    super.key,
    required this.type,
    this.title,
    this.limit = 12,
  });

  final String type;
  final String? title;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final items = StorageService.getRecentHistory(type, limit: limit);
    if (items.isEmpty) return const SizedBox.shrink();

    final label = title ??
        (type == 'live' ? 'Recently Watched' : 'Continue Watching');

    // Only show VOD items that have a saved position for "Continue Watching"
    final displayItems = type == 'vod'
        ? items.where((m) => (m['position'] as int? ?? 0) > 0).toList()
        : items;

    if (displayItems.isEmpty) return const SizedBox.shrink();

    final cardH = type == 'live' ? 80.0 : 140.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(
                type == 'live'
                    ? Icons.history_rounded
                    : Icons.play_circle_outline_rounded,
                color: AppColors.accent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: displayItems.length,
            itemBuilder: (ctx, i) => _HistoryCard(
              item: displayItems[i],
              type: type,
              cardHeight: cardH,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.type,
    required this.cardHeight,
  });

  final Map<String, dynamic> item;
  final String type;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final icon = item['icon'] as String? ?? '';
    final positionSec = item['position'] as int? ?? 0;

    final cardW = type == 'live' ? 120.0 : 90.0;

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: cardW,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster / logo
              ChannelLogo(
                url: icon,
                width: cardW,
                height: cardHeight,
                fit: type == 'live' ? BoxFit.contain : BoxFit.cover,
              ),

              // Dark gradient overlay at bottom for label
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xDD000000), Colors.transparent],
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Progress bar for VOD with saved position
              if (type == 'vod' && positionSec > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ProgressBar(item: item),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    final pid = StorageService.activePlaylistId;
    if (pid == null) return;
    final playlist = StorageService.getPlaylist(pid);
    if (playlist == null) return;

    final streamId = item['id'] as int? ?? 0;
    final name = item['name'] as String? ?? '';
    final icon = item['icon'] as String? ?? '';

    if (type == 'live') {
      final ch = LiveStream(
        num: 0,
        name: name,
        streamType: 'live',
        streamId: streamId,
        streamIcon: icon,
        epgChannelId: '',
        added: '',
        categoryId: '',
        customSid: '',
        tvArchive: '0',
        directSource: '',
        tvArchiveDuration: '0',
      );
      context.push('/player/live',
          extra: LivePlayerArgs(
            stream: ch,
            playlist: playlist,
            channelList: [ch],
            initialIndex: 0,
          ));
    } else {
      // VOD — play with resume position
      final ext = item['ext'] as String? ?? 'mp4';
      final positionSec = item['position'] as int? ?? 0;
      final vod = VodStream(
        num: 0,
        name: name,
        streamId: streamId,
        streamIcon: icon,
        rating: '',
        ratingFiveItem: '',
        added: '',
        categoryId: '',
        containerExtension: ext,
        customSid: '',
        directSource: '',
      );
      context.push('/player/vod',
          extra: VodPlayerArgs(
            vod: vod,
            playlist: playlist,
            startPosition: Duration(seconds: positionSec),
          ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    // We don't know the total duration without loading the file, so we use
    // a simple teal accent line as a "resume" indicator instead of a percentage.
    return Container(
      height: 3,
      color: AppColors.accent,
    );
  }
}

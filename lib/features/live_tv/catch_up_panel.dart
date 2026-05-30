import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/epg_listing.dart';
import '../../data/models/live_stream.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/vod_player_screen.dart';
import '../../services/xtream_service.dart';

/// Fetches the full EPG for a channel — up to 10 entries including past.
final _catchUpEpgProvider =
    FutureProvider.family<List<EpgListing>, int>((ref, streamId) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  // get_short_epg with a high limit gets current + past entries on most servers
  final all = await ref
      .read(xtreamServiceProvider)
      .getShortEpg(playlist, streamId, limit: 24);
  return all;
});

// ─────────────────────────────────────────────────────────────────────────────

/// Shows a bottom sheet with past EPG entries that can be replayed.
void showCatchUpPanel(BuildContext context, LiveStream channel) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CatchUpSheet(channel: channel),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _CatchUpSheet extends ConsumerWidget {
  const _CatchUpSheet({required this.channel});
  final LiveStream channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epgAsync = ref.watch(_catchUpEpgProvider(channel.streamId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catch-Up — ${channel.name}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: epgAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Failed to load EPG\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
                data: (listings) {
                  // Past and current entries — filter out future only
                  final now = DateTime.now();
                  final playable = listings.where((e) {
                    final start = e.startTime;
                    return start != null && start.isBefore(now);
                  }).toList()
                    ..sort((a, b) =>
                        (b.startTime ?? DateTime(0))
                            .compareTo(a.startTime ?? DateTime(0)));

                  if (playable.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_outlined,
                              size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('No catch-up recordings available',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: playable.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (ctx, i) => _CatchUpRow(
                      listing: playable[i],
                      channel: channel,
                      onPlay: () => _play(ctx, playable[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _play(BuildContext context, EpgListing listing) {
    final pid = StorageService.activePlaylistId;
    if (pid == null) return;
    final playlist = StorageService.getPlaylist(pid)!;

    final startTs = int.tryParse(listing.startTimestamp) ?? 0;
    final stopTs = int.tryParse(listing.stopTimestamp) ?? 0;
    if (startTs == 0) return;

    final url = playlist.catchUpUrl(
      channel.streamId.toString(),
      startTs,
      stopTs,
    );

    // Re-use VodPlayerScreen with an override URL
    Navigator.of(context).pop(); // Close panel before pushing player
    context.push(
      '/player/vod',
      extra: VodPlayerArgs(
        vod: VodStream(
          num: 0,
          name: listing.title.isNotEmpty ? listing.title : channel.name,
          streamId: channel.streamId,
          streamIcon: channel.streamIcon,
          rating: '',
          ratingFiveItem: '',
          added: '',
          categoryId: '',
          containerExtension: 'ts',
          customSid: '',
          directSource: '',
        ),
        playlist: playlist,
        overrideUrl: url,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CatchUpRow extends StatelessWidget {
  const _CatchUpRow({
    required this.listing,
    required this.channel,
    required this.onPlay,
  });

  final EpgListing listing;
  final LiveStream channel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final start = listing.startTime;
    final stop = listing.stopTime;
    final date = start != null ? DateFormat('EEE d MMM').format(start) : '';
    final timeRange = (start != null && stop != null)
        ? '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(stop)}'
        : '';
    final duration = (start != null && stop != null)
        ? '${stop.difference(start).inMinutes} min'
        : '';
    final isLive = listing.nowPlaying;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Row(
        children: [
          if (isLive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('NOW',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              listing.title.isNotEmpty ? listing.title : '—',
              style: TextStyle(
                color: isLive ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '$date  ·  $timeRange  ·  $duration',
          style:
              const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ),
      trailing: FilledButton.icon(
        onPressed: onPlay,
        icon: const Icon(Icons.play_arrow_rounded, size: 16),
        label: const Text('Watch'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(0, 32),
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/epg_listing.dart';
import '../../data/models/live_stream.dart';
import '../../services/xtream_service.dart';

final epgProvider =
    FutureProvider.family<List<EpgListing>, int>((ref, streamId) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  return ref.read(xtreamServiceProvider).getShortEpg(playlist, streamId, limit: 10);
});

/// Slide-up EPG panel — call with showModalBottomSheet.
class EpgPanel extends ConsumerWidget {
  const EpgPanel({super.key, required this.stream});
  final LiveStream stream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epgAsync = ref.watch(epgProvider(stream.streamId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stream.name,
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
          epgAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('EPG unavailable',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            data: (listings) => listings.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No EPG data for this channel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: listings.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) => _EpgRow(listing: listings[i]),
                    ),
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _EpgRow extends StatelessWidget {
  const _EpgRow({required this.listing});
  final EpgListing listing;

  @override
  Widget build(BuildContext context) {
    final start = listing.startTime;
    final stop = listing.stopTime;
    final timeStr = start != null && stop != null
        ? '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(stop)}'
        : '';
    final progress = listing.progressPercent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeStr,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                if (listing.nowPlaying && progress > 0) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (listing.nowPlaying)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    Expanded(
                      child: Text(
                        listing.title,
                        style: TextStyle(
                          color: listing.nowPlaying
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: listing.nowPlaying
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (listing.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    listing.description,
                    style:
                        const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

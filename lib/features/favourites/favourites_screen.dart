import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/vod_player_screen.dart';

final favouritesProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  return [
    ...StorageService.getFavourites('live'),
    ...StorageService.getFavourites('vod'),
    ...StorageService.getFavourites('series'),
  ];
});

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favouritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: favs.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No favourites yet',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Long-press a channel or movie to add it.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favs.length,
              itemBuilder: (_, i) {
                final f = favs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FocusableCard(
                    autofocus: i == 0,
                    onPressed: () {
                      if (f['type'] == 'vod') {
                        final id = StorageService.activePlaylistId!;
                        final playlist = StorageService.getPlaylist(id)!;
                        // Reconstruct minimal VodStream from stored map
                        final vod = VodStream(
                          num: 0,
                          name: f['name'] as String? ?? '',
                          streamId: f['id'] as int? ?? 0,
                          streamIcon: f['icon'] as String? ?? '',
                          rating: '',
                          ratingFiveItem: '',
                          added: '',
                          categoryId: '',
                          containerExtension: f['ext'] as String? ?? 'mp4',
                          customSid: '',
                          directSource: '',
                        );
                        context.push('/player/vod',
                            extra: VodPlayerArgs(vod: vod, playlist: playlist));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ChannelLogo(
                            url: f['icon'] as String? ?? '',
                            width: 56,
                            height: 38,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f['name'] as String? ?? '',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14)),
                                const SizedBox(height: 3),
                                Text((f['type'] as String? ?? '').toUpperCase(),
                                    style: const TextStyle(
                                        color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.favorite, color: AppColors.liveRed, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

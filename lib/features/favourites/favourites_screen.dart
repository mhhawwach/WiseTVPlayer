import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/live_stream.dart';
import '../../data/models/series_stream.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/live_player_screen.dart';
import '../../features/player/vod_player_screen.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  // Read fresh on every build so newly-added favourites appear immediately.
  // (Previously this used a StateProvider computed once at startup, so anything
  // favourited during the session never showed up until an app restart.)
  List<Map<String, dynamic>> _load() => [
        ...StorageService.getFavourites('live'),
        ...StorageService.getFavourites('vod'),
        ...StorageService.getFavourites('series'),
      ];

  void _open(BuildContext context, Map<String, dynamic> f) {
    final id = StorageService.activePlaylistId;
    if (id == null) return;
    final playlist = StorageService.getPlaylist(id);
    if (playlist == null) return;
    final type = f['type'] as String? ?? 'vod';
    final fid = f['id'] as int? ?? 0;
    final name = f['name'] as String? ?? '';
    final icon = f['icon'] as String? ?? '';

    if (type == 'live') {
      final ch = LiveStream(
        num: 0, name: name, streamType: 'live', streamId: fid, streamIcon: icon,
        epgChannelId: '', added: '', categoryId: '', customSid: '',
        tvArchive: '0', directSource: '', tvArchiveDuration: '0',
      );
      context.push('/player/live',
          extra: LivePlayerArgs(
              stream: ch, playlist: playlist, channelList: [ch], initialIndex: 0));
    } else if (type == 'series') {
      final s = SeriesStream(
        num: 0, name: name, seriesId: fid, cover: icon, plot: '', cast: '',
        director: '', genre: '', releaseDate: '', lastModified: '', rating: '',
        ratingFiveItem: '', backdropPath: '', youtubeTrailer: '',
        episodeRunTime: 0, categoryId: '',
      );
      context.push('/series/detail', extra: s);
    } else {
      final vod = VodStream(
        num: 0, name: name, streamId: fid, streamIcon: icon, rating: '',
        ratingFiveItem: '', added: '', categoryId: '',
        containerExtension: f['ext'] as String? ?? 'mp4', customSid: '', directSource: '',
      );
      context.push('/player/vod', extra: VodPlayerArgs(vod: vod, playlist: playlist));
    }
  }

  @override
  Widget build(BuildContext context) {
    final favs = _load();

    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: favs.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border_rounded, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No favourites yet',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text('Press the yellow button while watching to add one.',
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
                    onPressed: () => _open(context, f),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ChannelLogo(url: f['icon'] as String? ?? '', width: 56, height: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f['name'] as String? ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                          const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
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

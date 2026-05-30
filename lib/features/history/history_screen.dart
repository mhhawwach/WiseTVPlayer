import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/focusable_card.dart';
import '../../data/models/vod_stream.dart';
import '../../features/player/live_player_screen.dart';
import '../../features/player/vod_player_screen.dart';
import '../../data/models/live_stream.dart';

final historyProvider = StateNotifierProvider<_HistoryNotifier, List<Map<String, dynamic>>>(
    (ref) => _HistoryNotifier());

class _HistoryNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  _HistoryNotifier() : super(StorageService.getHistory());

  Future<void> clear() async {
    await StorageService.clearHistory();
    state = [];
  }

  void reload() => state = StorageService.getHistory();
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch History'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(historyProvider.notifier).clear(),
              child: const Text('Clear All', style: TextStyle(color: AppColors.liveRed)),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No history yet',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 80, endIndent: 16),
              itemBuilder: (_, i) {
                final item = items[i];
                return _HistoryTile(
                  item: item,
                  onTap: () => _play(context, ref, item),
                );
              },
            ),
    );
  }

  void _play(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final pid = StorageService.activePlaylistId;
    if (pid == null) return;
    final playlist = StorageService.getPlaylist(pid)!;

    if (item['type'] == 'live') {
      // Re-open live stream directly — rebuild minimal LiveStream
      final stream = _minimalLiveStream(
        id: item['id'] as int? ?? 0,
        name: item['name'] as String? ?? '',
        icon: item['icon'] as String? ?? '',
      );
      context.push('/player/live',
          extra: LivePlayerArgs(
            stream: stream,
            playlist: playlist,
            channelList: [stream],
            initialIndex: 0,
          ));
    } else {
      final vod = VodStream(
        num: 0,
        name: item['name'] as String? ?? '',
        streamId: item['id'] as int? ?? 0,
        streamIcon: item['icon'] as String? ?? '',
        rating: '',
        ratingFiveItem: '',
        added: '',
        categoryId: '',
        containerExtension: item['ext'] as String? ?? 'mp4',
        customSid: '',
        directSource: '',
      );
      context.push('/player/vod',
          extra: VodPlayerArgs(
            vod: vod,
            playlist: playlist,
            startPosition: Duration(
              seconds: item['position'] as int? ?? 0,
            ),
          ));
    }
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ts = item['ts'] as int? ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final label = DateFormat('MMM d, HH:mm').format(dt);
    final type = (item['type'] as String? ?? '').toUpperCase();

    return FocusableCard(
      borderRadius: 0,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChannelLogo(url: item['icon'] as String? ?? '', width: 56, height: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text('$type · $label',
                      style:
                          const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline,
                color: AppColors.primary, size: 26),
          ],
        ),
      ),
    );
  }
}

/// Minimal live stream for re-playing from history without refetching.
LiveStream _minimalLiveStream({
  required int id,
  required String name,
  required String icon,
}) =>
    LiveStream(
      num: 0,
      name: name,
      streamType: 'live',
      streamId: id,
      streamIcon: icon,
      epgChannelId: '',
      added: '',
      categoryId: '',
      customSid: '',
      tvArchive: '0',
      directSource: '',
      tvArchiveDuration: '0',
    );

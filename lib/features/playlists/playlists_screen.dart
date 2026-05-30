import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/content_refresh.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/playlist.dart';

final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((ref) {
  return PlaylistsNotifier();
});

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier() : super(StorageService.playlists);

  void reload() => state = StorageService.playlists;

  Future<void> remove(String id) async {
    await StorageService.deletePlaylist(id);
    state = StorageService.playlists;
  }

  Future<void> setActive(String id) async {
    await StorageService.setActivePlaylistId(id);
    state = StorageService.playlists;
  }
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _addPlaylist(BuildContext context, WidgetRef ref) async {
    final before = StorageService.activePlaylistId;
    await context.push('/playlists/add');
    ref.read(playlistsProvider.notifier).reload();
    // A newly added playlist becomes active — refresh all content for it.
    if (StorageService.activePlaylistId != before) {
      invalidateAllContent(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final activeId = StorageService.activePlaylistId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addPlaylist(context, ref),
          ),
        ],
      ),
      body: playlists.isEmpty
          ? _EmptyPlaylists(onAdd: () => _addPlaylist(context, ref))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = playlists[i];
                return _PlaylistTile(
                  playlist: p,
                  isActive: p.id == activeId,
                  onTap: () {
                    if (p.id == activeId) {
                      context.go('/home');
                      return;
                    }
                    ref.read(playlistsProvider.notifier).setActive(p.id);
                    invalidateAllContent(ref);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Switched to ${p.name}')),
                    );
                    context.go('/home');
                  },
                  onDelete: () {
                    final wasActive = p.id == activeId;
                    ref.read(playlistsProvider.notifier).remove(p.id);
                    if (wasActive) {
                      final remaining = StorageService.playlists;
                      if (remaining.isNotEmpty) {
                        ref
                            .read(playlistsProvider.notifier)
                            .setActive(remaining.first.id);
                      }
                      invalidateAllContent(ref);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final Playlist playlist;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: isActive ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    isActive ? Icons.check_circle_rounded : Icons.playlist_play,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('ACTIVE',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      playlist.serverUrl,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (playlist.daysLeft >= 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${playlist.daysLeft} days left',
                        style: TextStyle(
                          color: playlist.daysLeft < 7
                              ? AppColors.liveRed
                              : AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('No playlists yet',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Add your Xtream Codes credentials to get started.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Playlist'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/category_prefs_notifier.dart';
import '../../core/storage/storage_service.dart';
import '../../core/widgets/category_grid.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_grid.dart';
import '../../core/widgets/recently_watched_row.dart';
import '../../data/models/live_category.dart';
import '../../features/movies/movies_list_screen.dart';
import '../../services/xtream_service.dart';

final vodCategoriesProvider = FutureProvider<List<LiveCategory>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  return ref.read(xtreamServiceProvider).getVodCategories(playlist);
});

const _allCategory = LiveCategory(
  categoryId: AppConstants.catAllId,
  categoryName: 'All Movies',
  parentId: 0,
);

class MoviesCategoriesScreen extends ConsumerWidget {
  const MoviesCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vodCategoriesProvider);
    final prefs = ref.watch(categoryPrefsProvider);
    // Kick off the full movie list fetch in the background the moment the
    // categories screen appears.  By the time the user taps any category tile
    // (typically 1-3 s of browsing) the data is already loading or fully
    // loaded in allVodStreamsProvider, making navigation instant.
    ref.watch(allVodStreamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: async.when(
        loading: () => const LoadingGrid(),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(vodCategoriesProvider)),
        data: (cats) {
          final visible = applyOrderAndFilter(cats, prefs, 'movies');
          final withAll = [_allCategory, ...visible];

          return Column(
            children: [
              // "Continue Watching" — only VOD items with a saved position
              const RecentlyWatchedRow(type: 'vod', title: 'Continue Watching'),
              Expanded(
                child: CategoryGrid(
                  categories: withAll,
                  prefs: prefs,
                  section: 'movies',
                  onNavigate: (cat) => context.go(
                    '/movies/${cat.categoryId}'
                    '?name=${Uri.encodeComponent(cat.categoryName)}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

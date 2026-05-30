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
import '../../services/xtream_service.dart';

final liveCategoriesProvider = FutureProvider<List<LiveCategory>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  return ref.read(xtreamServiceProvider).getLiveCategories(playlist);
});

// Synthetic "All Channels" category — always shown first.
const _allCategory = LiveCategory(
  categoryId: AppConstants.catAllId,
  categoryName: 'All Channels',
  parentId: 0,
);

class LiveCategoriesScreen extends ConsumerWidget {
  const LiveCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(liveCategoriesProvider);
    final prefs = ref.watch(categoryPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const LoadingGrid(),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(liveCategoriesProvider)),
        data: (categories) {
          final visible = applyOrderAndFilter(categories, prefs, 'live');
          // Prepend the "All" card — it's never hidden/locked
          final withAll = [_allCategory, ...visible];

          return Column(
            children: [
              const RecentlyWatchedRow(type: 'live'),
              Expanded(
                child: CategoryGrid(
                  categories: withAll,
                  prefs: prefs,
                  section: 'live',
                  onNavigate: (cat) => context.go(
                    '/live/${cat.categoryId}'
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

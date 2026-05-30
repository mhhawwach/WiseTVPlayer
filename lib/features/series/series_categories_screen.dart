import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/category_prefs_notifier.dart';
import '../../core/storage/storage_service.dart';
import '../../core/widgets/category_grid.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_grid.dart';
import '../../data/models/live_category.dart';
import '../../features/series/series_list_screen.dart';
import '../../services/xtream_service.dart';

final seriesCategoriesProvider = FutureProvider<List<LiveCategory>>((ref) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  return ref.read(xtreamServiceProvider).getSeriesCategories(playlist);
});

const _allCategory = LiveCategory(
  categoryId: AppConstants.catAllId,
  categoryName: 'All Series',
  parentId: 0,
);

class SeriesCategoriesScreen extends ConsumerWidget {
  const SeriesCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(seriesCategoriesProvider);
    final prefs = ref.watch(categoryPrefsProvider);
    // Prefetch the full series list while the user browses categories.
    ref.watch(allSeriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('TV Series')),
      body: async.when(
        loading: () => const LoadingGrid(),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(seriesCategoriesProvider)),
        data: (cats) {
          final visible = applyOrderAndFilter(cats, prefs, 'series');
          final withAll = [_allCategory, ...visible];

          return CategoryGrid(
            categories: withAll,
            prefs: prefs,
            section: 'series',
            onNavigate: (cat) => context.go(
              '/series/${cat.categoryId}'
              '?name=${Uri.encodeComponent(cat.categoryName)}',
            ),
          );
        },
      ),
    );
  }
}

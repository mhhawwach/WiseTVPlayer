import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/category_prefs_notifier.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_grid.dart';
import '../../data/models/live_category.dart';
import '../../features/live_tv/live_categories_screen.dart';
import '../../features/movies/movies_categories_screen.dart';
import '../../features/series/series_categories_screen.dart';
import '../../features/parental/pin_dialog.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  ConsumerState<CategoryManagerScreen> createState() =>
      _CategoryManagerScreenState();
}

class _CategoryManagerScreenState
    extends ConsumerState<CategoryManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Live TV'),
            Tab(text: 'Movies'),
            Tab(text: 'Series'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CatManagerTab(section: 'live'),
          _CatManagerTab(section: 'movies'),
          _CatManagerTab(section: 'series'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CatManagerTab extends ConsumerWidget {
  const _CatManagerTab({required this.section});
  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(categoryPrefsProvider);

    final asyncData = switch (section) {
      'live' => ref.watch(liveCategoriesProvider),
      'movies' => ref.watch(vodCategoriesProvider),
      _ => ref.watch(seriesCategoriesProvider),
    };

    return asyncData.when(
      loading: () => const LoadingGrid(),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () {
          switch (section) {
            case 'live': ref.invalidate(liveCategoriesProvider);
            case 'movies': ref.invalidate(vodCategoriesProvider);
            default: ref.invalidate(seriesCategoriesProvider);
          }
        },
      ),
      data: (cats) {
        final ordered = _applyOrder(cats, section);
        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          onReorderItem: (oldIdx, newIdx) =>
              _reorder(ref, ordered, oldIdx, newIdx),
          itemCount: ordered.length,
          itemBuilder: (_, i) {
            final cat = ordered[i];
            final hidden = prefs.hidden.contains(cat.categoryId);
            final locked = prefs.locked.contains(cat.categoryId);

            return ListTile(
              key: ValueKey(cat.categoryId),
              leading: const Icon(Icons.drag_handle,
                  color: AppColors.textMuted),
              title: Text(
                cat.categoryName,
                style: TextStyle(
                  color: hidden
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  decoration:
                      hidden ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock toggle
                  IconButton(
                    icon: Icon(
                      locked ? Icons.lock : Icons.lock_open_outlined,
                      color: locked
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: locked ? 'Unlock' : 'Lock with PIN',
                    onPressed: () =>
                        _toggleLock(context, ref, cat.categoryId, locked),
                  ),
                  // Hide toggle
                  IconButton(
                    icon: Icon(
                      hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: hidden
                          ? AppColors.liveRed
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: hidden ? 'Show' : 'Hide',
                    onPressed: () => ref
                        .read(categoryPrefsProvider.notifier)
                        .toggleHidden(cat.categoryId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<LiveCategory> _applyOrder(List<LiveCategory> cats, String section) {
    final order = StorageService.getCategoryOrder(section);
    if (order.isEmpty) return cats;
    final map = {for (final c in cats) c.categoryId: c};
    final sorted = <LiveCategory>[];
    for (final id in order) {
      if (map.containsKey(id)) sorted.add(map.remove(id)!);
    }
    sorted.addAll(map.values); // append any new cats not in saved order
    return sorted;
  }

  Future<void> _reorder(WidgetRef ref, List<LiveCategory> current,
      int oldIdx, int newIdx) async {
    // onReorderItem already adjusts newIndex — no correction needed here.
    final list = List<LiveCategory>.from(current);
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);
    await StorageService.setCategoryOrder(
        section, list.map((c) => c.categoryId).toList());
    // Refresh the prefs notifier so category screens re-sort
    ref.read(categoryPrefsProvider.notifier).reload();
  }

  Future<void> _toggleLock(BuildContext context, WidgetRef ref,
      String id, bool currentlyLocked) async {
    if (currentlyLocked) {
      // Unlock: require current PIN
      if (StorageService.hasParentalPin) {
        final ok =
            await showPinDialog(context, title: 'Enter PIN to unlock');
        if (!ok) return;
      }
      await ref.read(categoryPrefsProvider.notifier).toggleLocked(id);
    } else {
      // Lock: require PIN to be set first
      if (!StorageService.hasParentalPin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Set a parental PIN in Settings first')));
        return;
      }
      await ref.read(categoryPrefsProvider.notifier).toggleLocked(id);
    }
  }
}

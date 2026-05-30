import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

/// Holds the current visibility / lock state for all categories.
class CategoryPrefs {
  final Set<String> hidden;
  final Set<String> locked;

  const CategoryPrefs({
    this.hidden = const {},
    this.locked = const {},
  });

  CategoryPrefs copyWith({Set<String>? hidden, Set<String>? locked}) =>
      CategoryPrefs(
        hidden: hidden ?? this.hidden,
        locked: locked ?? this.locked,
      );
}

class CategoryPrefsNotifier extends StateNotifier<CategoryPrefs> {
  CategoryPrefsNotifier()
      : super(CategoryPrefs(
          hidden: StorageService.hiddenCategoryIds,
          locked: StorageService.lockedCategoryIds,
        ));

  Future<void> toggleHidden(String id) async {
    await StorageService.toggleCategoryHidden(id);
    state = state.copyWith(hidden: StorageService.hiddenCategoryIds);
  }

  Future<void> toggleLocked(String id) async {
    await StorageService.toggleCategoryLocked(id);
    state = state.copyWith(locked: StorageService.lockedCategoryIds);
  }

  void reload() {
    state = CategoryPrefs(
      hidden: StorageService.hiddenCategoryIds,
      locked: StorageService.lockedCategoryIds,
    );
  }
}

final categoryPrefsProvider =
    StateNotifierProvider<CategoryPrefsNotifier, CategoryPrefs>(
  (ref) => CategoryPrefsNotifier(),
);

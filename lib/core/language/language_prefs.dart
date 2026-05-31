/// Riverpod state + pure helpers for the per-profile / per-playlist content
/// language filter.
///
/// Deliberately depends on **core only** (the classifier, the [LiveCategory]
/// model, and [StorageService]) — never on feature screens — so the feature
/// screens can import this without creating an import cycle. Each consumer
/// watches the category list it already has plus [languagePrefsProvider] and
/// calls [blockedCategoryIdsFor] / [effectiveSelection].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/live_category.dart';
import '../storage/storage_service.dart';
import 'category_language.dart';

/// Holds the **stored** language selection for the active playlist, or `null`
/// when the user has not chosen yet (downstream then applies the auto-detected
/// default, so a fresh profile still gets the Arabic+English experience).
class LanguagePrefsNotifier extends StateNotifier<Set<String>?> {
  LanguagePrefsNotifier() : super(_loadForActive());

  static Set<String>? _loadForActive() {
    final pid = StorageService.activePlaylistId;
    if (pid == null) return null;
    return StorageService.selectedLanguages(pid);
  }

  /// Re-read from storage — call after a profile or playlist switch.
  void reload() => state = _loadForActive();

  /// Persist [langs] for the active playlist and update listeners immediately.
  Future<void> setSelected(Set<String> langs) async {
    final pid = StorageService.activePlaylistId;
    if (pid == null) return;
    await StorageService.setSelectedLanguages(pid, langs);
    state = langs;
  }
}

final languagePrefsProvider =
    StateNotifierProvider<LanguagePrefsNotifier, Set<String>?>(
  (ref) => LanguagePrefsNotifier(),
);

/// The selection actually applied to [cats]: the user's [stored] choice, or —
/// when they haven't chosen — the auto-detected default (Arabic+English where
/// present, otherwise everything). Pure; safe to call in build().
Set<String> effectiveSelection(
    Iterable<LiveCategory> cats, Set<String>? stored) {
  if (stored != null) return stored;
  final present = CategoryLanguage.languagesPresent(cats);
  return CategoryLanguage.defaultSelectionFor(present);
}

/// The set of category IDs to hide given [cats] and the [stored] selection.
/// Categories with no language marker are never included (always shown).
Set<String> blockedCategoryIdsFor(
    Iterable<LiveCategory> cats, Set<String>? stored) {
  final catList = cats is List<LiveCategory> ? cats : cats.toList();
  if (catList.isEmpty) return const {};
  return CategoryLanguage.blockedCategoryIds(
      catList, effectiveSelection(catList, stored));
}

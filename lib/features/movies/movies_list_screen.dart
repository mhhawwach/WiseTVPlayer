import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/language/language_prefs.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/rating.dart';
import '../../core/utils/year_parser.dart';
import '../../core/widgets/color_shortcut_bar.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/widgets/loading_grid.dart';
import '../../core/widgets/tv_focus.dart';
import '../../data/models/live_category.dart';
import '../../data/models/vod_stream.dart';
import '../../services/xtream_service.dart';
import '../favourites/favourites_screen.dart';
import 'movies_categories_screen.dart' show vodCategoriesProvider;

// ── Sort mode ─────────────────────────────────────────────────────────────────

enum _SortMode { defaultOrder, nameAZ, nameZA, ratingDesc, recentlyAdded, byYear }

// ── Provider ──────────────────────────────────────────────────────────────────
// Always fetches ALL movies in one call and filters client-side.
// Advantages over per-category fetching:
//   • One network request total — any category tap is instant after first load
//   • Single cache entry shared across all category views
//   • keepAlive means the list survives navigation — zero re-fetches

final allVodStreamsProvider = FutureProvider<List<VodStream>>((ref) async {
  ref.keepAlive();
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  return ref.read(xtreamServiceProvider).getVodStreams(playlist, categoryId: null);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MoviesListScreen extends ConsumerStatefulWidget {
  const MoviesListScreen(
      {super.key, required this.categoryId, required this.categoryName});
  final String categoryId;
  final String categoryName;

  @override
  ConsumerState<MoviesListScreen> createState() => _MoviesListScreenState();
}

class _MoviesListScreenState extends ConsumerState<MoviesListScreen> {
  String _search    = '';
  _SortMode _sort   = _SortMode.defaultOrder;

  // Colour-shortcut plumbing: jump to search (red), open the sort menu (blue),
  // favourite the highlighted poster (yellow). `_focused` tracks the focused
  // card without rebuilding the grid on every D-pad move.
  final FocusNode _searchFocus = searchEscapeFocusNode();
  final GlobalKey<PopupMenuButtonState<_SortMode>> _sortKey = GlobalKey();
  VodStream? _focused;

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _favouriteFocused() {
    final m = _focused;
    if (m == null) return;
    StorageService.toggleFavourite('vod', m.streamId, {
      'type': 'vod', 'id': m.streamId, 'name': m.name,
      'icon': m.streamIcon, 'ext': m.containerExtension,
    });
    final added = StorageService.isFavourite('vod', m.streamId);
    setState(() {}); // refresh the star badge
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(added ? '★ Added to Favourites' : 'Removed from Favourites'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _openFavourites() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const FavouritesScreen()));

  String _sortLabel(_SortMode m, AppStrings s) => switch (m) {
        _SortMode.defaultOrder  => s.sortDefault,
        _SortMode.nameAZ        => s.sortNameAZ,
        _SortMode.nameZA        => s.sortNameZA,
        _SortMode.ratingDesc    => s.sortRating,
        _SortMode.recentlyAdded => s.sortRecentlyAdded,
        _SortMode.byYear        => s.sortByYear,
      };

  List<VodStream> _process(List<VodStream> allMovies, Set<String> langBlocked) {
    // Step 1 — category filter (client-side, instant)
    var list = widget.categoryId == AppConstants.catAllId
        ? allMovies
        : allMovies
            .where((m) => m.categoryId == widget.categoryId)
            .toList();

    // Step 1b — language filter. Drops movies whose category is in an
    // unselected language. A no-op when viewing one (already-allowed) category;
    // only bites in the "All Movies" view.
    if (langBlocked.isNotEmpty) {
      list = list.where((m) => !langBlocked.contains(m.categoryId)).toList();
    }

    // Step 2 — search filter
    if (_search.isNotEmpty) {
      list = list.where((m) => m.name.toLowerCase().contains(_search)).toList();
    }

    switch (_sort) {
      case _SortMode.nameAZ:
        list = [...list]..sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.nameZA:
        list = [...list]..sort((a, b) => b.name.compareTo(a.name));
      case _SortMode.ratingDesc:
        list = [...list]..sort((a, b) {
            final ra = parseRating(a.rating) ?? 0;
            final rb = parseRating(b.rating) ?? 0;
            return rb.compareTo(ra);
          });
      case _SortMode.recentlyAdded:
        // `added` is a Unix-timestamp string from the Xtream API
        list = [...list]..sort((a, b) {
            final ta = int.tryParse(a.added) ?? 0;
            final tb = int.tryParse(b.added) ?? 0;
            return tb.compareTo(ta); // newest first
          });
      case _SortMode.byYear:
        // Extract production year from title (e.g. "Movie Name (2024)")
        list = [...list]..sort((a, b) {
            final ya = YearParser.parseYearFromTitle(a.name) ?? 0;
            final yb = YearParser.parseYearFromTitle(b.name) ?? 0;
            return yb.compareTo(ya); // newest year first
          });
      case _SortMode.defaultOrder:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s     = ref.watch(stringsProvider);
    final async = ref.watch(allVodStreamsProvider);
    final langPrefs = ref.watch(languagePrefsProvider);
    final vodCats =
        ref.watch(vodCategoriesProvider).value ?? const <LiveCategory>[];
    final langBlocked = blockedCategoryIdsFor(vodCats, langPrefs);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          PopupMenuButton<_SortMode>(
            key: _sortKey,
            icon: const Icon(Icons.sort_rounded, size: 22),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => _SortMode.values
                .map((m) => PopupMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          if (m == _sort)
                            Icon(Icons.check, size: 16, color: AppColors.primary)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(_sortLabel(m, s)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: s.searchMoviesHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: ColorShortcuts(
        onSearch: () => _searchFocus.requestFocus(),
        onSort: () => _sortKey.currentState?.showButtonMenu(),
        onFavouriteKey: _favouriteFocused,
        onFavouriteTap: _openFavourites,
        child: async.when(
          loading: () => const LoadingGrid(aspectRatio: 0.7),
          error: (e, _) => Center(
              child: Text(e.toString(),
                  style: const TextStyle(color: AppColors.textSecondary))),
          data: (movies) {
            final filtered = _process(movies, langBlocked);
            if (filtered.isEmpty) {
              return Center(
                child: Text(s.noMoviesFound,
                    style: const TextStyle(color: AppColors.textSecondary)),
              );
            }
            // Default the highlight to the first poster so the yellow button
            // has a target even before the grid reports its first focus event.
            _focused ??= filtered.first;

            final cols = MediaQuery.of(context).size.width > 900 ? 6 : 3;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.62,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _PosterCard(
                key: ValueKey(filtered[i].streamId),
                name: filtered[i].name,
                imageUrl: filtered[i].streamIcon,
                rating: filtered[i].rating,
                autofocus: i == 0,
                isFavourite: StorageService.isFavourite('vod', filtered[i].streamId),
                onFocus: (f) {
                  if (f) _focused = filtered[i];
                },
                onTap: () => context.go('/movies/detail', extra: filtered[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Premium poster card ───────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.autofocus,
    required this.onTap,
    this.isFavourite = false,
    this.onFocus,
  });

  final String name;
  final String imageUrl;
  final String rating;
  final bool autofocus;
  final VoidCallback onTap;
  final bool isFavourite;
  final ValueChanged<bool>? onFocus;

  @override
  Widget build(BuildContext context) {
    final ratingLabel = formatRatingLabel(rating);
    final hasRating = ratingLabel != null;

    return FocusableCard(
      autofocus: autofocus,
      onPressed: onTap,
      onFocusChange: onFocus,
      borderRadius: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image — full bleed (optimization #3: custom CacheManager)
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 320,
                    cacheManager: AppImageCacheManager(),
                    errorWidget: (_, __, ___) => _PosterPlaceholder(name: name),
                    placeholder: (_, __) =>
                        Container(color: AppColors.surfaceVariant),
                  )
                : _PosterPlaceholder(name: name),

            // Bottom gradient + title
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xEE000000), Color(0x00000000)],
                    stops: [0.0, 0.75],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ),
            ),

            // Favourite star (top-left) — set via the yellow remote button.
            if (isFavourite)
              Positioned(
                top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFFFBC02D), size: 14),
                ),
              ),

            // Rating badge
            if (hasRating)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFB300), size: 10),
                      const SizedBox(width: 2),
                      Text(
                        ratingLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_creation_outlined,
              color: AppColors.textMuted, size: 28),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              name,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

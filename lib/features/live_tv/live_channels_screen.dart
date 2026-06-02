import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/category_prefs_notifier.dart';
import '../../core/storage/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/category_grid.dart';
import '../../core/widgets/color_shortcut_bar.dart';
import '../../core/widgets/focusable_card.dart';
import '../../core/widgets/loading_grid.dart';
import '../../core/widgets/tv_focus.dart';
import '../../data/models/epg_listing.dart';
import '../../data/models/live_category.dart';
import '../../data/models/live_stream.dart';
import '../../features/epg/epg_panel.dart';
import '../../features/favourites/favourites_screen.dart';
import '../../features/player/live_player_screen.dart';
import '../../features/player/widgets/aspect_mode.dart';
import '../../features/live_tv/catch_up_panel.dart';
import '../../features/live_tv/live_categories_screen.dart';
import '../../services/player/player_factory.dart';
import '../../services/xtream_service.dart';

// ── View mode (grid of logos ⇄ list with now/next EPG) ─────────────────────────

enum _ViewMode { grid, list }

// ── Sort mode ─────────────────────────────────────────────────────────────────

enum _SortMode { defaultOrder, nameAZ, nameZA }

extension on _SortMode {
  String get label => switch (this) {
        _SortMode.defaultOrder => 'Default',
        _SortMode.nameAZ => 'A → Z',
        _SortMode.nameZA => 'Z → A',
      };
}

// ── Provider ──────────────────────────────────────────────────────────────────

final liveChannelsProvider =
    FutureProvider.family<List<LiveStream>, String>((ref, categoryId) async {
  final id = StorageService.activePlaylistId;
  if (id == null) return [];
  final playlist = StorageService.getPlaylist(id);
  if (playlist == null) return [];
  // '__all__' means no category filter — fetch every channel
  final catId = categoryId == AppConstants.catAllId ? null : categoryId;
  return ref
      .read(xtreamServiceProvider)
      .getLiveStreams(playlist, categoryId: catId);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class LiveChannelsScreen extends ConsumerStatefulWidget {
  const LiveChannelsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  final String categoryId;
  final String categoryName;

  @override
  ConsumerState<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends ConsumerState<LiveChannelsScreen> {
  String _search = '';
  _SortMode _sort = _SortMode.defaultOrder;
  // Default to the distinctive now/next list view; users can toggle to grid.
  _ViewMode _view = _ViewMode.list;

  final FocusNode _searchFocus = searchEscapeFocusNode();

  static const _viewKey = 'live_view_mode';

  @override
  void initState() {
    super.initState();
    final saved = StorageService.getSetting<String>(_viewKey);
    if (saved == 'grid') _view = _ViewMode.grid;
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() => _view =
        _view == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid);
    StorageService.setSetting(
        _viewKey, _view == _ViewMode.list ? 'list' : 'grid');
  }

  List<LiveStream> _process(List<LiveStream> channels) {
    var list = _search.isEmpty
        ? channels
        : channels
            .where((c) => c.name.toLowerCase().contains(_search))
            .toList();

    switch (_sort) {
      case _SortMode.nameAZ:
        list = [...list]..sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.nameZA:
        list = [...list]..sort((a, b) => b.name.compareTo(a.name));
      case _SortMode.defaultOrder:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(liveChannelsProvider(widget.categoryId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: Icon(
              _view == _ViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              size: 22,
            ),
            tooltip: _view == _ViewMode.grid ? 'List view' : 'Grid view',
            onPressed: _toggleView,
          ),
          PopupMenuButton<_SortMode>(
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
                            Icon(Icons.check,
                                size: 16, color: AppColors.primary)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(m.label),
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
              decoration: const InputDecoration(
                hintText: 'Search channels...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: channelsAsync.when(
        loading: () => const LoadingGrid(aspectRatio: 1.55),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (channels) {
          final filtered = _process(channels);
          return _view == _ViewMode.grid
              ? _ChannelGrid(channels: filtered, allChannels: channels)
              : _ChannelList(channels: filtered, allChannels: channels);
        },
      ),
    );
  }
}

// ── Grid ──────────────────────────────────────────────────────────────────────

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
    required this.channels,
    required this.allChannels,
  });

  final List<LiveStream> channels;
  final List<LiveStream> allChannels;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const Center(
        child: Text('No channels found',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final cols = MediaQuery.of(context).size.width > 900 ? 5 : 3;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: channels.length,
      itemBuilder: (_, i) {
        final ch = channels[i];
        return _ChannelCard(
          key: ValueKey(ch.streamId),
          channel: ch,
          autofocus: i == 0,
          onTap: () {
            final id = StorageService.activePlaylistId!;
            final playlist = StorageService.getPlaylist(id)!;
            context.push('/player/live',
                extra: LivePlayerArgs(
                  stream: ch,
                  playlist: playlist,
                  channelList: allChannels,
                  initialIndex: allChannels.indexOf(ch),
                ));
          },
        );
      },
    );
  }
}

// ── Premium channel card ──────────────────────────────────────────────────────

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    super.key,
    required this.channel,
    required this.autofocus,
    required this.onTap,
  });

  final LiveStream channel;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      autofocus: autofocus,
      onPressed: onTap,
      borderRadius: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Container(color: AppColors.card),

            // Channel logo — contained, centered in upper portion
            Positioned(
              top: 10,
              left: 8,
              right: 8,
              bottom: 28,
              child: channel.streamIcon.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: channel.streamIcon,
                      fit: BoxFit.contain,
                      memCacheHeight: 80,
                      errorWidget: (_, __, ___) =>
                          _ChannelLogoPlaceholder(name: channel.name),
                      placeholder: (_, __) =>
                          Container(color: AppColors.surfaceVariant),
                    )
                  : _ChannelLogoPlaceholder(name: channel.name),
            ),

            // Bottom strip — channel name
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.divider,
                      width: 1,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),

            // LIVE indicator — top right
            Positioned(
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.liveRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: AppColors.liveRed,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // CatchUp badge — top left (tappable)
            if (channel.hasCatchUp)
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showCatchUpPanel(context, channel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded,
                            color: Colors.white, size: 9),
                        SizedBox(width: 2),
                        Text(
                          'CU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChannelLogoPlaceholder extends StatelessWidget {
  const _ChannelLogoPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.live_tv_rounded, color: AppColors.textMuted, size: 22),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 9, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List view with now/next EPG ───────────────────────────────────────────────

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.allChannels,
    this.autofocusFirst = true,
    this.onChannelFocus,
    this.onChannelOpen,
  });

  final List<LiveStream> channels;
  final List<LiveStream> allChannels;

  /// When false, the first row does not grab focus on build — used by the
  /// two-pane layout so the category list keeps initial focus.
  final bool autofocusFirst;

  /// Fired when a channel row gains focus (drives the live mini-preview).
  final ValueChanged<LiveStream>? onChannelFocus;

  /// Called when a channel is opened. Returns the warmed-up preview player to
  /// hand off to the fullscreen screen for a seamless, re-buffer-free entry —
  /// or null to open the stream fresh. Also stops the preview when not handing
  /// off, so two decoders never run at once.
  final AppPlayer? Function(LiveStream ch)? onChannelOpen;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const Center(
        child: Text('No channels found',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 100),
      itemCount: channels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final ch = channels[i];
        return _ChannelListRow(
          key: ValueKey(ch.streamId),
          channel: ch,
          autofocus: autofocusFirst && i == 0,
          onFocus: onChannelFocus,
          onTap: () {
            final warm = onChannelOpen?.call(ch);
            final id = StorageService.activePlaylistId!;
            final playlist = StorageService.getPlaylist(id)!;
            context.push('/player/live',
                extra: LivePlayerArgs(
                  stream: ch,
                  playlist: playlist,
                  channelList: allChannels,
                  initialIndex: allChannels.indexOf(ch),
                  warmPlayer: warm,
                ));
          },
        );
      },
    );
  }
}

class _ChannelListRow extends ConsumerWidget {
  const _ChannelListRow({
    super.key,
    required this.channel,
    required this.autofocus,
    required this.onTap,
    this.onFocus,
  });

  final LiveStream channel;
  final bool autofocus;
  final VoidCallback onTap;
  final ValueChanged<LiveStream>? onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // EPG can be disabled via a feature flag. When off, skip the per-channel
    // fetch entirely and render a clean row (no now/next).
    const epgOn = AppConstants.epgEnabled;
    final epgAsync =
        epgOn ? ref.watch(epgProvider(channel.streamId)) : null;
    final (EpgListing?, EpgListing?) nowNext =
        epgOn ? _nowNext(epgAsync!.valueOrNull ?? const []) : (null, null);
    final now = nowNext.$1;
    final next = nowNext.$2;

    return Semantics(
      button: true,
      label: now != null
          ? '${channel.name}, now playing ${now.title}'
          : channel.name,
      child: FocusableCard(
        autofocus: autofocus,
        onPressed: onTap,
        onFocusChange: onFocus == null ? null : (f) { if (f) onFocus!(channel); },
        borderRadius: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 42,
                child: channel.streamIcon.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: channel.streamIcon,
                        fit: BoxFit.contain,
                        memCacheHeight: 84,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.live_tv_rounded,
                            color: AppColors.textMuted,
                            size: 22),
                        placeholder: (_, __) =>
                            Container(color: AppColors.surfaceVariant),
                      )
                    : const Icon(Icons.live_tv_rounded,
                        color: AppColors.textMuted, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (now != null) ...[
                      Text(
                        now.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (now.progressPercent > 0) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: now.progressPercent,
                            backgroundColor: AppColors.divider,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                            minHeight: 2,
                          ),
                        ),
                      ],
                      if (next != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Next: ${next.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ] else if (epgOn)
                      Text(
                        epgAsync!.isLoading
                            ? 'Loading guide…'
                            : 'No guide data',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LiveDot(),
                      SizedBox(width: 3),
                      Text('LIVE',
                          style: TextStyle(
                            color: AppColors.liveRed,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          )),
                    ],
                  ),
                  if (channel.hasCatchUp) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showCatchUpPanel(context, channel),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded,
                                color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text('CU',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks the current programme and the one that follows it.
  static (EpgListing?, EpgListing?) _nowNext(List<EpgListing> listings) {
    if (listings.isEmpty) return (null, null);
    final nowIdx = listings.indexWhere((e) => e.nowPlaying);
    if (nowIdx >= 0) {
      final now = listings[nowIdx];
      final next =
          nowIdx + 1 < listings.length ? listings[nowIdx + 1] : null;
      return (now, next);
    }
    final dtNow = DateTime.now();
    for (var i = 0; i < listings.length; i++) {
      final s = listings[i].startTime;
      final e = listings[i].stopTime;
      if (s != null && e != null && dtNow.isAfter(s) && dtNow.isBefore(e)) {
        return (listings[i], i + 1 < listings.length ? listings[i + 1] : null);
      }
    }
    return (null, listings.first);
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AppColors.liveRed,
          shape: BoxShape.circle,
        ),
      );
}

// Shared search + sort processing for channel lists.
List<LiveStream> _processChannels(
    List<LiveStream> channels, String search, _SortMode sort) {
  var list = search.isEmpty
      ? channels
      : channels.where((c) => c.name.toLowerCase().contains(search)).toList();
  switch (sort) {
    case _SortMode.nameAZ:
      list = [...list]..sort((a, b) => a.name.compareTo(b.name));
    case _SortMode.nameZA:
      list = [...list]..sort((a, b) => b.name.compareTo(a.name));
    case _SortMode.defaultOrder:
      break;
  }
  return list;
}

// ═════════════════════════════════════════════════════════════════════════════
// Two-pane Live TV — categories on the left, channels on the right.
// This is the DEFAULT Live TV layout (TV-friendly nested lists). Arrowing
// through categories live-updates the channel pane; arrow-right enters it.
// ═════════════════════════════════════════════════════════════════════════════

class LiveTwoPaneScreen extends ConsumerStatefulWidget {
  const LiveTwoPaneScreen({super.key});

  @override
  ConsumerState<LiveTwoPaneScreen> createState() => _LiveTwoPaneScreenState();
}

class _LiveTwoPaneScreenState extends ConsumerState<LiveTwoPaneScreen> {
  String _catId = AppConstants.catAllId;
  String _catName = 'All Channels';
  String _search = '';
  _SortMode _sort = _SortMode.defaultOrder;

  // Reliably land focus on the first category once the (async) list is ready.
  final FocusNode _firstCatFocus = FocusNode(debugLabel: 'live-first-cat');
  // Search field uses the escape node so Down drops into the category list
  // instead of trapping the D-pad on the box.
  final FocusNode _searchFocus = searchEscapeFocusNode();
  bool _didInitialFocus = false;

  @override
  void dispose() {
    _firstCatFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(LiveCategory c) {
    if (_catId == c.categoryId) return;
    setState(() {
      _catId = c.categoryId;
      _catName = c.categoryName;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (categories) {
          final visible = applyOrderAndFilter(categories, prefs, 'live');
          final cats = <LiveCategory>[
            const LiveCategory(
              categoryId: AppConstants.catAllId,
              categoryName: 'All Channels',
              parentId: 0,
            ),
            ...visible,
          ];

          // Land focus on the first category once the list is ready. autofocus
          // alone is unreliable here because the items build after the loading
          // frame, so we also request it explicitly on the first data build.
          if (!_didInitialFocus) {
            _didInitialFocus = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _firstCatFocus.requestFocus();
            });
          }

          return Row(
            children: [
              // ── Left: search-all + category list ─────────────────────────
              SizedBox(
                width: 264,
                child: ColoredBox(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      // Search across ALL channels (overrides the selected
                      // category while there's a query).
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: TextField(
                          focusNode: _searchFocus,
                          onChanged: (v) =>
                              setState(() => _search = v.toLowerCase()),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Search all channels...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: cats.length,
                          itemBuilder: (_, i) {
                            final c = cats[i];
                            return _CategoryRailItem(
                              category: c,
                              selected: c.categoryId == _catId,
                              autofocus: i == 0,
                              focusNode: i == 0 ? _firstCatFocus : null,
                              onSelected: () => _select(c),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: AppColors.divider),
              // ── Right: channels (selected category, or all when searching) ─
              Expanded(
                child: _LiveRightPane(
                  catId: _catId,
                  catName: _catName,
                  search: _search,
                  sort: _sort,
                  onSort: (m) => setState(() => _sort = m),
                  onSearch: () => _searchFocus.requestFocus(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveRightPane extends ConsumerStatefulWidget {
  const _LiveRightPane({
    required this.catId,
    required this.catName,
    required this.search,
    required this.sort,
    required this.onSort,
    required this.onSearch,
  });

  final String catId;
  final String catName;
  final String search;
  final _SortMode sort;
  final ValueChanged<_SortMode> onSort;
  final VoidCallback onSearch;

  @override
  ConsumerState<_LiveRightPane> createState() => _LiveRightPaneState();
}

class _LiveRightPaneState extends ConsumerState<_LiveRightPane> {
  // Mini-preview (wide layouts only): a lightweight player that follows the
  // highlighted channel after a short dwell. Paused before opening fullscreen
  // so two decoders never run at once. Phones/narrow keep the plain list.
  AppPlayer? _preview;
  Timer? _previewTimer;
  int? _previewId;
  String _previewName = '';

  // Tracks the highlighted channel so the yellow shortcut can favourite it,
  // and a key so the blue shortcut can open the sort menu.
  LiveStream? _focusedChannel;
  final GlobalKey<PopupMenuButtonState<_SortMode>> _sortKey = GlobalKey();

  AppPlayer _ensurePreview() => _preview ??= PlayerFactory.create();

  void _favouriteFocused() {
    final ch = _focusedChannel;
    if (ch == null) return;
    StorageService.toggleFavourite('live', ch.streamId, {
      'type': 'live', 'id': ch.streamId, 'name': ch.name, 'icon': ch.streamIcon,
    });
    final added = StorageService.isFavourite('live', ch.streamId);
    if (mounted) setState(() {});
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

  void _schedulePreview(LiveStream ch) {
    if (_previewId == ch.streamId) return;
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final id = StorageService.activePlaylistId;
      final pl = id != null ? StorageService.getPlaylist(id) : null;
      if (pl == null) return;
      _previewId = ch.streamId;
      setState(() => _previewName = ch.name);
      _ensurePreview().open(pl.liveStreamUrl(ch.streamId.toString(), 'ts'));
    });
  }

  /// Called when a channel is opened fullscreen. If the preview is *already
  /// playing this exact channel*, relinquish ownership of that warmed-up player
  /// and return it so the fullscreen screen can adopt it (seamless, no
  /// re-buffer). Otherwise just stop the preview and return null (fresh open).
  AppPlayer? _handoffForOpen(LiveStream ch) {
    _previewTimer?.cancel();
    if (_preview != null && _previewId == ch.streamId) {
      final warm = _preview;
      // Drop our reference WITHOUT disposing — the fullscreen player owns it
      // now. Rebuild so the (now-detached) preview pane spins up a fresh,
      // empty player rather than rendering the handed-off one twice.
      _preview = null;
      _previewId = null;
      setState(() {});
      return warm;
    }
    _previewId = null;
    _preview?.pause();
    return null;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _preview?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = widget.search.isNotEmpty;
    // While searching, query ALL channels regardless of the selected category.
    final effectiveCatId = searching ? AppConstants.catAllId : widget.catId;
    final channelsAsync = ref.watch(liveChannelsProvider(effectiveCatId));
    // Show the preview on landscape, roomy layouts. TVs report a SCALED logical
    // width (e.g. a 1080p panel at 320dpi = 960 logical px), so the old ≥1200
    // gate wrongly excluded them. Gate on landscape + ≥900 instead.
    final mq = MediaQuery.of(context).size;
    final wide = mq.width >= 900 && mq.width > mq.height;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  searching ? 'Search results' : widget.catName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<_SortMode>(
                key: _sortKey,
                icon: const Icon(Icons.sort_rounded, size: 22),
                tooltip: 'Sort',
                initialValue: widget.sort,
                onSelected: widget.onSort,
                itemBuilder: (_) => _SortMode.values
                    .map((m) => PopupMenuItem(value: m, child: Text(m.label)))
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ColorShortcuts(
            onSearch: widget.onSearch,
            onSort: () => _sortKey.currentState?.showButtonMenu(),
            onFavouriteKey: _favouriteFocused,
            onFavouriteTap: _openFavourites,
            child: channelsAsync.when(
            loading: () => const LoadingGrid(aspectRatio: 1.55),
            error: (e, _) => Center(
              child: Text(e.toString(),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            data: (channels) {
              final filtered =
                  _processChannels(channels, widget.search, widget.sort);
              final list = _ChannelList(
                channels: filtered,
                allChannels: channels,
                autofocusFirst: false,
                onChannelFocus: (ch) {
                  _focusedChannel = ch;
                  if (wide) _schedulePreview(ch);
                },
                onChannelOpen: wide ? _handoffForOpen : null,
              );
              if (!wide) return list;
              // Proportional preview width so it fits both 960-logical TVs and
              // full-HD-logical desktops.
              return LayoutBuilder(
                builder: (ctx, cons) {
                  final pvW = (cons.maxWidth * 0.42).clamp(260.0, 520.0);
                  return Row(
                    children: [
                      Expanded(child: list),
                      SizedBox(
                        width: pvW,
                        child: _PreviewPane(player: _ensurePreview(), name: _previewName),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ),
        ),
      ],
    );
  }
}

// Mini-preview pane shown to the right of the channel list on wide screens.
class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.player, required this.name});
  final AppPlayer player;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: Colors.black,
                child: player.buildVideoWidget(context, AspectMode.contain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? 'Highlight a channel to preview' : name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Press OK to watch fullscreen',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CategoryRailItem extends StatefulWidget {
  const _CategoryRailItem({
    required this.category,
    required this.selected,
    required this.autofocus,
    required this.onSelected,
    this.focusNode,
  });

  final LiveCategory category;
  final bool selected;
  final bool autofocus;
  final VoidCallback onSelected;
  final FocusNode? focusNode;

  @override
  State<_CategoryRailItem> createState() => _CategoryRailItemState();
}

class _CategoryRailItemState extends State<_CategoryRailItem>
    with AutomaticKeepAliveClientMixin {
  bool _focused = false;

  @override
  bool get wantKeepAlive => _focused;

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep the focused category alive in the lazy list
    final active = widget.selected;
    return Semantics(
      button: true,
      selected: active,
      label: widget.category.categoryName,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (f) {
          setState(() => _focused = f);
          updateKeepAlive();
          // Live-preview the channels as the user arrows through categories.
          if (f) widget.onSelected();
        },
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onSelected();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onSelected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.focus.withValues(alpha: 0.18)
                  : active
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? AppColors.focus
                    : active
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                width: _focused ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.category.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/content_refresh.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/storage/storage_service.dart';
import '../../core/utils/content_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/clapper_logo.dart';
import '../playlists/playlists_screen.dart';
import '../profiles/profiles_screen.dart';

class _Tab {
  final IconData activeIcon;
  final IconData icon;
  /// Label is derived from [AppStrings] at build time — not stored here.
  const _Tab(this.activeIcon, this.icon);
}

const _tabs = [
  _Tab(Icons.home_rounded,            Icons.home_outlined),
  _Tab(Icons.live_tv_rounded,        Icons.live_tv_outlined),
  _Tab(Icons.movie_creation_rounded, Icons.movie_creation_outlined),
  _Tab(Icons.video_library_rounded,  Icons.video_library_outlined),
  _Tab(Icons.search_rounded,         Icons.search_rounded),
  _Tab(Icons.favorite_rounded,       Icons.favorite_border_rounded),
  _Tab(Icons.settings_rounded,       Icons.settings_outlined),
];

// A non-navigation rail action (refresh content). Sits between Favourites and
// Settings; activating it force-refreshes the active playlist.
const _refreshTab = _Tab(Icons.refresh_rounded, Icons.refresh_rounded);

List<String> _tabLabels(AppStrings s) => [
  s.home, s.liveTV, s.movies, s.series, s.search, s.favourites, s.settings,
];

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _railExpanded = false;
  DateTime? _lastBackAt;

  void _goTab(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  // Force-refresh the active playlist's content (rail "Refresh" item). Wipes
  // cached lists and re-runs the content providers (→ network).
  void _refreshContent() {
    final pid = StorageService.activePlaylistId;
    if (pid != null) ContentCacheService.invalidatePlaylist(pid);
    invalidateAllContent(ref);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Refreshing content…'),
        duration: Duration(seconds: 2),
      ));
  }

  // Back behaviour:
  //   • On a sub-tab → return to the Home tab.
  //   • On the Home tab → first Back shows a hint; a second Back within 2s
  //     opens an "Exit?" confirmation (defaulting to No).
  void _onBack() {
    if (widget.navigationShell.currentIndex != 0) {
      _goTab(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      _lastBackAt = null;
      _showExitDialog();
    } else {
      _lastBackAt = now;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Press Back again to exit'),
          duration: Duration(seconds: 2),
        ));
    }
  }

  void _showExitDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Exit WiseVodPlayer?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to close the app?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          // "No" is the default (autofocused) choice.
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5252)),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s      = ref.watch(stringsProvider);
    final labels = _tabLabels(s);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: _TVShell(
        shell: widget.navigationShell,
        currentIndex: widget.navigationShell.currentIndex,
        tabLabels: labels,
        onTabTap: _goTab,
        onRefresh: _refreshContent,
        expanded: _railExpanded,
        onToggleExpand: () => setState(() => _railExpanded = !_railExpanded),
      ),
    );
  }
}

// ── TV / wide — premium side rail ────────────────────────────────────────────

class _TVShell extends StatefulWidget {
  const _TVShell({
    required this.shell,
    required this.currentIndex,
    required this.tabLabels,
    required this.onTabTap,
    required this.onRefresh,
    required this.expanded,
    required this.onToggleExpand,
  });
  final StatefulNavigationShell shell;
  final int currentIndex;
  final List<String> tabLabels;
  final ValueChanged<int> onTabTap;
  final VoidCallback onRefresh;
  final bool expanded;
  final VoidCallback onToggleExpand;

  @override
  State<_TVShell> createState() => _TVShellState();
}

class _TVShellState extends State<_TVShell> {
  // The rail and the page live in separate focus scopes; directional focus
  // can't reliably cross between them, so we bridge explicitly:
  //   • _railFocusNode  — the active rail item; content's Left-at-edge targets it.
  //   • _contentScope   — the page scope; the rail's Right targets it.
  final FocusNode _railFocusNode = FocusNode(debugLabel: 'railActive');
  final FocusScopeNode _contentScope = FocusScopeNode(debugLabel: 'content');

  @override
  void initState() {
    super.initState();
    // Default initial focus to the rail (Home), after the first frame so it
    // beats any autofocus inside the page content (which used to steal it,
    // landing the user on the refresh button instead of the rail).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _railFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _railFocusNode.dispose();
    _contentScope.dispose();
    super.dispose();
  }

  void _focusContent() {
    if (_tryFocusContent()) return;
    // The page may still be building its first focusables (async content load)
    // — retry once after the frame so Right reliably enters the content instead
    // of feeling dead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryFocusContent();
    });
  }

  // Focuses the first concrete focusable inside the content scope. requestFocus
  // on the scope alone does NOT reliably descend into the page's nested
  // Navigator focus scope, so we target a node directly (works across scopes).
  bool _tryFocusContent() {
    for (final node in _contentScope.traversalDescendants) {
      node.requestFocus();
      return true;
    }
    return false;
  }

  // Bridges content → rail. Returns true (handled) for Left so we control the
  // move: stay within the page if there's something to the left, otherwise
  // hop back to the side rail (which lives in an outer focus scope).
  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final moved = FocusManager.instance.primaryFocus
              ?.focusInDirection(TraversalDirection.left) ??
          false;
      if (!moved) _railFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Focus(
            skipTraversal: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: widget.expanded ? 196 : 64,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  right: BorderSide(
                    color: AppColors.divider,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Logo / toggle button
                  GestureDetector(
                    onTap: widget.onToggleExpand,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Row(
                        children: [
                          const ClapperLogo(size: 36),
                          if (widget.expanded) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('WiseVod',
                                      style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: -0.3)),
                                  Text('Player',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.expanded) _RailPlaylistName(),
                  const SizedBox(height: 8),
                  Divider(color: AppColors.divider, height: 1, indent: 10, endIndent: 10),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Navigation tabs Home..Favourites (indices 0–5).
                          for (var i = 0; i < 6; i++)
                            _TVRailItem(
                              tab: _tabs[i],
                              label: widget.tabLabels[i],
                              selected: widget.currentIndex == i,
                              expanded: widget.expanded,
                              autofocus: i == 0,
                              // The active tab carries the shared node so the
                              // page content can hand focus back to the rail.
                              focusNode: i == widget.currentIndex
                                  ? _railFocusNode
                                  : null,
                              onTap: () => widget.onTabTap(i),
                              onMoveRight: _focusContent,
                            ),
                          // Refresh action (between Favourites and Settings).
                          _TVRailItem(
                            tab: _refreshTab,
                            label: 'Refresh',
                            selected: false,
                            expanded: widget.expanded,
                            autofocus: false,
                            onTap: widget.onRefresh,
                            onMoveRight: _focusContent,
                          ),
                          // Settings (index 6).
                          _TVRailItem(
                            tab: _tabs[6],
                            label: widget.tabLabels[6],
                            selected: widget.currentIndex == 6,
                            expanded: widget.expanded,
                            autofocus: false,
                            focusNode:
                                widget.currentIndex == 6 ? _railFocusNode : null,
                            onTap: () => widget.onTabTap(6),
                            onMoveRight: _focusContent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Profile avatar at rail bottom ──────────────────────
                  _ProfileRailButton(
                    expanded: widget.expanded,
                    onMoveRight: _focusContent,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Page content in its own focus scope so the rail can hand focus in
          // (Right), and the Focus catches Left-at-edge to hand it back out.
          Expanded(
            child: FocusScope(
              node: _contentScope,
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _onContentKey,
                child: widget.shell,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TVRailItem extends StatefulWidget {
  const _TVRailItem({
    required this.tab,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.autofocus,
    required this.onTap,
    this.focusNode,
    this.onMoveRight,
  });
  final _Tab tab;
  final String label;
  final bool selected;
  final bool expanded;
  final bool autofocus;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onMoveRight;

  @override
  State<_TVRailItem> createState() => _TVRailItemState();
}

class _TVRailItemState extends State<_TVRailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          // Right hands focus into the page content (separate focus scope).
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              widget.onMoveRight != null) {
            widget.onMoveRight!();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _focused
                ? AppColors.focus.withValues(alpha: 0.22)
                : widget.selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: _focused
                ? Border.all(color: AppColors.focus, width: 2.5)
                : widget.selected
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1)
                    : null,
            // Bright cyan glow so the focused item is unmistakable on a TV.
            boxShadow: _focused
                ? [
                    BoxShadow(
                        color: AppColors.focus.withValues(alpha: 0.55),
                        blurRadius: 12,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Active indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: 22,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                widget.selected ? widget.tab.activeIcon : widget.tab.icon,
                color: widget.selected
                    ? AppColors.primary
                    : _focused
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                size: 20,
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.selected
                        ? AppColors.primary
                        : _focused
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ── Profile avatar button — shown at bottom of TV rail ───────────────────────

class _ProfileRailButton extends ConsumerStatefulWidget {
  const _ProfileRailButton({required this.expanded, this.onMoveRight});
  final bool expanded;
  final VoidCallback? onMoveRight;

  @override
  ConsumerState<_ProfileRailButton> createState() => _ProfileRailButtonState();
}

class _ProfileRailButtonState extends ConsumerState<_ProfileRailButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Semantics(
      button: true,
      label: 'Profile menu',
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              _showProfileMenu(context, ref);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                widget.onMoveRight != null) {
              widget.onMoveRight!();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => _showProfileMenu(context, ref),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: EdgeInsets.symmetric(
                horizontal: widget.expanded ? 10 : 6, vertical: 8),
            decoration: BoxDecoration(
              color: _focused
                  ? AppColors.focus.withValues(alpha: 0.20)
                  : AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused
                    ? AppColors.focus
                    : AppColors.primary.withValues(alpha: 0.18),
                width: _focused ? 2.0 : 1,
              ),
            ),
            child: widget.expanded
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProfileAvatar(profile: profile, size: 28),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          profile?.name ?? 'Profile',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: ProfileAvatar(profile: profile, size: 30)),
          ),
        ),
      ),
    );
  }
}

// ── Profile menu (Switch User / Exit App) ───────────────────────────────────

void _showProfileMenu(BuildContext context, WidgetRef ref) {
  final profile = ref.read(profileProvider);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileAvatar(profile: profile, size: 34),
                  const SizedBox(width: 10),
                  Text(
                    profile?.name ?? 'Profile',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            _ProfileMenuOption(
              icon: Icons.switch_account_rounded,
              label: 'Switch User',
              autofocus: true,
              onTap: () {
                Navigator.of(ctx).pop();
                context.go('/profiles/select');
              },
            ),
            _ProfileMenuOption(
              icon: Icons.exit_to_app_rounded,
              label: 'Exit App',
              danger: true,
              onTap: () {
                Navigator.of(ctx).pop();
                SystemNavigator.pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileMenuOption extends StatefulWidget {
  const _ProfileMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final bool danger;

  @override
  State<_ProfileMenuOption> createState() => _ProfileMenuOptionState();
}

class _ProfileMenuOptionState extends State<_ProfileMenuOption> {
  bool _focused = false;
  static const _danger = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? _danger : AppColors.primary;
    return Semantics(
      button: true,
      label: widget.label,
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 264,
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _focused
                  ? accent.withValues(alpha: 0.16)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused
                    ? accent.withValues(alpha: 0.7)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: accent, size: 22),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.danger ? _danger : AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

// ── Active playlist name in the rail header (reactive to switches) ───────────

class _RailPlaylistName extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the playlists list rebuilds this when the active one changes.
    ref.watch(playlistsProvider);
    final id = StorageService.activePlaylistId;
    final name = id != null ? (StorageService.getPlaylist(id)?.name ?? '') : '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 2),
      child: Row(
        children: [
          Icon(Icons.dns_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

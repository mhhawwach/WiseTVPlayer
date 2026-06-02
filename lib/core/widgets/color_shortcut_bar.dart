import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A slim, colour-coded shortcut bar that mirrors the TV remote's coloured
/// buttons — the pattern popular IPTV apps use:
///
///   • Red    → Search
///   • Blue   → Sort
///   • Yellow → Favourite the highlighted item
///
/// (Green is intentionally left free.)
///
/// Wrap a screen body in this. It draws a hint bar across the top and listens
/// for the matching colour keys bubbling up from the focused descendant,
/// invoking the supplied callbacks. The chips are also tappable for pointer /
/// touch devices. Pass `null` for an action to hide its chip and ignore its key.
class ColorShortcuts extends StatelessWidget {
  const ColorShortcuts({
    super.key,
    required this.child,
    this.onSearch,
    this.onSort,
    this.onFavouriteKey,
    this.onFavouriteTap,
    this.favouriteLabel = 'Favourite',
  });

  final Widget child;
  final VoidCallback? onSearch;
  final VoidCallback? onSort;

  /// Fired by the YELLOW remote button — e.g. favourite the highlighted item.
  final VoidCallback? onFavouriteKey;

  /// Fired when the Favourites chip is tapped with a pointer (phones / mouse).
  /// Falls back to [onFavouriteKey] when null.
  final VoidCallback? onFavouriteTap;

  /// Label shown on the yellow chip ("Favourite" while browsing a grid).
  final String favouriteLabel;

  static const _red = Color(0xFFE53935);
  static const _blue = Color(0xFF2196F3);
  static const _yellow = Color(0xFFFBC02D);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.colorF0Red && onSearch != null) {
      onSearch!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.colorF3Blue && onSort != null) {
      onSort!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.colorF2Yellow && onFavouriteKey != null) {
      onFavouriteKey!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (onSearch != null)
        _Chip(color: _red, icon: Icons.search_rounded, label: 'Search', onTap: onSearch!),
      if (onSort != null)
        _Chip(color: _blue, icon: Icons.sort_rounded, label: 'Sort', onTap: onSort!),
      if (onFavouriteKey != null || onFavouriteTap != null)
        _Chip(
          color: _yellow,
          icon: Icons.star_rounded,
          label: favouriteLabel,
          onTap: onFavouriteTap ?? onFavouriteKey!,
        ),
    ];

    // skipTraversal keeps the wrapper out of D-pad traversal while still
    // sitting in the focus tree as an ancestor — so colour keys pressed on a
    // focused grid card bubble up here and get handled.
    return Focus(
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chips.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    chips[i],
                  ],
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: 34,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }
}
